import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:card_fan_spread/card_fan_spread.dart';
import 'package:card_fan_spread/src/card_layout.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_card_image.dart';

const Size _canvas = Size(400, 600);

/// 双手开扇布局（其余参数与组件一致地透传，验证「参数与开扇一样」）。
FanSpreadLayout _twoHandLayout({
  double fanAngle = 220,
  int cardCount = 52,
  Size canvas = _canvas,
  double tierRatio = 0,
  double pivotX = kDefaultFanPivotX,
  double pivotLift = kDefaultFanPivotLift,
  SpreadDirection direction = SpreadDirection.leftToRight,
}) {
  return CardSpreadLayout.compute(
    mode: FanSpreadMode.twoHandFan,
    canvas: canvas,
    cardCount: cardCount,
    fanAngle: fanAngle,
    fanTierRatio: tierRatio,
    fanPivotX: pivotX,
    fanPivotLift: pivotLift,
    tableStepRatio: 0.09,
    tableArcLift: -0.6,
    direction: direction,
  ) as FanSpreadLayout;
}

/// 第 [i] 张牌在进度 [p] 时的画布中心（与画家同一套变换）。
Offset _cardCenter(FanSpreadLayout layout, int i, [double p = 1]) {
  final angle = layout.targetAngles[i] * p;
  final local = Offset(
    layout.cardWidth / 2 - layout.pivotOffset.dx,
    layout.cardHeight / 2 - layout.pivotOffset.dy,
  );
  return layout.origin +
      layout.pivotOffsets[i] * (layout.pivotFollowsProgress ? p : 1) +
      Offset(
        local.dx * math.cos(angle) - local.dy * math.sin(angle),
        local.dx * math.sin(angle) + local.dy * math.cos(angle),
      );
}

/// 第 [i] 张牌的四个角在画布中的坐标。
List<Offset> _cardCorners(FanSpreadLayout layout, int i) {
  final angle = layout.targetAngles[i];
  final cos = math.cos(angle);
  final sin = math.sin(angle);
  return <Offset>[
    for (final corner in <Offset>[
      Offset.zero,
      Offset(layout.cardWidth, 0),
      Offset(0, layout.cardHeight),
      Offset(layout.cardWidth, layout.cardHeight),
    ])
      layout.origin +
          layout.pivotOffsets[i] +
          Offset(
            (corner.dx - layout.pivotOffset.dx) * cos -
                (corner.dy - layout.pivotOffset.dy) * sin,
            (corner.dx - layout.pivotOffset.dx) * sin +
                (corner.dy - layout.pivotOffset.dy) * cos,
          ),
  ];
}

/// 整副牌在画布中的包围盒。
({double minX, double maxX, double minY, double maxY}) _bounds(
  FanSpreadLayout layout,
) {
  var minX = double.infinity;
  var maxX = -double.infinity;
  var minY = double.infinity;
  var maxY = -double.infinity;
  for (var i = 0; i < layout.cardCount; i++) {
    for (final p in _cardCorners(layout, i)) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
  }
  return (minX: minX, maxX: maxX, minY: minY, maxY: maxY);
}

Widget _app({
  required ui.Image back,
  required CardFanSpreadController controller,
  double fanAngle = 220,
  ValueChanged<double>? onFanAngleChanged,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: _canvas.width,
        height: _canvas.height,
        child: CardFanSpread(
          mode: FanSpreadMode.twoHandFan,
          controller: controller,
          cardBack: TestCardImage(back),
          fanAngle: fanAngle,
          autoPlay: false,
          onFanAngleChanged: onFanAngleChanged,
        ),
      ),
    ),
  );
}

/// 绕 [pivot]、半径 [radius]、指针角 [deg] 的画布点（0 = 正上方，顺时针为正）。
///
/// 与组件内部测「牌转了多少度」用的是同一套口径（`atan2(dx, −dy)`）：照这样
/// 铺出的轨迹，等于手指绕着那只手画圆。
Offset _pointerAt(Offset pivot, double radius, double deg) {
  final r = deg * math.pi / 180;
  return pivot + Offset(radius * math.sin(r), -radius * math.cos(r));
}

