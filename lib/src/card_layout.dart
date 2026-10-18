import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'card_fan_spread.dart';

/// 一次布局计算的结果。
///
/// 几何（牌尺寸、每张牌的目标位置 / 角度）在 build 阶段算一次，
/// paint 阶段只做变换与贴图，避免每帧重复计算。
///
/// 收拢时是正面竖立的一叠牌（展牌叠在中间、开扇为未旋转状态），
/// 展开时两侧同时向外散开。
sealed class CardSpreadLayout {
  const CardSpreadLayout._({
    required this.mode,
    required this.direction,
    required this.cardCount,
    required this.cardWidth,
    required this.cardHeight,
    required this.drawOrder,
    required this.shapedDelays,
    required this.key,
  });

  final FanSpreadMode mode;

  /// 展开的左右方向（四种模式通用，见 [SpreadDirection]）。
  final SpreadDirection direction;
  final int cardCount;
  final double cardWidth;
  final double cardHeight;

  /// 绘制顺序（同时决定遮挡关系：后画的压在先画的上面）。
  final List<int> drawOrder;

  /// 每张牌「出发顺序」的整形值（[delayOf] 经 0.85 次幂之后的结果）。
  ///
  /// 逐帧（52 张 × 60fps）调用 [cardProgressAt] 时会反复算到它，而它只与
  /// 牌数和模式有关，所以在布局阶段一次算好；顺带去掉每帧 52 次 `math.pow`
  ///（那是动态分派的 num 运算，实测占单帧 CPU 的大头）。
  final List<double> shapedDelays;

  /// 布局指纹，用于 [CustomPainter.shouldRepaint] 快速判断是否需要重绘。
  final String key;

  /// 本地坐标系中单张牌的位置。
  Rect get localCardRect;

  Size get cardSize => Size(cardWidth, cardHeight);

  /// 第 i 张牌的出发顺序，0 = 最先出发，1 = 最后出发。
  ///
  /// 开扇 / S 扇：沿脊线从起点那端先转出去，末端最后跟上（[direction] 决定
  /// 哪一端是起点）。
  /// 展牌：中间的牌先滑出去，两端最后跟上（两侧同时向外散开）。
  /// 双手开扇：两扇各自从两手之间的接缝向两端张开，[direction] 决定哪只手先动。
  double delayOf(int i) => _delayAt(mode, direction, cardCount, i);

  /// [delayOf] 的纯函数版本：布局阶段要按它预计算 [shapedDelays]，
  /// 与 [delayOf] 共用同一份公式，避免两处写法漂移。
  static double _delayAt(
    FanSpreadMode mode,
    SpreadDirection direction,
    int n,
    int i,
  ) {
    if (n <= 1) return 0;
    switch (mode) {
      case FanSpreadMode.fan:
      case FanSpreadMode.sFan:
        // 沿脊线推进：起点那端先出发，末端最后跟上。
        return direction == SpreadDirection.leftToRight
            ? i / (n - 1)
            : 1 - i / (n - 1);
      case FanSpreadMode.tableSpread:
        // 中间的牌先出发、两端最后跟上：两侧同时向外散开。
        return ((n - 1) / 2 - i).abs() / ((n - 1) / 2);
      case FanSpreadMode.twoHandFan:
        // 两扇从两手之间的接缝同时向各自的外侧张开；[direction] 决定哪只手
        // 先动——先动的那只手走完前半程，另一只手再跟上（各占一半行程）。
        final base = ((n - 1) / 2 - i).abs() / ((n - 1) / 2);
        final left = n ~/ 2;
        final isFirstHand = direction == SpreadDirection.leftToRight
            ? i < left
            : i >= left;
        return isFirstHand ? base * 0.5 : 0.5 + base * 0.5;
    }
  }

  /// 布局阶段算好的 [shapedDelays]（[cardProgressAt] 用它替代逐帧 `math.pow`）。
  static List<double> _shapedDelaysOf(
    FanSpreadMode mode,
    SpreadDirection direction,
    int n,
  ) {
    return List<double>.generate(n, (i) {
      final d = _delayAt(mode, direction, n, i);
      if (d <= 0) return 0.0;
      if (d >= 1) return 1.0;
      return math.pow(d, 0.85).toDouble();
    }, growable: false);
  }

  /// 第 i 张牌在总进度 [progress] 下的单卡进度（含逐张错峰与缓动曲线）。
  ///
  /// 逐张错峰：靠后的牌略微提前出发，模拟手势逐渐加速，
  /// 既能拉开层次感，又不会让最后几张显得拖沓。
  ///
  /// 画家（每帧）与手势命中测试（判断触摸是否落在某张牌上）
  /// 必须共用这一方法，否则拖动判定会与画面不一致。
  double cardProgressAt(
    int i,
    double progress, {
    required double stagger,
    required Curve curve,
  }) {
    if (progress >= 1) return 1;
    final shaped = shapedDelays[i];
    final raw = (progress * (1 + stagger) - shaped * stagger).clamp(0.0, 1.0);
    return curve.transform(raw);
  }

