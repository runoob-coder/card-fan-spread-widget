import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart'
    show
        kDoubleTapSlop,
        kDoubleTapTimeout,
        kDoubleTapTouchSlop,
        kPrimaryButton,
        PointerCancelEvent,
        PointerDownEvent,
        PointerMoveEvent,
        PointerUpEvent;
import 'package:flutter/widgets.dart';

import 'card_layout.dart';
import 'card_sprite.dart';

/// 纸牌展开模式（四类布局）。
///
/// 左右方向不再编码在模式里，统一由 [CardFanSpread.direction] 控制，
/// 四种模式共用同一个语义：见 [SpreadDirection]。
enum FanSpreadMode {
  /// 展牌摊开：类似荷官在赌桌上把牌摊成一条弧形长带。
  ///
  /// [CardFanSpread.direction] 决定**叠压顺序**：哪一端压在上层、
  /// 哪一张是「最顶那张」（可拖动的那张）。
  tableSpread,

  /// 开扇：所有牌钉在同一个枢轴（圆心）上，只靠朝向角散开成圆扇。
  ///
  /// [CardFanSpread.direction] 决定扇形从哪一端长出去：
  /// [SpreadDirection.leftToRight] 从左到右，[SpreadDirection.rightToLeft]
  /// 从右到左（即原来的「反开扇」）。收拢态下拖顶牌也能定方向：手指把顶牌
  /// 往哪边带，就建议哪个方向（见 [CardFanSpread.onDirectionChanged]）。
  fan,

  /// S 扇：牌柄沿一条 S 形脊线排开，整叠牌卷成一条 S 形的牌带
  ///（Cardistry 里的 S Fan）。
  ///
  /// 与开扇「所有牌钉在同一个枢轴上」不同，这里每张牌的枢轴沿脊线依次
  /// 挪动，牌垂直于脊线的切向朝外辐射，整叠牌摊成一条**竖立的 S 形牌带**
  /// （S 的上下两段分别朝左右反弯，中间收细）。
  /// 角度范围同样由 [CardFanSpread.fanAngle] 控制，
  /// 0° 表示完全收拢（脊线长度归零，仍是一叠重合的牌）；
  /// 它比别的模式能转得更狠——上限是 [kMaxSFanAngle]（540°）。
  ///
  /// [CardFanSpread.direction] 决定 S 的朝向：
  /// [SpreadDirection.rightToLeft] 得到**水平镜像**的 S（脊线左右翻转，
  /// 牌序也跟着反过来），[SpreadDirection.leftToRight] 是默认那条。
  sFan,

  /// 双手开扇：左右手各捏一扇，对称。
  ///
  /// 整叠牌从中间分成两半：前一半（左手）朝左扇开、后一半（右手）朝右扇开。
  /// 两只手分居两侧，各自绕自己的手握点旋转，扇面在上下两端交叉——即魔术师
  /// 双手各捏半叠牌同时展开的双手开扇。
  ///
  /// 与其它模式不同，**收拢态就是左右两叠**（各在自己那只手上）：两只手始终
  /// 在各自的位置，不会在收拢动画里合并成一叠。
  ///
  /// [CardFanSpread.direction] 决定「哪只手先动、哪半叠压在上层」：
  /// [SpreadDirection.leftToRight] 左手先动、右半叠压在上层，
  /// [SpreadDirection.rightToLeft] 反之。
  ///
  /// 参数与开扇一致（[CardFanSpread.fanPivotX] /
  /// [CardFanSpread.fanPivotLift] 同样生效），但不支持双层错落
  /// （[CardFanSpread.fanTierRatio] 被忽略）。每一边的摆幅由
  /// [CardFanSpread.fanAngle] 控制，最大 [kMaxTwoHandFanAngle]（220°）：
  /// 再大两扇就会互相盖住。
  twoHandFan,
}

/// 开扇角度的取值范围（角度制）。
///
/// 下界 0 表示扇形完全收拢：所有牌的目标角都是 0，展开动画结束后
/// 仍然是一叠完全重合的牌（与「收拢态」画面一致）——双手开扇例外，
/// 它的收拢态本来就是左右两叠（见 [FanSpreadMode.twoHandFan]）。
/// 拖动最顶的牌调整角度时也会被限制在这个范围内。
///
/// 它是开扇 / 反开扇的上限，S 扇不受此限（见 [kMaxSFanAngle]），
/// 双手开扇另封顶 [kMaxTwoHandFanAngle]（超出部分由布局钳掉，
/// 构造时只校验到这里）。
const double kMinFanAngle = 0;
/// 开扇 / 反开扇的 `fanAngle` 上限（360°，完整取值范围见上方说明）。
const double kMaxFanAngle = 360;

/// S 扇（[FanSpreadMode.sFan]）的 `fanAngle` 上限（角度制）。
///
/// S 扇的 `fanAngle` 是**脊线切向的总摆幅**——「转出去再转回来」的幅度，
/// 所以它能超过一整圈（普通开扇做不到：超过 360° 就只是绕回来盖住自己）：
/// - 360°：正好转出一整圈再转回来，最标准的那个 S；
/// - 360°~450°：两个弯更卷、更饱满（450° 附近碗最圆）；
/// - 450°~540°：两个弯各自快闭合成圆，仍认得出是 S，但已接近极限；
/// - 540° 以上：两条牌带开始互相绕成「8」字，画面上已经不是 S 了。
///
/// 上限因此取 540；构造时按模式校验（S 扇 0~[kMaxSFanAngle]，
/// 其余模式 0~[kMaxFanAngle]）。
const double kMaxSFanAngle = 540;

/// 双手开扇（[FanSpreadMode.twoHandFan]）每一边的最大角度（角度制）。
///
/// 双手开扇是左右手各捏半叠牌、各自绕自己的手握点扇开：每边都摆满 220° 时
/// 两扇在上下两端交叉（220° × 2 − 360° = 80°，上下各 40°），这正是真实
/// 双手开扇里两扇交叉的样子。220° 是观感基准，再大两扇就会盖成一团。
/// [CardFanSpread.fanAngle] 超出部分被布局钳掉（指纹同样按钳后的值计算）。
const double kMaxTwoHandFanAngle = 220;

/// 双层错落（[CardFanSpread.fanTierRatio]）的上界，占牌高的比例。
///
/// 0 表示两层齐平（单层扇形）；0.65 已是可读的极限——外层的牌几乎整张
/// 错开一层，再大就与内层脱节了。
const double kMaxFanTierRatio = 0.65;

/// 开扇 / 反开扇的枢轴（开扇的「圆心」）在牌宽方向的位置取值范围（归一化）。
///
/// 0 = 牌左边缘，0.5 = 牌边中心（[kDefaultFanPivotX]），1 = 牌右边缘。
/// 所有牌绕各自同一个相对位置旋转：把枢轴挪到一侧，扇形就朝另一侧偏轴展开
/// （例如枢轴贴在左边缘时，整副牌从左边缘这一个点上向右扫开）。
const double kMinFanPivotX = 0;
const double kMaxFanPivotX = 1;

/// 开扇 / 反开扇的枢轴（圆心）相对牌底边的沉深取值范围（牌高的倍数）。
///
/// 0 = 正好落在牌边上；正值沉到牌边下方（牌像从枢轴上垂挂下来，扇面外沿
/// 更陡）；负值抬到牌面内（[kDefaultFanPivotLift] = -0.06，即牌底边内侧
/// 6% 牌高处——拇指捏住扇骨的位置）。下界 -0.5 = 牌面中点，
/// 上界 1.0 = 牌边下方一整张牌高处。
const double kMinFanPivotLift = -0.5;
/// 枢轴沉深上限（牌边下方一整张牌高，取值范围见上方说明）。
const double kMaxFanPivotLift = 1.0;

/// [CardFanSpread.fanPivotX] 的默认值：牌边中心。
const double kDefaultFanPivotX = 0.5;

/// [CardFanSpread.fanPivotLift] 的默认值：牌底边内侧 6% 牌高。
const double kDefaultFanPivotLift = -0.06;

/// 展牌收拢态下，判定「手指往哪边拖」所需的最小横移（逻辑像素）。
///
/// 比这更小的位移当作抖动，先不定方向（也不换向），免得手一抖就把
/// 整叠牌的叠压方向翻过去。
const double kDirectionDragSlop = 8;

/// 开扇收拢态下，判定「手指把顶牌往哪边带」所需的最小转角（度）。
///
/// 与 [kDirectionDragSlop] 同理：比这更小的转角当作抖动，先不定方向。
/// 顶牌绕枢轴的转角与画布大小无关，所以这里用角度而不是像素。
const double kFanDirectionDragSlop = 6;

/// 没有可用牌图时，每张牌的底色（白底空白牌）。
///
/// 出现时机：[CardFanSpread.cardBack] 为 null，或者图片还没解码完成
/// （资源缺失 / 网络错误 / 首帧尚未就绪）导致拿不到 `ui.Image`。
/// 此时每张牌按一张**背面朝上的空白白牌**绘制，
/// 而不是让牌消失成透明，或变成一块默认黑块。
const Color kCardBlankColor = Color(0xFFFFFFFF);

/// [CardFanSpread] 的动画控制器。
///
/// 通过 [play] / [close] / [toggle] / [replay] 驱动开合动画，
/// 通过 [progress] 读取当前进度（0 = 收拢，1 = 完全展开）。
///
/// 同一个 controller 可以同时绑定到多个 [CardFanSpread] 组件
///（例如「缩略预览 + 主视图」）：控制命令作用于全部绑定的组件，
/// [progress] / [isAnimating] / [isOpened] 读取最近绑定的那一个。
class CardFanSpreadController extends ChangeNotifier {
  /// 创建一个动画控制器。
  ///
  /// 未绑定到任何 [CardFanSpread] 时，所有读取类 getter
  /// （[progress] / [isAnimating] / [isOpened]）都返回「收拢」状态。
  CardFanSpreadController();

  /// 已绑定的动画（LinkedHashSet 保持绑定顺序，最后一个为「主」组件）。
  final Set<AnimationController> _animations = <AnimationController>{};

  AnimationController? get _primary =>
      _animations.isEmpty ? null : _animations.last;

  /// 当前展开进度，0~1（读取最近绑定的组件）。
  double get progress => _primary?.value ?? 0;

  /// 是否正在播放动画。
  bool get isAnimating => _primary?.isAnimating ?? false;

  /// 是否已完全展开。
  bool get isOpened => (_primary?.value ?? 0) >= 1;

  /// 播放展开动画；若已完全展开则从头重播。
  void play() {
    for (final a in _animations) {
      a.forward(from: a.isCompleted ? 0 : null);
    }
  }

  /// 无论当前进度如何，都从收拢状态重新展开。
  void replay() {
    for (final a in _animations) {
      a.forward(from: 0);
    }
  }

  /// 收拢（反向播放到 0）。
  void close() {
    for (final a in _animations) {
      a.reverse();
    }
  }

  /// 已展开则收拢，否则展开。
  void toggle() {
    for (final a in _animations) {
      if (a.isCompleted) {
        a.reverse();
      } else {
        a.forward();
      }
    }
  }

  /// 立刻回到收拢状态。
  void reset() {
    for (final a in _animations) {
      a.value = 0;
    }
  }

