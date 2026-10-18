import 'dart:async';
import 'dart:ui' as ui;

import 'package:card_fan_spread/card_fan_spread.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_card_image.dart';

/// 无图可用时的「空白白牌」回归测试。
///
/// 历史 bug：逐帧回退路径用 `Paint()` 的默认颜色（纯黑）填充牌身，
/// 于是「未传牌背 / 图片没解码好 / 解码失败」时整叠牌是一块块黑牌。
/// 期望行为：画成一张背面朝上的空白白牌（[kCardBlankColor]）。
void main() {
  late ui.Image darkFace;

  setUpAll(() async {
    // 深灰牌面：用来验证「空白白牌 → 牌面」的过渡不会闪黑。
    darkFace = await solidCardImage(const ui.Color(0xFF202020));
  });

  /// 台面铺满整块底色，组件居中铺满（展牌模式在进度 0 时整叠牌重合在中间）。
  Widget build({
    ImageProvider? cardBack,
    List<ImageProvider>? cardFaces,
    bool showFace = false,
    CardFanSpreadController? controller,
    Color background = const Color(0xFF000000),
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
            child: ColoredBox(
              color: background,
              child: CardFanSpread(
                mode: FanSpreadMode.tableSpread,
                cardCount: 8,
                autoPlay: false,
                controller: controller,
                cardBack: cardBack,
                cardFaces: cardFaces,
                showFace: showFace,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('未传牌背：每张牌是白底空白牌，而不是黑块', (tester) async {
    await tester.pumpWidget(build());
    await tester.pump();

    final pixels = await _capture(tester);
    final card = pixels.brightBounds();
    expect(card, isNotNull, reason: '未传牌背时应当仍然画出牌身（白底空白牌）');
    expect(
      pixels.average(_inner(card!)),
      greaterThan(220),
      reason: '空白牌应当是白底（实测中心亮度 ${pixels.average(_inner(card))}）',
    );
    expect(
      pixels.average(_corner),
      lessThan(40),
      reason: '牌之外的画布应当保持背景色，白区确实是牌身而不是整块白',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('牌图一直没有就绪（资源缺失 / 加载中）：同样画白底空白牌', (tester) async {
    await tester.pumpWidget(build(cardBack: _PendingImageProvider()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final pixels = await _capture(tester);
    final card = pixels.brightBounds();
    expect(card, isNotNull, reason: '图片未就绪时应当画出白底空白牌，而不是什么都不画');
    expect(
      pixels.average(_inner(card!)),
      greaterThan(220),
      reason: '图片未就绪时空白牌应当是白底（实测中心亮度 ${pixels.average(_inner(card))}）',
    );
    expect(pixels.average(_corner), lessThan(40));
    expect(tester.takeException(), isNull);
  });

  testWidgets('未传牌背 + 有牌面：展开后切到牌面是渐变过渡，中途不闪黑', (tester) async {
    final controller = CardFanSpreadController();
    final faces = List<ImageProvider>.filled(8, TestCardImage(darkFace));

    Widget page({required bool showFace}) => build(
      controller: controller,
      cardFaces: faces,
      showFace: showFace,
      // 中灰台面：白牌 / 深灰牌面的切换会明显改变整幅画面的平均亮度。
      background: const Color(0xFF808080),
    );

    await tester.pumpWidget(page(showFace: false));
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.progress, 1);
    final blank = (await _capture(tester)).average(_whole);

    await tester.pumpWidget(page(showFace: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    final midway = (await _capture(tester)).average(_whole);

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final face = (await _capture(tester)).average(_whole);

    expect(blank, greaterThan(face + 10), reason: '白牌应当比深灰牌面亮得多');
    expect(
      midway,
      lessThan(blank - 3),
      reason: '过渡中途不应直接跳到白牌（mid=$midway, blank=$blank）',
    );
    expect(
      midway,
      greaterThan(face + 3),
      reason: '过渡中途不应直接跳到牌面（mid=$midway, face=$face）',
    );
    expect(tester.takeException(), isNull);
  });
}

final GlobalKey _boundaryKey = GlobalKey();
const Size _canvas = Size(400, 600);

/// 画布左上角的背景采样区（远离牌身）。
const Rect _corner = Rect.fromLTWH(2, 2, 16, 16);

/// 整幅画布。
final Rect _whole = Rect.fromLTWH(0, 0, _canvas.width, _canvas.height);

/// 取一个矩形中心 40% 的区域（避开圆角 / 描边 / 投影）。
Rect _inner(Rect bounds) => Rect.fromLTWH(
  bounds.left + bounds.width * 0.3,
  bounds.top + bounds.height * 0.3,
  bounds.width * 0.4,
  bounds.height * 0.4,
);

/// 把 [RenderRepaintBoundary] 的渲染结果抓成裸像素，便于做像素级断言。
class _Pixels {
  _Pixels(this.bytes, this.width, this.height);

  final Uint8List bytes;
  final int width;
  final int height;

  int _luminance(int x, int y) => bytes[(y * width + x) * 4];

  /// 区域平均亮度（0~255）。
  double average(Rect rect) {
    final left = rect.left.round().clamp(0, width - 1);
    final top = rect.top.round().clamp(0, height - 1);
    final right = rect.right.round().clamp(left + 1, width);
    final bottom = rect.bottom.round().clamp(top + 1, height);
    var sum = 0;
    var count = 0;
    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        sum += _luminance(x, y);
        count++;
      }
    }
    return sum / count;
  }

  /// 亮度 > 150 的像素的包围盒（牌身）；找不出有面积的区域时返回 null。
  Rect? brightBounds() {
    var minX = width, maxX = -1, minY = height, maxY = -1;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (_luminance(x, y) > 150) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxX - minX < 20 || maxY - minY < 20) return null;
    return Rect.fromLTRB(
      minX.toDouble(),
      minY.toDouble(),
      (maxX + 1).toDouble(),
      (maxY + 1).toDouble(),
    );
  }
}

Future<_Pixels> _capture(WidgetTester tester) async {
  final render = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundaryKey),
  );
  final image = (await tester.runAsync(() => render.toImage()))!;
  final data = (await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
  ))!;
  return _Pixels(data.buffer.asUint8List(), image.width, image.height);
}

/// 永远不 resolve 的牌图：模拟资源缺失 / 网络图片迟迟不返回。
class _PendingImageProvider extends ImageProvider<_PendingImageProvider> {
  @override
  Future<_PendingImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_PendingImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _PendingImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
  }
}