/// 拖某一叠的**顶牌**：从它的中心起，绕**那只手**的握点沿圆弧转 [sweepDeg]
/// 度（正 = 顺时针），返回回调收到的全部角度。
///
/// [play] 为 false 时不播放展开动画（模拟收拢态起拖）。
Future<List<double>> _dragPileTop(
  WidgetTester tester, {
  required ui.Image back,
  required FanSpreadLayout layout,
  required int topIndex,
  required double startFanAngle,
  required double sweepDeg,
  bool play = true,
}) async {
  final controller = CardFanSpreadController();
  final reports = <double>[];
  await tester.pumpWidget(
    _app(
      back: back,
      controller: controller,
      fanAngle: startFanAngle,
      onFanAngleChanged: reports.add,
    ),
  );
  if (play) {
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.progress, 1);
  }

  final pivot = layout.origin + layout.pivotOffsets[topIndex];
  final center = _cardCenter(layout, topIndex);
  final radius = (center - pivot).distance;
  final startDeg =
      math.atan2(center.dx - pivot.dx, -(center.dy - pivot.dy)) * 180 / math.pi;
  final gesture = await tester.startGesture(center);
  for (var k = 1; k <= 4; k++) {
    await gesture.moveTo(
      _pointerAt(pivot, radius, startDeg + sweepDeg * k / 4),
    );
    await tester.pump();
  }
  await gesture.up();
  await tester.pump();
  controller.dispose();
  return reports;
}