  /// 把展开进度直接定位到 [value]（0~1），并停掉正在跑的动画。
  ///
  /// 「拖动跟手开合」用：动画不会继续播放，松手后画面就停在当前进度。
  void seekTo(double value) {
    final target = value.clamp(0.0, 1.0);
    for (final a in _animations) {
      // 先 stop 再赋值：正在跑的动画会在下一帧把 value 覆盖回去。
      a.stop();
      a.value = target;
    }
  }

  void _onAnimationStatus(AnimationStatus status) => notifyListeners();

  void _bind(AnimationController animation) {
    // 同一个动画只绑一次（组件重建时会再次走到这里），
    // 否则监听器会重复累积。
    if (!_animations.add(animation)) return;
    animation.addListener(notifyListeners);
    animation.addStatusListener(_onAnimationStatus);
  }

  void _unbind(AnimationController animation) {
    if (!_animations.remove(animation)) return;
    // value 与 status 两类监听器必须成对移除：status 监听器漏移除时，
    // controller 被 dispose 后动画状态变化仍会向它发通知，
    // debug 下直接触发 ChangeNotifier.debugAssertNotDisposed。
    animation.removeListener(notifyListeners);
    animation.removeStatusListener(_onAnimationStatus);
  }

  @override
  void dispose() {
    // 用户先 dispose controller 时主动解绑，
    // 避免已销毁的 ChangeNotifier 再收到动画通知。
    for (final animation in _animations.toList()) {
      _unbind(animation);
    }
    super.dispose();
  }
}

/// 展开的左右方向，[FanSpreadMode] 四种模式通用。
///
/// 每个模式下它控制的东西不同，但都是「从哪一侧开始、哪一侧压在上面」：
/// - [FanSpreadMode.tableSpread]：叠压顺序与「最顶那张」所在的一端
///   （[leftToRight] 时右半部分的牌压在上层）；
/// - [FanSpreadMode.fan]：扇形从哪一端长出去（[leftToRight] 从左到右）；
/// - [FanSpreadMode.sFan]：S 的朝向（[rightToLeft] 得到水平镜像的 S，
///   牌序也反过来）；
/// - [FanSpreadMode.twoHandFan]：哪只手先动、哪半叠压在上层
///   （[leftToRight] 左手先动、右半叠在上）。
enum SpreadDirection {
  /// 从左到右。
  leftToRight,

  /// 从右到左。
  rightToLeft,
}

/// 纸牌开扇组件。
///
/// 四种模式（[mode]）× 两个方向（[direction]）：
/// - [FanSpreadMode.tableSpread]：展牌摊开，模拟荷官在桌面上摊牌，
///   由 [direction] 决定从左往右还是从右往左（叠压顺序与顶牌所在端）；
/// - [FanSpreadMode.fan]：开扇，整叠牌钉在同一个圆心上，
///   由 [direction] 决定扇形从左端还是右端长出去；
/// - [FanSpreadMode.sFan]：S 扇，牌柄沿一条 S 形脊线依次排开，
///   整叠牌卷成一条 S 形的牌带（Cardistry 的 S Fan），见 [fanAngle]；
///   [direction] 为 [SpreadDirection.rightToLeft] 时得到水平镜像的 S；
/// - [FanSpreadMode.twoHandFan]：双手开扇，左右手各捏一扇、对称——整叠牌从
///   中间分成两半，左右手各捏一半、各绕自己的手握点朝外扇开，扇面在上下两端
///   交叉；[direction] 决定哪只手先动、哪半叠压在上层。
///
/// 开扇 / 反开扇还可以通过 [fanTierRatio] 打开「双层错落」：奇数下标的牌
/// 沿长轴向外推出一层，画面变成内 / 外两层错落的**双层扇**
///（即魔术里的「大扇（Giant Fan / Giant Pressure Fan）」——用完美洗牌
/// 把两叠牌交错后开出的大扇形）。
///
/// 图片来源：牌背图 [cardBack] 可选；若要显示牌面，
/// 传入 52 张（或任意数量，会循环取用）牌面图 [cardFaces]，
/// 再把 [showFace] 置为 true 即可整体切换。
///
/// 没有图也能用：不传 [cardBack]（或图片还没解码好 / 解码失败）时，
/// 每张牌画成一张背面朝上的空白白牌，而不是透明或黑块。
///
/// 扇形的张开角度范围通过 [fanAngle]（角度制）调整，
/// 对开扇 / 反开扇 / S 扇 / 双手开扇同时生效（双手开扇下它是**每一边**的
/// 摆幅，上限 [kMaxTwoHandFanAngle]；S 扇下它是脊线切向的总摆幅，
/// 上限 [kMaxSFanAngle] = 540°，能卷过一整圈）。
///
/// 开扇 / 反开扇 / 双手开扇的「圆心」（枢轴）默认在牌边中心附近，也可以用
/// [fanPivotX] 沿牌宽方向挪到任意一侧、或用 [fanPivotLift] 沉到牌边下方——
/// 所有牌仍绕各自同一个相对位置旋转，扇形随之偏轴 / 垂挂，得到不同的视觉效果。
///
/// 布局注意：需要**有界约束**——用 `SizedBox` / `Expanded` / `AspectRatio`
/// 等包裹，或放在普通盒子布局里。在 `Row` 这类提供无界宽度的父组件中
/// 直接使用时，会退回内置的固定尺寸（400×600）以保证不崩溃。
class CardFanSpread extends StatefulWidget {
  /// 创建一个纸牌展开组件。
  ///
  /// 牌背图 [cardBack] 与可选牌面图 [cardFaces] 由调用方提供（见类级说明）。
  /// 其余参数控制布局（[mode] / [direction]）、扇角（[fanAngle]）、枢轴
  /// （[fanPivotX] / [fanPivotLift]）、双层错落（[fanTierRatio]）与动画
  /// （[duration] / [curve] / [stagger] / [autoPlay]）。
  const CardFanSpread({
    super.key,
    this.cardBack,
    this.cardFaces,
    this.mode = FanSpreadMode.fan,
    this.direction = SpreadDirection.leftToRight,
    this.controller,
    this.showFace = false,
    this.cardCount = 52,
    this.fanAngle = 220,
    this.fanTierRatio = 0,
    this.fanPivotX = kDefaultFanPivotX,
    this.fanPivotLift = kDefaultFanPivotLift,
    this.tableStepRatio = 0.09,
    this.tableArcLift = -0.6,
    this.shadowColor = kCardShadowColor,
    this.duration = const Duration(milliseconds: 1800),
    this.curve = Curves.easeOutCubic,
    this.stagger = 0.55,
    this.autoPlay = true,
    this.doubleTapToToggle = true,
    this.onDoubleTap,
    this.tableDragToSpread = true,
    this.onDirectionChanged,
    this.onFanAngleChanged,
    this.spriteMemoryBudget = kSpriteMemoryBudget,
  }) : assert(cardCount >= 2, 'cardCount 至少为 2'),
       // S 扇的 fanAngle 是脊线切向的总摆幅，能卷过一整圈（见 [kMaxSFanAngle]）。
       assert(
         fanAngle >= kMinFanAngle &&
             fanAngle <=
                 (mode == FanSpreadMode.sFan ? kMaxSFanAngle : kMaxFanAngle),
         'fanAngle 取值范围 0~360 度（S 扇 0~540 度）',
       ),
       assert(
         fanTierRatio >= 0 && fanTierRatio <= kMaxFanTierRatio,
         'fanTierRatio 取值范围 0~$kMaxFanTierRatio',
       ),
       assert(
         fanPivotX >= kMinFanPivotX && fanPivotX <= kMaxFanPivotX,
         'fanPivotX 取值范围 $kMinFanPivotX~$kMaxFanPivotX',
       ),
       assert(
         fanPivotLift >= kMinFanPivotLift && fanPivotLift <= kMaxFanPivotLift,
         'fanPivotLift 取值范围 $kMinFanPivotLift~$kMaxFanPivotLift',
       ),
       assert(stagger >= 0 && stagger <= 2, 'stagger 取值范围 0~2');

  /// 牌背图片，可选。
  ///
  /// 不传（null）、或图片尚未解码完成 / 解码失败时，每张牌按一张
  /// 背面朝上的空白白牌（[kCardBlankColor]）绘制，不会变成透明或黑块。
  final ImageProvider? cardBack;

  /// 牌面图片列表（通常 52 张）。为空或 [showFace] 为 false 时全部显示牌背。
  final List<ImageProvider>? cardFaces;

  /// 展开模式（四类布局）。
  final FanSpreadMode mode;

  /// 展开的左右方向，四种模式通用（各模式含义见 [SpreadDirection]）。
  final SpreadDirection direction;

  /// 动画控制器，可选。
  final CardFanSpreadController? controller;

  /// true 显示牌面，false 显示牌背。
  final bool showFace;

  /// 参与展开的牌数。
  final int cardCount;

  /// 开扇 / 反开扇 / S 扇 / 双手开扇的角度范围（角度制）。
  ///
  /// 0 表示完全收拢：所有牌的目标角都是 0。开扇 / 反开扇 / S 扇展开后仍是
  /// 一叠重合的牌；双手开扇则是左右两叠竖牌（双手各捏一半，见下）。
  ///
  /// 取值上限随模式不同：开扇 / 反开扇 0~[kMaxFanAngle]（360°），
  /// S 扇 0~[kMaxSFanAngle]（540°），双手开扇每一边封顶
  /// [kMaxTwoHandFanAngle]（220°）。超出各自上限时构造断言报错
  /// （双手开扇是布局钳掉，见下）。
  ///
  /// 对 S 扇而言，它指的是牌带**反弯的幅度**：脊线由两段曲率相反的圆弧
  /// 拼成，切向先转出去 `fanAngle` 的一半、再转回来，牌垂直于脊线所以也
  /// 跟着摆出同样的幅度——整条 S 因此是竖立的，而不是斜着甚至躺倒的。
  /// 这个「转出去再转回来」的幅度本身可以超过一整圈，所以 S 扇的上限
  /// 比其它模式高一档（360° 是最标准的 S，450° 前后最饱满，
  /// 540° 是「快卷成 8 字」前仍认得出 S 的极限）。
  ///
  /// 对双手开扇而言，它是**每一边**的摆幅：左手朝左扫开、右手朝右扫开，
  /// 上限 [kMaxTwoHandFanAngle]（220°，再大两扇在上下两端就会盖成一团）；
  /// 超出部分被布局钳掉。它是 0 时两扇都没张开，但双手各捏一半，所以展开后
  /// 是**左右两叠**竖牌，而不是像其它模式那样合成一叠。摆幅长到 90° 之后两扇
  /// 就以正左右为中心、上下平分空间（不再随角度继续往外倒）。
  final double fanAngle;

  /// 开扇 / 反开扇的「双层错落」幅度（外层沿长轴向外推出的距离 / 牌高）。
  ///
  /// 大于 0 时，奇数下标的牌整体向外推出一层（模拟完美洗牌后两叠牌
  /// 交错的状态），画面从单层扇形变成内 / 外两层错落的**双层扇**，
  /// 也就是魔术里的「大扇（Giant Fan）」；扇面外径比同角度的普通开扇更大。
  ///
  /// 0（默认）表示两层齐平，即单层扇形；取值范围 0~[kMaxFanTierRatio]，
  /// 建议搭配较大的 [fanAngle]（例如 300~360）使用。
  /// 仅开扇 / 反开扇有效，S 扇 / 双手开扇忽略该参数。
  final double fanTierRatio;

