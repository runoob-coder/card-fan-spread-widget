import 'dart:io';
import 'dart:ui' as ui;

import 'package:card_fan_spread/card_fan_spread.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_card_image.dart';

/// README 截图生成器。
///
/// 用法（在包根目录执行）：
/// ```sh
/// GENERATE_SCREENSHOTS=1 flutter test test/screenshots_generator_test.dart
/// ```
///
/// 不设环境变量时全部跳过，因此普通 `flutter test`（含 CI）不受影响。
/// 参数与 `example/lib/main.dart` 的默认值保持一致。
final bool _generate = Platform.environment['GENERATE_SCREENSHOTS'] == '1';

/// 演示工程的牌背素材目录（相对包根目录）。
const String _backDir = 'example/assets/back';

/// 演示工程的牌面素材目录（相对包根目录，Rider 牌面）。
const String _faceDir = 'example/assets/rider_cards';

/// 统一的默认牌背：Rider Back。
const String _backAsset = 'Back_Rider.webp';

const Size _canvas = Size(640, 640);

/// 透明背景：截图保留 alpha，不再铺白底。
const Color _bgColor = Color(0x00000000);

/// 加载统一的牌背（Rider Back，与演示工程同一批素材）。
Future<ui.Image> _loadCardBack() async {
  final bytes = await File('$_backDir/$_backAsset').readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}

/// 加载一副完整的 Rider 牌面（52 张标准牌）。
Future<List<ui.Image>> _loadCardFaces() async {
  const List<String> suits = <String>['Clubs', 'Diamonds', 'Hearts', 'Spades'];
  const List<String> ranks = <String>[
    'A',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    'J',
    'Q',
    'K',
  ];
  final names = <String>[
    for (final String suit in suits)
      for (final String rank in ranks) '${suit}_$rank.webp',
  ];
  final images = <ui.Image>[];
  for (final name in names) {
    final bytes = await File('$_faceDir/$name').readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    images.add(frame.image);
  }
  return images;
}

Widget _frame({
  required GlobalKey boundaryKey,
  required ui.Image back,
  required FanSpreadMode mode,
  required CardFanSpreadController controller,
  SpreadDirection direction = SpreadDirection.leftToRight,
  double fanAngle = 260,
  double fanTierRatio = 0,
  double fanPivotX = kDefaultFanPivotX,
  double fanPivotLift = kDefaultFanPivotLift,
  bool showFace = false,
  List<ui.Image>? faces,
}) {
  return MediaQuery(
    data: const MediaQueryData(size: _canvas),
    child: Directionality(
      textDirection: TextDirection.ltr,
      // pumpWidget 的根约束是 tight 800×600，会直接把 SizedBox 钳制成
      // 800×600；必须套一层 Center 放宽约束，画布才是 600×400。
      // 白底放在 RepaintBoundary 内部，才会被拍进截图。
      child: Center(
        child: RepaintBoundary(
          key: boundaryKey,
          child: SizedBox(
            width: _canvas.width,
            height: _canvas.height,
            child: ColoredBox(
              color: _bgColor,
              child: CardFanSpread(
                mode: mode,
                controller: controller,
                cardBack: TestCardImage(back),
                cardFaces: faces?.map(TestCardImage.new).toList(),
                showFace: showFace,
                cardCount: 52,
                direction: direction,
                fanAngle: fanAngle,
                fanTierRatio: fanTierRatio,
                fanPivotX: fanPivotX,
                fanPivotLift: fanPivotLift,
                tableStepRatio: 0.09,
                tableArcLift: -0.6,
                duration: const Duration(milliseconds: 1800),
                stagger: 0,
                autoPlay: false,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _capture(
  WidgetTester tester,
  String pngName, {
  required FanSpreadMode mode,
  SpreadDirection direction = SpreadDirection.leftToRight,
  double fanAngle = 260,
  double fanTierRatio = 0,
  double fanPivotX = kDefaultFanPivotX,
  double fanPivotLift = kDefaultFanPivotLift,
  bool showFace = false,
}) async {
  final boundaryKey = GlobalKey();

  // 测试窗口默认 800×600，装不下 640×640 的画布（会被压成 640×600）。
  await tester.binding.setSurfaceSize(_canvas);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  // 文件读取 / 图片解码是真实异步：必须放在 runAsync 里，
  // 直接在 testWidgets 体内 await 会因 fake-async 不推进而超时。
  // runAsync 的返回类型是 T?，加载成功必然非空。
  final back = (await tester.runAsync(_loadCardBack))!;
  // 牌面截图才需要加载 52 张牌面；牌背截图只加载牌背即可。
  final faces = showFace ? (await tester.runAsync(_loadCardFaces))! : null;

  final controller = CardFanSpreadController();
  await tester.pumpWidget(
    _frame(
      boundaryKey: boundaryKey,
      back: back,
      mode: mode,
      direction: direction,
      controller: controller,
      fanAngle: fanAngle,
      fanTierRatio: fanTierRatio,
      fanPivotX: fanPivotX,
      fanPivotLift: fanPivotLift,
      showFace: showFace,
      faces: faces,
    ),
  );
  controller.play();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 2600));
  expect(controller.progress, 1);
  // 等异步精灵图合成完成（onReady 里 setState），再喂一帧应用。
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 150)),
  );
  await tester.pump();

  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(boundaryKey),
  );
  final outPath = '${Directory.current.path}/screenshots/$pngName';
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await File(outPath).writeAsBytes(data!.buffer.asUint8List());
  });
  // ignore: avoid_print
  print('已生成 $outPath');
}