  factory CardSpreadLayout.compute({
    required FanSpreadMode mode,
    required Size canvas,
    required int cardCount,
    required double fanAngle,
    required double tableStepRatio,
    required double tableArcLift,
    required SpreadDirection direction,
    required double fanTierRatio,
    required double fanPivotX,
    required double fanPivotLift,
  }) {
    return switch (mode) {
      FanSpreadMode.tableSpread => TableSpreadLayout._(
        canvas: canvas,
        cardCount: cardCount,
        stepRatio: tableStepRatio,
        arcLift: tableArcLift,
        direction: direction,
      ),
      // 双层错落只属于开扇（大扇）：S 扇的牌沿 S 形脊线摊开，
      // 再按奇偶沿各自长轴错开两层只会糊掉那条 S，所以直接忽略该参数。
      FanSpreadMode.fan => FanSpreadLayout._(
        mode: mode,
        direction: direction,
        canvas: canvas,
        cardCount: cardCount,
        fanAngle: fanAngle,
        tierRatio: fanTierRatio,
        pivotX: fanPivotX,
        pivotLift: fanPivotLift,
      ),
      // 枢轴位置同样只属于开扇：S 扇的牌柄钉在脊线上，
      // 挪动牌内的枢轴只会让牌偏离脊线，故固定用默认值（行为不变）。
      FanSpreadMode.sFan => FanSpreadLayout._(
        mode: mode,
        direction: direction,
        canvas: canvas,
        cardCount: cardCount,
        fanAngle: fanAngle,
        tierRatio: 0,
        pivotX: kDefaultFanPivotX,
        pivotLift: kDefaultFanPivotLift,
      ),
      // 双手开扇：参数与开扇 / 反开扇一致（枢轴可调），但两扇在上下两端交叉
      // 盖在一起，双层错落只会糊成一团，故忽略 fanTierRatio；每边的摆幅封顶
      // kMaxTwoHandFanAngle（220°），超出部分在此钳掉——指纹用的也是钳后
      // 的值，拖过 220° 不会触发无谓的重排。
      FanSpreadMode.twoHandFan => FanSpreadLayout._(
        mode: mode,
        direction: direction,
        canvas: canvas,
        cardCount: cardCount,
        fanAngle: fanAngle.clamp(kMinFanAngle, kMaxTwoHandFanAngle),
        tierRatio: 0,
        pivotX: fanPivotX,
        pivotLift: fanPivotLift,
      ),
    };
  }
}

/// 一条「脊线」：每张牌的枢轴相对公共原点的偏移（归一化，牌高 = 1）
/// 与朝向角（弧度，0 = 竖直向上）。
typedef _Spine = ({List<Offset> pivots, List<double> angles});

/// 开扇 / 反开扇 / S 扇 / 双手开扇。
///
/// 收拢时每张牌正面竖立（角度 0），展开时转到自己的目标角度 [targetAngles]，
/// 同时把自己的枢轴挪到 [pivotOffsets] 指出的位置（是否随进度长出来见
/// [pivotFollowsProgress]）。
///
/// 普通开扇 / 反开扇的 [pivotOffsets] 恒为 0：所有牌钉在同一个点上，
/// 只靠朝向角散开成圆扇，收拢态是公共原点上的**一叠**。S 扇的枢轴沿一条
/// S 形脊线依次排开、牌垂直于脊线的切向朝外辐射，整叠牌因此摊成一条
/// **竖立的 S 形牌带**（Cardistry 的 S Fan）。双手开扇则是左右手各捏一扇：
/// [pivotOffsets] 是 ±d 两个手握点（见 [_twoHandFanHandSpread]）且**恒生效**
/// （收拢态即**左右两叠**），朝向角分成左右两个半区——左手朝左扫开、右手朝右
/// 扫开，两扇在上下两端交叉。
///
/// [tierRatio] 大于 0 时开启「双层错落」：奇数下标的牌沿自身长轴向外推出
/// [tierOffsets]（模拟完美洗牌后两叠牌交错的状态），画面从单层扇形变成
/// 内 / 外两层错落的「双层扇 / 大扇（Giant Fan）」。
///
/// 开扇 / 反开扇的「圆心」（枢轴）落在牌内的哪个位置由 [pivotX] / [pivotLift]
/// 决定（归一化后经 [pivotOffset] 暴露给画家与命中测试）：默认在牌边中心
/// 附近，也可以沿牌宽方向挪到任意一侧、或沉到牌边下方——所有牌仍绕各自
/// 同一个相对位置旋转，扇形随之偏轴 / 垂挂，呈现不同的视觉效果。
/// S 扇的牌柄钉在脊线上，这两个参数被布局固定为默认值。
class FanSpreadLayout extends CardSpreadLayout {
  const FanSpreadLayout._raw({
    required super.mode,
    required super.direction,
    required super.cardCount,
    required super.cardWidth,
    required super.cardHeight,
    required super.shapedDelays,
    required super.key,
    required this.fanAngle,
    required this.origin,
    required this.pivotOffset,
    required this.targetAngles,
    required this.tierOffsets,
    required this.pivotOffsets,
    required this.pivotFollowsProgress,
    required super.drawOrder,
  }) : super._();