  /// 开扇 / 反开扇 / 双手开扇的枢轴（开扇的「圆心」）在牌宽方向的位置（归一化）。
  ///
  /// 0 = 牌左边缘，0.5 = 牌边中心（默认），1 = 牌右边缘。
  /// 所有牌绕各自同一个相对位置旋转，因此把枢轴挪到一侧，扇形就会朝另一侧
  /// 偏轴展开——例如枢轴贴在左边缘时，整副牌从左边缘这一个点上向右扫开，
  /// 与中心枢轴的圆扇是截然不同的视觉效果。
  /// 取值范围 [kMinFanPivotX]~[kMaxFanPivotX]；仅开扇 / 反开扇 / 双手开扇
  /// 有效，S 扇忽略该参数（牌柄钉在脊线上）。
  final double fanPivotX;

  /// 开扇 / 反开扇 / 双手开扇的枢轴（圆心）相对牌底边的沉深（牌高的倍数）。
  ///
  /// 0 = 正好落在牌边上；正值沉到牌边下方——牌像是从枢轴上垂挂下来，
  /// 扇面外沿更陡；负值抬到牌面内，默认 -0.06（牌底边内侧 6% 牌高处，
  /// 即拇指捏住扇骨的位置）。取值范围 [kMinFanPivotLift]~[kMaxFanPivotLift]
  /// （-0.5 ~ 1.0）。
  /// 与 [fanPivotX] 组合可得到偏轴 / 垂挂等多种扇形；
  /// 仅开扇 / 反开扇 / 双手开扇有效，S 扇忽略该参数。
  final double fanPivotLift;

  /// 展牌模式下相邻牌的错位距离占牌宽的比例（越小重叠越深）。
  final double tableStepRatio;

  /// 展牌模式下两端相对中间上翘的幅度（占牌高的比例）。
  ///
  /// 正值两端上翘，负值两端下翘（中间拱起）。
  final double tableArcLift;

  /// 牌与牌之间的投影颜色。
  ///
  /// 纸牌高度重叠时阴影会层层累积，默认取很淡的 14% 黑，
  /// 主要靠描边来交代层次。传 [Colors.transparent] 可完全关掉阴影。
  final Color shadowColor;

  /// 完整展开动画时长。
  final Duration duration;

  /// 整体缓动曲线。
  final Curve curve;

  /// 逐张牌之间的级联错峰程度，0 为所有牌同时运动。
  final double stagger;

  /// 是否在挂载后自动播放展开动画。
  final bool autoPlay;

  /// 双击画布是否切换「播放 / 收拢」（默认 true）。
  ///
  /// 已完全展开 → 收拢；否则 → 展开（正在收拢时顺势转回展开），
  /// 与 [CardFanSpreadController.toggle] 的语义一致。
  /// 传 false 可关掉（例如画布外层自己也要处理双击）。
  ///
  /// 传了 [controller] 时，双击作用于该 controller 绑定的**全部**组件，
  /// 而不只是被双击的那一个。
  final bool doubleTapToToggle;

  /// 双击画布时触发（在播放 / 收拢切换之后）。
  ///
  /// 与 [doubleTapToToggle] 无关：即使关掉了内置切换，回调依然会触发，
  /// 可以拿它做埋点或驱动别的逻辑。
  final VoidCallback? onDoubleTap;

  /// 拖动「最顶的那张牌」调整开扇角度时触发（角度制，
  /// [kMinFanAngle] ~ 当前模式的上限：S 扇 [kMaxSFanAngle]，双手开扇
  /// [kMaxTwoHandFanAngle]，其余 [kMaxFanAngle]）。
  ///
  /// 受控组件模式：把收到的角度回填给 [fanAngle] 即可让扇形跟随手指
  /// 张开 / 收拢；不传该回调时拖动无效。
  ///
  /// 若拖动时牌堆尚未展开（进度 < 1），会**同时播放展开动画**，
  /// 让「拖动 → 开扇」成为连贯动作；正在收拢时拖动则顺势转为展开。
  ///
  /// 四种扇都支持，触摸需要落在「最顶的那张牌」上（展牌模式不使用 fanAngle）：
  /// 单叠的模式指压在最上面的那张；**双手开扇是两叠**，左右两叠各自的顶牌都能
  /// 抓，拖其中哪一叠调的都是同一个摆幅。S 扇的顶牌在牌带末端，灵敏度是开扇的
  /// 两倍：它转 1°，开扇角变 4°。
  final ValueChanged<double>? onFanAngleChanged;

  /// 展牌模式下，拖动「最顶的那张牌」是否跟手展开 / 收拢（默认 true）。
  ///
  /// 手指拖着最外面那张牌走，牌摊到哪儿进度就停在哪儿——松手**不会**
  /// 继续播放（与真实摊牌一致），要继续得再拖、双击或调 controller。
  /// 传 false 关掉后，展牌只能靠 controller / 双击开合。
  ///
  /// 开扇 / 反开扇的拖动是调 [fanAngle]，与本开关无关。
  final bool tableDragToSpread;

  /// 展牌 / 开扇在**收拢态**被拖动时，若拖动方向与当前生效方向不匹配则触发，
  /// 给出建议的方向（受控组件模式：把值回填给 [direction] 即可）。
  ///
  /// 规则（顶牌跟着手指走，牌朝手指**同方向**铺开）：
  /// - [FanSpreadMode.tableSpread]：收拢时往右拖 → [SpreadDirection.leftToRight]
  ///   （顶牌是最右那张，牌带朝右铺，跟着手指一起往右）；往左拖 →
  ///   [SpreadDirection.rightToLeft]。已经摊开的牌（进度 > 0）再拖只是跟手收放，
  ///   不会再换方向。
  /// - [FanSpreadMode.fan]：**画面收拢**时拖动顶牌，手指把它往顺时针带 →
  ///   [SpreadDirection.leftToRight]；往逆时针带 → [SpreadDirection.rightToLeft]。
  ///   「画面收拢」指 `fanAngle` 就是收拢角，或者展开进度为 0（按过收拢、
  ///   动画还没放）——后者 `fanAngle` 可能仍是 220°，同样要让手势直接定方向。
  ///   张开的扇往里拖、手指**推过收拢角**后同样换向接着张开——不会被钳在
  ///   [kMinFanAngle] 卡住；只是拖到收拢角停住不再推则不会翻。同一个手势里
  ///   往复拖动也会来回翻：顶牌每穿过一次收拢角就换一次向（换向后累计转角清零，
  ///   静止的手指不会连续翻，[kFanDirectionDragSlop] 即换向后的滞回）。
  ///
  /// 展牌一次拖动只定一次方向；开扇不设这个限制。
  ///
  /// **不传该回调组件也会自己换**（内部记一份「生效方向」），否则收拢态往另一侧
  /// 拖会被钳在收拢角 / 收拢进度上完全没反应——方向建议无处可去。接了回调则以
  /// 调用方为准：回写什么就用什么，调用方显式改 [direction] 时同样以调用方为准。
  ///
  /// S 扇 / 双手开扇不触发：S 扇的顶牌在牌带末端、双手开扇本来左右各一扇，
  /// 「另一侧」没有明确含义（方向用 [direction] 显式给即可）。
  final ValueChanged<SpreadDirection>? onDirectionChanged;

  /// 预合成精灵图的显存预算（字节），默认 [kSpriteMemoryBudget]（64MB）。
  ///
  /// 每种源图（牌背 1 张 + 用到的牌面）会合成两份位图（带阴影 / 纯净），
  /// 总量超过预算时自动按比例下调合成倍率（清晰度换内存）。
  /// 牌面不重复且张数很多时（例如 52 张）调大可以换取更锐利的牌面；
  /// 内存紧张的平台（低端设备 / Web）可以调小。
  final int spriteMemoryBudget;

  @override
  State<CardFanSpread> createState() => _CardFanSpreadState();
}

class _RepaintSignal extends ChangeNotifier {
  void signal() => notifyListeners();
}

class _ImageEntry {
  ImageStream? stream;
  ImageStreamListener? listener;
  ui.Image? image;
}

