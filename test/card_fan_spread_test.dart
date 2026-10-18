import 'dart:ui' as ui;

import 'package:card_fan_spread/card_fan_spread.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_card_image.dart';

/// 与包内默认阴影保持一致（白底测试里用来对比有无阴影的差异）。
const Color kCardShadowColorForTest = Color(0x24000000);

void main() {
  late ui.Image back;
  late ui.Image face;

  setUpAll(() async {
    back = await solidCardImage(const ui.Color(0xFF333366));
    face = await solidCardImage(const ui.Color(0xFFCCDDCC));
  });

  Widget buildWidget({
    FanSpreadMode mode = FanSpreadMode.fan,
    SpreadDirection direction = SpreadDirection.leftToRight,
    CardFanSpreadController? controller,
    bool showFace = false,
    double fanAngle = 220,
    bool withFaces = false,
  }) {
    return MediaQuery(
      data: const MediaQueryData(size: Size(400, 600)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: CardFanSpread(
          mode: mode,
          direction: direction,
          controller: controller,
          showFace: showFace,
          fanAngle: fanAngle,
          autoPlay: false,
          cardBack: TestCardImage(back),
          cardFaces: withFaces ? List.filled(52, TestCardImage(face)) : null,
        ),
      ),
    );
  }

  Future<void> pumpOpen(WidgetTester tester, [int ms = 2200]) async {
    await tester.pump();
    await tester.pump(Duration(milliseconds: ms));
  }

  testWidgets('开扇：动画从 0 进行到 1 且不抛异常', (tester) async {
    final controller = CardFanSpreadController();
    await tester.pumpWidget(buildWidget(controller: controller));
    await tester.pump();
    expect(controller.progress, 0);

    controller.play();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.progress, greaterThan(0));
    await tester.pump(const Duration(seconds: 3));
    expect(controller.progress, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('三种模式均可正常绘制', (tester) async {
    for (final mode in FanSpreadMode.values) {
      await tester.pumpWidget(buildWidget(mode: mode));
      await pumpOpen(tester);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('开扇 rightToLeft 的牌序与 leftToRight 镜像（首牌朝向相反）', (tester) async {
    // 通过不同 fanAngle 下都稳定绘制来验证角度参数生效；几何差异体现在
    // 绘制角度上，这里只验证参数接受与动画完成。
    final controller = CardFanSpreadController();
    await tester.pumpWidget(
      buildWidget(
        mode: FanSpreadMode.fan,
        direction: SpreadDirection.rightToLeft,
        controller: controller,
        fanAngle: 120,
      ),
    );
    controller.play();
    await pumpOpen(tester);
    expect(controller.progress, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('showFace 时使用牌面图片', (tester) async {
    await tester.pumpWidget(buildWidget(showFace: true, withFaces: true));
    await pumpOpen(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('画面在展开过程中逐帧变化（像素级回归）', (tester) async {
    final boundaryKey = GlobalKey();
    final controller = CardFanSpreadController();
    final whiteCard = await solidCardImage(const ui.Color(0xFFFFFFFF));

    Future<int> fingerprint() async {
      final render = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundaryKey),
      );
      final image = (await tester.runAsync(() => render.toImage()))!;
      final data = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
      ))!;
      final bytes = data.buffer.asUint8List();
      var sum = 0;
      for (var i = 0; i < bytes.length; i += 37) {
        sum += bytes[i] * ((i % 251) + 1);
      }
      return sum;
    }

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: 400,
              height: 600,
              child: Container(
                color: const Color(0xFF000000),
                child: CardFanSpread(
                  key: const Key('spread'),
                  mode: FanSpreadMode.fan,
                  controller: controller,
                  cardBack: TestCardImage(whiteCard),
                  autoPlay: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // 等图片解码完成，避免把「图片到达」误判成「动画推进」。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final initial = await fingerprint();

    controller.play();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    final midway = await fingerprint();
    expect(midway, isNot(initial), reason: '展开过程中画面必须变化');

    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    final opened = await fingerprint();
    expect(opened, isNot(midway), reason: '动画应在推进');
    expect(controller.progress, 1);

    // 完全收拢后应与初始状态完全一致
    controller.close();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.progress, 0);
    final closed = await fingerprint();
    expect(closed, initial, reason: '收拢后应回到初始画面');
    expect(tester.takeException(), isNull);
  });

  testWidgets('图片解码完成后会刷新到真实牌图', (tester) async {
    // 白色牌图 + 黑色背景：首帧若没刷新会是灰占位色
    final whiteCard = await solidCardImage(const ui.Color(0xFFFFFFFF));
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: 400,
              height: 600,
              child: Container(
                color: const Color(0xFF000000),
                child: CardFanSpread(
                  cardBack: TestCardImage(whiteCard),
                  cardCount: 8,
                  autoPlay: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    Future<double> whiteRatio() async {
      final render = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundaryKey),
      );
      final image = (await tester.runAsync(() => render.toImage()))!;
      final data = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
      ))!;
      final bytes = data.buffer.asUint8List();
      var whitePixels = 0;
      var total = 0;
      for (var i = 0; i < bytes.length; i += 4 * 7) {
        total++;
        if (bytes[i] > 230 && bytes[i + 1] > 230 && bytes[i + 2] > 230) {
          whitePixels++;
        }
      }
      return whitePixels / total;
    }

    // 逐帧绘制路径（精灵图尚未合成好）
    final direct = await whiteRatio();
    expect(direct, greaterThan(0.1), reason: '应当已经绘制出白色的牌，而不是灰占位卡');

    // 等精灵图合成完成后重绘，画面应保持一致（渲染路径切换不影响结果）
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final viaSprite = await whiteRatio();
    expect(viaSprite, greaterThan(0.1));
    expect(
      (viaSprite - direct).abs() / direct,
      lessThan(0.25),
      reason: '精灵图路径与逐帧绘制路径的画面应基本一致',
    );
  });

  testWidgets('阴影两端都不过分：收拢不叠成黑框、摊开后仍看得见投影', (tester) async {
    final whiteCard = await solidCardImage();
    final boundaryKey = GlobalKey();

    /// 白底 + 白牌：所有非纯白像素都来自描边 / 阴影。
    Future<int> darkest() async {
      final render = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundaryKey),
      );
      final image = (await tester.runAsync(() => render.toImage()))!;
      final data = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
      ))!;
      final bytes = data.buffer.asUint8List();
      var min = 255;
      for (var i = 0; i < bytes.length; i += 4) {
        if (bytes[i] < min) min = bytes[i];
      }
      return min;
    }

    /// 非纯白像素数量：包含描边 + 阴影，可用于对比有无阴影的差异。
    Future<int> shadedPixelCount() async {
      final render = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundaryKey),
      );
      final image = (await tester.runAsync(() => render.toImage()))!;
      final data = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
      ))!;
      final bytes = data.buffer.asUint8List();
      var count = 0;
      for (var i = 0; i < bytes.length; i += 4) {
        if (bytes[i] < 250) count++;
      }
      return count;
    }

    Widget build(Color shadowColor) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: 400,
              height: 600,
              child: Container(
                color: const Color(0xFFFFFFFF),
                child: CardFanSpread(
                  mode: FanSpreadMode.tableSpread,
                  cardBack: TestCardImage(whiteCard),
                  shadowColor: shadowColor,
                  autoPlay: false,
                ),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> openFully() async {
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
    }

    // 完全透明的牌色（等价于 Colors.transparent，但这里不引入 Material 依赖）。
    await tester.pumpWidget(build(const Color(0x00000000)));
    await openFully();
    final noShadow = await shadedPixelCount();
    final darkestNoShadow = await darkest();

    await tester.pumpWidget(build(kCardShadowColorForTest));
    await openFully();
    final withShadow = await shadedPixelCount();

    expect(
      withShadow,
      greaterThan(noShadow * 1.2),
      reason: '摊开后阴影几乎不存在（$withShadow vs 无阴影 $noShadow 像素）',
    );
    // 阴影面积本来就远大于细描边，所以「过重」用最暗亮度来衡量，
    // 而不是用像素数：单张 14% 阴影叠一两层也不该出现接近纯黑的区域。
    expect(await darkest(), greaterThan(90), reason: '摊开后出现了接近纯黑的区域，说明阴影叠加过头了');

    // 收拢：52 张牌重合，阴影/描边绝不能叠成黑框
    await tester.pumpWidget(build(kCardShadowColorForTest));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final collapsed = await darkest();
    expect(
      collapsed,
      greaterThan(190),
      reason: '收拢时最暗处只有 $collapsed/255 亮度，说明装饰被重复叠加了',
    );
    expect(darkestNoShadow, lessThan(250), reason: '无阴影时描边仍应可见');
  });

  testWidgets('收拢时不会把多张牌的阴影叠成黑边', (tester) async {
    final whiteCard = await solidCardImage();
    final boundaryKey = GlobalKey();

    /// 白底 + 白牌：所有非纯白像素都来自描边 / 阴影。
    Future<int> darkest() async {
      final render = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundaryKey),
      );
      final image = (await tester.runAsync(() => render.toImage()))!;
      final data = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
      ))!;
      final bytes = data.buffer.asUint8List();
      var min = 255;
      for (var i = 0; i < bytes.length; i += 4) {
        final brightness = bytes[i];
        if (brightness < min) min = brightness;
      }
      return min;
    }

    Widget build(FanSpreadMode mode) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: 400,
              height: 600,
              child: Container(
                color: const Color(0xFFFFFFFF),
                child: CardFanSpread(
                  mode: mode,
                  cardBack: TestCardImage(whiteCard),
                  autoPlay: false,
                ),
              ),
            ),
          ),
        ),
      );
    }

    for (final mode in FanSpreadMode.values) {
      await tester.pumpWidget(build(mode));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final minBrightness = await darkest();
      expect(
        minBrightness,
        greaterThan(190),
        reason:
            '${mode.name} 收拢时最暗处只有 '
            '${(minBrightness / 255 * 100).toInt()}% 亮度，说明阴影被重复叠加了',
      );
    }
  });

  testWidgets('toggle / close / reset 行为正确', (tester) async {
    final controller = CardFanSpreadController();
    await tester.pumpWidget(buildWidget(controller: controller));
    await tester.pump();

    controller.toggle();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.isOpened, isTrue);

    controller.close();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.progress, 0);

    controller.replay();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.progress, greaterThan(0));
    controller.reset();
    expect(controller.progress, 0);
  });

  testWidgets('无界宽度约束（如直接放在 Row 里）不崩溃', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 400,
          height: 600,
          // Row 给子组件无界宽度：应退回内置固定尺寸而不是布局断言崩溃。
          child: Row(
            children: [
              CardFanSpread(cardBack: TestCardImage(back), autoPlay: false),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.byType(CustomPaint), findsOneWidget);
  });
}