  /// 扑克牌宽高比。
  static const double _aspect = 0.70;

  /// 双手开扇里两只手（两扇各自的枢轴）离公共原点的距离（牌高的倍数）。
  ///
  /// 默认的牌内枢轴（pivotX 0.5 / pivotLift −0.06）下，一扇 220° 时它的
  /// 上 / 下尖端横向大约探出枢轴 0.65 牌高，所以 d = 0.65 时两扇刚好相触。
  /// 取 0.55：两只手分居两侧、各自捏一扇（两扇的收拢点一眼可辨），中缝处两扇
  /// 还相交约 0.2 牌高、上下各留一个缺口。再小两扇会糊成一整块（0.4 时中缝
  /// 几乎被交叉的牌填满），再大则散成两把互不相干的扇子（0.65 起完全分离），
  /// 而且整体变宽、牌会被缩得更小。
  static const double _twoHandFanHandSpread = 0.55;

  /// 双手开扇里每扇的「中心方向」转到正外侧所需的摆幅（角度制）。
  ///
  /// 两扇的中心方向从竖直（收拢）转到正左右（各自朝外），到 90° 就不再往外倒，
  /// 之后只加宽扇面。这样任何 ≥90° 的摆幅都是**以正左右为中心、上下平分空间**
  /// 的扇形（上下两端留等大的缺口）。
  ///
  /// 不能让它一直线性地长到 [kMaxTwoHandFanAngle]：那样 140° 时中心才转到
  /// 57°，两扇整体朝上歪、中下部空出一大块，左右也不居中——正是「看起来是
  /// 倾斜的、下方会有空白」的原因。
  static const double _twoHandFanCenterKnee = 90;

  /// 牌的四个角，归一化坐标（牌高 = 1），原点在枢轴 [px], [py]。
  ///
  /// 枢轴在牌内的相对位置不再固定：沿牌宽方向（0 = 左边缘，1 = 右边缘）
  /// 与相对牌底边的沉深（0 = 底边，正 = 沉到下方，负 = 抬到牌内）都可调，
  /// 求包围盒时对每张牌的四个角做旋转（+ 层间错落）即可。
  static List<Offset> _baseCorners(double px, double py) => <Offset>[
    Offset(-px, -py),
    Offset(_aspect - px, -py),
    Offset(-px, 1 - py),
    Offset(_aspect - px, 1 - py),
  ];

  /// 本布局是按这个摆幅算出来的（角度制）。
  ///
  /// 双手开扇已按 [kMaxTwoHandFanAngle] 钳过——与算脊线用的是同一个值，
  /// 不会出现「布局按 220° 画、字段里却记着 300°」。拖动时求「顶牌朝向角
  /// 对摆幅的变化率」要用它（见 [targetAngleRateOf]）。
  final double fanAngle;

  /// 枢轴在画布中的位置。
  final Offset origin;

  /// 枢轴相对牌左上角的偏移（像素）。
  final Offset pivotOffset;

  /// 每张牌的最终朝向角（弧度，0 = 竖直向上，即收拢时整叠牌的朝向）。
  final List<double> targetAngles;

  /// 每张牌沿自身长轴（远离枢轴的方向）额外推出的距离（像素）。
  ///
  /// 双层错落关闭时全为 0；开启后奇数下标（外层）为 `tierRatio × 牌高`。
  final List<double> tierOffsets;

  /// 每张牌的枢轴相对 [origin] 的偏移（像素）。
  ///
  /// [pivotFollowsProgress] 为 true 时按进度线性插值：收拢时（进度 0）所有牌
  /// 都在 [origin] 上叠成一摞，展开后第 i 张牌的枢轴落在 `origin + pivotOffsets[i]`。
  /// 为 false 时这个偏移**始终生效**：收拢时每张牌就已经待在自己的枢轴上。
  ///
  /// 普通开扇 / 反开扇全为 `Offset.zero`；S 扇的枢轴沿 S 形脊线排开（随进度
  /// 从原点长出去）；双手开扇是 ±d 两个手握点（一直就在那里）。
  final List<Offset> pivotOffsets;

  /// [pivotOffsets] 是否随展开进度「长出来」。
  ///
  /// true（开扇 / 反开扇 / S 扇）：收拢时整叠牌重合在公共原点，枢轴随进度
  /// 挪到各自的位置——S 扇的脊线就是从这一叠里长出来的。
  ///
  /// false（双手开扇）：枢轴是两只手的固定位置，收拢时就是**左右两叠**
  /// （各在自己那只手上），全程不合并——两只手不会在动画里合成一只手。
  final bool pivotFollowsProgress;

