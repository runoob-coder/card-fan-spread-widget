import 'dart:ui' as ui;

import 'package:card_fan_spread/card_fan_spread.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_card_image.dart';

const double _canvasWidth = 400;
const double _canvasHeight = 600;
final GlobalKey _boundaryKey = GlobalKey();

Widget _buildSpread({
  required FanSpreadMode mode,
  required ui.Image card,
  CardFanSpreadController? controller,
  SpreadDirection direction = SpreadDirection.leftToRight,
  double tableArcLift = -0.6,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: _boundaryKey,
        child: SizedBox(
          width: _canvasWidth,
          height: _canvasHeight,
          child: Container(
            color: const Color(0xFF000000),
            child: CardFanSpread(
              mode: mode,
              controller: controller,
              cardBack: TestCardImage(card),
              direction: direction,
              tableArcLift: tableArcLift,
              autoPlay: false,
            ),
          ),
        ),
      ),
    ),
  );
}

/// 白色像素的水平重心与横向跨度（均按画布宽度归一化）。
Future<({double centroid, double span})> _measure(WidgetTester tester) async {
  final render = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundaryKey),
  );
  final image = (await tester.runAsync(() => render.toImage()))!;
  final data = (await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
  ))!;
  final bytes = data.buffer.asUint8List();
  final w = image.width;
  final h = image.height;
  double sum = 0;
  double xSum = 0;
  int minX = w;
  int maxX = 0;
  for (var y = 0; y < h; y += 2) {
    for (var x = 0; x < w; x += 2) {
      final i = (y * w + x) * 4;
      if (bytes[i] > 200 && bytes[i + 1] > 200 && bytes[i + 2] > 200) {
        sum += 1;
        xSum += x;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
      }
    }
  }
  return (centroid: xSum / sum / w, span: (maxX - minX) / w);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _playToEnd(WidgetTester tester, CardFanSpreadController c) async {
  c.play();
  await tester.pump();
  await tester.pump(const Duration(seconds: 3));
  expect(c.progress, 1);
}

void main() {
  late ui.Image whiteCard;

  setUp(() async {
    whiteCard = await solidCardImage();
  });

  testWidgets('展牌：收拢时竖立在中间，展开时向两侧同时散开', (tester) async {
    final controller = CardFanSpreadController();
    await tester.pumpWidget(
      _buildSpread(
        mode: FanSpreadMode.tableSpread,
        card: whiteCard,
        controller: controller,
      ),
    );
    await _settle(tester);

    final closed = await _measure(tester);
    expect(closed.centroid, closeTo(0.5, 0.06), reason: '收拢时整叠牌应居中');
    expect(closed.span, lessThan(0.35), reason: '收拢时应是窄窄的一叠牌');

    // 展开到一半：仍应保持左右对称（说明是中间向外扩，而不是从一端推过去）
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    final midway = await _measure(tester);
    expect(midway.centroid, closeTo(0.5, 0.1), reason: '展开过程中应保持左右对称');
    expect(midway.span, greaterThan(closed.span), reason: '横向跨度应在变大');

    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    final opened = await _measure(tester);
    expect(opened.centroid, closeTo(0.5, 0.06));
    expect(opened.span, greaterThan(midway.span));
    expect(opened.span, greaterThan(0.8), reason: '完全摊开后应铺满整条带');
  });

  testWidgets('开扇：收拢时正面竖立，展开时对称张成扇形', (tester) async {
    final controller = CardFanSpreadController();
    await tester.pumpWidget(
      _buildSpread(
        mode: FanSpreadMode.fan,
        card: whiteCard,
        controller: controller,
      ),
    );
    await _settle(tester);

    final closed = await _measure(tester);
    expect(
      closed.centroid,
      closeTo(0.5, 0.06),
      reason: '收拢时应是正面竖立的一叠牌（不是倾倒在某一侧）',
    );
    expect(closed.span, lessThan(0.4), reason: '收拢时的宽度应接近单张牌宽');

    await _playToEnd(tester, controller);
    final opened = await _measure(tester);
    expect(opened.centroid, closeTo(0.5, 0.08), reason: '扇形左右应对称');
    expect(opened.span, greaterThan(closed.span * 1.8));
    expect(tester.takeException(), isNull);
  });

  testWidgets('开扇 rightToLeft 同样是收拢竖立、对称展开', (tester) async {
    final controller = CardFanSpreadController();
    await tester.pumpWidget(
      _buildSpread(
        mode: FanSpreadMode.fan,
        direction: SpreadDirection.rightToLeft,
        card: whiteCard,
        controller: controller,
      ),
    );
    await _settle(tester);

    final closed = await _measure(tester);
    expect(closed.centroid, closeTo(0.5, 0.06));
    expect(closed.span, lessThan(0.4));

    await _playToEnd(tester, controller);
    final opened = await _measure(tester);
    expect(opened.centroid, closeTo(0.5, 0.08));
    expect(opened.span, greaterThan(closed.span * 1.8));
  });

  testWidgets('展牌方向只影响遮挡关系，不影响对称展开', (tester) async {
    final controller = CardFanSpreadController();
    await tester.pumpWidget(
      _buildSpread(
        mode: FanSpreadMode.tableSpread,
        card: whiteCard,
        controller: controller,
        direction: SpreadDirection.rightToLeft,
      ),
    );
    await _settle(tester);
    final closed = await _measure(tester);
    expect(closed.centroid, closeTo(0.5, 0.06));

    await _playToEnd(tester, controller);
    final opened = await _measure(tester);
    expect(opened.centroid, closeTo(0.5, 0.06));
    expect(opened.span, greaterThan(0.8));
  });

  testWidgets('两端上翘可为负值（两端下翘）', (tester) async {
    final controller = CardFanSpreadController();
    await tester.pumpWidget(
      _buildSpread(
        mode: FanSpreadMode.tableSpread,
        card: whiteCard,
        controller: controller,
        tableArcLift: -0.4,
      ),
    );
    await _playToEnd(tester, controller);

    final opened = await _measure(tester);
    expect(opened.centroid, closeTo(0.5, 0.06));
    expect(tester.takeException(), isNull);
  });
}