void main() {
  late ui.Image back;

  setUpAll(() async {
    back = await solidCardImage(const ui.Color(0xFF333366));
  });

  test('双手开扇：左右两扇各自在自己的半区里扫开', () {
    const fanAngle = 220.0;
    final layout = _twoHandLayout(fanAngle: fanAngle);
    final n = layout.cardCount;
    final left = n ~/ 2;
    final sweep = fanAngle * math.pi / 180;

    // 左扇朝左（−90°）：从 −90° − half 扫到 −90° + half。
    for (var i = 0; i < left; i++) {
      final expected = -math.pi / 2 - sweep / 2 + sweep * i / (left - 1);
      expect(layout.targetAngles[i], closeTo(expected, 1e-9));
    }
    // 右扇朝右（+90°）：从 +90° − half 扫到 +90° + half。
    for (var j = 0; j < n - left; j++) {
      final expected = math.pi / 2 - sweep / 2 + sweep * j / (n - left - 1);
      expect(layout.targetAngles[left + j], closeTo(expected, 1e-9));
    }

    // 两端：左扇首牌在 −200°、右扇末牌在 +200°，两扇在上下两端交叉。
    expect(layout.targetAngles.first, closeTo(-200 * math.pi / 180, 1e-9));
    expect(layout.targetAngles[left - 1], closeTo(20 * math.pi / 180, 1e-9));
    expect(layout.targetAngles[left], closeTo(-20 * math.pi / 180, 1e-9));
    expect(layout.targetAngles.last, closeTo(200 * math.pi / 180, 1e-9));
  });

  test('双手开扇：两扇严格镜像对称（偶数牌数）', () {
    final layout = _twoHandLayout();
    final n = layout.cardCount;
    final left = n ~/ 2;

    for (var j = 0; j < left; j++) {
      // 右扇第 j 张 = 左扇第（left − 1 − j）张的镜像（θ → −θ）。
      expect(
        layout.targetAngles[left + j],
        closeTo(-layout.targetAngles[left - 1 - j], 1e-9),
      );
      // 位置同样镜像：绕公共枢轴旋转 θ 与 −θ 互为镜像。
      final a = _cardCenter(layout, left + j);
      final b = _cardCenter(layout, left - 1 - j);
      expect(
        a.dx - layout.origin.dx,
        closeTo(-(b.dx - layout.origin.dx), 1e-9),
      );
      expect(a.dy - layout.origin.dy, closeTo(b.dy - layout.origin.dy, 1e-9));
    }
  });

  test('双手开扇：每一边最大 220°，超出部分被钳掉', () {
    expect(kMaxTwoHandFanAngle, 220);

    // 超过 220° 一律按 220° 布局：几何与指纹都相同（拖过界不触发重排）。
    final at220 = _twoHandLayout(fanAngle: 220);
    for (final over in <double>[240, 300, 360]) {
      final clamped = _twoHandLayout(fanAngle: over);
      expect(clamped.key, at220.key);
      for (var i = 0; i < clamped.cardCount; i++) {
        expect(clamped.targetAngles[i], closeTo(at220.targetAngles[i], 1e-9));
      }
    }

    // 每一边的跨度恰好 220°。
    final left = at220.cardCount ~/ 2;
    expect(
      at220.targetAngles[left - 1] - at220.targetAngles[0],
      closeTo(220 * math.pi / 180, 1e-9),
    );
    expect(
      at220.targetAngles[at220.cardCount - 1] - at220.targetAngles[left],
      closeTo(220 * math.pi / 180, 1e-9),
    );

    // 小于 220° 时两扇按比例收窄，不钳位；中心方向在摆幅到 90° 前按比例从
    // 竖直转出去（110° 时中心已经落在正外侧 ±90°，每扇跨度 110°、首牌在 −145°）。
    final narrow = _twoHandLayout(fanAngle: 110);
    expect(
      narrow.targetAngles[0],
      closeTo(-(math.pi / 2 + 110 * math.pi / 180 / 2), 1e-9),
    );
    expect(
      narrow.targetAngles[narrow.cardCount - 1],
      closeTo(math.pi / 2 + 110 * math.pi / 180 / 2, 1e-9),
    );
  });

  test('双手开扇：扇幅 ≥90° 时两扇以正左右为中心（上下平分空间、不朝上歪）', () {
    const kMax = 220.0;
    for (final fanAngle in <double>[90, 110, 140, 180, kMax]) {
      final layout = _twoHandLayout(fanAngle: fanAngle);
      final n = layout.cardCount;
      final left = n ~/ 2;
      // 左扇首尾两张的角平分线 = −90°（朝左），右扇同理。中心落在正外侧，
      // 扇面的角覆盖就以水平线上下对称 —— 这正是「上下平分空间、不朝上歪」
      // 的几何条件（旧版线性转到 220° 时，140° 的中心才 −57°，整体偏上、
      // 中下部留一大块空白）。
      expect(
        (layout.targetAngles[0] + layout.targetAngles[left - 1]) / 2,
        closeTo(-math.pi / 2, 1e-9),
        reason: '$fanAngle° 时左扇应以朝左为中心',
      );
      expect(
        (layout.targetAngles[left] + layout.targetAngles[n - 1]) / 2,
        closeTo(math.pi / 2, 1e-9),
        reason: '$fanAngle° 时右扇应以朝右为中心',
      );
      // 上下的牌数相等（以水平线为界）：扇面确实平分上下空间。
      final upper = layout.targetAngles.where((a) => math.cos(a) > 0).length;
      expect(upper * 2, n, reason: '$fanAngle° 时朝上的牌与朝下的牌应一样多');
    }

    // 90° 以下仍从竖直按比例转出（这样 0° 才是「收拢 = 竖直」）。
    final narrow = _twoHandLayout(fanAngle: 45);
    expect(
      (narrow.targetAngles[0] +
              narrow.targetAngles[narrow.cardCount ~/ 2 - 1]) /
          2,
      closeTo(-math.pi / 4, 1e-9),
    );
  });

  test('双手开扇：0° 时两扇都没张开，两半各在自己那只手里成叠', () {
    final layout = _twoHandLayout(fanAngle: 0);
    final n = layout.cardCount;
    final left = n ~/ 2;
    for (final angle in layout.targetAngles) {
      expect(angle, 0);
    }
    // 左手那半的牌重合在左手、右手那半的重合在右手：两叠竖牌，而不是一叠
    //（双手各捏一半，牌没扇开也还是各自握在手里）。
    final leftCenters = <Offset>[
      for (var i = 0; i < left; i++) _cardCenter(layout, i),
    ];
    for (final center in leftCenters) {
      expect((center - leftCenters.first).distance, lessThan(1e-9));
    }
    final rightCenters = <Offset>[
      for (var i = left; i < n; i++) _cardCenter(layout, i),
    ];
    for (final center in rightCenters) {
      expect((center - rightCenters.first).distance, lessThan(1e-9));
    }
    expect(
      (rightCenters.first - leftCenters.first).distance,
      greaterThan(0.5 * layout.cardHeight),
    );
  });

  test('双手开扇：两只手分居左右、镜像对称，不合并成一只手', () {
    final layout = _twoHandLayout();
    final n = layout.cardCount;
    final left = n ~/ 2;
    // 左手在左、右手在右，离公共原点等距（镜像对称）。
    for (var i = 0; i < left; i++) {
      expect(layout.pivotOffsets[i].dx, lessThan(0));
      expect(layout.pivotOffsets[i].dy, 0);
      expect(layout.pivotOffsets[i], layout.pivotOffsets[0]);
    }
    for (var i = left; i < n; i++) {
      expect(layout.pivotOffsets[i].dx, greaterThan(0));
      expect(layout.pivotOffsets[i].dy, 0);
      expect(layout.pivotOffsets[i], layout.pivotOffsets[n - 1]);
    }
    expect(
      layout.pivotOffsets[left].dx,
      closeTo(-layout.pivotOffsets[0].dx, 1e-9),
    );
    // 两只手真的分开了（一手多宽，而不是挤在一个点上），也没远到各扇各的。
    final gap = layout.pivotOffsets[left].dx - layout.pivotOffsets[0].dx;
    expect(gap, greaterThan(0.5 * layout.cardHeight));
    expect(gap, lessThan(1.6 * layout.cardHeight));
  });

  test('双手开扇：收拢态就是左右两叠，两只手不合并', () {
    final layout = _twoHandLayout();
    final n = layout.cardCount;
    final left = n ~/ 2;
    final centers = <Offset>[
      for (var i = 0; i < n; i++) _cardCenter(layout, i, 0),
    ];
    // 收拢时左右各半的牌分别重合在自己那只手上：两叠，而不是一叠。
    for (var i = 0; i < left; i++) {
      expect((centers[i] - centers[0]).distance, lessThan(1e-9));
    }
    for (var i = left; i < n; i++) {
      expect((centers[i] - centers[left]).distance, lessThan(1e-9));
    }
    expect(
      (centers[left] - centers[0]).distance,
      greaterThan(0.5 * layout.cardHeight),
    );
    // 逐张错峰：两扇都从两手之间的接缝向各自的外侧张开（接缝那端先出、
    // 最外端最后跟上），而 [direction] 决定哪只手先动——先动的那只手整扇
    // 早于另一只，所以同一进度下它的牌走得更靠前。
    final leftHand = layout.cardCount ~/ 2 - 1; // 左扇最外端
    final rightHand = layout.cardCount - 1; // 右扇最外端
    expect(
      layout.cardProgressAt(leftHand, 0.5, stagger: 0.55, curve: Curves.linear),
      greaterThan(
        layout.cardProgressAt(
          rightHand,
          0.5,
          stagger: 0.55,
          curve: Curves.linear,
        ),
      ),
    );
  });

  test('双手开扇：每扇从接缝向两端张开，方向决定哪只手先动', () {
    final layout = _twoHandLayout();
    final n = layout.cardCount;
    final left = n ~/ 2;
    // 每只手内部：靠接缝的那端最先出发，最外端最后跟上。
    expect(layout.delayOf(left - 1), lessThan(layout.delayOf(0)));
    expect(layout.delayOf(left), lessThan(layout.delayOf(n - 1)));
    // leftToRight：左手先动，左扇整扇早于右扇（各占一半行程）。
    for (var i = 0; i < left; i++) {
      // 先动的手整扇落在前半程 [0, 0.5]，另一只落在后半程（0.5, 1]。
      expect(layout.delayOf(i), lessThanOrEqualTo(0.5));
      expect(layout.delayOf(left + i), greaterThan(0.5));
      expect(layout.delayOf(i), lessThan(layout.delayOf(left + i)));
    }
    // 换方向：右手先动，两扇的先后对调（各自仍是接缝先出、外端最后）。
    final rtl = _twoHandLayout(direction: SpreadDirection.rightToLeft);
    expect(rtl.delayOf(left - 1), lessThan(rtl.delayOf(0)));
    expect(rtl.delayOf(left), lessThan(rtl.delayOf(n - 1)));
    for (var i = 0; i < left; i++) {
      expect(rtl.delayOf(i), greaterThan(0.5));
      expect(rtl.delayOf(left + i), lessThanOrEqualTo(0.5));
      expect(rtl.delayOf(left + i), lessThan(rtl.delayOf(i)));
    }
  });

  test('双手开扇：方向决定哪半叠压在上层', () {
    final ltr = _twoHandLayout();
    final rtl = _twoHandLayout(direction: SpreadDirection.rightToLeft);
    final n = ltr.cardCount;
    final left = n ~/ 2;
    // leftToRight：右手后动 → 右半叠压在上层（最后画的是右半叠的牌）。
    expect(ltr.drawOrder.last, n - 1);
    // rightToLeft：左手后动 → 左半叠压在上层。
    expect(rtl.drawOrder.last, 0);
    expect(rtl.drawOrder.first, n - 1);
    // 两扇的几何不受方向影响：还是左手在左、右手在右。
    for (var i = 0; i < left; i++) {
      expect(rtl.pivotOffsets[i].dx, closeTo(ltr.pivotOffsets[i].dx, 1e-9));
      expect(rtl.targetAngles[i], closeTo(ltr.targetAngles[i], 1e-9));
    }
    expect(rtl.key, isNot(ltr.key));
  });

  test('双手开扇：没有双层错落', () {
    final plain = _twoHandLayout();
    final tiered = _twoHandLayout(tierRatio: 0.44);
    // 两扇在上下两端交叉盖在一起，错层只会糊成一团：参数被忽略。
    for (final offset in tiered.tierOffsets) {
      expect(offset, 0);
    }
    // 参数既然被忽略，布局指纹就应当一致——否则拖滑块会白重排一次。
    expect(tiered.key, plain.key);

    // 对照：开扇模式下双层错落照旧生效。
    final fan = CardSpreadLayout.compute(
      mode: FanSpreadMode.fan,
      canvas: _canvas,
      cardCount: 52,
      fanAngle: 220,
      fanTierRatio: 0.44,
      fanPivotX: kDefaultFanPivotX,
      fanPivotLift: kDefaultFanPivotLift,
      tableStepRatio: 0.09,
      tableArcLift: -0.6,
      direction: SpreadDirection.leftToRight,
    ) as FanSpreadLayout;
    expect(fan.tierOffsets[1], greaterThan(0));
  });

  test('双手开扇：fanPivotX / fanPivotLift 与开扇一样生效', () {
    // 枢轴在牌内的相对位置随参数走（S 扇会被固定成默认值，这里不能）。
    for (final pivotX in <double>[0, 0.25, 1]) {
      final layout = _twoHandLayout(pivotX: pivotX);
      expect(layout.pivotOffset.dx / layout.cardWidth, closeTo(pivotX, 1e-9));
    }
    for (final pivotLift in <double>[-0.5, 0, 1]) {
      final layout = _twoHandLayout(pivotLift: pivotLift);
      expect(
        layout.pivotOffset.dy / layout.cardHeight,
        closeTo(1 + pivotLift, 1e-9),
      );
    }

    // 参数变化要反映到布局指纹上，否则 shouldRepaint 会漏判。
    expect(_twoHandLayout(pivotX: 0).key, isNot(_twoHandLayout().key));
    expect(_twoHandLayout(pivotLift: 1).key, isNot(_twoHandLayout().key));
  });

  test('双手开扇：布局指纹与其它模式不同', () {
    final twoHand = _twoHandLayout();
    FanSpreadLayout other(FanSpreadMode mode) => CardSpreadLayout.compute(
      mode: mode,
      canvas: _canvas,
      cardCount: 52,
      fanAngle: 220,
      fanTierRatio: 0,
      fanPivotX: kDefaultFanPivotX,
      fanPivotLift: kDefaultFanPivotLift,
      tableStepRatio: 0.09,
      tableArcLift: -0.6,
      direction: SpreadDirection.leftToRight,
    ) as FanSpreadLayout;

    expect(twoHand.key, isNot(other(FanSpreadMode.fan).key));
    expect(twoHand.key, isNot(other(FanSpreadMode.sFan).key));
    // 同一个开扇模式换个方向，指纹也必须变（方向进了 key）。
    final ltr = CardSpreadLayout.compute(
      mode: FanSpreadMode.fan,
      canvas: _canvas,
      cardCount: 52,
      fanAngle: 220,
      fanTierRatio: 0,
      fanPivotX: kDefaultFanPivotX,
      fanPivotLift: kDefaultFanPivotLift,
      tableStepRatio: 0.09,
      tableArcLift: -0.6,
      direction: SpreadDirection.leftToRight,
    );
    final rtl = CardSpreadLayout.compute(
      mode: FanSpreadMode.fan,
      canvas: _canvas,
      cardCount: 52,
      fanAngle: 220,
      fanTierRatio: 0,
      fanPivotX: kDefaultFanPivotX,
      fanPivotLift: kDefaultFanPivotLift,
      tableStepRatio: 0.09,
      tableArcLift: -0.6,
      direction: SpreadDirection.rightToLeft,
    );
    expect(rtl.key, isNot(ltr.key));
  });

  test('双手开扇：整副牌始终落在画布内', () {
    for (final fanAngle in <double>[0, 90, 220, 360]) {
      for (final canvas in <Size>[
        const Size(400, 600),
        const Size(1000, 400),
        const Size(640, 640),
      ]) {
        final layout = _twoHandLayout(fanAngle: fanAngle, canvas: canvas);
        final b = _bounds(layout);
        expect(b.minX, greaterThanOrEqualTo(-0.5));
        expect(b.maxX, lessThanOrEqualTo(canvas.width + 0.5));
        expect(b.minY, greaterThanOrEqualTo(-0.5));
        expect(b.maxY, lessThanOrEqualTo(canvas.height + 0.5));
      }
    }
  });

  test('双手开扇：左右各一扇（各自朝外扫开，上下两端交叉）', () {
    final layout = _twoHandLayout();
    final origin = layout.origin;
    // 统计各方向上的牌数：左半圆与右半圆都不为空，且上下交叉处两扇都有牌。
    var leftHalf = 0;
    var rightHalf = 0;
    var topSeam = 0;
    var bottomSeam = 0;
    for (var i = 0; i < layout.cardCount; i++) {
      final angle = layout.targetAngles[i];
      final sin = math.sin(angle);
      if (sin < -0.5) leftHalf++;
      if (sin > 0.5) rightHalf++;
      final cos = math.cos(angle);
      if (cos > 0.9) topSeam++; // 朝上（两扇交叉处）
      if (cos < -0.9) bottomSeam++; // 朝下（两扇交叉处）
    }
    expect(leftHalf, greaterThan(0));
    expect(rightHalf, greaterThan(0));
    expect(topSeam, greaterThan(0), reason: '上端两扇交叉，应有两扇的牌');
    expect(bottomSeam, greaterThan(0), reason: '下端两扇交叉，应有两扇的牌');

    // 两扇合起来几乎铺满一整圈：四个正方向都有牌覆盖（按圆周距离找最近牌，
    // 直线差值会在 ±180° 附近误判——例如朝左时最近的牌在 −94.4° 而非 200°）。
    for (final deg in <double>[0, 90, 180, 270]) {
      final target = deg * math.pi / 180;
      double circularDist(double a) {
        final d = (a - target).abs() % (2 * math.pi);
        return math.min(d, 2 * math.pi - d);
      }

      final nearest = layout.targetAngles.reduce(
        (a, b) => circularDist(a) < circularDist(b) ? a : b,
      );
      expect(circularDist(nearest), lessThan(0.2));
    }
    // 每张牌绕「自己那只手」旋转：牌心到各自手握点的距离恒定（牌心在牌内的
    // 相对位置固定），两半并不共用一个枢轴。
    final fromHand = <double>[
      for (var i = 0; i < layout.cardCount; i++)
        (_cardCenter(layout, i) - (origin + layout.pivotOffsets[i])).distance,
    ];
    for (final r in fromHand) {
      expect(r, closeTo(fromHand.first, 1e-9));
    }
    // 两只手分开后整体是「比高更宽」的形状（共用枢轴时会接近正圆）。
    final box = _bounds(layout);
    expect(box.maxX - box.minX, greaterThan(box.maxY - box.minY));
    // 牌心相对枢轴铺满左右上下：两扇确实朝两侧展开，而不是叠在一点
    // （每张牌的牌心到枢轴距离恒为 0.465×牌高，只能用方向证明展开）。
    final dirs = <Offset>[
      for (var i = 0; i < layout.cardCount; i++)
        _cardCenter(layout, i) - origin,
    ];
    const reach = 0.3;
    expect(dirs.any((d) => d.dx < -reach * layout.cardHeight), isTrue);
    expect(dirs.any((d) => d.dx > reach * layout.cardHeight), isTrue);
    expect(dirs.any((d) => d.dy < -reach * layout.cardHeight), isTrue);
    expect(dirs.any((d) => d.dy > reach * layout.cardHeight), isTrue);
  });

  testWidgets('双手开扇：展开 / 收拢动画跑通且不抛异常', (tester) async {
    final controller = CardFanSpreadController();
    await tester.pumpWidget(_app(back: back, controller: controller));
    await tester.pump();
    expect(controller.progress, 0);

    controller.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.progress, 1);
    expect(tester.takeException(), isNull);

    controller.close();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.progress, 0);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('双手开扇：拖动最顶的牌可以调角度（与 S 扇不同）', (tester) async {
    final controller = CardFanSpreadController();
    final reports = <double>[];
    await tester.pumpWidget(
      _app(back: back, controller: controller, onFanAngleChanged: reports.add),
    );
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.progress, 1);

    // 最顶那张牌是右扇末端（与开扇同侧）：拖它应当推出角度变化。
    final layout = _twoHandLayout(cardCount: 52);
    final top = _cardCenter(layout, layout.drawOrder.last);
    final gesture = await tester.startGesture(top);
    await gesture.moveTo(top + const Offset(30, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(reports, isNotEmpty);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  test('双手开扇：左右两扇的顶牌随摆幅转向不同（跟手方向按几何取）', () {
    // 摆幅不到拐点（90°）时两扇的中心还在往外倒：左扇的顶牌贴在内缘（摆幅越大
    // 它越往内侧倒），右扇的顶牌自然顺着摆幅走——两者变化率**符号相反**，所以
    // 拖动跟手方向必须按几何算，写死一个方向必然错一半。
    final narrow = _twoHandLayout(fanAngle: 40);
    final left = narrow.cardCount ~/ 2;
    expect(narrow.targetAngleRateOf(left - 1), closeTo(-0.5, 1e-6));
    expect(narrow.targetAngleRateOf(narrow.cardCount - 1), closeTo(1.5, 1e-6));

    // 过了拐点中心固定在两外侧，两扇都只加宽：两张顶牌同向（都是 +0.5，与开扇
    // 一致，正好是拖动用的增益 2 的倒数）。
    final wide = _twoHandLayout(fanAngle: 140);
    expect(wide.targetAngleRateOf(left - 1), closeTo(0.5, 1e-6));
    expect(wide.targetAngleRateOf(wide.cardCount - 1), closeTo(0.5, 1e-6));

    // 对照：普通开扇的顶牌恒为 +0.5（摆幅变 2° 它转 1°），与增益 2 互为倒数。
    final fan = CardSpreadLayout.compute(
      mode: FanSpreadMode.fan,
      canvas: _canvas,
      cardCount: 52,
      fanAngle: 140,
      fanTierRatio: 0,
      fanPivotX: kDefaultFanPivotX,
      fanPivotLift: kDefaultFanPivotLift,
      tableStepRatio: 0.09,
      tableArcLift: -0.6,
      direction: SpreadDirection.leftToRight,
    ) as FanSpreadLayout;
    expect(fan.targetAngleRateOf(fan.cardCount - 1), closeTo(0.5, 1e-9));

    // 布局记住的是**钳后**的摆幅：双手开扇给 300° 也只会按 220° 排版，
    // 变化率自然按 220° 附近取。
    expect(_twoHandLayout(fanAngle: 300).fanAngle, kMaxTwoHandFanAngle);
  });

  testWidgets('双手开扇：拖左叠的顶牌也能调角度（两叠都抓得住）', (tester) async {
    const start = 140.0;
    final layout = _twoHandLayout(fanAngle: start);
    final left = layout.cardCount ~/ 2;
    // 左叠顶牌在左手斜上方（140° 时朝向角 −20°）：顺时针拖 20° → 摆幅 +40°。
    final reports = await _dragPileTop(
      tester,
      back: back,
      layout: layout,
      topIndex: left - 1,
      startFanAngle: start,
      sweepDeg: 20,
    );
    expect(reports, isNotEmpty);
    expect(reports.last, closeTo(start + 40, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('双手开扇：拖左叠顶牌反向转 → 摆幅变小', (tester) async {
    const start = 140.0;
    final layout = _twoHandLayout(fanAngle: start);
    final left = layout.cardCount ~/ 2;
    final reports = await _dragPileTop(
      tester,
      back: back,
      layout: layout,
      topIndex: left - 1,
      startFanAngle: start,
      sweepDeg: -20,
    );
    expect(reports, isNotEmpty);
    expect(reports.last, closeTo(start - 40, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('双手开扇：拖右叠的顶牌照旧（回归）', (tester) async {
    const start = 140.0;
    final layout = _twoHandLayout(fanAngle: start);
    final reports = await _dragPileTop(
      tester,
      back: back,
      layout: layout,
      topIndex: layout.cardCount - 1,
      startFanAngle: start,
      sweepDeg: 20,
    );
    expect(reports, isNotEmpty);
    expect(reports.last, closeTo(start + 40, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('双手开扇：拖到 220° 就停住，回调不会报出更大的角度', (tester) async {
    const start = 200.0;
    final layout = _twoHandLayout(fanAngle: start);
    final left = layout.cardCount ~/ 2;
    // 顺时针拖 60°：按增益应到 320°，超过每边 220° 的上限 → 停在 220°。
    final reports = await _dragPileTop(
      tester,
      back: back,
      layout: layout,
      topIndex: left - 1,
      startFanAngle: start,
      sweepDeg: 60,
    );
    expect(reports, isNotEmpty);
    for (final v in reports) {
      expect(v, inInclusiveRange(kMinFanAngle, kMaxTwoHandFanAngle));
    }
    expect(reports.last, kMaxTwoHandFanAngle);
    expect(tester.takeException(), isNull);
  });

  testWidgets('双手开扇：收拢态拖左叠顶牌 → 既调角度又开始展开', (tester) async {
    const start = 140.0;
    final controller = CardFanSpreadController();
    final reports = <double>[];
    await tester.pumpWidget(
      _app(
        back: back,
        controller: controller,
        fanAngle: start,
        onFanAngleChanged: reports.add,
      ),
    );
    await tester.pump();
    expect(controller.progress, 0);

    // 收拢态：左叠是一摞竖牌立在左手上（不是合并到中间），拖它同样能起扇。
    final layout = _twoHandLayout(fanAngle: start);
    final left = layout.cardCount ~/ 2;
    final top = _cardCenter(layout, left - 1, 0);
    final pivot = layout.origin + layout.pivotOffsets[left - 1];
    final radius = (top - pivot).distance;
    final gesture = await tester.startGesture(top);
    for (var k = 1; k <= 4; k++) {
      // 收拢时顶牌竖直（朝向角 0）：顺时针拖 → 摆幅变大。
      await gesture.moveTo(_pointerAt(pivot, radius, 20 * k / 4));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(reports, isNotEmpty);
    expect(reports.last, closeTo(start + 40, 0.5));
    expect(controller.progress, greaterThan(0), reason: '收拢态拖动应同时播放展开动画');

    await tester.pump(const Duration(seconds: 3));
    expect(controller.progress, 1);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });
}