class _CardFanSpreadState extends State<CardFanSpread>
    with TickerProviderStateMixin {
  late final AnimationController _animation;

  /// 牌背 → 牌面的交叉淡入淡出进度，避免切换时整幅画面明暗跳变。
  late final AnimationController _faceMix;

  /// 旧牌背 → 新牌背的交叉溶解进度（换牌背时的过渡）。
  late final AnimationController _backMix;

  /// 正在淡出的旧牌背（换牌背时把旧图克隆出来留着过渡用）。
  ///
  /// 必须**克隆**：`_resolveImages` 会把旧 provider 的 entry 回收并 dispose 掉
  /// 原来的 `ui.Image`，不克隆的话画家手里就剩一张已释放的图。
  ui.Image? _outgoingBack;

  /// 换了牌背、但新图还没解码好：这期间继续画 [_outgoingBack]，
  /// 不然每张牌会先闪一下空白白牌。
  bool _backFadePending = false;

  final CardSpriteCache _spriteCache = CardSpriteCache();
  final _imageEntries = <ImageProvider, _ImageEntry>{};
  final _imagesChanged = _RepaintSignal();
  int _spriteVersion = 0;

  /// 上次解析图片时使用的配置；dpr / locale 等变化时需要全部失效重解析。
  ImageConfiguration? _imageConfig;

  /// 当前**生效**的方向。
  ///
  /// 初始跟 [CardFanSpread.direction]；收拢态被往另一侧拖时，手势会把生效方向
  /// 翻过去，同时通过 [CardFanSpread.onDirectionChanged] 通知调用方。
  ///
  /// 没有那个回调时组件自己翻：方向是纯受控参数，调用方不接管就意味着建议无处
  /// 可去，收拢态往另一侧拖会被钳在收拢角 / 收拢进度上——手感就是「拖不动、
  /// 改不了方向」。
  late SpreadDirection _effectiveDirection = widget.direction;

  /// 最近一次 build 算出的布局，供「拖动最顶的牌」做命中测试。
  CardSpreadLayout? _lastLayout;

  // 拖动开扇角度的状态（_dragStartFanAngle 为 null = 未在拖动）。
  double? _dragStartFanAngle;
  double _dragPointerAngle = 0;
  double _dragAngleDelta = 0;

  /// 起拖时「最顶那张牌」的枢轴（像素），指针角度绕它测量。
  ///
  /// 必须**冻结**：S 扇的顶牌枢轴沿 S 形脊线排开，开扇角一变它就跟着往前挪
  /// （几十到上百像素），若每帧都拿新枢轴去量同一个手指位置，会凭空算出巨大的
  /// 角度增量、拖动直接失控。开扇 / 反开扇的枢轴恒为 [FanSpreadLayout.origin]、
  /// 双手开扇的枢轴是**那只手**的握点（见 [FanSpreadLayout.pivotOffsets]）：两者
  /// 在拖动过程中都不动，冻结与实时取值完全等价。
  Offset? _dragPivot;

  /// 起拖时算好的「指针转 1° → 开扇角变多少度」，整个拖动过程保持不变。
  ///
  /// 在起拖时算而不是每帧算：卡牌尺寸会随布局一起被重新缩放（S 扇尤其如此），
  /// 每帧取新值会让手感忽快忽慢。
  double _dragGain = 2;

  /// 起拖时算好的「手指往哪边转是开扇」：+1 = 顺时针（指针角度变大）开扇，
  /// −1 = 逆时针开扇。整个拖动过程保持不变。
  ///
  /// 同样在起拖时定：双手开扇的左扇顶牌在摆幅跨过拐点时**方向会翻**，每帧
  /// 重新求值会让手指停在原地、扇面自己来回弹。
  double _dragSign = 1;

  /// 当前模式下 `fanAngle` 的上限：S 扇能卷过一整圈到 [kMaxSFanAngle]，
  /// 双手开扇每一边封顶 [kMaxTwoHandFanAngle]（与布局的钳位一致），
  /// 其余是 [kMaxFanAngle]。拖动时的钳位用它，避免拖出「回调给了 360°
  /// 而画面上只到 220°」这类回调与画面不一致的值。
  double get _maxFanAngle => switch (widget.mode) {
    FanSpreadMode.sFan => kMaxSFanAngle,
    FanSpreadMode.twoHandFan => kMaxTwoHandFanAngle,
    _ => kMaxFanAngle,
  };

  // 展牌「顶牌跟手」的状态（_dragStartCardProgress 为 null = 未在拖动）。
  /// 起拖时被拖的那张牌（drawOrder.last）的单卡进度。
  double? _dragStartCardProgress;
  Offset? _dragStartPosition;

  /// 本次拖动的「摊开方向」：+1 = 手指往右，-1 = 手指往左，0 = 还没定。
  ///
  /// 收拢态起拖时由第一次有效横移定下来，用于决定展牌方向，也用于把
  /// 手指位移换算成进度（换向之后顶牌走的是反方向，这里把它们对齐）。
  int _dragOpenDx = 0;

  /// 起拖时画面是否收拢（一叠重合的牌）：进度为 0 或角度本就是收拢角。
  /// 收拢态下方向由手势第一次有效转向直接定（不用等推过收拢角）。
  bool _dragStartFanCollapsed = false;

  // 双击检测的状态（自己判，不用识别器，见 build 里的说明）。
  /// 触摸容差：设备上报的 touchSlop 优先，否则用 [kDoubleTapTouchSlop]。
  double _touchSlop = kDoubleTapTouchSlop;

  /// 正在跟踪的「可能是点击」的那次按下（null = 没有）。
  int? _tapPointer;
  Offset? _tapDownPosition;

  /// 上一次有效点击抬起的时刻与位置（用于判第二次点击）。
  ///
  /// 用单调时钟而不是 [DateTime.now]：后者会被系统对时 / 用户改表影响，
  /// 时钟回拨会让「两次点击间隔」算出负值或超大值，双击判定失灵。
  static final Stopwatch _monotonicClock = Stopwatch()..start();
  Duration? _lastTapElapsed;
  Offset? _lastTapPosition;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(vsync: this, duration: widget.duration);
    _faceMix = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: widget.showFace ? 1 : 0,
    );
    _backMix = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    widget.controller?._bind(_animation);
    // 牌背 / 牌面交叉淡入淡出结束后重建一次：牌面精灵此时才真正不再需要，
    // 让 _ensureSprites 把它们从缓存里淘汰掉（见 [_onFaceMixStatus]）。
    _faceMix.addStatusListener(_onFaceMixStatus);
    _backMix.addStatusListener(_onBackMixStatus);
    // 图片解码完成后需要重建 painter，把 ui.Image 传给绘制层。
    _imagesChanged.addListener(_onImagesChanged);
    if (widget.autoPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _animation.forward();
      });
    }
    // 图片解析在 didChangeDependencies 里做：createLocalImageConfiguration
    // 需要 context，且 initState 阶段继承链还没就绪。
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 订阅 MediaQuery：窗口跨屏移动导致 devicePixelRatio 变化时，
    // 资源变体（2.0x / 3.0x）需要按新 dpr 重新选择。
    MediaQuery.maybeOf(context);
    _resolveImages(createLocalImageConfiguration(context));
  }

  @override
  void didUpdateWidget(covariant CardFanSpread oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.duration;
    // 方向是受控参数：调用方显式改了就以调用方为准。手势翻过去的生效方向只在
    // 「没人接管」（没回调 / 回调没回写）时留下来。
    if (widget.direction != oldWidget.direction) {
      _effectiveDirection = widget.direction;
    }
    if (widget.showFace != oldWidget.showFace) {
      widget.showFace ? _faceMix.forward() : _faceMix.reverse();
    }
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?._unbind(_animation);
      widget.controller?._bind(_animation);
    }
    // 双击被关掉后 Listener 会卸载，残留的「上一次点击」不能再参与判定。
    if (!widget.doubleTapToToggle && widget.onDoubleTap == null) {
      _resetTapTracking();
    }
    if (widget.cardBack != oldWidget.cardBack ||
        !listEquals(widget.cardFaces, oldWidget.cardFaces)) {
      if (widget.cardBack != oldWidget.cardBack) {
        _startBackFade(oldWidget.cardBack);
      }
      _resolveImages();
    }
  }

  @override
  void dispose() {
    widget.controller?._unbind(_animation);
    _faceMix.removeStatusListener(_onFaceMixStatus);
    _backMix.removeStatusListener(_onBackMixStatus);
    _imagesChanged.removeListener(_onImagesChanged);
    _outgoingBack?.dispose();
    _outgoingBack = null;
    for (final provider in _imageEntries.keys.toList()) {
      _dropEntry(provider);
    }
    _imageEntries.clear();
    _spriteCache.dispose();
    _imagesChanged.dispose();
    _animation.dispose();
    _faceMix.dispose();
    _backMix.dispose();
    super.dispose();
  }

  void _onImagesChanged() {
    if (!mounted) return;
    if (_backFadePending && _imageEntries[widget.cardBack]?.image != null) {
      _backFadePending = false;
      _backMix.forward(from: 0);
    }
    setState(() {});
  }

  /// 换牌背：把此刻画面上那张牌背留作淡出层，等新图到位再溶解。
  ///
  /// 必须在 [_resolveImages] **之前**调用——它会把旧 provider 的 entry 连同
  /// `ui.Image` 一起回收掉。
  void _startBackFade(ImageProvider? previousProvider) {
    // 此刻画面上那张牌背：旧 provider 的图（还没被回收），或上一段过渡残留的
    // （连续换牌背时新图可能还没到位）。
    final shown = _imageEntries[previousProvider]?.image ?? _outgoingBack;
    _outgoingBack?.dispose();
    _outgoingBack = shown?.clone();
    _backFadePending = _outgoingBack != null;
  }

  /// 旧牌背 → 新牌背的溶解结束：重建一次，让旧牌背退出合成集合、释放精灵。
  void _onBackMixStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed &&
        status != AnimationStatus.dismissed) {
      return;
    }
    if (status == AnimationStatus.completed && _outgoingBack != null) {
      _outgoingBack!.dispose();
      _outgoingBack = null;
    }
    if (mounted) setState(() {});
  }

  /// 精灵图合成完成后重绘一次。
  void _onSpritesReady() {
    if (mounted) setState(() => _spriteVersion = _spriteCache.version);
  }

  /// 牌背 / 牌面交叉淡入淡出结束：重建一次，让不再需要的牌面精灵被淘汰。
  void _onFaceMixStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed &&
        status != AnimationStatus.dismissed) {
      return;
    }
    if (mounted) setState(() {});
  }

  /// 为当前尺寸准备精灵图（幂等，牌尺寸不变则不重复合成）。
  void _ensureSprites(BuildContext context, CardSpreadLayout layout) {
    final images = <ui.Image>{};
    final backProvider = widget.cardBack;
    final back = backProvider == null
        ? null
        : _imageEntries[backProvider]?.image;
    if (back != null) images.add(back);
    // 正在淡出的旧牌背也要有精灵，否则这 280ms 里它走逐帧回退路径。
    final outgoing = _outgoingBack;
    if (outgoing != null) images.add(outgoing);
    // 牌面只在「要显示」或「正在淡出的过渡中」才参与合成：淡出结束前就把它们
    // 淘汰掉，会让交叉溶解中途掉回逐帧回退路径（52 张牌各自 clip + 模糊）。
    if (widget.showFace || _faceMix.value > 0) {
      final faces = widget.cardFaces ?? const <ImageProvider>[];
      // 只有前 min(cardCount, 张数) 张会被取用（画家按 `i % 长度` 取图），
      // 不必为整副牌合成精灵——牌数少时能省下大量合成与显存。
      final used = math.min(widget.cardCount, faces.length);
      for (var i = 0; i < used; i++) {
        final image = _imageEntries[faces[i]]?.image;
        if (image != null) images.add(image);
      }
    }
    if (images.isEmpty) return;
    final dpr = View.maybeOf(context)?.devicePixelRatio ?? 1.0;
    _spriteCache.update(
      images: images,
      width: layout.cardWidth,
      height: layout.cardHeight,
      dpr: dpr,
      shadowColor: widget.shadowColor,
      onReady: _onSpritesReady,
      maxMemoryBytes: widget.spriteMemoryBudget,
    );
  }

  /// 解析当前 [widget] 用到的全部牌图。
  ///
  /// 两个容易被忽略的点：
  /// 1. 必须传真实的 [ImageConfiguration]（含 devicePixelRatio / locale /
  ///    textDirection…）：传 [ImageConfiguration.empty] 会让
  ///    `AssetBundleImageProvider` 永远只选 1.0x 主资源，高 DPR 屏上牌面发虚。
  /// 2. 配置变化（如窗口跨屏移动导致 dpr 变化）或 provider 被换掉时，
  ///    旧 entry 必须回收，否则旧的 `ui.Image` 会一直驻留内存。
  ///
  /// [config] 由调用方传入（didChangeDependencies 里新算的配置），
  /// 缺省时复用上次的配置——仅 provider 变化不会触发资源重选。
  void _resolveImages([ImageConfiguration? config]) {
    config ??= _imageConfig ?? createLocalImageConfiguration(context);
    final providers = <ImageProvider>{?widget.cardBack, ...?widget.cardFaces};

    // 配置变化：旧图是按旧 dpr / locale 选的，全部失效重解析。
    final previousConfig = _imageConfig;
    _imageConfig = config;
    if (previousConfig != null && !_sameConfig(previousConfig, config)) {
      for (final provider in _imageEntries.keys.toList()) {
        _dropEntry(provider);
      }
    }
    // 回收不再使用的 entry（换牌背 / 换牌面 / 牌数减少）。
    for (final provider in _imageEntries.keys.toList()) {
      if (!providers.contains(provider)) {
        _dropEntry(provider);
      }
    }

    for (final provider in providers) {
      final entry = _imageEntries.putIfAbsent(provider, _ImageEntry.new);
      if (entry.image != null || entry.stream != null) continue;
      final stream = provider.resolve(config);
      final listener = ImageStreamListener((info, _) {
        // 迟到的回调：这个 entry 已经被回收（换图 / 配置变化 / 组件已卸载）时，
        // 它持有的旧 clone 早就 dispose 过了，再碰就是二次释放；直接忽略，
        // 新的 entry 会自己重新解析。
        if (_imageEntries[provider] != entry) return;
        final image = info.image.clone();
        if (entry.image != image) {
          entry.image?.dispose();
          entry.image = image;
          _imagesChanged.signal();
        } else {
          image.dispose();
        }
      });
      entry.stream = stream;
      entry.listener = listener;
      stream.addListener(listener);
    }
  }

  /// 移除并释放一个图片 entry：解绑流监听、释放 clone 出的 `ui.Image`，
  /// 并同步失效精灵图缓存里以它为源的条目。
  void _dropEntry(ImageProvider provider) {
    final entry = _imageEntries.remove(provider);
    if (entry == null) return;
    final stream = entry.stream;
    final listener = entry.listener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    final image = entry.image;
    // 先摘掉引用：万一还有迟到的监听回调拿着这个 entry，也不会把同一个 clone
    // 二次 dispose（`ui.Image.dispose` 在重复释放时会直接断言失败）。
    entry.image = null;
    if (image != null) {
      // 先失效精灵再 dispose 源图，避免缓存里留下永不使用的位图。
      _spriteCache.evict(image);
      image.dispose();
    }
  }

  /// [ImageConfiguration] 没有实现 `==`，按字段比较。
  static bool _sameConfig(ImageConfiguration a, ImageConfiguration b) {
    return a.devicePixelRatio == b.devicePixelRatio &&
        a.locale == b.locale &&
        a.textDirection == b.textDirection &&
        a.size == b.size &&
        a.platform == b.platform &&
        identical(a.bundle, b.bundle);
  }

  /// 无界约束（例如直接放在 Row / 横向 ListView 里没加 Flexible）时的
  /// 确定性后备尺寸：[CustomPaint] 收到 infinity 尺寸会直接触发布局断言，
  /// 这里退化成固定尺寸，至少保证不崩溃、有内容可看。
  static const Size _kFallbackCanvas = Size(400, 600);

  Size _boundedCanvas(BoxConstraints constraints) {
    final biggest = constraints.biggest;
    return Size(
      constraints.hasBoundedWidth ? biggest.width : _kFallbackCanvas.width,
      constraints.hasBoundedHeight ? biggest.height : _kFallbackCanvas.height,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvas = _boundedCanvas(constraints);
        final layout = CardSpreadLayout.compute(
          mode: widget.mode,
          canvas: canvas,
          cardCount: widget.cardCount,
          fanAngle: widget.fanAngle,
          fanTierRatio: widget.fanTierRatio,
          fanPivotX: widget.fanPivotX,
          fanPivotLift: widget.fanPivotLift,
          tableStepRatio: widget.tableStepRatio,
          tableArcLift: widget.tableArcLift,
          direction: _effectiveDirection,
        );
        _ensureSprites(context, layout);
        // 缓存布局供手势命中测试使用（触摸 → 逆变换 → 判断是否落在某张牌上）。
        _lastLayout = layout;
        final onFanAngleChanged = widget.onFanAngleChanged;
        // 牌区自己是一层重绘边界：动画每帧只需重绘这块画布，
        // 不会沿祖先链把同级组件（滑块、背景渐变…）一起拖着重画
        //（RenderCustomPaint 本身不是 repaint boundary）。
        Widget paint = RepaintBoundary(
          child: CustomPaint(
            size: canvas,
            painter: _CardSpreadPainter(
              animation: _animation,
              faceMix: _faceMix,
              backCrossFade: _backMix,
              layout: layout,
              stagger: widget.stagger,
              shadowColor: widget.shadowColor,
              curve: widget.curve,
              showFace: widget.showFace,
              backImage: widget.cardBack == null
                  ? null
                  : _imageEntries[widget.cardBack]?.image,
              previousBackImage: _outgoingBack,
              faceImages: (widget.cardFaces ?? const [])
                  .map((p) => _imageEntries[p]?.image)
                  .toList(),
              sprites: _spriteCache.sprites,
              flatSprites: _spriteCache.flatSprites,
              spriteCardSizes: _spriteCache.spriteCardSizes,
              spriteVersion: _spriteVersion,
            ),
          ),
        );
        // 双击用 [Listener] 自己判，而不是 GestureDetector.onDoubleTap：
        // 识别器一旦进场，手势竞技场就有了两个成员，拖动不再像只有一个成员时
        // 那样在「按下」时被默认判胜，而要等移动超过 panSlop 才赢下来，
        // 于是开头那几十像素的位移会被吃掉（短促地拨一下顶牌调不动角度）；
        // 而且 DoubleTapGestureRecognizer 每次按下都会起一个 40ms 的定时器，
        // 测试里没推进够时间就会报「A Timer is still pending」。
        // Listener 直接收原始指针事件、不参与竞技场，对拖动零干扰。
        _touchSlop =
            MediaQuery.maybeOf(context)?.gestureSettings.touchSlop ??
            kDoubleTapTouchSlop;
        if (widget.doubleTapToToggle || widget.onDoubleTap != null) {
          paint = Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            onPointerCancel: _onPointerCancel,
            child: paint,
          );
        }
        // 展牌默认就要装拖动（顶牌跟手开合）；开扇 / 反开扇 / S 扇 / 双手开扇
        // 只在调用方关心角度变化时装——多了个识别器就会抢走外层
        //（PageView 之类）的横向滑动。
        final dragEnabled =
            onFanAngleChanged != null ||
            (widget.mode == FanSpreadMode.tableSpread &&
                widget.tableDragToSpread);
        if (dragEnabled) {
          paint = GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: (d) => _onPanStart(d, onFanAngleChanged),
            onPanUpdate: (d) => _onPanUpdate(d, onFanAngleChanged),
            onPanEnd: (_) => _endDrag(),
            onPanCancel: _endDrag,
            child: paint,
          );
        }
        return paint;
      },
    );
  }

  // ---------------- 双击画布：播放 / 收拢 ----------------

  /// 双击画布：已展开则收拢，否则展开。
  ///
  /// 有外部 [CardFanSpreadController] 时走 controller——它可能同时绑了多个组件
  ///（例如「缩略预览 + 主视图」），双击应让它们一起开合，所以不能只驱动
  /// 本组件的动画；没有 controller 时才直接驱动自己的动画。
  void _onDoubleTap() {
    if (widget.doubleTapToToggle) {
      final controller = widget.controller;
      if (controller != null) {
        controller.toggle();
      } else if (_animation.isCompleted) {
        _animation.reverse();
      } else {
        _animation.forward();
      }
    }
    widget.onDoubleTap?.call();
  }

  /// 清掉双击检测的中间状态（关掉双击、或手势被取消时调用）。
  void _resetTapTracking() {
    _tapPointer = null;
    _tapDownPosition = null;
    _lastTapElapsed = null;
    _lastTapPosition = null;
  }

  void _onPointerDown(PointerDownEvent event) {
    // 只认主键（鼠标右键 / 触控笔的副按钮不算双击）。
    if (event.buttons != kPrimaryButton) return;
    _tapPointer = event.pointer;
    _tapDownPosition = event.position;
  }

  void _onPointerMove(PointerMoveEvent event) {
    // 移动超出容差 → 这一下是拖动，不是点击（拖完立刻松手也不该算双击）。
    if (_tapPointer != event.pointer) return;
    final down = _tapDownPosition;
    if (down != null && (event.position - down).distance > _touchSlop) {
      _tapPointer = null;
      _tapDownPosition = null;
    }
  }

  /// 双击在「第二下抬起」时判定，而不是按下时：
  /// 按下即触发的话，紧随其后（同一个事件派发里）的拖动识别器会拿到
  /// onPanStart，而此时收拢动画还没跑起来、isCompleted 仍为真，
  /// onPanStart 会顺势 forward() 把刚启动的收拢又顶回展开。
  void _onPointerUp(PointerUpEvent event) {
    // _tapPointer 已被清空 = 这一下移动过了，算拖动不算点击。
    if (_tapPointer != event.pointer) return;
    _tapPointer = null;
    _tapDownPosition = null;
    final lastElapsed = _lastTapElapsed;
    final lastPosition = _lastTapPosition;
    final isDoubleTap =
        lastElapsed != null &&
        lastPosition != null &&
        _monotonicClock.elapsed - lastElapsed <= kDoubleTapTimeout &&
        (event.position - lastPosition).distance <= kDoubleTapSlop;
    if (isDoubleTap) {
      // 不再把这一下记成新点击的起点，否则三击会连出两次双击。
      _lastTapElapsed = null;
      _lastTapPosition = null;
      _onDoubleTap();
      return;
    }
    _lastTapElapsed = _monotonicClock.elapsed;
    _lastTapPosition = event.position;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    // 只清掉「正在跟踪的这一次按下」：另一根手指被取消不该把上一次有效点击
    // 记录也抹掉（否则多指操作后双击永远判不出来）。
    if (_tapPointer == event.pointer) {
      _tapPointer = null;
      _tapDownPosition = null;
    }
  }

  // ---------------- 拖动最顶的牌调整开扇角度 ----------------

  /// 触摸点相对 [pivot] 的角度（度，0 = 正上方，顺时针为正，与牌的旋转角同向）。
  double _pointerAngleDeg(Offset position, Offset pivot) {
    final dx = position.dx - pivot.dx;
    final dy = position.dy - pivot.dy;
    return math.atan2(dx, -dy) * 180 / math.pi;
  }

  /// 可抓取（拖动调摆幅）的牌：每种模式都是压在**最上面**的那张。
  ///
  /// 双手开扇是两叠牌，所以有两张「顶牌」——左右各一张，两叠都能抓；两叠都
  /// 命中时优先给压在更上面的那叠（按 [FanSpreadLayout.drawOrder] 从后往前找，
  /// 方向换了之后压在上面的那叠也跟着换）。其余模式只有一叠。
  List<int> _grabableTopCards(FanSpreadLayout fan) {
    if (fan.mode == FanSpreadMode.twoHandFan) {
      final left = fan.cardCount ~/ 2;
      var foundLeft = false;
      var foundRight = false;
      final tops = <int>[];
      for (final i in fan.drawOrder.reversed) {
        if (i < left) {
          if (foundLeft) continue;
          foundLeft = true;
        } else {
          if (foundRight) continue;
          foundRight = true;
        }
        tops.add(i);
        if (foundLeft && foundRight) break;
      }
      return tops;
    }
    return <int>[fan.drawOrder.last];
  }

  /// 触摸点命中的可抓取牌，都没命中时返回 −1。
  int _hitTopCard(Offset position, FanSpreadLayout fan) {
    for (final i in _grabableTopCards(fan)) {
      if (_hitCard(position, fan, i)) return i;
    }
    return -1;
  }

  /// 触摸点是否落在第 [i] 张牌上。
  ///
  /// 把触摸点逆变换到牌的局部坐标系再判断（牌的当前位置由动画进度决定，
  /// 与画家共用 [CardSpreadLayout.cardProgressAt]，保证判定与画面一致）。
  bool _hitCard(Offset position, FanSpreadLayout fan, int i) {
    final p = fan.cardProgressAt(
      i,
      _animation.value,
      stagger: widget.stagger,
      curve: widget.curve,
    );
    final angle = fan.targetAngles[i] * p;
    // 双层错落的外层牌沿长轴推出了 tierOffsets[i]，逆变换时要一并加回来。
    final tier = fan.tierOffsets[i] * p;
    // 这张牌自己的枢轴（S 扇沿脊线挪动过、双手开扇是两只手的位置），
    // 逆变换同样要减掉——和画家用同一套（是否随进度长出来见 layout）。
    final pivot =
        fan.origin + fan.pivotOffsets[i] * (fan.pivotFollowsProgress ? p : 1.0);
    final dx = position.dx - pivot.dx;
    final dy = position.dy - pivot.dy;
    final cos = math.cos(-angle);
    final sin = math.sin(-angle);
    final lx = dx * cos - dy * sin + fan.pivotOffset.dx;
    final ly = dx * sin + dy * cos + fan.pivotOffset.dy + tier;
    const slop = 8.0; // 触摸容差
    return lx >= -slop &&
        lx <= fan.cardWidth + slop &&
        ly >= -slop &&
        ly <= fan.cardHeight + slop;
  }

  /// 拖动分发：展牌走「顶牌跟手开合」，四种扇走「拖顶牌调开扇角度」。
  void _onPanStart(DragStartDetails details, ValueChanged<double>? onFanAngle) {
    final layout = _lastLayout;
    if (layout is TableSpreadLayout) {
      _onTableDragStart(details, layout);
    } else if (layout is FanSpreadLayout && onFanAngle != null) {
      _onFanAngleDragStart(details, onFanAngle);
    }
  }

  void _onPanUpdate(
    DragUpdateDetails details,
    ValueChanged<double>? onFanAngle,
  ) {
    final layout = _lastLayout;
    if (layout is TableSpreadLayout) {
      _onTableDragUpdate(details, layout);
    } else if (layout is FanSpreadLayout && onFanAngle != null) {
      _onFanAngleDragUpdate(details, onFanAngle);
    }
  }

  // ---------------- 展牌：拖动最顶的牌跟手开合 ----------------

  /// 触摸点是否落在展牌「最顶的那张牌」上。
  ///
  /// 与画家共用「中心 = lerp(收拢位置, 最终位置, p)、旋转 = lerp(初始角, 目标角, p)」
  /// 这套变换，只是反过来用（把触摸点旋转回牌的局部坐标系再判断）。
  bool _hitTopTableCard(Offset position, TableSpreadLayout table) {
    final i = table.drawOrder.last;
    final p = table.cardProgressAt(
      i,
      _animation.value,
      stagger: widget.stagger,
      curve: widget.curve,
    );
    final center = Offset(
      ui.lerpDouble(table.stackOffset.dx, table.centers[i].dx, p)!,
      ui.lerpDouble(table.stackOffset.dy, table.centers[i].dy, p)!,
    );
    final angle = ui.lerpDouble(table.stackRotation, table.rotations[i], p)!;
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;
    final cos = math.cos(-angle);
    final sin = math.sin(-angle);
    final lx = dx * cos - dy * sin;
    final ly = dx * sin + dy * cos;
    const slop = 8.0; // 触摸容差
    final halfW = table.cardWidth / 2;
    final halfH = table.cardHeight / 2;
    return lx >= -halfW - slop &&
        lx <= halfW + slop &&
        ly >= -halfH - slop &&
        ly <= halfH + slop;
  }

  void _onTableDragStart(DragStartDetails details, TableSpreadLayout table) {
    if (!widget.tableDragToSpread) return;
    if (!_hitTopTableCard(details.localPosition, table)) return;
    final i = table.drawOrder.last;
    final axis = table.centers[i] - table.stackOffset;
    if (axis.distance <= 0) return;
    _dragOpenDx = 0;
    _dragStartPosition = details.localPosition;
    _dragStartCardProgress = table.cardProgressAt(
      i,
      _animation.value,
      stagger: widget.stagger,
      curve: widget.curve,
    );
  }

  void _onTableDragUpdate(DragUpdateDetails details, TableSpreadLayout table) {
    final start = _dragStartCardProgress;
    final startPosition = _dragStartPosition;
    if (start == null || startPosition == null) return;
    final delta = details.localPosition - startPosition;
    _resolveDragDirection(delta);
    final i = table.drawOrder.last;
    // 顶牌的行程轴每次都按当前布局重算：换向之后顶牌换成了另一端的那张，
    // 行程方向也跟着反过来。
    final axis = table.centers[i] - table.stackOffset;
    final span = axis.distance;
    if (span <= 0) return;
    final projected = delta.dx * axis.dx + delta.dy * axis.dy;
    // 换向之后顶牌走的是手指的反方向，这里把两者对齐：
    // 手指继续往原方向走就继续摊开，往回收就收拢。
    final sign = _dragOpenDx == 0 || axis.dx * _dragOpenDx >= 0 ? 1.0 : -1.0;
    final fraction = sign * projected / (span * span);
    // 手指位移在这条轴上的投影占整段行程的比例，就是顶牌该走到的进度。
    final cardProgress = (start + fraction).clamp(0.0, 1.0);
    _seekProgress(_progressForCardProgress(table, i, cardProgress));
  }

  /// 收拢态起拖时，用第一次有效横移决定展牌方向。
  ///
  /// 顶牌跟着手指走：往右拖 → 从左往右（顶牌 = 最右那张，牌带朝右铺），
  /// 往左拖 → 从右往左（顶牌 = 最左那张，牌带朝左铺）。
  ///
  /// 只在收拢态起拖时判定：已经摊开的牌再拖只是跟手收放（拖过头也只钳在 0），
  /// 不换向。一次拖动只定一次，[_dragOpenDx] 同时兼作「已判过」的标记和换向后
  /// 行程符号的校正量。
  void _resolveDragDirection(Offset delta) {
    if (_dragStartCardProgress != 0 || _dragOpenDx != 0) return;
    if (delta.dx.abs() < kDirectionDragSlop) return;
    _dragOpenDx = delta.dx > 0 ? 1 : -1;
    final desired = _dragOpenDx > 0
        ? SpreadDirection.leftToRight
        : SpreadDirection.rightToLeft;
    if (desired != _effectiveDirection) {
      _applyDirection(desired);
    }
  }

  /// 换向：把**生效方向**翻过去，并通知调用方（有回调的话）。
  ///
  /// 生效方向必须先翻：没有 [CardFanSpread.onDirectionChanged] 时调用方不接管，
  /// 建议就无处可去，收拢态往另一侧拖会被钳在临界值上完全没反应。
  void _applyDirection(SpreadDirection desired) {
    _effectiveDirection = desired;
    widget.onDirectionChanged?.call(desired);
  }

  /// 开扇收拢态下，手势自己定方向——与展牌 [_resolveDragDirection] 同一套规则：
  /// 顶牌跟着手指走，手指把顶牌往顺时针带 → [SpreadDirection.leftToRight]
  /// （扇形朝右铺开），往逆时针带 → [SpreadDirection.rightToLeft]。
  ///
  /// 触发时机（两种，语义相同——都是「顶牌跟着手指走」）：
  /// 1. 起拖时画面收拢（`_dragStartFanCollapsed`，进度 0 或角度本就是收拢角）：
  ///    第一次有效转向就定方向；
  /// 2. 张开的扇被往里拖到 0° 之后，手指继续往同侧推（[rawAngle] 越过下限）。
  ///    没有这条，拖到 0° 再推只会被 clamp 一直按在 0°，手感就是「卡住」。
  ///
  /// 停在 0° 上不再推的人不会误翻（情形 2 要求 [rawAngle] 真的越过下限）；
  /// 一次拖动最多换一次向。
  ///
  /// 返回 true 表示已经换向并重置了拖动基准，调用方要跟着重置
  /// [startFanAngle] 之类的本地快照，否则这一帧会用旧基准算出跳变。
  ///
  /// **不限制「一次拖动只能换一次向」**：顶牌每穿过一次收拢角（竖立位置）就翻
  /// 一次，往复拖动就能来回换向。每次换向都会把累计转角清零，所以静止的手指
  /// 不会连续翻；[kFanDirectionDragSlop] 的 6° 就是换向后的滞回，挡住边界抖动。
  bool _resolveFanDragDirection(FanSpreadLayout layout, double rawAngle) {
    if (layout.mode != FanSpreadMode.fan) return false;
    if (_dragAngleDelta.abs() < kFanDirectionDragSlop) return false;
    // 不是收拢态起拖的话，必须真的把扇子推过收拢角才换向。
    if (!_dragStartFanCollapsed && rawAngle > kMinFanAngle) return false;
    final desired = _dragAngleDelta > 0
        ? SpreadDirection.leftToRight
        : SpreadDirection.rightToLeft;
    if (desired == _effectiveDirection) return false;
    _applyDirection(desired);
    // 换向后同一个手势要能接着把扇子张开：从**收拢角**重新起步（画面此时就是
    // 一叠重合的牌，`widget.fanAngle` 可能还是旧的 220°），符号取反——镜像之后
    // 手指的转向正好对应摆幅增大。
    _dragStartFanAngle = kMinFanAngle;
    _dragAngleDelta = 0;
    _dragSign = -_dragSign;
    return true;
  }

  /// 反解总进度：找最小的 v（0~1）使第 [i] 张牌的单卡进度 ≥ [cardProgress]。
  ///
  /// 总进度才是动画的值，而跟手算出来的是「顶牌该到哪儿」，两者差着
  /// 逐张错峰与缓动曲线。单卡进度对总进度单调不减，二分即可，
  /// 不必去反解 [curve]。
  double _progressForCardProgress(
    CardSpreadLayout layout,
    int i,
    double cardProgress,
  ) {
    // 两端直接给精确值：二分会留下 1e-8 量级的尾巴，收拢态看着没关严实。
    if (cardProgress <= 0) return 0;
    if (cardProgress >= 1) return 1;
    var lo = 0.0;
    var hi = 1.0;
    for (var k = 0; k < 24; k++) {
      final mid = (lo + hi) / 2;
      final p = layout.cardProgressAt(
        i,
        mid,
        stagger: widget.stagger,
        curve: widget.curve,
      );
      if (p >= cardProgress) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    return hi;
  }

  /// 跟手定位进度：停掉正在跑的动画后直接赋值。
  ///
  /// 有 controller 时走 controller，让绑定在同一个 controller 上的组件一起动。
  void _seekProgress(double value) {
    final controller = widget.controller;
    if (controller != null) {
      controller.seekTo(value);
    } else {
      // 先 stop 再赋值：正在跑的动画会在下一帧把 value 覆盖回去。
      _animation.stop();
      _animation.value = value;
    }
  }

  void _onFanAngleDragStart(
    DragStartDetails details,
    ValueChanged<double> onFanAngleChanged,
  ) {
    final layout = _lastLayout;
    // 展牌模式不使用 fanAngle；触摸没落在可抓取的牌上也不响应。
    if (layout is! FanSpreadLayout) return;
    final i = _hitTopCard(details.localPosition, layout);
    if (i < 0) return;
    // 牌堆未展开（或正在收拢）时拖动最顶的牌：一并播放展开动画。
    // 「拖动 → 开扇」是一个连贯动作，否则只改角度在收拢态下看不到任何变化。
    // 若正在反向收拢，forward() 会顺势转为展开。
    if (!_animation.isCompleted) {
      _animation.forward();
    }
    // 顶牌绕**自己的**枢轴转：S 扇的枢轴沿脊线排开过、双手开扇是那只手的
    // 握点，都不在公共原点上，指针角度必须绕同一个点测，才和「牌跟着手指转」
    // 对齐（其余模式两者等价）。
    final pivot =
        layout.origin +
        layout.pivotOffsets[i] *
            (layout.pivotFollowsProgress
                ? layout.cardProgressAt(
                    i,
                    _animation.value,
                    stagger: widget.stagger,
                    curve: widget.curve,
                  )
                : 1.0);
    _dragPivot = pivot;
    _dragStartFanAngle = widget.fanAngle;
    _dragPointerAngle = _pointerAngleDeg(details.localPosition, pivot);
    _dragAngleDelta = 0;
    // 起拖时**画面**是否收拢（一叠重合的牌）：进度为 0，或者角度本就是收拢角。
    // 注意不能只看 `fanAngle`——按下「收拢」后进度归零而 fanAngle 还是 220°，
    // 画面同样是一叠；这时方向要由手势直接定，否则往另一侧拖得转满 110° 才换向。
    _dragStartFanCollapsed =
        _animation.value <= 0 || widget.fanAngle <= kMinFanAngle;
    // S 扇的顶牌枢轴离牌心只有 0.44 张牌高，手指离枢轴很近：若按严格几何用
    // 常数 4，扁画布上挪十几像素就会从 220° 直接顶到 360°（实测 30px → +140°，
    // 拖起来像是「固定死在 360」）。改成 4 ×（手指到枢轴的距离 / 牌高）：
    // 手指划过的**弧长**决定开扇角（一张牌高的行程 ≈ 满量程），既与画布大小
    // 无关，也保住了「牌带末端跟着手指走」的手感；贴着枢轴抓时增益最低 1.2。
    _dragGain = layout.mode == FanSpreadMode.sFan
        ? (4 * (details.localPosition - pivot).distance / layout.cardHeight)
              .clamp(1.2, 4.0)
        : 2.0;
    // 方向：顶牌落在扇形**外缘**时（开扇 / S 扇），手指往哪边转、摆幅就往哪边
    // 走，[SpreadDirection.rightToLeft] 是水平镜像，符号取反；双手开扇的顶牌
    // 贴在**内缘**（摆幅越大它越往内侧倒，过了拐点还会翻回来），方向只能问布局
    // 的局部变化率。
    _dragSign = layout.mode == FanSpreadMode.twoHandFan
        ? (layout.targetAngleRateOf(i) < 0 ? -1.0 : 1.0)
        : (_effectiveDirection == SpreadDirection.rightToLeft ? -1.0 : 1.0);
  }

  void _onFanAngleDragUpdate(
    DragUpdateDetails details,
    ValueChanged<double> onFanAngleChanged,
  ) {
    final layout = _lastLayout;
    var startFanAngle = _dragStartFanAngle;
    final pivot = _dragPivot;
    if (layout is! FanSpreadLayout || startFanAngle == null || pivot == null) {
      return;
    }

    final pointer = _pointerAngleDeg(details.localPosition, pivot);
    // 累加「每次更新的增量」而不是直接和起点相减：
    // 指针角度在 ±180°（枢轴正下方）处不连续，直接相减时累计旋转超过 180°
    // 会让增量符号翻转，表现为开扇角在 0° 与上限两个临界值之间来回闪现。
    // 单次更新的增量必然远小于 180°，逐次累加天然完成解绕。
    var step = pointer - _dragPointerAngle;
    while (step > 180) {
      step -= 360;
    }
    while (step < -180) {
      step += 360;
    }
    _dragAngleDelta += step;
    _dragPointerAngle = pointer;
    final gain = _dragGain;
    final sign = _dragSign;
    // 换向判定要用**未被钳制**的原始角度：拖到 0°（或上限）之后手指继续推，
    // 不在这里放行就会被下面的 clamp 一直按在临界值上，表现为「卡住」。
    if (_resolveFanDragDirection(
      layout,
      startFanAngle + sign * gain * _dragAngleDelta,
    )) {
      startFanAngle = _dragStartFanAngle!;
    }

    final next = (startFanAngle + sign * gain * _dragAngleDelta).clamp(
      kMinFanAngle,
      _maxFanAngle,
    );
    // 回写被钳掉的部分：拖到临界值（0° / 上限）后反向拖动应立刻响应，
    // 而不是等手指「补回」越界的量。
    _dragAngleDelta = (next - startFanAngle) / (sign * gain);
    onFanAngleChanged(next);
  }

  /// 结束拖动（开扇调角度与展牌跟手共用一套收尾）。
  void _endDrag() {
    _dragStartFanAngle = null;
    _dragPointerAngle = 0;
    _dragAngleDelta = 0;
    _dragPivot = null;
    _dragGain = 2;
    _dragSign = 1;
    _dragStartCardProgress = null;
    _dragStartPosition = null;
    _dragOpenDx = 0;
    _dragStartFanCollapsed = false;
  }
}

