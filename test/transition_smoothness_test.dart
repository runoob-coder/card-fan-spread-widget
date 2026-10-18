import 'dart:ui' as ui;

import 'package:card_fan_spread/card_fan_spread.dart';
import 'package:card_fan_spread/src/card_sprite.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_card_image.dart';

final GlobalKey _boundaryKey = GlobalKey();
const Size _canvas = Size(400, 600);

/// 平均亮度（0~255）。
Future<double> _averageBrightness(WidgetTester tester) async {
  final render = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundaryKey),
  );
  final image = (await tester.runAsync(() => render.toImage()))!;
  final data = (await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
  ))!;
  final bytes = data.buffer.asUint8List();
  double sum = 0;
  var count = 0;
  for (var i = 0; i < bytes.length; i += 4 * 3) {
    sum += bytes[i];
    count++;
  }
  return sum / count;
}

/// 换牌背的宿主页（牌背 provider 由外部提供，可整体替换）。
class _BackSwitchHost extends StatefulWidget {
  const _BackSwitchHost({required this.back});

  final ui.Image back;

  @override
  State<_BackSwitchHost> createState() => _BackSwitchHostState();
}

class _BackSwitchHostState extends State<_BackSwitchHost> {
  late ImageProvider back = TestCardImage(widget.back);

