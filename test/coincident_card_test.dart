import 'dart:ui' as ui;

import 'package:card_fan_spread/card_fan_spread.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_card_image.dart';

/// 完全重合的牌不再重复贴图（52 张收拢态 → 1~2 次贴图）之后，画面必须仍然
/// 是一叠**不透明**的牌：跳过画错了会漏出背景，不跳过则白白浪费。
///
/// 两条不变量：
/// 1. 牌数从 3 变到 52，收拢态的画面几乎不变（整叠牌本来就是重合的）；
/// 2. 牌身内部没有背景色透出 —— 最后那张不透明的牌确实画了。
void main() {
  const canvas = Size(400, 600);
  final boundaryKey = GlobalKey();
  late ui.Image whiteCard;

  setUpAll(() async {
    whiteCard = await solidCardImage(const ui.Color(0xFFFFFFFF));
  });

  Widget build(int cardCount, FanSpreadMode mode) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: boundaryKey,
          child: SizedBox(
            width: canvas.width,
            height: canvas.height,
            child: ColoredBox(
              color: const Color(0xFF000000),
              child: CardFanSpread(
                mode: mode,
                cardCount: cardCount,
                cardBack: TestCardImage(whiteCard),
                autoPlay: false,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 牌身包围盒、亮像素数、牌内最低亮度（漏画判据）与牌区平均亮度。
  Future<({int area, int min, double mean})> measure(
    WidgetTester tester,
  ) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    final image = (await tester.runAsync(() => boundary.toImage()))!;
    final data = (await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
    ))!;
    final bytes = data.buffer.asUint8List();
    final w = image.width;
    final h = image.height;

    var minX = w;
    var maxX = 0;
    var minY = h;
    var maxY = 0;
    var sum = 0;
    var count = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final b = bytes[(y * w + x) * 4];
        if (b > 200) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
          sum += b;
          count++;
        }
      }
    }
    // 牌身内部（包围盒缩进 15%）的最低亮度：漏画会让黑色背景透出来。
    final padX = ((maxX - minX) * 0.15).round();
    final padY = ((maxY - minY) * 0.15).round();
    var minInCard = 255;
    for (var y = minY + padY; y <= maxY - padY; y++) {
      for (var x = minX + padX; x <= maxX - padX; x++) {
        final b = bytes[(y * w + x) * 4];
        if (b < minInCard) minInCard = b;
      }
    }
    return (area: count, min: minInCard, mean: count == 0 ? 0.0 : sum / count);
  }

  Future<void> pumpAt(
    WidgetTester tester,
    int cardCount,
    FanSpreadMode mode,
  ) async {
    await tester.pumpWidget(build(cardCount, mode));
    await tester.pump();
  }

  testWidgets('收拢态：牌数增加不改变画面，且牌身不漏背景', (tester) async {
    await pumpAt(tester, 3, FanSpreadMode.fan);
    final few = await measure(tester);

    await pumpAt(tester, 52, FanSpreadMode.fan);
    final many = await measure(tester);

    expect(many.min, greaterThan(200), reason: '收拢态牌身必须完全不透明（不漏背景）');
    // 整叠牌完全重合：52 张与 3 张的画面应当几乎一致（差异只来自布局按包围盒
    // 自适应缩放时牌数带来的几个像素差别）。
    expect(
      (many.area - few.area).abs() / few.area,
      lessThan(0.05),
      reason: '牌数从 3 增到 52，收拢态画面面积不应明显变化',
    );
    expect((many.mean - few.mean).abs(), lessThan(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('展牌收拢态同样不漏背景', (tester) async {
    await pumpAt(tester, 52, FanSpreadMode.tableSpread);
    final m = await measure(tester);
    expect(m.min, greaterThan(200), reason: '展牌收拢态整叠牌重合，牌身应完全不透明');
    expect(tester.takeException(), isNull);
  });
}
