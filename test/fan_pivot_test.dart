import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:card_fan_spread/card_fan_spread.dart';
import 'package:card_fan_spread/src/card_layout.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_card_image.dart';

/// 开扇 / 反开扇「圆心（枢轴）位置」的回归测试。
///
/// 枢轴默认在牌边中心附近（拇指捏住扇骨的位置）；[fanPivotX] 让它沿牌宽方向
/// 挪到任意一侧、[fanPivotLift] 让它沉到牌边下方——所有牌仍绕各自同一个
/// 相对位置旋转，扇形随之偏轴 / 垂挂。
/// 约定：默认参数必须与加参数之前的几何完全一致（行为不回退）。
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

/// 第 [i] 张牌在进度 1 时的画布中心（与画家同一套变换，含层间错落）。
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

/// 第 [i] 张牌的四个角在画布中的坐标（含层间错落）。
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
  required ui.Image back,
  required CardFanSpreadController controller,
  double fanAngle = 220,
  double pivotX = kDefaultFanPivotX,
  double pivotLift = kDefaultFanPivotLift,
  ValueChanged<double>? onFanAngleChanged,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: _boundaryKey,
        child: SizedBox(
          width: _canvas.width,
          height: _canvas.height,
          child: CardFanSpread(
            mode: FanSpreadMode.fan,
            controller: controller,
            cardBack: TestCardImage(back),
            fanAngle: fanAngle,
            fanPivotX: pivotX,
            fanPivotLift: pivotLift,
            autoPlay: false,
            onFanAngleChanged: onFanAngleChanged,
          ),
        ),
      ),
    ),
  );
}

/// 像素抓取用的边界 key（每次抓取前重新挂载，见 [_capture]）。
final GlobalKey _boundaryKey = GlobalKey();

/// 把 [RenderRepaintBoundary] 的渲染结果抓成裸像素，便于做像素级断言。
Future<Uint8List> _capture(WidgetTester tester) async {
  final render = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundaryKey),
  );
  final image = (await tester.runAsync(() => render.toImage()))!;
  final data = (await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
  ))!;
  return data.buffer.asUint8List();
}

/// 两张等尺寸截图中「差异明显」的像素比例（亮度差 > 16 记为不同）。
double _diffRatio(Uint8List a, Uint8List b) {
  var diff = 0;
  for (var p = 0; p < a.length; p += 4) {
    if ((a[p] - b[p]).abs() > 16) diff++;
  }
  return diff / (a.length / 4);
}