  /// 第 [i] 张牌的**目标朝向角**随 [fanAngle] 的局部变化率（度/度）。
  ///
  /// 拖「最顶的那张牌」调摆幅时用它把「手指转过多少度」换算成「摆幅该变多少
  /// 度」：符号即「手指往哪边转是开扇」，倒数就是让牌 1:1 跟手的增益。
  ///
  /// 普通开扇 / 反开扇恒为 ∓0.5（顶牌正好落在扇形的半边：摆幅变 2° 它转 1°，
  /// 与拖动时用的增益 2 正好互为倒数）；双手开扇则**左右两扇符号相反**——左扇
  /// 的顶牌贴在扇形内缘，摆幅越大它越往内侧倒（过了 [_twoHandFanCenterKnee]
  /// 还会翻回来），写死一个方向必然错一半；S 扇的顶牌在牌带末端，变化率被
  /// 「垂直度」的爬升放大、还会变号，那边另有一套按弧长折算的增益。
  ///
  /// 用有限差分（对同一套脊线公式取相邻两个摆幅）算而不是手写导数：脊线公式
  /// 里的钳位与拐点抄一遍必然漂移。
  double targetAngleRateOf(int i) {
    const eps = 0.5; // 度
    final hi = math.min(fanAngle + eps, _maxFanAngleOf(mode));
    final lo = math.max(fanAngle - eps, kMinFanAngle);
    if (hi - lo <= 1e-9) return 0;
    final a = _spineOf(mode, direction, cardCount, hi).angles[i];
    final b = _spineOf(mode, direction, cardCount, lo).angles[i];
    return (a - b) * 180 / math.pi / (hi - lo);
  }

  @override
  Rect get localCardRect => Rect.fromLTWH(0, 0, cardWidth, cardHeight);

  /// 牌枢轴到牌心的距离（牌高的倍数），即 `0.5 + kDefaultFanPivotLift`。
  ///
  /// S 扇里**牌的中心**沿 S 形脊线排布（这样牌带轮廓才对称、上下两个碗一样大），
  /// 而枢轴钉在牌底边内侧，所以要沿牌朝向反推这个距离才得到枢轴位置。
  /// 捏牌线因此自然偏在牌带中心线内侧——和真实持牌一致。
  static const double _sFanPivotToCenter = 0.5 + kDefaultFanPivotLift;

  /// 「牌垂直于脊线」长到位的摆幅（弧度）。
  ///
  /// 完全收拢（Δ → 0）时脊线缩成一个点，此时若仍按垂直算，整叠牌会横躺
  /// 成一摞；让垂直本身随摆幅长出来，收拢态就与其它模式一致（竖直的一摞），
  /// 摆到 30° 以后牌就一直垂直于脊线。
  static const double _sFanPerpendicularRamp = math.pi / 6;

  /// S 扇脊线的半径（相对牌高）。
  ///
  /// 脊线由两段半径为 `_sFanRadius × 牌高` 的反向圆弧拼接而成：半径越小，
  /// S 拐得越急、两个「碗」越圆、牌带越饱满（0.6 时 S 的摆幅只有 0.26 张牌，
  /// 被牌长淹没，摊出来是个 C）；越大则弧越平缓、牌带越长越薄（2.0 时两段弧
  /// 被拉得过直，整条 S 又细又长、上下两个碗都不饱满）。
  ///
  /// 1.0 是逐次收紧的结果（2.0 → 1.4 → 1.0）：碗够圆、牌带够饱满，又不至于
  /// 缩成 C（到 0.8 时两端牌的外缘已能看到明显的锯齿感）。
  static const double _sFanRadius = 1.0;

  /// 某一模式下 `fanAngle` 的上限（角度制），与构造断言 / 布局钳位一致。
  static double _maxFanAngleOf(FanSpreadMode mode) => switch (mode) {
    FanSpreadMode.sFan => kMaxSFanAngle,
    FanSpreadMode.twoHandFan => kMaxTwoHandFanAngle,
    _ => kMaxFanAngle,
  };

  /// 某一模式的脊线（每张牌的枢轴与朝向角）。
  static _Spine _spineOf(
    FanSpreadMode mode,
    SpreadDirection direction,
    int cardCount,
    double fanAngle,
  ) => switch (mode) {
    FanSpreadMode.sFan => _sFanSpine(direction, cardCount, fanAngle),
    // 双手开扇的两只手本来就分居左右，方向只影响叠压与动画先后，
    // 不改几何（见 [_drawOrderOf]）。
    FanSpreadMode.twoHandFan => _twoHandFanSpine(cardCount, fanAngle),
    // 开扇：所有牌钉在同一个枢轴上，只靠朝向角散开。
    _ => _pointedFanSpine(direction, cardCount, fanAngle),
  };