/// 一次真实的贴图（牌图 + 变换 + 装饰强度），用于判定下一张牌是否完全重复。
class _DrawnCard {
  const _DrawnCard({
    required this.image,
    required this.angle,
    required this.pivot,
    required this.tier,
    required this.decorAlpha,
  });

  final ui.Image? image;
  final double angle;
  final Offset pivot;
  final double tier;
  final double decorAlpha;

  bool matches({
    required ui.Image? image,
    required double angle,
    required Offset pivot,
    required double tier,
    required double decorAlpha,
  }) {
    return identical(this.image, image) &&
        this.angle == angle &&
        this.pivot == pivot &&
        this.tier == tier &&
        this.decorAlpha == decorAlpha;
  }
}

class _CardSpreadPainter extends CustomPainter {
  _CardSpreadPainter({
    required this.animation,
    required this.faceMix,
    required this.backCrossFade,
    required this.layout,
    required this.stagger,
    required this.curve,
    required this.showFace,
    required this.backImage,
    required this.previousBackImage,
    required this.faceImages,
    required this.sprites,
    required this.flatSprites,
    required this.spriteCardSizes,
    required this.spriteVersion,
    required this.shadowColor,
  }) : super(repaint: Listenable.merge([animation, faceMix, backCrossFade]));

  /// 关键：进度不能直接快照成字段，否则 repaint 通知重绘时拿到的还是旧值，
  /// 画面会完全静止。这里每次绘制都实时读取动画当前值。
  final Animation<double> animation;