void main() {
  group('README 截图', () {
    testWidgets('展牌（牌背）', (tester) async {
      if (!_generate) return;
      await _capture(
        tester,
        'table-spread.png',
        mode: FanSpreadMode.tableSpread,
      );
    });

    testWidgets('开扇（牌背）', (tester) async {
      if (!_generate) return;
      await _capture(tester, 'fan.png', mode: FanSpreadMode.fan);
    });

    testWidgets('反开扇（牌背）', (tester) async {
      if (!_generate) return;
      await _capture(
        tester,
        'reverse-fan.png',
        mode: FanSpreadMode.fan,
        direction: SpreadDirection.rightToLeft,
      );
    });

    testWidgets('大扇（开扇 + 双层错落，牌背）', (tester) async {
      if (!_generate) return;
      await _capture(
        tester,
        'giant-fan.png',
        mode: FanSpreadMode.fan,
        // 260° 开扇 + 44% 双层错落：即魔术里的「大扇」。
        fanAngle: 260,
        fanTierRatio: 0.44,
      );
    });

    testWidgets('S 扇（牌背）', (tester) async {
      if (!_generate) return;
      await _capture(
        tester,
        's-fan.png',
        mode: FanSpreadMode.sFan,
        // 540°：脊线切向总摆幅拉满，S 最卷、最饱满的档位。
        fanAngle: 540,
      );
    });

    testWidgets('双手开扇（牌背）', (tester) async {
      if (!_generate) return;
      await _capture(
        tester,
        'two-hand-fan.png',
        mode: FanSpreadMode.twoHandFan,
      );
    });

    testWidgets('偏轴开扇（枢轴贴在左边缘，牌背）', (tester) async {
      if (!_generate) return;
      await _capture(
        tester,
        'fan-pivot-left.png',
        mode: FanSpreadMode.fan,
        // 圆心挪到牌左边缘：整副牌从这一个点向右扫开。
        fanPivotX: 0,
      );
    });

    testWidgets('垂挂开扇（枢轴沉到牌边下方一整张牌，牌背）', (tester) async {
      if (!_generate) return;
      await _capture(
        tester,
        'fan-pivot-drop.png',
        mode: FanSpreadMode.fan,
        // 圆心沉到底边下方一整张牌高：牌像从枢轴上垂挂下来。
        fanPivotLift: 1.0,
      );
    });

    // —— 牌面版（统一用 Rider 牌面，showFace: true）——
    testWidgets('开扇（牌面）', (tester) async {
      if (!_generate) return;
      await _capture(
        tester,
        'fan-face.png',
        mode: FanSpreadMode.fan,
        // 比默认 220° 更大的开扇角度，把牌面铺得更开。
        fanAngle: 300,
        showFace: true,
      );
    });

    testWidgets('展牌（牌面）', (tester) async {
      if (!_generate) return;
      await _capture(
        tester,
        'table-spread-face.png',
        mode: FanSpreadMode.tableSpread,
        showFace: true,
      );
    });

    testWidgets('S 扇（牌面）', (tester) async {
      if (!_generate) return;
      await _capture(
        tester,
        's-fan-face.png',
        mode: FanSpreadMode.sFan,
        fanAngle: 540,
        showFace: true,
      );
    });

    testWidgets('双手开扇（牌面）', (tester) async {
      if (!_generate) return;
      await _capture(
        tester,
        'two-hand-fan-face.png',
        mode: FanSpreadMode.twoHandFan,
        showFace: true,
      );
    });
  });
}