  /// 绘制顺序（同时决定遮挡关系：后画的压在上面）。
  ///
  /// 默认按索引递增（后出发的牌压在先出发的上面）：开扇两种方向都如此，
  /// 与「方向」改造前的行为一致。
  ///
  /// 两处需要反序：
  /// - S 扇的 rightToLeft：整条牌带是水平镜像 + 牌序反转（见 [_sFanSpine]），
  ///   绘制顺序不跟着反的话，镜像后的叠压层次就不是原图的镜像了；
  /// - 双手开扇：两只手分居左右，[direction] 决定哪只手先动——先动的那只手
  ///   在下（先画），另一半压在上层（leftToRight 时右手后动 → 右半叠在上）。
  static List<int> _drawOrderOf(
    FanSpreadMode mode,
    SpreadDirection direction,
    int cardCount,
  ) {
    final descending =
        (mode == FanSpreadMode.sFan || mode == FanSpreadMode.twoHandFan) &&
        direction == SpreadDirection.rightToLeft;
    return List<int>.generate(
      cardCount,
      (i) => descending ? cardCount - 1 - i : i,
      growable: false,
    );
  }

  /// 开扇：所有牌钉在同一个枢轴上，只靠朝向角散开。
  static _Spine _pointedFanSpine(
    SpreadDirection direction,
    int cardCount,
    double fanAngle,
  ) {
    final sweep = fanAngle * math.pi / 180;
    final half = sweep / 2;
    final start = direction == SpreadDirection.leftToRight ? -half : half;
    final step = direction == SpreadDirection.leftToRight ? sweep : -sweep;
    return (
      pivots: List<Offset>.filled(cardCount, Offset.zero, growable: false),
      angles: List<double>.generate(cardCount, (i) {
        final t = cardCount <= 1 ? 0.5 : i / (cardCount - 1);
        return start + step * t;
      }, growable: false),
    );
  }

  /// 脊线起点的切向（弧度）。
  ///
  /// 两段等长反向圆弧拼成的 S，其**弦向**正好是起点切向再减去半个摆幅
  /// （`φ0 − Δ/2`）。所以让它跟着摆幅走（`Δ/2`），整条 S 的弦向就恒为竖直：
  /// 牌带上下立起来、S 的来回摆动是左右方向的——视觉上才是「竖立的 S」，
  /// 而不是斜着甚至躺倒的 S。
  ///
  /// 牌朝向取的是「相对起点转了多少」，所以这个值只决定整条 S 摊在画面里的
  /// 朝向，不影响牌与脊线的关系。
  static double _sFanStartAngle(double fanAngle) =>
      fanAngle * math.pi / 180 / 4;