  /// 换牌背（测试里驱动）。
  void switchTo(ui.Image image) {
    setState(() => back = TestCardImage(image));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: _boundaryKey,
          child: SizedBox(
            width: _canvas.width,
            height: _canvas.height,
            child: Container(
              color: const Color(0xFF808080),
              child: CardFanSpread(
                mode: FanSpreadMode.fan,
                cardBack: back,
                // 牌数少、且已经完全张开：相邻牌离得远（decorAlpha = 1），
                // 交叉溶解不会被「重合的半透明层累积」放大。
                cardCount: 8,
                fanAngle: 220,
                stagger: 0,
                autoPlay: false,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _build({
  required CardFanSpreadController controller,
  required ui.Image back,
  required ui.Image face,
  required bool showFace,
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
          child: Container(
            // 中灰背景：黑牌 / 白牌的切换会明显地改变平均亮度
            color: const Color(0xFF808080),
            child: CardFanSpread(
              mode: FanSpreadMode.tableSpread,
              controller: controller,
              cardBack: TestCardImage(back),
              cardFaces: List.filled(8, TestCardImage(face)),
              showFace: showFace,
              cardCount: 8,
              autoPlay: false,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  test('装饰强度随距离平滑变化，不存在硬跳变', () {
    expect(cardDecorationAlpha(0), 0);
    expect(cardDecorationAlpha(kCardShadowExtent), 1);
    expect(cardDecorationAlpha(kCardShadowExtent * 2), 1);

    // 单调递增，且任何一小步的增幅都有上限（硬阈值会出现一步 +1 的跳变）
    var previous = cardDecorationAlpha(0);
    for (var d = 0.0; d <= kCardShadowExtent; d += 0.05) {
      final value = cardDecorationAlpha(d);
      expect(value, greaterThanOrEqualTo(previous));
      expect(value - previous, lessThanOrEqualTo(0.15));
      previous = value;
    }
  });

  testWidgets('牌背 → 牌面是渐变过渡，而不是瞬间切换', (tester) async {
    final back = await solidCardImage(const ui.Color(0xFF101010));
    final face = await solidCardImage(const ui.Color(0xFFF5F5F5));
    final controller = CardFanSpreadController();

    await tester.pumpWidget(
      _build(controller: controller, back: back, face: face, showFace: false),
    );
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.progress, 1);

    final dark = await _averageBrightness(tester);

    // 切到牌面：先取过渡中的一帧，再取过渡结束的一帧
    await tester.pumpWidget(
      _build(controller: controller, back: back, face: face, showFace: true),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    final midway = await _averageBrightness(tester);

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final bright = await _averageBrightness(tester);

    expect(
      midway,
      greaterThan(dark + 3),
      reason: '过渡中途应当已经变亮了一些（dark=$dark, mid=$midway）',
    );
    expect(
      midway,
      lessThan(bright - 3),
      reason: '过渡中途不应直接跳到最终亮度（mid=$midway, bright=$bright）',
    );
    expect(bright, greaterThan(dark + 10));
    expect(tester.takeException(), isNull);
  });

  testWidgets('牌面 → 牌背同样平滑过渡', (tester) async {
    final back = await solidCardImage(const ui.Color(0xFF101010));
    final face = await solidCardImage(const ui.Color(0xFFF5F5F5));
    final controller = CardFanSpreadController();

    await tester.pumpWidget(
      _build(controller: controller, back: back, face: face, showFace: true),
    );
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    final bright = await _averageBrightness(tester);

    await tester.pumpWidget(
      _build(controller: controller, back: back, face: face, showFace: false),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    final midway = await _averageBrightness(tester);

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final dark = await _averageBrightness(tester);

    expect(midway, lessThan(bright - 3));
    expect(midway, greaterThan(dark + 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('收拢态（牌完全重合）下切换同样是逐步淡入，不会瞬间跳变', (tester) async {
    // 牌几乎完全重合时每张牌都走「纯净精灵」路径：若淡入淡出的强度被忽略，
    //（或基底也跟着 mix 一起变淡）几十层半透明叠加会把中途帧直接推到终点，
    // 收拢态下切换牌背 / 牌面看起来就是瞬间跳变。
    final back = await solidCardImage(const ui.Color(0xFF101010));
    final face = await solidCardImage(const ui.Color(0xFFF5F5F5));
    final controller = CardFanSpreadController();

    // 不调用 play()：整叠牌停在收拢位置（完全重合）。
    await tester.pumpWidget(
      _build(controller: controller, back: back, face: face, showFace: false),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final dark = await _averageBrightness(tester);

    Future<double> sampleIn(int ms) async {
      await tester.pump(Duration(milliseconds: ms));
      return _averageBrightness(tester);
    }

    await tester.pumpWidget(
      _build(controller: controller, back: back, face: face, showFace: true),
    );
    await tester.pump();
    // _faceMix 时长 280ms：按 1/4、1/2、3/4 三个中途点采样。
    final quarter = await sampleIn(70);
    final half = await sampleIn(70);
    final threeQuarters = await sampleIn(70);

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final bright = await _averageBrightness(tester);

    expect(
      quarter,
      greaterThan(dark + 3),
      reason: '过渡中途应已开始变亮（dark=$dark, quarter=$quarter）',
    );
    expect(quarter, lessThan(bright - 3));
    expect(
      half,
      greaterThan(quarter + 3),
      reason: '中途应逐步变亮，而不是一步跳到牌面（quarter=$quarter, half=$half）',
    );
    expect(threeQuarters, greaterThan(half + 3));
    expect(threeQuarters, lessThan(bright - 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('换牌背是交叉溶解，而不是瞬间替换', (tester) async {
    final darkBack = await solidCardImage(const ui.Color(0xFF101010));
    final brightBack = await solidCardImage(const ui.Color(0xFFF5F5F5));

    await tester.pumpWidget(_BackSwitchHost(back: darkBack));
    // 等精灵合成好，确认起点就是暗牌背。
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    }
    final dark = await _averageBrightness(tester);

    // 换成亮牌背：交叉溶解（280ms）。
    final host = tester.state<_BackSwitchHostState>(
      find.byType(_BackSwitchHost),
    );
    host.switchTo(brightBack);
    await tester.pump();
    // 新牌背还没解码好：仍然画旧的，不能闪一下白牌。
    expect(
      await _averageBrightness(tester),
      moreOrLessEquals(dark, epsilon: 3),
      reason: '新牌背解码完成前应继续显示旧牌背',
    );

    // 溶解进行中：连续采样必须逐步变化（而不是一步跳过去）。
    // 注意不能一次 pump 一大段——fake 时钟下 ticker 会按整段 elapsed 一次跳完。
    Future<double> sampleIn(int ms) async {
      await tester.pump(Duration(milliseconds: ms));
      return _averageBrightness(tester);
    }

    final samples = <double>[for (var i = 0; i < 6; i++) await sampleIn(70)];
    final bright = samples.last;

    // 至少 3 个采样点严格位于两端之间 → 是渐变，不是瞬间替换。
    final middle = samples
        .where((v) => v > dark + 3 && v < bright - 3)
        .toList();
    expect(
      middle.length,
      greaterThanOrEqualTo(3),
      reason:
          '换牌背应当是渐变过渡，不是瞬间替换（dark=$dark, '
          'samples=$samples）',
    );
    // 且单调不减（溶解方向正确）。
    for (var i = 1; i < samples.length; i++) {
      expect(
        samples[i],
        greaterThanOrEqualTo(samples[i - 1] - 0.5),
        reason: '溶解过程应当单调推进（samples=$samples）',
      );
    }
    expect(bright, greaterThan(dark + 10));
    expect(tester.takeException(), isNull);
  });
}
