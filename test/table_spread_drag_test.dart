import 'dart:ui' as ui;

import 'package:card_fan_spread/card_fan_spread.dart';
import 'package:card_fan_spread/src/card_layout.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_card_image.dart';

const Size _canvas = Size(400, 600);

void main() {
  late ui.Image whiteCard;
  late CardFanSpreadController controller;

  setUp(() async {
    whiteCard = await solidCardImage(const ui.Color(0xFFFFFFFF));
    controller = CardFanSpreadController();
  });

  TableSpreadLayout layoutOf({
    SpreadDirection direction = SpreadDirection.leftToRight,
  }) => CardSpreadLayout.compute(
    mode: FanSpreadMode.tableSpread,
    canvas: _canvas,
    cardCount: 52,
    fanAngle: 220,
    fanTierRatio: 0,
    fanPivotX: kDefaultFanPivotX,
    fanPivotLift: kDefaultFanPivotLift,
    tableStepRatio: 0.09,
    tableArcLift: -0.6,
    direction: direction,
  ) as TableSpreadLayout;

  /// 顶牌（最后画、压在最上面那张）当前的中心。
  Offset topCardCenter(TableSpreadLayout t, double progress) {
    final i = t.drawOrder.last;
    final p = t.cardProgressAt(
      i,
      progress,
      stagger: 0,
      curve: Curves.easeOutCubic,
    );
    return Offset(
      ui.lerpDouble(t.stackOffset.dx, t.centers[i].dx, p)!,
      ui.lerpDouble(t.stackOffset.dy, t.centers[i].dy, p)!,
    );
  }

  /// 顶牌自己的单卡进度（stagger = 0 时就是总进度）。
  double topCardProgress(TableSpreadLayout t, double progress) =>
      t.cardProgressAt(
        t.drawOrder.last,
        progress,
        stagger: 0,
        curve: Curves.easeOutCubic,
      );

  /// 顶牌的行程：从收拢位置到最终位置。
  Offset topCardAxis(TableSpreadLayout t) =>
      t.centers[t.drawOrder.last] - t.stackOffset;

  Future<void> pumpTable(
    WidgetTester tester, {
    CardFanSpreadController? controller,
    SpreadDirection direction = SpreadDirection.leftToRight,
    bool tableDragToSpread = true,
  }) {
    return tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: _canvas.width,
            height: _canvas.height,
            child: Container(
              color: const Color(0xFF000000),
              child: CardFanSpread(
                mode: FanSpreadMode.tableSpread,
                controller: controller,
                cardBack: TestCardImage(whiteCard),
                shadowColor: const Color(0x00000000),
                autoPlay: false,
                stagger: 0,
                direction: direction,
                tableDragToSpread: tableDragToSpread,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 从 [from] 拖 [delta] 后松手。
  Future<void> drag(WidgetTester tester, Offset from, Offset delta) async {
    final gesture = await tester.startGesture(from);
    await gesture.moveBy(delta);
    await gesture.up();
    await tester.pump();
  }

  testWidgets('拖动顶牌走一半行程 → 顶牌跟手走到一半', (tester) async {
    final t = layoutOf();
    await pumpTable(tester, controller: controller);
    await tester.pump();
    expect(controller.progress, 0);

    final axis = topCardAxis(t);
    final span = axis.distance;
    await drag(tester, topCardCenter(t, 0), axis * 0.5);

    expect(span, greaterThan(0));
    expect(topCardProgress(t, controller.progress), closeTo(0.5, 0.02));
    expect(controller.isAnimating, isFalse, reason: '跟手定位，不是播放动画');
    expect(tester.takeException(), isNull);
  });

  testWidgets('松手后停在原地，不会自己播完', (tester) async {
    final t = layoutOf();
    await pumpTable(tester, controller: controller);
    await tester.pump();

    await drag(tester, topCardCenter(t, 0), topCardAxis(t) * 0.3);
    final held = controller.progress;
    expect(held, greaterThan(0));

    await tester.pump(const Duration(seconds: 3));
    expect(controller.progress, held, reason: '松手停在手指松开时的进度');
    expect(controller.isAnimating, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('往回拖到底 → 完全收拢', (tester) async {
    final t = layoutOf();
    await pumpTable(tester, controller: controller);
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.progress, 1);

    final axis = topCardAxis(t);
    // 反向拖满整段行程（再多一点也没关系，会被钳到 0）。
    await drag(tester, topCardCenter(t, 1), -axis * 1.5);
    expect(controller.progress, 0);
    expect(topCardProgress(t, controller.progress), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('拖过头 → 钳在完全展开', (tester) async {
    final t = layoutOf();
    await pumpTable(tester, controller: controller);
    await tester.pump();

    await drag(tester, topCardCenter(t, 0), topCardAxis(t) * 2);
    expect(controller.progress, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('分几次拖：进度累加，跟手不跳变', (tester) async {
    final t = layoutOf();
    await pumpTable(tester, controller: controller);
    await tester.pump();

    final axis = topCardAxis(t);
    final start = topCardCenter(t, 0);
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(axis * 0.2);
    await tester.pump();
    final after20 = topCardProgress(t, controller.progress);
    await gesture.moveBy(axis * 0.3); // 累计 50%
    await tester.pump();
    final after50 = topCardProgress(t, controller.progress);
    await gesture.up();
    await tester.pump();

    expect(after20, closeTo(0.2, 0.02));
    expect(after50, closeTo(0.5, 0.02));
    expect(tester.takeException(), isNull);
  });

  testWidgets('触摸没落在顶牌上 → 不响应', (tester) async {
    await pumpTable(tester, controller: controller);
    await tester.pump();

    // 左上角空白：收拢时整叠牌在画布中间，这里什么都没有。
    await drag(tester, const Offset(12, 12), const Offset(40, 30));
    expect(controller.progress, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('右→左方向：顶牌换成另一端的那张，同样跟手', (tester) async {
    final t = layoutOf(direction: SpreadDirection.rightToLeft);
    await pumpTable(
      tester,
      controller: controller,
      direction: SpreadDirection.rightToLeft,
    );
    await tester.pump();

    expect(t.drawOrder.last, 0, reason: '右→左时最左那张压在最上面');
    await drag(tester, topCardCenter(t, 0), topCardAxis(t) * 0.5);
    expect(topCardProgress(t, controller.progress), closeTo(0.5, 0.02));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tableDragToSpread = false → 不响应', (tester) async {
    final t = layoutOf();
    await pumpTable(tester, controller: controller, tableDragToSpread: false);
    await tester.pump();

    await drag(tester, topCardCenter(t, 0), topCardAxis(t) * 0.5);
    expect(controller.progress, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('不传 controller 也能跟手（像素对比）', (tester) async {
    final t = layoutOf();
    final key = GlobalKey();

    Future<int> fingerprint() async {
      final render = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(key),
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
            key: key,
            child: SizedBox(
              width: _canvas.width,
              height: _canvas.height,
              child: Container(
                color: const Color(0xFF000000),
                child: CardFanSpread(
                  mode: FanSpreadMode.tableSpread,
                  cardBack: TestCardImage(whiteCard),
                  shadowColor: const Color(0x00000000),
                  autoPlay: false,
                  stagger: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();
    final collapsed = await fingerprint();

    await drag(tester, topCardCenter(t, 0), topCardAxis(t) * 0.6);
    expect(
      await fingerprint(),
      isNot(collapsed),
      reason: '无 controller 时拖动也应摊开',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('controller 绑定多个组件时，拖动作用于全部组件', (tester) async {
    final firstKey = GlobalKey();
    final secondKey = GlobalKey();

    Future<int> fingerprint(GlobalKey key) async {
      final render = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(key),
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

    Widget half(GlobalKey key) => RepaintBoundary(
      key: key,
      child: SizedBox(
        width: 200,
        height: 300,
        child: Container(
          color: const Color(0xFF000000),
          child: CardFanSpread(
            mode: FanSpreadMode.tableSpread,
            controller: controller,
            cardBack: TestCardImage(whiteCard),
            shadowColor: const Color(0x00000000),
            autoPlay: false,
            stagger: 0,
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: Row(children: [half(firstKey), half(secondKey)]),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();
    final first0 = await fingerprint(firstKey);
    final second0 = await fingerprint(secondKey);

    // 只拖左边那块（它的画布只有 200x300，顶牌行程按自己的布局算）。
    final small = CardSpreadLayout.compute(
      mode: FanSpreadMode.tableSpread,
      canvas: const Size(200, 300),
      cardCount: 52,
      fanAngle: 220,
      fanTierRatio: 0,
      fanPivotX: kDefaultFanPivotX,
      fanPivotLift: kDefaultFanPivotLift,
      tableStepRatio: 0.09,
      tableArcLift: -0.6,
      direction: SpreadDirection.leftToRight,
    ) as TableSpreadLayout;
    final axis = small.centers[small.drawOrder.last] - small.stackOffset;
    await drag(tester, Offset(100, 150), axis * 0.5);

    expect(controller.progress, greaterThan(0));
    expect(await fingerprint(firstKey), isNot(first0));
    expect(
      await fingerprint(secondKey),
      isNot(second0),
      reason: '拖动走 controller.seekTo()，另一个绑定的组件也应一起摊开',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('收拢态往右拖 → 切成从左往右，顶牌跟着手指往右', (tester) async {
    SpreadDirection? reported;
    await tester.pumpWidget(
      _TableHost(
        image: whiteCard,
        controller: controller,
        direction: SpreadDirection.rightToLeft,
        onDirection: (d) => reported = d,
      ),
    );
    await tester.pump();
    expect(controller.progress, 0);

    final leftToRight = layoutOf(direction: SpreadDirection.leftToRight);
    await drag(tester, leftToRight.stackOffset, const Offset(100, 0));

    expect(reported, SpreadDirection.leftToRight);
    expect(
      topCardProgress(leftToRight, controller.progress),
      closeTo(expectedCardProgress(leftToRight, 100), 0.02),
      reason: '顶牌换成最右那张，跟着手指一起往右摊开',
    );
    expect(controller.isAnimating, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('收拢态往左拖 → 切成从右往左', (tester) async {
    SpreadDirection? reported;
    await tester.pumpWidget(
      _TableHost(
        image: whiteCard,
        controller: controller,
        direction: SpreadDirection.leftToRight,
        onDirection: (d) => reported = d,
      ),
    );
    await tester.pump();
    expect(controller.progress, 0);

    final rightToLeft = layoutOf(direction: SpreadDirection.rightToLeft);
    await drag(tester, rightToLeft.stackOffset, const Offset(-100, 0));

    expect(reported, SpreadDirection.rightToLeft);
    expect(
      topCardProgress(rightToLeft, controller.progress),
      closeTo(expectedCardProgress(rightToLeft, -100), 0.02),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('方向已经匹配 → 不回调，但仍跟手摊开', (tester) async {
    SpreadDirection? reported;
    final leftToRight = layoutOf(direction: SpreadDirection.leftToRight);
    await tester.pumpWidget(
      _TableHost(
        image: whiteCard,
        controller: controller,
        direction: SpreadDirection.leftToRight,
        onDirection: (d) => reported = d,
      ),
    );
    await tester.pump();

    await drag(tester, leftToRight.stackOffset, const Offset(100, 0));

    expect(reported, isNull, reason: '方向已经是「从左往右」，不用再切');
    expect(
      topCardProgress(leftToRight, controller.progress),
      closeTo(expectedCardProgress(leftToRight, 100), 0.02),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('换向后继续拖：进度连续，往回拖就收拢', (tester) async {
    SpreadDirection? reported;
    final leftToRight = layoutOf(direction: SpreadDirection.leftToRight);
    await tester.pumpWidget(
      _TableHost(
        image: whiteCard,
        controller: controller,
        direction: SpreadDirection.rightToLeft,
        onDirection: (d) => reported = d,
      ),
    );
    await tester.pump();

    final gesture = await tester.startGesture(leftToRight.stackOffset);
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    final after30 = controller.progress;
    expect(reported, SpreadDirection.leftToRight);
    expect(after30, greaterThan(0));

    await gesture.moveBy(const Offset(60, 0)); // 累计 90
    await tester.pump();
    final after90 = controller.progress;
    expect(after90, greaterThan(after30));

    await gesture.moveBy(const Offset(-120, 0)); // 累计 -30，往回拖
    await tester.pump();
    expect(controller.progress, lessThan(after30));
    expect(controller.progress, 0, reason: '手指拖回起点就该完全收拢');
    await gesture.up();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('已经摊开的牌再拖 → 不换方向', (tester) async {
    SpreadDirection? reported;
    final t = layoutOf();
    await tester.pumpWidget(
      _TableHost(
        image: whiteCard,
        controller: controller,
        onDirection: (d) => reported = d,
      ),
    );
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.progress, 1);

    await drag(tester, topCardCenter(t, 1), const Offset(100, 0));

    expect(reported, isNull, reason: '只在收拢态用拖动方向定展牌方向');
    expect(controller.progress, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('横移太小 → 不换方向', (tester) async {
    SpreadDirection? reported;
    final t = layoutOf();
    await tester.pumpWidget(
      _TableHost(
        image: whiteCard,
        controller: controller,
        onDirection: (d) => reported = d,
      ),
    );
    await tester.pump();

    // 3px 抖动，比 kDirectionDragSlop（8）小。
    await drag(tester, t.stackOffset, const Offset(3, 0));

    expect(reported, isNull);
    expect(controller.progress, lessThan(0.05));
    expect(tester.takeException(), isNull);
  });

  testWidgets('不接方向回调 → 不换方向，但仍然跟手开合', (tester) async {
    final t = layoutOf();
    await pumpTable(tester, controller: controller);
    await tester.pump();

    await drag(tester, t.stackOffset, const Offset(100, 0));

    expect(controller.progress, greaterThan(0));
    expect(controller.isAnimating, isFalse);
    expect(tester.takeException(), isNull);
  });

  test('顶牌在两种叠压方向下都是最后出发的那张', () {
    for (final dir in SpreadDirection.values) {
      final t = layoutOf(direction: dir);
      // 展牌的 delay 以中间为准：两端的牌最晚出发。
      expect(
        t.delayOf(t.drawOrder.last),
        closeTo(1, 1e-9),
        reason: '$dir 的顶牌应该是最后出发的',
      );
    }
  });

  test('顶牌行程方向与叠压方向一致', () {
    final leftToRight = layoutOf();
    final rightToLeft = layoutOf(direction: SpreadDirection.rightToLeft);
    expect(topCardAxis(leftToRight).dx, greaterThan(0));
    expect(topCardAxis(rightToLeft).dx, lessThan(0));
  });
}

/// 受控宿主：把组件给的方向回写回去（模拟真实调用方）。
class _TableHost extends StatefulWidget {
  const _TableHost({
    required this.image,
    required this.controller,
    this.direction = SpreadDirection.leftToRight,
    this.onDirection,
  });

  final ui.Image image;
  final CardFanSpreadController controller;
  final SpreadDirection direction;
  final ValueChanged<SpreadDirection>? onDirection;

  @override
  State<_TableHost> createState() => _TableHostState();
}

class _TableHostState extends State<_TableHost> {
  late SpreadDirection _direction = widget.direction;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: _canvas.width,
          height: _canvas.height,
          child: Container(
            color: const Color(0xFF000000),
            child: CardFanSpread(
              mode: FanSpreadMode.tableSpread,
              controller: widget.controller,
              cardBack: TestCardImage(widget.image),
              shadowColor: const Color(0x00000000),
              autoPlay: false,
              stagger: 0,
              direction: _direction,
              onDirectionChanged: (d) {
                widget.onDirection?.call(d);
                setState(() => _direction = d);
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// 收拢态下往 [dx] 方向拖动，期望**顶牌**走到的单卡进度。
///
/// 反手铺开：换向之后顶牌走的是手指的反方向，投影到轴上取绝对值。
/// （总进度还要再过一遍缓动曲线，跟手看的是这个量。）
double expectedCardProgress(TableSpreadLayout afterFlip, double dx) {
  final axis =
      afterFlip.centers[afterFlip.drawOrder.last] - afterFlip.stackOffset;
  final span = axis.distance;
  return dx.abs() * axis.dx.abs() / (span * span);
}