  /// S 扇（Cardistry 的 S Fan）。
  ///
  /// 与普通开扇「所有牌共用一个枢轴」不同：这里**牌的中心**沿一条 **S 形
  /// 脊线**依次排开，牌垂直于脊线的切向朝外辐射（真实开扇里牌就是从捏牌线
  /// 辐射出去的），于是整叠牌摊成一条 **S 形的牌带**。
  ///
  /// 之所以按「牌心在脊线上」而不是「枢轴在脊线上」：牌带的轮廓是由牌身堆出来
  /// 的，对称与否要看牌心连线。枢轴钉在牌底边内侧（不在牌心），若直接把枢轴
  /// 排在脊线上，整条牌带会偏向一侧，S 的两半就被推成一侧远一侧近——上碗比
  /// 下碗大出将近一张牌长。按牌心排布后脊线本身就是对称的 S，牌带轮廓随之
  /// 对称，上下两个碗一样大；捏牌线则自然偏在牌带中心线内侧，与真实持牌一致。
  ///
  /// 脊线由两段**曲率相反**的圆弧拼接而成：切向先从 φ0 转到 φ0 − Δ，
  /// 再转回 φ0。「转出去再转回来」正是 S 的来源——普通开扇的切向是单向扫过
  /// 的，无论角度调多大都只会得到圆扇。
  ///
  /// 起点切向取 Δ/2，两段等长反向圆弧的**弦向**正好因此恒为竖直
  /// （弦向 = φ0 − Δ/2）：整条 S 在画面里是竖立的，而不是斜着甚至躺倒的。
  /// 又因为首尾两张牌垂直于脊线、朝向相同，牌带的总跨度正好等于脊线弦向，
  /// 不会被扇形本身甩成斜的。
  ///
  /// [fanAngle] = 0 时脊线长度归零、「垂直」也还没长出来，所有牌保持竖直，
  /// 整叠牌仍是一摞竖直重合的牌——与其它模式的「收拢」语义保持一致。
  static _Spine _sFanSpine(
    SpreadDirection direction,
    int cardCount,
    double fanAngle,
  ) {
    // 脊线单段弧的转角 Δ。若把 fanAngle 直接当作 Δ，240° 的摆幅会让牌带
    // 绕回来卷成螺旋；折半后默认 220° 对应 Δ = 110°，是条舒展的 S。
    final turn = fanAngle * math.pi / 180 / 2;
    final startAngle = _sFanStartAngle(fanAngle); // 起点切向 φ0 = Δ/2
    final arc = turn * _sFanRadius; // 单段弧长
    final step = cardCount <= 1 ? 0.0 : 2 * arc / (cardCount - 1);
    // 「牌垂直于脊线」随摆幅长出来：收拢时脊线缩成一个点，此时按垂直算会让
    // 整叠牌横躺，所以让垂直度从 0 平滑长到 1（见 [_sFanPerpendicularRamp]）。
    final perpendicular = (turn / _sFanPerpendicularRamp).clamp(0.0, 1.0);
    final inflectionAngle = startAngle - turn;
    final pivots = <Offset>[];
    final angles = <double>[];
    for (var i = 0; i < cardCount; i++) {
      // 按弧长取点：第 i 张牌在脊线上走过的距离 s = i·step。
      final s = i * step;
      // 脊线是两段曲率相反的圆弧，直接用圆弧解析式取点，不用步进积分：
      // 步进法在「跨拐点的那一步」会把整步都按同一段弧的曲率算，偶数张牌时
      // （拐点恰好落在两步之间）第二段的转角会差出一步，S 就歪了、也不再对称。
      // 圆弧位移 = (1/κ)·(cos φ起 − cos φ, sin φ起 − sin φ)。
      // 拐点位置（第一段弧在 s = arc 处）先算出来，第二段从它接上去。
      final inflectionPosition =
          -Offset(
            math.cos(startAngle) - math.cos(inflectionAngle),
            math.sin(startAngle) - math.sin(inflectionAngle),
          ) *
          _sFanRadius;
      final onFirstArc = s <= arc;
      final from = onFirstArc ? startAngle : inflectionAngle;
      final phi = onFirstArc
          ? startAngle - s / _sFanRadius
          : inflectionAngle + (s - arc) / _sFanRadius;
      final position =
          (onFirstArc ? Offset.zero : inflectionPosition) +
          Offset(
                math.cos(from) - math.cos(phi),
                math.sin(from) - math.sin(phi),
              ) *
              _sFanRadius *
              (onFirstArc ? -1.0 : 1.0);
      // 牌的中心排在脊线上（见 [_sFanSpine] 的说明），枢轴在牌底边内侧，
      // 因此沿牌朝向反推 _sFanPivotToCenter 得到枢轴位置。
      final angle = phi - math.pi / 2 * perpendicular;
      pivots.add(
        position -
            Offset(math.sin(angle), -math.cos(angle)) * _sFanPivotToCenter,
      );
      angles.add(angle);
    }
    // rightToLeft：整条 S 水平镜像（x 取反、朝向角取反），同时把牌序反过来
    // ——第 i 张牌落到镜像脊线的第 n−1−i 个位置上。两者一起做，得到的才是
    // leftToRight 的镜像（叠压层次见 [_drawOrderOf]，那边同样反了序）；
    // 只镜像不反序的话，牌沿脊线的排布方向就与「先出发的那一端」对不上。
    if (direction == SpreadDirection.rightToLeft) {
      return (
        pivots: List<Offset>.generate(
          cardCount,
          (i) => Offset(
            -pivots[cardCount - 1 - i].dx,
            pivots[cardCount - 1 - i].dy,
          ),
          growable: false,
        ),
        angles: List<double>.generate(
          cardCount,
          (i) => -angles[cardCount - 1 - i],
          growable: false,
        ),
      );
    }
    return (pivots: pivots, angles: angles);
  }

  /// 双手开扇：左右手各捏一扇，对称。
  ///
  /// 整叠牌从中间分成两半：前一半（左手）朝左扇开、后一半（右手）朝右扇开。
  /// 两只手分居公共原点两侧（见 [_twoHandFanHandSpread]），各自绕自己的手握点
  /// 旋转，扇面在上下两端交叉（每边 220° 时交叉 40°）——即魔术师双手各捏半叠
  /// 牌同时展开的双手开扇。两只手的位置**始终生效**（[pivotFollowsProgress]
  /// 为 false）：收拢（进度 0）时就是左右两叠，不会合并成一叠。
  ///
  /// [fanAngle] 是**每一边**的摆幅（与开扇 / 反开扇同义，但封顶
  /// [kMaxTwoHandFanAngle]，由 `CardSpreadLayout.compute` 钳好后传入）：
  /// 再大两扇就会互相盖住。0° 时摆幅为零，所有牌保持竖直重合（与其它模式的
  /// 「收拢」语义一致）；摆幅长到 [_twoHandFanCenterKnee]（90°）时两扇的中心
  /// 已经落在正外侧（左扇 −90°、右扇 +90°），此后只加宽、不再继续往外倒——
  /// 于是任何 ≥90° 的摆幅都是**上下平分空间**的对称扇形，不会朝上歪。
  ///
  /// 偶数张牌时严格镜像对称：右扇第 j 张的朝向 = 左扇第（半边数 − 1 − j）张
  /// 的朝向取反（镜像把朝向角 θ 映射为 −θ），枢轴 ±d 也互为镜像。
  static _Spine _twoHandFanSpine(int cardCount, double fanAngle) {
    final degrees = fanAngle.clamp(kMinFanAngle, kMaxTwoHandFanAngle);
    final sweep = degrees * math.pi / 180;
    // 中心方向：摆幅 ≤ [_twoHandFanCenterKnee] 时按比例从竖直转出去，之后固定
    // 在正外侧（±90°）。关键在于**别一路线性长到 220°**——那样 140° 时中心才
    // 57°，两扇朝上歪、下方空一大块；中心落在正外侧时扇面才是上下平分的。
    final center = math.pi / 2 * math.min(1, degrees / _twoHandFanCenterKnee);
    final half = sweep / 2;
    final left = cardCount ~/ 2;
    final right = cardCount - left;
    return (
      pivots: List<Offset>.generate(
        cardCount,
        (i) => Offset(
          i < left ? -_twoHandFanHandSpread : _twoHandFanHandSpread,
          0,
        ),
        growable: false,
      ),
      angles: List<double>.generate(cardCount, (i) {
        if (i < left) {
          final t = left <= 1 ? 0.5 : i / (left - 1);
          return -center - half + sweep * t;
        }
        final t = right <= 1 ? 0.5 : (i - left) / (right - 1);
        return center - half + sweep * t;
      }, growable: false),
    );
  }

