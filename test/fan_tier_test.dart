import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:card_fan_spread/card_fan_spread.dart';
import 'package:card_fan_spread/src/card_layout.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_card_image.dart';

const Size _canvas = Size(400, 600);

/// 与组件一致的布局参数（展牌参数对开扇无影响，但接口需要）。
FanSpreadLayout _fanLayout({
  FanSpreadMode mode = FanSpreadMode.fan,
  SpreadDirection direction = SpreadDirection.leftToRight,
  double fanAngle = 220,
  double tierRatio = 0,
  double pivotX = kDefaultFanPivotX,
  double pivotLift = kDefaultFanPivotLift,
  int cardCount = 52,
  Size canvas = _canvas,
}) {
  return CardSpreadLayout.compute(
    mode: mode,
    direction: direction,
    canvas: canvas,
    cardCount: cardCount,
    fanAngle: fanAngle,
    fanTierRatio: tierRatio,
    fanPivotX: pivotX,
    fanPivotLift: pivotLift,
    tableStepRatio: 0.09,
    tableArcLift: -0.6,
  ) as FanSpreadLayout;
}

/// 第 [i] 张牌在进度 1 时的画布中心（与画家同一套变换，含双层错落）。
Offset _cardCenter(FanSpreadLayout layout, int i) {
  final angle = layout.targetAngles[i];
  final local = Offset(
    layout.cardWidth / 2 - layout.pivotOffset.dx,
    layout.cardHeight / 2 - layout.pivotOffset.dy - layout.tierOffsets[i],
  );
  return layout.origin +
      Offset(
        local.dx * math.cos(angle) - local.dy * math.sin(angle),
        local.dx * math.sin(angle) + local.dy * math.cos(angle),
      );
}

/// 第 [i] 张牌的四个角在画布中的坐标（含双层错落）。
List<Offset> _cardCorners(FanSpreadLayout layout, int i) {
  final angle = layout.targetAngles[i];
  final tier = layout.tierOffsets[i];
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
          Offset(
            (corner.dx - layout.pivotOffset.dx) * cos -
                (corner.dy - layout.pivotOffset.dy - tier) * sin,
            (corner.dx - layout.pivotOffset.dx) * sin +
                (corner.dy - layout.pivotOffset.dy - tier) * cos,
          ),
  ];
}

Widget _app({
  required FanSpreadMode mode,
  required ui.Image back,
  required CardFanSpreadController controller,
  double fanAngle = 220,
  double tierRatio = 0,
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
          mode: mode,
          controller: controller,
          cardBack: TestCardImage(back),
          fanAngle: fanAngle,
          fanTierRatio: tierRatio,
          autoPlay: false,
          onFanAngleChanged: onFanAngleChanged,
        ),
      ),
    ),
  );
}

