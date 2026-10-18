import 'dart:ui' as ui;

import 'package:card_fan_spread/card_fan_spread.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_card_image.dart';

final GlobalKey _boundaryKey = GlobalKey();

/// 白牌 + 黑底场景的边缘测量结果。
///
/// - [intermediate]：中间色调像素总数；
/// - [cornerIntermediate]：牌包围盒四角区域内的中间色调像素数
///   （圆角永远是斜边，不受直线边是否恰好像素对齐影响，是可靠的 AA 指标）；
/// - [maxStep]：相邻像素的最大亮度跳变。
typedef EdgeMeasure = ({int intermediate, int cornerIntermediate, int maxStep});

Future<EdgeMeasure> _measureEdges(WidgetTester tester) async {
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

  // 牌的包围盒（白色区域）。
  var minX = w, maxX = 0, minY = h, maxY = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (bytes[(y * w + x) * 4] > 200) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }

  var intermediate = 0;
  var cornerIntermediate = 0;
  const cornerZone = 24;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final b = bytes[(y * w + x) * 4];
      if (b > 10 && b < 245) {
        intermediate++;
        final inCornerX = x < minX + cornerZone || x > maxX - cornerZone;
        final inCornerY = y < minY + cornerZone || y > maxY - cornerZone;
        if (inCornerX && inCornerY) cornerIntermediate++;
      }
    }
  }
  var maxStep = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 1; x < w; x++) {
      final step = (bytes[(y * w + x - 1) * 4] - bytes[(y * w + x) * 4]).abs();
      if (step > maxStep) maxStep = step;
    }
  }
  return (
    intermediate: intermediate,
    cornerIntermediate: cornerIntermediate,
    maxStep: maxStep,
  );
}

Widget _blackBacked(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: _boundaryKey,
        child: SizedBox(
          width: 400,
          height: 600,
          child: Container(color: const Color(0xFF000000), child: child),
        ),
      ),
    ),
  );
}

void main() {
  late ui.Image whiteCard;

  setUp(() async {
    whiteCard = await solidCardImage(const ui.Color(0xFFFFFFFF));
  });

  testWidgets('回退路径：源图缩小到牌尺寸时圆角有抗锯齿过渡', (tester) async {
    await tester.pumpWidget(
      _blackBacked(
        CardFanSpread(
          cardBack: TestCardImage(whiteCard),
          // 关掉阴影：投影自带连续渐变，会干扰边缘指标的纯度。
          shadowColor: const Color(0x00000000),
          autoPlay: false,
        ),
      ),
    );
    // 等图片解码完成、精灵图尚未合成 → 走逐帧回退路径（650×916 → ~134×191，
    // 近 5 倍缩小，最考验过滤质量）。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final m = await _measureEdges(tester);
    // 对照：默认 low 过滤下该场景圆角区域 0 个中间色调像素、maxStep=255。
    expect(
      m.cornerIntermediate,
      greaterThanOrEqualTo(10),
      reason:
          '回退路径的圆角几乎没有中间色调（${m.cornerIntermediate}），'
          '说明 drawImageRect 用了低质量过滤',
    );
    // 直线边恰好落在整数像素上时本来就是硬边（最锐利的渲染），
    // 抗锯齿要保证的是圆角 / 斜边 / 旋转边缘，由 cornerIntermediate 衡量。
    expect(m.intermediate, greaterThan(0));
  });

  testWidgets('精灵路径：旋转展开后牌缘保持平滑（无硬锯齿）', (tester) async {
    final controller = CardFanSpreadController();
    await tester.pumpWidget(
      _blackBacked(
        CardFanSpread(
          mode: FanSpreadMode.fan,
          controller: controller,
          cardBack: TestCardImage(whiteCard),
          shadowColor: const Color(0x00000000),
          autoPlay: false,
        ),
      ),
    );

    // 先播放到完全展开（牌转到各自角度，贴图带旋转）
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.progress, 1);

    // 等精灵图合成完成，之后走精灵贴图路径
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final m = await _measureEdges(tester);
    expect(
      m.intermediate,
      // 对照：默认 low 过滤下该场景约 11786 个中间色调像素。
      greaterThan(13500),
      reason:
          '旋转贴图的边缘过渡不足（${m.intermediate}），'
          '说明过滤质量过低，旋转边缘出现锯齿',
    );
    expect(m.maxStep, lessThan(255));
    expect(tester.takeException(), isNull);
  });
}