  factory FanSpreadLayout._({
    required FanSpreadMode mode,
    required SpreadDirection direction,
    required Size canvas,
    required int cardCount,
    required double fanAngle,
    required double tierRatio,
    required double pivotX,
    required double pivotLift,
  }) {
    // 双手开扇的两只手始终在各自位置上（收拢即左右两叠，不合并）；
    // 其余模式的枢轴都是从收拢的那一叠里「长出来」的。
    final pivotFollowsProgress = mode != FanSpreadMode.twoHandFan;

    // 脊线：每张牌的枢轴（相对公共原点）与朝向角。
    final spine = _spineOf(mode, direction, cardCount, fanAngle);

    // 枢轴在牌内的归一化位置（牌高 = 1，原点在牌左上角，y 向下）：
    // px 沿牌宽（0 = 左边缘，_aspect = 右边缘），py 沿牌高
    // （1 = 底边，>1 = 沉到牌边下方，<1 = 抬到牌面内）。
    // 越界值在此钳掉，布局层对任何输入都保持确定性。
    final px = pivotX.clamp(kMinFanPivotX, kMaxFanPivotX) * _aspect;
    final py = 1.0 + pivotLift.clamp(kMinFanPivotLift, kMaxFanPivotLift);
    final corners = _baseCorners(px, py);

    // 归一化单位（牌高 = 1）的层间错落，最终乘 scale 换算成像素。
    double tierAt(int i) => i.isOdd ? tierRatio : 0.0;

    // 展开状态的包围盒，同时并入**收拢状态**（正面竖立、未旋转）。
    //
    // 收拢时每张牌落在哪里：普通开扇 / S 扇整叠牌重合在公共原点；双手开扇的
    // 牌则各自待在自己的枢轴上（左右两叠，见 [pivotFollowsProgress]）——两叠
    // 张开角度很小时会伸到扇面包围盒之外，所以必须逐张算进去，否则收拢态会被
    // 缩放 / 居中算漏、露出画布。
    double minX = double.infinity;
    double maxX = -double.infinity;
    double minY = double.infinity;
    double maxY = -double.infinity;
    for (var i = 0; i < cardCount; i++) {
      final angle = spine.angles[i];
      final tier = tierAt(i);
      final pivot = spine.pivots[i];
      final cosValue = math.cos(angle);
      final sinValue = math.sin(angle);
      final rest = pivotFollowsProgress ? Offset.zero : pivot;
      for (final corner in corners) {
        // 收拢状态：未旋转、只挪到自己的枢轴上。
        if (corner.dx + rest.dx < minX) minX = corner.dx + rest.dx;
        if (corner.dx + rest.dx > maxX) maxX = corner.dx + rest.dx;
        if (corner.dy + rest.dy < minY) minY = corner.dy + rest.dy;
        if (corner.dy + rest.dy > maxY) maxY = corner.dy + rest.dy;

        // 展开状态：沿牌的长轴（远离枢轴）推出 tier，旋转后为
        // (tier·sin, −tier·cos)；再加上这张牌自己的枢轴相对公共原点的偏移。
        final rx =
            corner.dx * cosValue -
            corner.dy * sinValue +
            tier * sinValue +
            pivot.dx;
        final ry =
            corner.dx * sinValue +
            corner.dy * cosValue -
            tier * cosValue +
            pivot.dy;
        if (rx < minX) minX = rx;
        if (rx > maxX) maxX = rx;
        if (ry < minY) minY = ry;
        if (ry > maxY) maxY = ry;
      }
    }
    final double scale;
    if (canvas.isEmpty || maxX <= minX || maxY <= minY) {
      scale = 1;
    } else {
      scale =
          math.min(
            canvas.width / (maxX - minX),
            canvas.height / (maxY - minY),
          ) *
          0.96;
    }

    final cardHeight = scale;
    return FanSpreadLayout._raw(
      mode: mode,
      direction: direction,
      cardCount: cardCount,
      cardWidth: _aspect * scale,
      cardHeight: cardHeight,
      shapedDelays: CardSpreadLayout._shapedDelaysOf(
        mode,
        direction,
        cardCount,
      ),
      key:
          'fan|${mode.name}|${direction.name}|$cardCount|'
          '${fanAngle.toStringAsFixed(1)}|'
          '${tierRatio.toStringAsFixed(4)}|'
          '${px.toStringAsFixed(4)}|${py.toStringAsFixed(4)}|'
          '${canvas.width.toStringAsFixed(1)}x${canvas.height.toStringAsFixed(1)}',
      fanAngle: fanAngle,
      origin: Offset(
        canvas.width / 2 - (minX + maxX) / 2 * scale,
        canvas.height / 2 - (minY + maxY) / 2 * scale,
      ),
      pivotOffset: Offset(px * scale, py * scale),
      targetAngles: spine.angles,
      tierOffsets: List<double>.generate(
        cardCount,
        (i) => tierAt(i) * scale,
        growable: false,
      ),
      pivotOffsets: List<Offset>.generate(
        cardCount,
        (i) => spine.pivots[i] * scale,
        growable: false,
      ),
      pivotFollowsProgress: pivotFollowsProgress,
      drawOrder: _drawOrderOf(mode, direction, cardCount),
    );
  }
}

