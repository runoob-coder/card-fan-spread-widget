import 'dart:ui' as ui;

import 'package:card_fan_spread/card_fan_spread.dart';
import 'package:card_fan_spread/src/card_sprite.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_card_image.dart';

/// 画布尺寸可变的宿主页（改尺寸只走 setState，不会重建牌图 provider）。
class _ResizeHost extends StatefulWidget {
  const _ResizeHost({required this.card, required this.canvas});

  final ui.Image card;
  final Size canvas;

  @override
  State<_ResizeHost> createState() => _ResizeHostState();
}

class _ResizeHostState extends State<_ResizeHost> {
  /// 牌图 provider 必须是**同一个对象**：每次 build 新建一个会触发组件重新解析
  /// 图片（拿到新的 ui.Image 克隆 → 精灵缓存里查不到 → 退回回退路径），
  /// 那样就测不到「精灵还在、只是尺寸旧了」这个场景。
  late final ImageProvider back = TestCardImage(widget.card);

  /// 画布尺寸（用 ValueNotifier 承载：测试里改它只重建牌区子树）。
  late final ValueNotifier<Size> canvas = ValueNotifier<Size>(widget.canvas);

  @override
  void dispose() {
    canvas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: _boundaryKey,
          child: ValueListenableBuilder<Size>(
            valueListenable: canvas,
            builder: (context, size, _) => SizedBox(
              width: size.width,
              height: size.height,
              child: Container(
                color: const Color(0x00000000),
                child: CardFanSpread(
                  mode: FanSpreadMode.fan,
                  cardBack: back,
                  cardCount: 52,
                  fanAngle: 220,
                  autoPlay: false,
                  // 关掉阴影：外接框就是牌身本身。
                  shadowColor: const Color(0x00000000),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final GlobalKey _boundaryKey = GlobalKey();

/// 画布上「不透明」像素的外接框。
///
/// 阈值取 128：半透明描边与放大后变虚的圆角不计入，否则「旧精灵被放大」带来的
/// 抗锯齿差异会盖过真正的尺寸误差。
Future<ui.Rect> _contentBox(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundaryKey),
  );
  final image = await tester.runAsync(() => boundary.toImage());
  final data = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
  );
  image!.dispose();
  final bytes = data!.buffer.asUint8List();
  final w = image.width;
  final h = image.height;
  double minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (bytes[(y * w + x) * 4 + 3] > 128) {
        if (x < minX) minX = x.toDouble();
        if (x > maxX) maxX = x.toDouble();
        if (y < minY) minY = y.toDouble();
        if (y > maxY) maxY = y.toDouble();
      }
    }
  }
  return ui.Rect.fromLTRB(minX, minY, maxX + 1, maxY + 1);
}

/// 等精灵图真正落地（合成是异步的：pump 推进 fake 时钟，runAsync 给真实时间）。
Future<void> _settleSprites(WidgetTester tester) async {
  // 先推进过 [kSpriteSettleDelay]，让「换档」请求真正执行（否则牌尺寸变了也
  // 一直用旧精灵）。
  await tester.pump(kSpriteSettleDelay * 2);
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  }
}

void main() {
  testWidgets('牌尺寸变了、精灵还没换档时，牌仍按布局尺寸绘制', (tester) async {
    final back = await tester.runAsync(() => solidCardImage()) as ui.Image;
    await tester.pumpWidget(
      _ResizeHost(card: back, canvas: const Size(300, 300)),
    );

    // 1) 小画布：精灵按「小牌」的尺寸合成出来。
    await _settleSprites(tester);
    final host = tester.state<_ResizeHostState>(find.byType(_ResizeHost));

    // 2) 画布放大一倍：牌跟着变大一倍，但精灵还是旧的小尺寸（换档要等牌尺寸
    //    稳定 [kSpriteSettleDelay]；这里只 pump 一帧，防抖还没到）。
    host.canvas.value = const Size(600, 600);
    await tester.pump();
    final staleBox = await _contentBox(tester);

    // 3) 等过防抖、精灵按新尺寸重合成之后。
    await _settleSprites(tester);
    final freshBox = await _contentBox(tester);

    // 牌必须始终按**布局**给的尺寸画：旧精灵只是分辨率不够，不能把牌画大 / 画小。
    // 精灵里的留白是按合成时的尺寸加的，直接把整张精灵拉到
    // `rect.inflate(kCardSpritePadding)` 上会连留白一起缩放——精灵高差一倍时牌会
    // 被画小 10%，首屏精灵陆续到位的过程里看起来就是纸牌忽大忽小。
    expect(
      staleBox.width,
      moreOrLessEquals(freshBox.width, epsilon: 1.5),
      reason: '旧精灵（未换档）与新精灵画出的牌宽度应一致',
    );
    expect(
      staleBox.height,
      moreOrLessEquals(freshBox.height, epsilon: 1.5),
      reason: '旧精灵（未换档）与新精灵画出的牌高度应一致',
    );
    expect(tester.takeException(), isNull);
  });
}
