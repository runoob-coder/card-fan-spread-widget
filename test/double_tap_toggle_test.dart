import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:card_fan_spread/card_fan_spread.dart';
import 'package:card_fan_spread/src/card_layout.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_card_image.dart';

const Size _canvas = Size(400, 600);

/// 画布中心（收拢时整叠牌就在附近）。
const Offset _center = Offset(200, 300);

/// 左上角空白处：牌叠之外，用来验证「空白区域也能双击」（translucent）。
const Offset _blank = Offset(12, 12);

void main() {
  late ui.Image whiteCard;
  late CardFanSpreadController controller;

  setUp(() async {
    whiteCard = await solidCardImage(const ui.Color(0xFFFFFFFF));
    controller = CardFanSpreadController();
  });

  /// 铺一块 [CardFanSpread] 画布（默认收拢、不自动播放）。
  Future<void> pumpCanvas(
    WidgetTester tester, {
    CardFanSpreadController? controller,
    FanSpreadMode mode = FanSpreadMode.fan,
    bool doubleTapToToggle = true,
    VoidCallback? onDoubleTap,
    ValueChanged<double>? onFanAngleChanged,
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
                mode: mode,
                controller: controller,
                cardBack: TestCardImage(whiteCard),
                shadowColor: const Color(0x00000000),
                autoPlay: false,
                stagger: 0,
                doubleTapToToggle: doubleTapToToggle,
                onDoubleTap: onDoubleTap,
                onFanAngleChanged: onFanAngleChanged,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 完全展开时「最顶的那张牌」的中心（拖动命中测试的起点）。
  Offset topCardCenter() {
    final fan = CardSpreadLayout.compute(
      mode: FanSpreadMode.fan,
      canvas: _canvas,
      cardCount: 52,
      fanAngle: 220,
      fanTierRatio: 0,
      fanPivotX: kDefaultFanPivotX,
      fanPivotLift: kDefaultFanPivotLift,
      tableStepRatio: 0.09,
      tableArcLift: -0.6,
      direction: SpreadDirection.leftToRight,
    ) as FanSpreadLayout;
    final i = fan.drawOrder.last;
    final angle = fan.targetAngles[i];
    final local = Offset(
      fan.cardWidth / 2 - fan.pivotOffset.dx,
      fan.cardHeight / 2 - fan.pivotOffset.dy,
    );
    return fan.origin +
        Offset(
          local.dx * math.cos(angle) - local.dy * math.sin(angle),
          local.dx * math.sin(angle) + local.dy * math.cos(angle),
        );
  }

  /// 连点两下（第二下抬起时判定双击）。
  Future<void> tapTwice(
    WidgetTester tester,
    Offset first,
    Offset second,
  ) async {
    await tester.tapAt(first);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(second);
    await tester.pump();
  }

  /// 双击：两次点击间隔必须落在双击时限（300ms）内。
  Future<void> doubleTap(WidgetTester tester, Offset at) async {
    await tapTwice(tester, at, at);
  }

  /// 推进足够长时间，让开合动画走完（Ticker 首帧不积累时间，先空推进一帧）。
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
  }

  testWidgets('双击收拢态 → 播放展开', (tester) async {
    await pumpCanvas(tester, controller: controller);
    await tester.pump();
    expect(controller.progress, 0);

    await doubleTap(tester, _center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.progress, greaterThan(0), reason: '双击收拢态应立即开始展开');

    await settle(tester);
    expect(controller.progress, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('双击展开态 → 收拢', (tester) async {
    await pumpCanvas(tester, controller: controller);
    controller.play();
    await settle(tester);
    expect(controller.progress, 1);

    await doubleTap(tester, _center);
    await settle(tester);
    expect(controller.progress, 0, reason: '已展开时双击应反向收拢');
    expect(controller.isAnimating, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('正在收拢时双击 → 顺势转回展开', (tester) async {
    await pumpCanvas(tester, controller: controller);
    controller.play();
    await settle(tester);

    controller.close();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final mid = controller.progress;
    expect(mid, lessThan(1));
    expect(mid, greaterThan(0));

    await doubleTap(tester, _center);
    await settle(tester);
    expect(controller.progress, 1, reason: '收拢途中双击应转回展开，而不是继续收拢');
    expect(tester.takeException(), isNull);
  });

  testWidgets('双击画布空白处同样生效', (tester) async {
    // 触摸点远离牌叠：识别器用 translucent，空白处也要能命中。
    await pumpCanvas(tester, controller: controller);
    await tester.pump();

    await doubleTap(tester, _blank);
    await settle(tester);
    expect(controller.progress, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('展牌模式也能双击开合', (tester) async {
    await pumpCanvas(
      tester,
      controller: controller,
      mode: FanSpreadMode.tableSpread,
    );
    await tester.pump();

    await doubleTap(tester, _center);
    await settle(tester);
    expect(controller.progress, 1);

    await doubleTap(tester, _center);
    await settle(tester);
    expect(controller.progress, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('doubleTapToToggle = false → 双击不触发开合', (tester) async {
    var taps = 0;
    await pumpCanvas(
      tester,
      controller: controller,
      doubleTapToToggle: false,
      onDoubleTap: () => taps++,
    );
    await tester.pump();

    await doubleTap(tester, _center);
    await settle(tester);
    expect(controller.progress, 0, reason: '关掉内置切换后双击不应改变进度');
    expect(taps, 1, reason: 'onDoubleTap 与内置开关无关，关掉切换后回调仍要触发');
    expect(tester.takeException(), isNull);
  });

  testWidgets('onDoubleTap 在切换之后触发一次', (tester) async {
    var taps = 0;
    await pumpCanvas(tester, controller: controller, onDoubleTap: () => taps++);
    await tester.pump();

    await doubleTap(tester, _center);
    expect(taps, 1);
    await settle(tester);
    expect(controller.progress, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('不传 controller 时双击也能开合（像素对比）', (tester) async {
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
    // 等牌图与精灵图就绪，保证三次采样走同一条绘制路径。
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();
    final collapsed = await fingerprint();

    await doubleTap(tester, _center);
    await settle(tester);
    final spread = await fingerprint();
    expect(spread, isNot(collapsed), reason: '无 controller 时双击也应展开');

    await doubleTap(tester, _center);
    await settle(tester);
    final collapsedAgain = await fingerprint();
    expect(collapsedAgain, collapsed, reason: '再次双击应收拢回原画面');
    expect(tester.takeException(), isNull);
  });

  testWidgets('controller 绑定多个组件时，双击作用于全部组件', (tester) async {
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

    // 只双击左边那一块。
    await doubleTap(tester, const Offset(100, 150));
    await settle(tester);

    expect(controller.progress, 1);
    expect(await fingerprint(firstKey), isNot(first0));
    expect(
      await fingerprint(secondKey),
      isNot(second0),
      reason: '双击走 controller.toggle()，另一个绑定的组件也应一起展开',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('双击与拖动调角度共存：两者互不影响', (tester) async {
    double? reported;
    await pumpCanvas(
      tester,
      controller: controller,
      onFanAngleChanged: (v) => reported = v,
    );
    await tester.pump();

    // 1) 双击：展开
    await doubleTap(tester, _center);
    await settle(tester);
    expect(controller.progress, 1);

    // 2) 拖动：仍然能调整开扇角度（双击识别器没有吞掉拖动）
    final gesture = await tester.startGesture(topCardCenter());
    await gesture.moveBy(const Offset(-60, 45));
    await gesture.up();
    await tester.pump();
    expect(reported, isNotNull);
    expect(reported, isNot(220));
    expect(controller.progress, 1, reason: '拖动调角度不应影响展开进度');

    // 3) 再次双击（这次落在最顶的牌上）：收拢。
    //    收拢启动后紧接着会派发 onPanStart，不能让它把收拢又顶回展开。
    await doubleTap(tester, topCardCenter());
    await settle(tester);
    expect(controller.progress, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('单击不触发开合', (tester) async {
    await pumpCanvas(tester, controller: controller);
    await tester.pump();

    await tester.tapAt(_center);
    await settle(tester);
    expect(controller.progress, 0, reason: '只有双击才切换，单击应保持收拢');
    expect(tester.takeException(), isNull);
  });

  testWidgets('两下点击相距太远 → 不算双击', (tester) async {
    await pumpCanvas(tester, controller: controller);
    await tester.pump();

    // 两点相距 ≈354px，远超 kDoubleTapSlop（100）。
    await tapTwice(tester, const Offset(60, 60), const Offset(300, 320));
    await settle(tester);
    expect(controller.progress, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('拖动后松手不算点击，紧接着的单击不会凑成双击', (tester) async {
    await pumpCanvas(tester, controller: controller);
    await tester.pump();

    final gesture = await tester.startGesture(_center);
    await gesture.moveBy(const Offset(80, 0));
    await gesture.up();
    await tester.pump();

    await tester.tapAt(_center);
    await settle(tester);
    expect(controller.progress, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('连点三下只触发一次双击', (tester) async {
    var taps = 0;
    await pumpCanvas(tester, controller: controller, onDoubleTap: () => taps++);
    await tester.pump();

    await tester.tapAt(_center);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(_center);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(_center);
    await tester.pump();
    await settle(tester);

    expect(taps, 1, reason: '第三下应是新一次点击的起点，不能再凑出一次双击');
    expect(controller.progress, 1);
    expect(tester.takeException(), isNull);
  });
}