/// 展牌：牌沿一条弧线排列，从一端逐张摊向另一端。
///
/// [arcLift] 为正时两端上翘，为负时两端下翘（中间拱起）。
final class TableSpreadLayout extends CardSpreadLayout {
  const TableSpreadLayout._raw({
    required super.mode,
    required super.direction,
    required super.cardCount,
    required super.cardWidth,
    required super.cardHeight,
    required super.drawOrder,
    required super.shapedDelays,
    required super.key,
    required this.stackOffset,
    required this.stackRotation,
    required this.centers,
    required this.rotations,
  }) : super._();

  static const double _aspect = 0.70;

  /// 收拢时整叠牌所在的位置（起点那一侧）。
  final Offset stackOffset;

  /// 收拢时整叠牌的倾斜角。
  final double stackRotation;

  /// 每张牌最终的中心点。
  final List<Offset> centers;

  /// 每张牌最终的旋转角（沿曲线切线）。
  final List<double> rotations;

  @override
  Rect get localCardRect =>
      Rect.fromLTWH(-cardWidth / 2, -cardHeight / 2, cardWidth, cardHeight);

  factory TableSpreadLayout._({
    required Size canvas,
    required int cardCount,
    required double stepRatio,
    required double arcLift,
    required SpreadDirection direction,
  }) {
    final ratio = stepRatio.clamp(0.01, 0.5);
    final maxCh = canvas.height * 0.42;
    final cw = math.min(
      maxCh * _aspect,
      canvas.width * 0.96 / (1 + ratio * (cardCount - 1)),
    );
    final ch = cw / _aspect;
    final step = ratio * cw;
    final halfSpan = step * (cardCount - 1) / 2;
    final lift = arcLift * ch;
    final cx = canvas.width / 2;
    final centerY = canvas.height * 0.55;

    final centers = List<Offset>.generate(cardCount, (i) {
      final x = -halfSpan + step * i;
      final u = halfSpan <= 0 ? 0.0 : x / halfSpan;
      return Offset(cx + x, centerY + lift * (0.5 - u * u));
    }, growable: false);
    final rotations = List<double>.generate(cardCount, (i) {
      if (halfSpan <= 0) return 0;
      final x = -halfSpan + step * i;
      final u = x / halfSpan;
      return math.atan2(-2 * lift * u, halfSpan);
    }, growable: false);

    // [direction] 只决定遮挡关系（哪一端是「最顶那张」）：左→右时右半部分
    // 的牌压在上层，右→左时左半部分的牌压在上层。几何位置不随方向改变。
    final drawOrder = List<int>.generate(
      cardCount,
      (i) => direction == SpreadDirection.leftToRight ? i : cardCount - 1 - i,
      growable: false,
    );

    return TableSpreadLayout._raw(
      mode: FanSpreadMode.tableSpread,
      direction: direction,
      cardCount: cardCount,
      cardWidth: cw,
      cardHeight: ch,
      drawOrder: drawOrder,
      shapedDelays: CardSpreadLayout._shapedDelaysOf(
        FanSpreadMode.tableSpread,
        direction,
        cardCount,
      ),
      key:
          'table|$cardCount|${stepRatio.toStringAsFixed(4)}|'
          '${arcLift.toStringAsFixed(4)}|${direction.name}|'
          '${canvas.width.toStringAsFixed(1)}x${canvas.height.toStringAsFixed(1)}',
      stackOffset: Offset(cx, centerY + lift * 0.5),
      stackRotation: 0,
      centers: centers,
      rotations: rotations,
    );
  }
}