  double get progress => animation.value;

  /// 牌背 / 牌面的淡入淡出进度，同样实时读取。
  final Animation<double> faceMix;

  /// 旧牌背 / 新牌背的交叉溶解进度，同样实时读取。
  final Animation<double> backCrossFade;

  final CardSpreadLayout layout;
  final double stagger;
  final Curve curve;
  final bool showFace;
  final ui.Image? backImage;

  /// 正在淡出的旧牌背（换牌背的过渡期非空，见 [_startBackFade]）。
  final ui.Image? previousBackImage;
  final List<ui.Image?> faceImages;
  final Color shadowColor;

  /// 预合成好的精灵图（带阴影 / 不带阴影），key 为源图。
  final Map<ui.Image, ui.Image> sprites;
  final Map<ui.Image, ui.Image> flatSprites;

  /// 每张精灵里「牌身」那块的逻辑尺寸（见 [CardSpriteCache.spriteCardSizes]）。
  final Map<ui.Image, Size> spriteCardSizes;
  final int spriteVersion;

  int get cardCount => layout.cardCount;

  // 复用画笔，避免每帧为每张牌创建几十个对象。
  //
  // 贴图画笔必须显式设置 filterQuality：默认的 low（纯双线性）在
  // 「旋转 / 分数尺寸缩放 / 大图缩小」时边缘会出现锯齿与摩尔纹。
  // medium（mipmap + 双线性）在这些场景下边缘过渡最平滑
  //（实测旋转 25° 的牌，中间色调像素数比 low 多 ~35%，硬跳变更小）。
  // 精灵图合成（card_sprite.dart 的 _render）用的是同一档质量。
  //
  // 画笔是**实例**字段而不是 static：其中几个在绘制途中会被改 color，
  // 多个 CardFanSpread 实例共享同一组静态可变对象迟早会出错。
  final Paint _opaquePaint = Paint()..filterQuality = FilterQuality.medium;
  final Paint _tint = Paint()..filterQuality = FilterQuality.medium;
  final Paint _borderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = kCardBorderWidth
    ..color = kCardBorderColor;
  final Paint _shadowPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, kCardShadowBlur);

  /// 无图可用时画「空白白牌」用的画笔（每帧写入带 alpha 的底色）。
  final Paint _blankPaint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    switch (layout) {
      case FanSpreadLayout fan:
        _paintFan(canvas, fan);
      case TableSpreadLayout table:
        _paintTableSpread(canvas, table);
    }
  }

  /// 装饰（阴影 + 描边）随相邻牌错位距离淡入：0 = 纯净牌面，1 = 完整装饰。
  ///
  /// 相邻两张牌靠得比阴影延伸范围还近时，两者的投影与描边几乎完全重合，
  /// 多张叠起来就会糊成一条黑边（收拢时 52 张牌完全重合尤其明显）。
  /// 这种情况下装饰强度趋近 0，轮廓交给最底层那一张。
  ///
  /// 注意与阴影颜色无关：即使关掉阴影，重合时仍要淡出描边，否则同样会叠成黑框。
  double _decorationAlpha(Offset center, Offset? previous) {
    if (previous == null) return 1;
    return cardDecorationAlpha((center - previous).distance);
  }

  void _paintFan(Canvas canvas, FanSpreadLayout fan) {
    final tierOffsets = fan.tierOffsets;
    final pivotOffsets = fan.pivotOffsets;
    final pivotFollowsProgress = fan.pivotFollowsProgress;
    final localCenter = Offset(
      fan.cardWidth / 2 - fan.pivotOffset.dx,
      fan.cardHeight / 2 - fan.pivotOffset.dy,
    );
    final mix = faceMix.value;
    // 两个过渡（牌背↔牌面、旧牌背→新牌背）进行中都不能跳过重合的牌：
    // 那两层是半透明叠上去的，少画一层会改变最终混合结果。
    final crossFading =
        (mix > 0 && mix < 1) ||
        (backCrossFade.value > 0 && backCrossFade.value < 1);
    Offset? previousCenter;
    _DrawnCard? previous;
    for (final i in fan.drawOrder) {
      final p = fan.cardProgressAt(i, progress, stagger: stagger, curve: curve);
      final angle = fan.targetAngles[i] * p;
      final tier = tierOffsets[i] * p;
      // 枢轴偏移在**画布坐标系**里累加，与朝向角的旋转无关：
      // 先挪到这张牌自己的枢轴，再旋转（牌身在旋转后会朝外伸出）。
      final pivot =
          fan.origin + pivotOffsets[i] * (pivotFollowsProgress ? p : 1.0);
      final cosValue = math.cos(angle);
      final sinValue = math.sin(angle);
      final center =
          pivot +
          Offset(
            localCenter.dx * cosValue - (localCenter.dy - tier) * sinValue,
            localCenter.dx * sinValue + (localCenter.dy - tier) * cosValue,
          );
      final decorAlpha = _decorationAlpha(center, previousCenter);
      previousCenter = center;

      // 完全重合的牌（收拢态整叠牌、以及逐张错峰还没轮到的那些牌）变换与
      // 图层都相同，再画一遍只是重复同样的像素：跳过它们，52 张重合的收拢态
      // 因此从 52 次贴图降到 1~2 次。
      if (_canSkip(previous, crossFading) &&
          previous!.matches(
            image: _singleImageFor(i, mix),
            angle: angle,
            pivot: pivot,
            tier: tier,
            decorAlpha: decorAlpha,
          )) {
        continue;
      }
      previous = _DrawnCard(
        image: _singleImageFor(i, mix),
        angle: angle,
        pivot: pivot,
        tier: tier,
        decorAlpha: decorAlpha,
      );

      canvas
        ..save()
        ..translate(pivot.dx, pivot.dy)
        ..rotate(angle)
        ..translate(-fan.pivotOffset.dx, -fan.pivotOffset.dy)
        ..translate(0, -tier);
      _drawCard(canvas, fan.localCardRect, i, decorAlpha);
      canvas.restore();
    }
  }

  void _paintTableSpread(Canvas canvas, TableSpreadLayout table) {
    final mix = faceMix.value;
    final crossFading =
        (mix > 0 && mix < 1) ||
        (backCrossFade.value > 0 && backCrossFade.value < 1);
    Offset? previousCenter;
    _DrawnCard? previous;
    for (final i in table.drawOrder) {
      final p = table.cardProgressAt(
        i,
        progress,
        stagger: stagger,
        curve: curve,
      );
      final target = table.centers[i];
      final center = Offset(
        ui.lerpDouble(table.stackOffset.dx, target.dx, p)!,
        ui.lerpDouble(table.stackOffset.dy, target.dy, p)!,
      );
      final angle = ui.lerpDouble(table.stackRotation, table.rotations[i], p)!;
      final decorAlpha = _decorationAlpha(center, previousCenter);
      previousCenter = center;

      if (_canSkip(previous, crossFading) &&
          previous!.matches(
            image: _singleImageFor(i, mix),
            angle: angle,
            pivot: center,
            tier: 0,
            decorAlpha: decorAlpha,
          )) {
        continue;
      }
      previous = _DrawnCard(
        image: _singleImageFor(i, mix),
        angle: angle,
        pivot: center,
        tier: 0,
        decorAlpha: decorAlpha,
      );

      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..rotate(angle);
      _drawCard(canvas, table.localCardRect, i, decorAlpha);
      canvas.restore();
    }
  }

  /// 上一次真正画出去的那张牌，用于跳过与它完全重合的后续牌。
  static bool _canSkip(_DrawnCard? previous, bool crossFading) {
    // 交叉淡入淡出进行中不能跳过：那两张牌是半透明叠上去的，少画一层
    // 会改变最终混合结果（重合的牌也会因此透出不一样的颜色）。
    return previous != null && !crossFading;
  }

  /// 非过渡状态下第 i 张牌实际贴的那张图（过渡中返回 null，表示「不适用」）。
  ui.Image? _singleImageFor(int i, double mix) {
    if (mix <= 0) return backImage;
    return _faceImageFor(i) ?? backImage;
  }

  // ---------------- 单张牌绘制 ----------------

  ui.Image? _faceImageFor(int i) {
    if (faceImages.isEmpty) return null;
    return faceImages[i % faceImages.length];
  }

  void _drawCard(Canvas canvas, Rect rect, int i, double decorAlpha) {
    // 牌背 / 牌面切换时做交叉淡入淡出，避免整幅画面明暗跳变。
    // faceMix.value 本身就编码了状态（0 = 牌背，1 = 牌面，中间 = 过渡中），
    // 不能再拿 showFace 做门控，否则反向切换会瞬间跳变。
    final back = backImage;
    final face = _faceImageFor(i);
    final mix = faceMix.value;

    final faceOnTop = face != null && !identical(face, back) && mix > 0;
    if (faceOnTop && mix >= 1) {
      _paintCardImage(canvas, rect, face, 1, decorAlpha);
      return;
    }

    // 牌背层：换牌背时从旧牌背交叉溶解到新牌背；新牌背还没解码好时继续画旧的，
    // 免得每张牌先闪一下空白白牌。
    final outgoing = previousBackImage;
    final backMix = backCrossFade.value;
    if (outgoing != null && !identical(outgoing, back)) {
      if (back == null || backMix <= 0) {
        _paintCardImage(canvas, rect, outgoing, 1, decorAlpha);
      } else if (backMix >= 1) {
        _paintCardImage(canvas, rect, back, 1, decorAlpha);
      } else {
        // 与牌背 ↔ 牌面同一套系数：基底保持不透明、只让新牌背按进度淡入，
        // 重合的牌才不会被几十层半透明叠穿。
        _paintCardImage(
          canvas,
          rect,
          outgoing,
          1 - backMix * decorAlpha,
          decorAlpha,
        );
        _paintCardImage(canvas, rect, back, backMix, decorAlpha);
      }
    } else {
      _paintCardImage(canvas, rect, back, 1, decorAlpha);
    }

    if (faceOnTop) {
      _paintCardImage(canvas, rect, face, mix, decorAlpha);
    }
  }

  /// 画一张牌（牌图 + 随 [alpha] 缩放的装饰）。
  ///
  /// [alpha] 是牌背 / 牌面交叉淡入淡出的强度，两级（纯净 / 带装饰）都按它绘制，
  /// 不能有任何一级被满不透明地画上去，否则重合的牌会跳过淡入淡出。
  ///
  /// 装饰分两层叠加：先画纯净牌面，再把带阴影/描边的版本按 [decorAlpha]
  /// 半透明地盖上去。这样装饰强度可以连续变化，不会突然出现或消失。
  void _paintCardImage(
    Canvas canvas,
    Rect rect,
    ui.Image? image,
    double alpha,
    double decorAlpha,
  ) {
    if (alpha <= 0) return;
    final flat = image == null ? null : flatSprites[image];
    final decorated = image == null ? null : sprites[image];
    final paint = _tintPaint(alpha);

    if (decorated != null) {
      final dst = _spriteDst(rect, image!, decorated);
      if (decorAlpha >= 1) {
        canvas.drawImageRect(decorated, _srcOf(decorated), dst, paint);
        return;
      }
      if (flat != null) {
        // 纯净精灵同样要跟着 [alpha] 淡入淡出：这里以前用满不透明的
        // [_opaquePaint]，于是牌几乎重合（走这条分支）时牌背 ↔ 牌面的
        // 交叉淡入淡出被完全忽略，切换是瞬间跳变。
        //（alpha == 1 时 [_tintPaint] 返回的就是 [_opaquePaint]，非过渡帧不受影响。）
        canvas.drawImageRect(flat, _srcOf(flat), dst, paint);
        // 装饰层的强度量化后已经是 0 就不必再贴一次（收拢态 52 张重合的牌
        // 因此每张都省掉一次贴图）。
        if ((alpha * decorAlpha * 255).round() <= 0) return;
      }
      canvas.drawImageRect(
        decorated,
        _srcOf(decorated),
        dst,
        _tintPaint(alpha * decorAlpha),
      );
      return;
    }

    _paintFallback(canvas, rect, image, alpha, decorAlpha);
  }

  /// 精灵图还没合成好（首帧 / 尺寸刚变化）时的逐帧绘制路径。
  /// 样式与精灵图保持一致，避免精灵到位时画面突然变化。
  void _paintFallback(
    Canvas canvas,
    Rect rect,
    ui.Image? image,
    double alpha,
    double decorAlpha,
  ) {
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(rect.shortestSide * 0.07),
    );
    final decor = alpha * decorAlpha;
    if (decor > 0 && shadowColor.a > 0) {
      _shadowPaint.color = shadowColor.withValues(alpha: shadowColor.a * decor);
      canvas.drawRRect(rrect.shift(kCardShadowOffset), _shadowPaint);
    }
    if (image == null) {
      // 没有任何可用牌图（未传 / 还没解码好 / 解码失败）：
      // 按一张背面朝上的空白白牌绘制。
      // 注意不能拿 [_tintPaint] / [_opaquePaint] 填充——那个画笔的颜色是默认
      // 的纯黑（它只用于贴图，颜色被忽略），填充矩形会让整叠牌变成黑块。
      _blankPaint.color = kCardBlankColor.withValues(alpha: alpha);
      canvas.drawRRect(rrect, _blankPaint);
      if (decor > 0) {
        _borderPaint.color = kCardBorderColor.withValues(
          alpha: kCardBorderColor.a * decor,
        );
        canvas.drawRRect(rrect, _borderPaint);
      }
      return;
    }
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      rect,
      _tintPaint(alpha),
    );
    canvas.restore();
    if (decor > 0) {
      _borderPaint.color = kCardBorderColor.withValues(
        alpha: kCardBorderColor.a * decor,
      );
      canvas.drawRRect(rrect, _borderPaint);
    }
  }

  /// 精灵图的源区域（整张）。Rect 很轻量，每帧每张牌各创建一个。
  static Rect _srcOf(ui.Image image) =>
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());

  /// 精灵图贴到画布上的目标矩形：把精灵里的**牌身**精确对齐到 [rect]。
  ///
  /// 不能直接写 `rect.inflate(kCardSpritePadding)`：留白是合成时按
  /// [kCardSpritePadding] 加的，而合成尺寸（量化 / 档位 / 尺寸还在变时的旧精灵）
  /// 未必等于此刻布局给的牌尺寸，那样会把留白一起缩放、牌身画大或画小——
  /// 精灵高大 15% 时牌就被画大 2%，差一倍时差 10%，首屏精灵陆续到位的过程里
  /// 看起来就是纸牌忽大忽小。
  Rect _spriteDst(Rect rect, ui.Image source, ui.Image sprite) {
    final cardSize = spriteCardSizes[source];
    if (cardSize == null || cardSize.width <= 0 || cardSize.height <= 0) {
      return rect.inflate(kCardSpritePadding);
    }
    final scaleX = rect.width / cardSize.width;
    final scaleY = rect.height / cardSize.height;
    return Rect.fromLTWH(
      rect.left - kCardSpritePadding * scaleX,
      rect.top - kCardSpritePadding * scaleY,
      (cardSize.width + 2 * kCardSpritePadding) * scaleX,
      (cardSize.height + 2 * kCardSpritePadding) * scaleY,
    );
  }

  /// 复用同一个 Paint，按 alpha 着色（白色 tint 不改变颜色，只做整体淡出）。
  /// 继承 [_opaquePaint] / [_tint] 上的 medium 过滤质量，保证贴图边缘抗锯齿。
  Paint _tintPaint(double alpha) {
    final a = (alpha * 255).round().clamp(0, 255);
    return a >= 255
        ? _opaquePaint
        : (_tint..color = Color.fromARGB(a, 255, 255, 255));
  }

  @override
  bool shouldRepaint(_CardSpreadPainter oldDelegate) {
    return !identical(oldDelegate.animation, animation) ||
        !identical(oldDelegate.faceMix, faceMix) ||
        !identical(oldDelegate.backCrossFade, backCrossFade) ||
        // 模式与方向都进了 layout.key（见 CardSpreadLayout），这里不必再比一遍。
        oldDelegate.layout.key != layout.key ||
        oldDelegate.stagger != stagger ||
        oldDelegate.curve != curve ||
        oldDelegate.showFace != showFace ||
        oldDelegate.spriteVersion != spriteVersion ||
        oldDelegate.shadowColor != shadowColor ||
        oldDelegate.backImage != backImage ||
        oldDelegate.previousBackImage != previousBackImage ||
        !listEquals(oldDelegate.faceImages, faceImages);
  }
}