void main() {
  late ui.Image back;

  setUpAll(() async {
    back = await solidCardImage(const ui.Color(0xFF333366));
  });

  test('双层错落关闭时：每张牌都不外推，角度与单层开扇一致', () {
    final flat = _fanLayout(fanAngle: 360);
    expect(flat.tierOffsets.length, flat.cardCount);
    for (final offset in flat.tierOffsets) {
      expect(offset, 0);
    }
    // 关闭时的角度就是普通开扇的角度（-half → +half 均匀分布）。
    for (var i = 0; i < flat.cardCount; i++) {
      expect(
        flat.targetAngles[i],
        closeTo(-math.pi + 2 * math.pi * i / (flat.cardCount - 1), 1e-9),
      );
    }
  });

  test('双层错落开启时：奇数下标的牌整体外推一层，角度分布不变', () {
    final layout = _fanLayout(fanAngle: 360, tierRatio: 0.22);
    for (var i = 0; i < layout.cardCount; i++) {
      expect(
        layout.tierOffsets[i],
        closeTo(i.isOdd ? 0.22 * layout.cardHeight : 0.0, 1e-9),
      );
    }

    // 角度只由 fanAngle / mode 决定，不受双层错落影响。
    final flat = _fanLayout(fanAngle: 360);
    for (var i = 0; i < layout.cardCount; i++) {
      expect(layout.targetAngles[i], closeTo(flat.targetAngles[i], 1e-9));
    }
    // 布局指纹要变，否则 shouldRepaint 会漏掉重绘。
    expect(layout.key, isNot(flat.key));
  });

  test('双层错落：外层牌顶明显探出内层，但不超过错落量本身', () {
    final layout = _fanLayout(fanAngle: 360, tierRatio: 0.22);
    double farthestTip(int i) => _cardCorners(
      layout,
      i,
    ).fold<double>(0, (max, p) => math.max(max, (p - layout.origin).distance));

    final tier = layout.tierOffsets[1];
    final inner = farthestTip(0);
    final outer = farthestTip(1);
    expect(outer - inner, greaterThan(0.8 * tier));
    expect(outer - inner, lessThanOrEqualTo(tier + 1e-9));
  });

  test('双层错落上界为 kMaxFanTierRatio（65%），越界直接断言失败', () {
    expect(kMaxFanTierRatio, 0.65);

    final layout = _fanLayout(fanAngle: 360, tierRatio: kMaxFanTierRatio);
    expect(
      layout.tierOffsets[1],
      closeTo(kMaxFanTierRatio * layout.cardHeight, 1e-9),
    );

    expect(
      () => CardFanSpread(
        cardBack: TestCardImage(back),
        fanTierRatio: kMaxFanTierRatio + 0.01,
      ),
      throwsAssertionError,
    );
  });

  test('双层错落：含外层错落的整副牌仍完整落在画布内', () {
    for (final tierRatio in <double>[0, 0.22, 0.44, kMaxFanTierRatio]) {
      for (final canvas in <Size>[
        const Size(400, 600),
        const Size(1000, 400),
      ]) {
        for (final direction in SpreadDirection.values) {
          final layout = _fanLayout(
            fanAngle: 360,
            tierRatio: tierRatio,
            canvas: canvas,
            direction: direction,
          );
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
          expect(minX, greaterThanOrEqualTo(-0.5));
          expect(maxX, lessThanOrEqualTo(canvas.width + 0.5));
          expect(minY, greaterThanOrEqualTo(-0.5));
          expect(maxY, lessThanOrEqualTo(canvas.height + 0.5));
        }
      }
    }
  });

  test('开扇 rightToLeft 同样支持双层错落：角度镜像、错落一致', () {
    final ltr = _fanLayout(
      mode: FanSpreadMode.fan,
      fanAngle: 300,
      tierRatio: 0.3,
    );
    final rtl = _fanLayout(
      mode: FanSpreadMode.fan,
      direction: SpreadDirection.rightToLeft,
      fanAngle: 300,
      tierRatio: 0.3,
    );
    for (var i = 0; i < ltr.cardCount; i++) {
      expect(rtl.targetAngles[i], closeTo(-ltr.targetAngles[i], 1e-9));
      expect(rtl.tierOffsets[i], closeTo(ltr.tierOffsets[i], 1e-9));
    }
  });

  test('收拢时整叠牌重合（角度 0、错落 0）', () {
    final layout = _fanLayout(fanAngle: 360, tierRatio: 0.22);
    for (var i = 0; i < layout.cardCount; i++) {
      expect(
        layout.cardProgressAt(i, 0, stagger: 0.55, curve: Curves.easeOutCubic),
        0,
      );
    }
    // 错落随进度一起生长，进度 0 时外层不外推。
    final progressZeroCenter = _cardCenter(layout, 1);
    final flatZeroCenter = _cardCenter(_fanLayout(fanAngle: 360), 1);
    expect((progressZeroCenter - flatZeroCenter).distance, greaterThan(0));
  });

  testWidgets('开扇 + 双层错落：展开动画 0 → 1 且不抛异常', (tester) async {
    final controller = CardFanSpreadController();
    await tester.pumpWidget(
      _app(
        mode: FanSpreadMode.fan,
        back: back,
        controller: controller,
        fanAngle: 360,
        tierRatio: 0.22,
      ),
    );
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

  testWidgets('开扇 + 双层错落：最顶的牌依然可以拖动调角度', (tester) async {
    final controller = CardFanSpreadController();
    final reports = <double>[];
    const fanAngle = 360.0;
    await tester.pumpWidget(
      _app(
        mode: FanSpreadMode.fan,
        back: back,
        controller: controller,
        fanAngle: fanAngle,
        tierRatio: 0.22,
        onFanAngleChanged: reports.add,
      ),
    );
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.progress, 1);

    // 从「被外推一层的最顶那张牌」的中心起手拖动（命中测试必须把错落算进去）。
    final fan = _fanLayout(fanAngle: fanAngle, tierRatio: 0.22);
    final top = _cardCenter(fan, fan.drawOrder.last);
    final gesture = await tester.startGesture(top);
    await gesture.moveTo(top + const Offset(24, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(reports, isNotEmpty, reason: '带双层错落时，顶牌的命中测试应仍然有效');
    expect(tester.takeException(), isNull);
    controller.dispose();
  });
}