void main() {
  late ui.Image back;

  setUpAll(() async {
    back = await solidCardImage(const ui.Color(0xFF333366));
  });

  test('默认枢轴复现原有几何：牌边中心、底边内侧 6% 牌高', () {
    final layout = _fanLayout();
    // pivotOffset = (fanPivotX × 牌宽, (1 + fanPivotLift) × 牌高)；
    // 默认 (0.5, -0.06) 即旧版的「牌宽中心、牌内 94% 高度处」。
    expect(layout.pivotOffset.dx, closeTo(0.5 * layout.cardWidth, 1e-9));
    expect(layout.pivotOffset.dy, closeTo(0.94 * layout.cardHeight, 1e-9));
    // 宽高比不受枢轴影响。
    expect(layout.cardWidth, closeTo(0.70 * layout.cardHeight, 1e-9));
  });

  test('fanPivotX：枢轴沿牌宽方向移动（0 = 左边缘，1 = 右边缘）', () {
    for (final pivotX in <double>[0, 0.25, 0.5, 0.75, 1]) {
      final layout = _fanLayout(pivotX: pivotX);
      expect(layout.pivotOffset.dx, closeTo(pivotX * layout.cardWidth, 1e-9));
      // 纵向不受影响。
      expect(layout.pivotOffset.dy, closeTo(0.94 * layout.cardHeight, 1e-9));
    }
  });

  test('fanPivotLift：枢轴相对牌底边沉深（0 = 底边，正 = 沉到下方）', () {
    for (final lift in <double>[-0.5, -0.06, 0, 0.5, 1.0]) {
      final layout = _fanLayout(pivotLift: lift);
      expect(
        layout.pivotOffset.dy,
        closeTo((1 + lift) * layout.cardHeight, 1e-9),
      );
      // 横向不受影响。
      expect(layout.pivotOffset.dx, closeTo(0.5 * layout.cardWidth, 1e-9));
    }
  });

  test('枢轴不影响角度分布：目标角与默认枢轴完全一致', () {
    final plain = _fanLayout(fanAngle: 300);
    for (final pivotX in <double>[0, 1]) {
      for (final lift in <double>[kMinFanPivotLift, kMaxFanPivotLift]) {
        final moved = _fanLayout(
          fanAngle: 300,
          pivotX: pivotX,
          pivotLift: lift,
        );
        for (var i = 0; i < moved.cardCount; i++) {
          expect(
            moved.targetAngles[i],
            closeTo(plain.targetAngles[i], 1e-9),
            reason: '枢轴只改圆心位置，不应改动朝向角（pivotX=$pivotX, lift=$lift）',
          );
        }
      }
    }
  });

  test('布局指纹随枢轴变化（shouldRepaint 不会漏判）', () {
    final plain = _fanLayout();
    expect(_fanLayout(pivotX: 0).key, isNot(plain.key));
    expect(_fanLayout(pivotX: 1).key, isNot(plain.key));
    expect(_fanLayout(pivotLift: 0).key, isNot(plain.key));
    expect(_fanLayout(pivotLift: 1).key, isNot(plain.key));
    // 相同参数 → 指纹一致（拖滑块回到同一位置不会白重排）。
    expect(
      _fanLayout(pivotX: 0.25, pivotLift: 0.3).key,
      _fanLayout(pivotX: 0.25, pivotLift: 0.3).key,
    );
  });

  test('极端枢轴下整副牌仍完整落在画布内', () {
    for (final pivotX in <double>[0, 1]) {
      for (final lift in <double>[kMinFanPivotLift, kMaxFanPivotLift]) {
        for (final canvas in <Size>[
          const Size(400, 600),
          const Size(1000, 400),
        ]) {
          for (final direction in SpreadDirection.values) {
            final layout = _fanLayout(
              fanAngle: 360,
              tierRatio: 0.3,
              pivotX: pivotX,
              pivotLift: lift,
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
    }
  });

  test('偏轴枢轴确实改变画面几何：顶牌中心随枢轴移动', () {
    final i = 51; // 最顶的那张（开扇角度最大的一端）
    final centered = _cardCenter(_fanLayout(fanAngle: 300), i);
    final atLeft = _cardCenter(_fanLayout(fanAngle: 300, pivotX: 0), i);
    final atRight = _cardCenter(_fanLayout(fanAngle: 300, pivotX: 1), i);
    // 同一张牌：枢轴从左边缘挪到右边缘，它的落点应明显不同。
    expect((atLeft - centered).distance, greaterThan(1));
    expect((atRight - centered).distance, greaterThan(1));
    expect((atRight - atLeft).distance, greaterThan(2));
    // 垂挂（沉到牌边下方）同样改变落点。
    final dropped = _cardCenter(_fanLayout(fanAngle: 300, pivotLift: 1), i);
    expect((dropped - centered).distance, greaterThan(1));
  });

  test('S 扇忽略枢轴参数：几何与指纹都不变', () {
    final plain = _fanLayout(mode: FanSpreadMode.sFan, fanAngle: 240);
    final moved = _fanLayout(
      mode: FanSpreadMode.sFan,
      fanAngle: 240,
      pivotX: 1,
      pivotLift: 1,
    );
    // 牌柄钉在脊线上：挪动牌内枢轴只会让牌偏离脊线，故固定用默认值。
    expect(moved.pivotOffset.dx, closeTo(plain.pivotOffset.dx, 1e-9));
    expect(moved.pivotOffset.dy, closeTo(plain.pivotOffset.dy, 1e-9));
    // 参数既然被忽略，布局指纹就应当一致——否则拖滑块会白重绘一次。
    expect(moved.key, plain.key);
  });

  test('越界的枢轴参数直接断言失败，边界值合法', () {
    expect(() => CardFanSpread(fanPivotX: -0.01), throwsAssertionError);
    expect(() => CardFanSpread(fanPivotX: 1.01), throwsAssertionError);
    expect(
      () => CardFanSpread(fanPivotLift: kMinFanPivotLift - 0.01),
      throwsAssertionError,
    );
    expect(
      () => CardFanSpread(fanPivotLift: kMaxFanPivotLift + 0.01),
      throwsAssertionError,
    );
    final edge = CardFanSpread(
      fanPivotX: kMaxFanPivotX,
      fanPivotLift: kMaxFanPivotLift,
    );
    expect(edge.fanPivotX, kMaxFanPivotX);
    expect(edge.fanPivotLift, kMaxFanPivotLift);
  });

  testWidgets('偏轴枢轴：展开 / 收拢动画跑通且不抛异常', (tester) async {
    final controller = CardFanSpreadController();
    await tester.pumpWidget(
      _app(back: back, controller: controller, pivotX: 0, pivotLift: 0.5),
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

  testWidgets('偏轴枢轴：拖动最顶的牌依然可以调角度（命中测试跟着枢轴走）', (tester) async {
    final controller = CardFanSpreadController();
    final reports = <double>[];
    await tester.pumpWidget(
      _app(
        back: back,
        controller: controller,
        fanAngle: 220,
        pivotX: 0,
        pivotLift: 0.5,
        onFanAngleChanged: reports.add,
      ),
    );
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.progress, 1);

    // 从「偏轴 + 垂挂布局下」最顶那张牌的中心起手拖动：
    // 命中测试必须按同一个枢轴做逆变换，否则判定与画面不一致。
    final fan = _fanLayout(fanAngle: 220, pivotX: 0, pivotLift: 0.5);
    final top = _cardCenter(fan, fan.drawOrder.last);
    final gesture = await tester.startGesture(top);
    await gesture.moveTo(top + const Offset(24, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(reports, isNotEmpty, reason: '偏轴枢轴下顶牌的命中测试应仍然有效');
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('像素级：枢轴沿牌边移动确实得到不同的画面', (tester) async {
    Future<Uint8List> renderWith(double pivotX) async {
      final controller = CardFanSpreadController();
      await tester.pumpWidget(
        _app(back: back, controller: controller, fanAngle: 220, pivotX: pivotX),
      );
      controller.play();
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(controller.progress, 1);
      // 等异步精灵图合成完成（onReady 里 setState），再喂一帧应用。
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump();
      final pixels = await _capture(tester);
      controller.dispose();
      return pixels;
    }

    final centered = await renderWith(0.5);
    final atLeft = await renderWith(0);
    final atRight = await renderWith(1);

    // 同一副牌、同一个角度，仅枢轴不同：画面应当明显不同。
    expect(_diffRatio(centered, atLeft), greaterThan(0.02));
    expect(_diffRatio(centered, atRight), greaterThan(0.02));
    // 左右两个偏轴方向互为镜像，也不应相同。
    expect(_diffRatio(atLeft, atRight), greaterThan(0.02));
  });
}
