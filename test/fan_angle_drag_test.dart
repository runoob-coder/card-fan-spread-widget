import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:card_fan_spread/card_fan_spread.dart';
import 'package:card_fan_spread/src/card_layout.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_card_image.dart';

const Size _canvas = Size(400, 600);

/// 与组件相同的布局参数（展牌参数对开扇无影响，但接口需要）。
FanSpreadLayout _fanLayout({
  required FanSpreadMode mode,
  required double fanAngle,
  SpreadDirection direction = SpreadDirection.leftToRight,
  int cardCount = 52,
}) {
  return CardSpreadLayout.compute(
    mode: mode,
    direction: direction,
    canvas: _canvas,
    cardCount: cardCount,
    fanAngle: fanAngle,
    fanTierRatio: 0,
    fanPivotX: kDefaultFanPivotX,
    fanPivotLift: kDefaultFanPivotLift,
    tableStepRatio: 0.09,
    tableArcLift: -0.6,
  ) as FanSpreadLayout;
}

/// 第 [i] 张牌在进度 [progress] 下的画布中心（与画家同一套数学）。
Offset _cardCenter(
  FanSpreadLayout fan,
  int i,
  double progress, {
  double stagger = 0.55,
  Curve curve = Curves.easeOutCubic,
}) {
  final p = fan.cardProgressAt(i, progress, stagger: stagger, curve: curve);
  final angle = fan.targetAngles[i] * p;
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

/// 受控宿主：把回调角度回填给 fanAngle（模拟真实调用方）。
class _ControlledFan extends StatefulWidget {
  const _ControlledFan({
    required this.mode,
    required this.card,
    required this.controller,
    this.withCallback = true,
    this.withDirectionCallback = true,
    this.direction = SpreadDirection.leftToRight,
    this.fanAngle = 220,
    this.onSuggestedDirection,
  });

  final FanSpreadMode mode;
  final ui.Image card;
  final CardFanSpreadController controller;
  final bool withCallback;

  /// false = 模拟「只关心角度、不接方向回调」的调用方。
  final bool withDirectionCallback;
  final SpreadDirection direction;
  final double fanAngle;

  /// 组件建议的方向（换向）会在这里回出来，便于断言。
  final ValueChanged<SpreadDirection>? onSuggestedDirection;

  @override
  State<_ControlledFan> createState() => _ControlledFanState();
}

class _ControlledFanState extends State<_ControlledFan> {
  late double fanAngle = widget.fanAngle;
  late SpreadDirection direction = widget.direction;

  /// provider 只在 initState 建一次：`TestCardImage` 没有 `==`，每次 build 新建
  /// 会被组件当成「换了牌背」而整体重解析（回收旧 clone、重新合成精灵），
  /// 动画跑起来时一帧一次，既浪费也会放大图片句柄的竞态。
  late final ImageProvider _backProvider = TestCardImage(widget.card);

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
              mode: widget.mode,
              direction: direction,
              controller: widget.controller,
              cardBack: _backProvider,
              fanAngle: fanAngle,
              shadowColor: const Color(0x00000000),
              autoPlay: false,
              onFanAngleChanged: widget.withCallback
                  ? (v) => setState(() => fanAngle = v)
                  : null,
              onDirectionChanged: widget.withDirectionCallback
                  ? (d) {
                      widget.onSuggestedDirection?.call(d);
                      setState(() => direction = d);
                    }
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  late ui.Image whiteCard;
  late CardFanSpreadController controller;

  setUp(() async {
    whiteCard = await solidCardImage(const ui.Color(0xFFFFFFFF));
    controller = CardFanSpreadController();
  });

  /// 沿以枢轴为圆心、半径 [radius] 的圆弧生成触点序列（角度制，顺时针递增）。
  List<Offset> clockwiseArc(
    FanSpreadLayout fan, {
    required double radius,
    required double fromDeg,
    required double toDeg,
    required double stepDeg,
  }) {
    final points = <Offset>[];
    for (
      var a = fromDeg;
      stepDeg >= 0 ? a <= toDeg : a >= toDeg;
      a += stepDeg
    ) {
      final r = a * math.pi / 180;
      points.add(
        fan.origin + Offset(radius * math.sin(r), -radius * math.cos(r)),
      );
    }
    return points;
  }

  /// 从顶牌中心起，依次经过 [path] 中的每个触点拖动，返回全部回调角度。
  Future<List<double>> dragAlongPath(
    WidgetTester tester, {
    required FanSpreadMode mode,
    required List<Offset> Function(FanSpreadLayout fan) path,
    double startFanAngle = 220,
  }) async {
    final reports = <double>[];
    await tester.pumpWidget(
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
                fanAngle: startFanAngle,
                shadowColor: const Color(0x00000000),
                autoPlay: false,
                onFanAngleChanged: reports.add,
              ),
            ),
          ),
        ),
      ),
    );
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.progress, 1);

    final fan = _fanLayout(mode: mode, fanAngle: startFanAngle);
    final top = _cardCenter(fan, fan.drawOrder.last, 1);
    final gesture = await tester.startGesture(top);
    for (final p in path(fan)) {
      await gesture.moveTo(p);
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();
    return reports;
  }

  /// 完全展开后从顶牌中心出发拖动，返回回调收到的最晚角度。
  Future<double?> dragFromTopCard(
    WidgetTester tester, {
    required FanSpreadMode mode,
    SpreadDirection direction = SpreadDirection.leftToRight,
    required Offset dragBy,
    double startFanAngle = 220,
  }) async {
    double? reported;
    await tester.pumpWidget(
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
                direction: direction,
                controller: controller,
                cardBack: TestCardImage(whiteCard),
                fanAngle: startFanAngle,
                shadowColor: const Color(0x00000000),
                autoPlay: false,
                onFanAngleChanged: (v) => reported = v,
              ),
            ),
          ),
        ),
      ),
    );
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.progress, 1);

    final fan = _fanLayout(
      mode: mode,
      direction: direction,
      fanAngle: startFanAngle,
    );
    final top = _cardCenter(fan, fan.drawOrder.last, 1);
    final gesture = await tester.startGesture(top);
    await gesture.moveBy(dragBy);
    await gesture.up();
    await tester.pump();
    return reported;
  }

  testWidgets('开扇：拖动最顶的牌向外 → 角度变大', (tester) async {
    // 顶牌在 +110°（右下），继续顺时针（左下方向）拖动 → 开扇角变大。
    final reported = await dragFromTopCard(
      tester,
      mode: FanSpreadMode.fan,
      dragBy: const Offset(-40, 30),
    );
    expect(reported, isNotNull);
    expect(reported!, greaterThan(220));
    expect(reported, lessThanOrEqualTo(kMaxFanAngle));
    expect(tester.takeException(), isNull);
  });

  testWidgets('开扇：拖动最顶的牌向内 → 角度变小', (tester) async {
    // 反方向（右上）拖动 → 开扇角变小。
    final reported = await dragFromTopCard(
      tester,
      mode: FanSpreadMode.fan,
      dragBy: const Offset(40, -30),
    );
    expect(reported, isNotNull);
    expect(reported!, lessThan(220));
    expect(reported, greaterThanOrEqualTo(kMinFanAngle));
  });

  testWidgets('开扇 rightToLeft：方向镜像，拖动最顶的牌向外 → 角度变大', (tester) async {
    // rightToLeft 的顶牌在 -110°（左下），向右下拖动 → 开扇角变大。
    final reported = await dragFromTopCard(
      tester,
      mode: FanSpreadMode.fan,
      direction: SpreadDirection.rightToLeft,
      dragBy: const Offset(40, 30),
    );
    expect(reported, isNotNull);
    expect(reported!, greaterThan(220));
    expect(reported, lessThanOrEqualTo(kMaxFanAngle));
  });

  testWidgets('开扇收拢态往另一侧拖 → 自动换向，同一个手势继续张开', (tester) async {
    final suggested = <SpreadDirection>[];
    await tester.pumpWidget(
      _ControlledFan(
        mode: FanSpreadMode.fan,
        card: whiteCard,
        controller: controller,
        direction: SpreadDirection.leftToRight,
        fanAngle: kMinFanAngle,
        onSuggestedDirection: suggested.add,
      ),
    );
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    final fan = _fanLayout(mode: FanSpreadMode.fan, fanAngle: kMinFanAngle);
    // 收拢角下整叠牌重合，抓顶牌就是抓这叠。
    final top = _cardCenter(fan, fan.drawOrder.last, 1);
    final gesture = await tester.startGesture(top);
    await tester.pump();
    // 逆时针把顶牌带向左侧 → 建议 rightToLeft（顶牌跟着手指走）。
    await gesture.moveBy(const Offset(-60, 45));
    await tester.pump();
    expect(suggested, <SpreadDirection>[SpreadDirection.rightToLeft]);
    // 换向后同一个手势继续往同方向拖 → 扇形朝另一侧张开（角度变大）。
    await gesture.moveBy(const Offset(-60, 45));
    await tester.pump();
    final spread = tester.widget<CardFanSpread>(find.byType(CardFanSpread));
    expect(spread.direction, SpreadDirection.rightToLeft);
    expect(spread.fanAngle, greaterThan(kMinFanAngle));
    await gesture.up();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('开扇收拢态 rightToLeft 往另一侧拖 → 换回 leftToRight', (tester) async {
    final suggested = <SpreadDirection>[];
    await tester.pumpWidget(
      _ControlledFan(
        mode: FanSpreadMode.fan,
        card: whiteCard,
        controller: controller,
        direction: SpreadDirection.rightToLeft,
        fanAngle: kMinFanAngle,
        onSuggestedDirection: suggested.add,
      ),
    );
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    final fan = _fanLayout(mode: FanSpreadMode.fan, fanAngle: kMinFanAngle);
    final gesture = await tester.startGesture(
      _cardCenter(fan, fan.drawOrder.last, 1),
    );
    await tester.pump();
    // 顺时针把顶牌带向右侧 → 建议 leftToRight。
    await gesture.moveBy(const Offset(60, -45));
    await tester.pump();
    expect(suggested, <SpreadDirection>[SpreadDirection.leftToRight]);
    await gesture.up();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('已经张开的扇拖着调角度不会换向', (tester) async {
    final suggested = <SpreadDirection>[];
    await tester.pumpWidget(
      _ControlledFan(
        mode: FanSpreadMode.fan,
        card: whiteCard,
        controller: controller,
        direction: SpreadDirection.leftToRight,
        fanAngle: 220,
        onSuggestedDirection: suggested.add,
      ),
    );
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    final fan = _fanLayout(mode: FanSpreadMode.fan, fanAngle: 220);
    final gesture = await tester.startGesture(
      _cardCenter(fan, fan.drawOrder.last, 1),
    );
    await tester.pump();
    // 一路往里拖到 0°（反向），只调角度，不换向。
    await gesture.moveBy(const Offset(60, -45));
    await tester.pump();
    await gesture.moveBy(const Offset(60, -45));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(suggested, isEmpty);
    expect(
      tester.widget<CardFanSpread>(find.byType(CardFanSpread)).direction,
      SpreadDirection.leftToRight,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('开扇拖到 0° 后继续推 → 换向并接着张开（不再卡住）', (tester) async {
    final suggested = <SpreadDirection>[];
    await tester.pumpWidget(
      _ControlledFan(
        mode: FanSpreadMode.fan,
        card: whiteCard,
        controller: controller,
        direction: SpreadDirection.leftToRight,
        fanAngle: 220,
        onSuggestedDirection: suggested.add,
      ),
    );
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    final fan = _fanLayout(mode: FanSpreadMode.fan, fanAngle: 220);
    // 拖动绕的是**起拖时冻结的枢轴**（开扇下 = 布局原点），所以走圆弧而不是
    // 直线位移：直线挪到一定距离后转角会越来越小，永远收不到 0°。
    final pivot = fan.origin;
    final top = _cardCenter(fan, fan.drawOrder.last, 1);
    final radius = (top - pivot).distance;
    final gesture = await tester.startGesture(top);
    await tester.pump();
    // 从顶牌所在的 110° 一路顺时针扫到 -60°：前 110° 把扇子收到底，
    // 之后继续推就越过收拢角 —— 这里必须换向，否则会被钳在 0 拖不动。
    for (var deg = 100.0; deg >= -60; deg -= 10) {
      final r = deg * math.pi / 180;
      await gesture.moveTo(
        pivot + Offset(radius * math.sin(r), -radius * math.cos(r)),
      );
      await tester.pump();
    }
    // 只换了一次向，而且扇子接着往另一侧张开（不是钳在 0 不动）。
    expect(suggested, <SpreadDirection>[SpreadDirection.rightToLeft]);
    final spread = tester.widget<CardFanSpread>(find.byType(CardFanSpread));
    expect(spread.direction, SpreadDirection.rightToLeft);
    expect(spread.fanAngle, greaterThan(kMinFanAngle));
    await gesture.up();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('画面收拢但 fanAngle 仍是 220° 时，往另一侧拖也能换向', (tester) async {
    // 典型场景：按过「收拢」——进度归零、画面回到一叠，但 fanAngle 还是 220°。
    // 这时方向必须由手势直接定，否则得转满 110° 才换向（手感就是拖不动）。
    final suggested = <SpreadDirection>[];
    await tester.pumpWidget(
      _ControlledFan(
        mode: FanSpreadMode.fan,
        card: whiteCard,
        controller: controller,
        direction: SpreadDirection.leftToRight,
        fanAngle: 220,
        onSuggestedDirection: suggested.add,
      ),
    );
    // 宿主 autoPlay = false：进度停在 0，画面是一叠重合的牌，fanAngle 仍是 220。
    await tester.pump();
    expect(controller.progress, 0);

    final collapsed = _fanLayout(mode: FanSpreadMode.fan, fanAngle: 220);
    final top = _cardCenter(collapsed, collapsed.drawOrder.last, 0);
    final gesture = await tester.startGesture(top);
    await tester.pump();
    // 往左（逆时针）带顶牌 → 换到 rightToLeft，并从收拢角跟着手指长出去。
    for (var k = 0; k < 3; k++) {
      await gesture.moveBy(const Offset(-40, 30));
      await tester.pump();
    }
    expect(suggested, <SpreadDirection>[SpreadDirection.rightToLeft]);
    final spread = tester.widget<CardFanSpread>(find.byType(CardFanSpread));
    expect(spread.direction, SpreadDirection.rightToLeft);
    expect(spread.fanAngle, greaterThan(kMinFanAngle));
    expect(spread.fanAngle, lessThanOrEqualTo(kMaxFanAngle));
    await gesture.up();
    // 收拢态起拖会顺势 forward()，把动画跑完再收尾：别把在途的帧 / 精灵合成
    // 留给后面的用例（否则下一个用例的 takeException 会收到 ImageHandle 重复
    // dispose 的断言）。
    await tester.pump(const Duration(seconds: 3));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('不接 onDirectionChanged：收拢态往另一侧拖也能自己换向张开', (tester) async {
    // 真实调用方：角度受控回写，但没接方向回调。此前这种用法下收拢态往另一侧
    // 拖会被钳在 0° 完全没反应（方向建议无处可去）。现在组件自己翻「生效方向」。
    await tester.pumpWidget(
      _ControlledFan(
        mode: FanSpreadMode.fan,
        card: whiteCard,
        controller: controller,
        direction: SpreadDirection.leftToRight,
        fanAngle: 220,
        withCallback: true,
        withDirectionCallback: false, // 只关心角度，不接方向回调
      ),
    );
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.progress, 1);

    // 第一次拖动：绕冻结枢轴顺时针扫 110°，把扇子收到底（fanAngle → 0）。
    final fan = _fanLayout(mode: FanSpreadMode.fan, fanAngle: 220);
    final pivot = fan.origin;
    final top = _cardCenter(fan, fan.drawOrder.last, 1);
    final radius = (top - pivot).distance;
    var gesture = await tester.startGesture(top);
    await tester.pump();
    for (var deg = 110.0; deg >= 0; deg -= 10) {
      final r = deg * math.pi / 180;
      await gesture.moveTo(
        pivot + Offset(radius * math.sin(r), -radius * math.cos(r)),
      );
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();
    var spread = tester.widget<CardFanSpread>(find.byType(CardFanSpread));
    expect(spread.fanAngle, closeTo(kMinFanAngle, 1e-6));

    // 第二次拖动：松手后像真实用户那样直接往左拖。
    final collapsed = _fanLayout(mode: FanSpreadMode.fan, fanAngle: 0);
    gesture = await tester.startGesture(
      _cardCenter(collapsed, collapsed.drawOrder.last, 1),
    );
    await tester.pump();
    for (var k = 0; k < 5; k++) {
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();
    // 生效方向被组件自己翻过来了：扇子朝另一侧张开，而不是钳在 0° 不动。
    spread = tester.widget<CardFanSpread>(find.byType(CardFanSpread));
    expect(spread.fanAngle, greaterThan(kMinFanAngle));
    // 调用方的 direction 参数没被动过（没人接管，回写无从谈起）。
    expect(spread.direction, SpreadDirection.leftToRight);
    expect(tester.takeException(), isNull);
  });

  testWidgets('往复拖动：顶牌每穿过一次收拢角就换一次向', (tester) async {
    final suggested = <SpreadDirection>[];
    await tester.pumpWidget(
      _ControlledFan(
        mode: FanSpreadMode.fan,
        card: whiteCard,
        controller: controller,
        direction: SpreadDirection.leftToRight,
        fanAngle: 220,
        onSuggestedDirection: suggested.add,
      ),
    );
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.progress, 1);

    final fan = _fanLayout(mode: FanSpreadMode.fan, fanAngle: 220);
    final pivot = fan.origin;
    final top = _cardCenter(fan, fan.drawOrder.last, 1);
    final radius = (top - pivot).distance;
    // 绕着起拖时冻结的枢轴来回扫：每穿过一次收拢角（竖立位置）就翻一次向，
    // 扇形始终跟着手指那一侧张开。
    final gesture = await tester.startGesture(top);
    await tester.pump();
    var current = 100.0;
    for (final target in <double>[-120, 120, -120]) {
      while (current != target) {
        current += target > current ? 10 : -10;
        final r = current * math.pi / 180;
        await gesture.moveTo(
          pivot + Offset(radius * math.sin(r), -radius * math.cos(r)),
        );
        await tester.pump();
      }
    }
    await gesture.up();
    await tester.pump();
    // 三次穿越 → 三次换向，方向来回翻转，而不是只有第一次有效。
    expect(suggested, <SpreadDirection>[
      SpreadDirection.rightToLeft,
      SpreadDirection.leftToRight,
      SpreadDirection.rightToLeft,
    ]);
    final spread = tester.widget<CardFanSpread>(find.byType(CardFanSpread));
    expect(spread.direction, SpreadDirection.rightToLeft);
    expect(spread.fanAngle, greaterThan(kMinFanAngle));
    expect(tester.takeException(), isNull);
  });

  testWidgets('触摸没落在最顶的牌上 → 不触发', (tester) async {
    double? reported;
    await tester.pumpWidget(
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
                controller: controller,
                cardBack: TestCardImage(whiteCard),
                fanAngle: 220,
                shadowColor: const Color(0x00000000),
                autoPlay: false,
                onFanAngleChanged: (v) => reported = v,
              ),
            ),
          ),
        ),
      ),
    );
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    // 左上角空白处（远离扇形）
    final gesture = await tester.startGesture(const Offset(20, 20));
    await gesture.moveBy(const Offset(-30, 40));
    await gesture.up();
    await tester.pump();
    expect(reported, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('展牌模式不使用 fanAngle → 拖动不触发', (tester) async {
    double? reported;
    await tester.pumpWidget(
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
                fanAngle: 220,
                shadowColor: const Color(0x00000000),
                autoPlay: false,
                onFanAngleChanged: (v) => reported = v,
              ),
            ),
          ),
        ),
      ),
    );
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    final gesture = await tester.startGesture(const Offset(200, 300));
    await gesture.moveBy(const Offset(50, 50));
    await gesture.up();
    await tester.pump();
    expect(reported, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('角度被限制在 0~360 度', (tester) async {
    // 大幅向外拖 → 上限
    final opened = await dragFromTopCard(
      tester,
      mode: FanSpreadMode.fan,
      dragBy: const Offset(-400, 300),
    );
    expect(opened, kMaxFanAngle);

    // 大幅向「左上方」拖，让指针摆到枢轴左侧 → 下限
    final closed = await dragFromTopCard(
      tester,
      mode: FanSpreadMode.fan,
      dragBy: const Offset(-400, -500),
    );
    expect(closed, kMinFanAngle);
  });

  testWidgets('收拢态（动画未播放）拖动顶牌也能调整角度', (tester) async {
    double? reported;
    await tester.pumpWidget(
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
                controller: controller,
                cardBack: TestCardImage(whiteCard),
                fanAngle: 220,
                shadowColor: const Color(0x00000000),
                autoPlay: false,
                onFanAngleChanged: (v) => reported = v,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    // 不播放：progress = 0，整叠牌竖立在中间
    final fan = _fanLayout(mode: FanSpreadMode.fan, fanAngle: 220);
    final top = _cardCenter(fan, fan.drawOrder.last, 0);
    final gesture = await tester.startGesture(top);
    // 收拢时顶牌在枢轴正上方（角度 0），顺时针（右下）拖动 → 开扇。
    await gesture.moveBy(const Offset(40, 30));
    await gesture.up();
    await tester.pump();
    expect(reported, isNotNull);
    expect(reported!, greaterThan(220));
  });

  testWidgets('动画进行到一半时，命中判定用牌的当前位置', (tester) async {
    double? reported;
    await tester.pumpWidget(
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
                controller: controller,
                cardBack: TestCardImage(whiteCard),
                fanAngle: 220,
                shadowColor: const Color(0x00000000),
                autoPlay: false,
                onFanAngleChanged: (v) => reported = v,
              ),
            ),
          ),
        ),
      ),
    );
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900)); // progress ≈ 0.5
    final progress = controller.progress;
    expect(progress, greaterThan(0.2));
    expect(progress, lessThan(0.8));

    final fan = _fanLayout(mode: FanSpreadMode.fan, fanAngle: 220);
    final top = _cardCenter(fan, fan.drawOrder.last, progress);
    final gesture = await tester.startGesture(top);
    await gesture.moveBy(const Offset(-40, 30));
    await gesture.up();
    await tester.pump();
    expect(reported, isNotNull, reason: '半开状态下顶牌位置应与画面一致，否则命中判定会失效');
    expect(tester.takeException(), isNull);
  });

  testWidgets('受控回填：回调角度写回 fanAngle 后正常渲染', (tester) async {
    await tester.pumpWidget(
      _ControlledFan(
        mode: FanSpreadMode.fan,
        card: whiteCard,
        controller: controller,
      ),
    );
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    final fan = _fanLayout(mode: FanSpreadMode.fan, fanAngle: 220);
    final top = _cardCenter(fan, fan.drawOrder.last, 1);
    final gesture = await tester.startGesture(top);
    await gesture.moveBy(const Offset(-60, 45));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final state = tester.state<State>(find.byType(CardFanSpread));
    expect(state, isNotNull);
    expect(find.byType(CardFanSpread), findsOneWidget);
    expect(controller.progress, 1, reason: '拖动角度不应影响展开进度');
    expect(tester.takeException(), isNull);
  });

  testWidgets('不传 onFanAngleChanged 时拖动无副作用', (tester) async {
    await tester.pumpWidget(
      _ControlledFan(
        mode: FanSpreadMode.fan,
        card: whiteCard,
        controller: controller,
        withCallback: false,
      ),
    );
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    final fan = _fanLayout(mode: FanSpreadMode.fan, fanAngle: 220);
    final top = _cardCenter(fan, fan.drawOrder.last, 1);
    final gesture = await tester.startGesture(top);
    await gesture.moveBy(const Offset(-60, 45));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('跨过 ±180 不连续点后角度连续，不在 20 / 360 之间闪现', (tester) async {
    // 绕枢轴顺时针拖 260°（远超 180°）：指针角度在枢轴正下方会从 +179° 突变到
    // -179°，若用「当前角 - 起始角」直接相减，累计旋转过半圈后增量符号会翻转，
    // 表现为开扇角在 20° 与 360° 两个临界值之间来回跳变。
    final reports = await dragAlongPath(
      tester,
      mode: FanSpreadMode.fan,
      path: (fan) =>
          clockwiseArc(fan, radius: 150, fromDeg: 110, toDeg: 370, stepDeg: 20),
    );

    expect(reports.length, greaterThan(8));
    for (var i = 1; i < reports.length; i++) {
      final jump = (reports[i] - reports[i - 1]).abs();
      expect(
        jump,
        lessThan(90),
        reason:
            '第 $i 步角度跳变 ${jump.toStringAsFixed(1)}°：'
            '${reports[i - 1]} → ${reports[i]}，'
            '说明跨过 ±180° 时增量被翻转（临界值闪现）',
      );
    }
    for (final v in reports) {
      expect(v, inInclusiveRange(kMinFanAngle, kMaxFanAngle));
    }
    expect(reports.last, kMaxFanAngle);
    expect(tester.takeException(), isNull);
  });

  testWidgets('拖到上限 360 后反向拖动立刻响应（累加器已回写）', (tester) async {
    // 先顺时针拖过上限（此时回调已被钳到 360），再反向拖 40°：
    // 若累加器不回写被钳掉的部分，需要「补回」越界的量才会有反应。
    final fan = _fanLayout(mode: FanSpreadMode.fan, fanAngle: 220);
    final forward = clockwiseArc(
      fan,
      radius: 150,
      fromDeg: 110,
      toDeg: 370,
      stepDeg: 20,
    );
    final back = <Offset>[
      for (var a = 350; a >= 310; a -= 20)
        fan.origin +
            Offset(
              150 * math.sin(a * math.pi / 180),
              -150 * math.cos(a * math.pi / 180),
            ),
    ];

    final reports = await dragAlongPath(
      tester,
      mode: FanSpreadMode.fan,
      path: (_) => <Offset>[...forward, ...back],
    );
    expect(
      reports.last,
      lessThan(kMaxFanAngle),
      reason: '拖过上限后反向拖动应立即变小，实际停在 ${reports.last}',
    );
    expect(reports.last, greaterThanOrEqualTo(kMinFanAngle));
    expect(tester.takeException(), isNull);
  });

  testWidgets('收拢态拖动最顶的牌 → 同时播放展开动画', (tester) async {
    double? reported;
    await tester.pumpWidget(
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
                controller: controller,
                cardBack: TestCardImage(whiteCard),
                fanAngle: 220,
                shadowColor: const Color(0x00000000),
                autoPlay: false,
                onFanAngleChanged: (v) => reported = v,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(controller.progress, 0);

    final fan = _fanLayout(mode: FanSpreadMode.fan, fanAngle: 220);
    final top = _cardCenter(fan, fan.drawOrder.last, 0);
    final gesture = await tester.startGesture(top);
    await gesture.moveBy(const Offset(40, 30));
    await gesture.up();
    // Ticker 首帧不积累时间：先空推进一帧，再推进时长。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      controller.progress,
      greaterThan(0),
      reason: '收拢态拖动最顶的牌应同时把牌堆展开，而不只是改角度',
    );
    expect(reported, isNotNull);

    await tester.pump(const Duration(seconds: 3));
    expect(controller.progress, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('正在收拢时拖动最顶的牌 → 顺势转为展开', (tester) async {
    double? reported;
    await tester.pumpWidget(
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
                controller: controller,
                cardBack: TestCardImage(whiteCard),
                fanAngle: 220,
                shadowColor: const Color(0x00000000),
                autoPlay: false,
                onFanAngleChanged: (v) => reported = v,
              ),
            ),
          ),
        ),
      ),
    );
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.progress, 1);

    controller.close();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final midProgress = controller.progress;
    expect(midProgress, lessThan(1));
    expect(midProgress, greaterThan(0));

    final fan = _fanLayout(mode: FanSpreadMode.fan, fanAngle: 220);
    final top = _cardCenter(fan, fan.drawOrder.last, midProgress);
    final gesture = await tester.startGesture(top);
    await gesture.moveBy(const Offset(40, 30));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.progress, 1, reason: '拖动正在收拢的牌应转为展开');
    // 角度调整与展开动画应同时生效
    expect(reported, isNotNull);
    expect(reported, isNot(220));
    expect(tester.takeException(), isNull);
  });

  testWidgets('拖动非顶牌位置 → 不播放展开动画', (tester) async {
    double? reported;
    await tester.pumpWidget(
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
                controller: controller,
                cardBack: TestCardImage(whiteCard),
                fanAngle: 220,
                shadowColor: const Color(0x00000000),
                autoPlay: false,
                onFanAngleChanged: (v) => reported = v,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // 左上角空白处
    final gesture = await tester.startGesture(const Offset(20, 20));
    await gesture.moveBy(const Offset(40, 30));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    expect(controller.progress, 0, reason: '没落在最顶的牌上不应展开');
    expect(reported, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('展牌模式拖动最顶的牌 → 跟手开合，不播放动画', (tester) async {
    double? reported;
    await tester.pumpWidget(
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
                fanAngle: 220,
                shadowColor: const Color(0x00000000),
                autoPlay: false,
                onFanAngleChanged: (v) => reported = v,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final gesture = await tester.startGesture(const Offset(200, 300));
    await gesture.moveBy(const Offset(40, 30));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    expect(reported, isNull, reason: '展牌模式不使用 fanAngle，不应回调角度');
    expect(controller.isAnimating, isFalse, reason: '拖动是跟手定位进度，不是播放展开动画');
    expect(controller.progress, greaterThan(0), reason: '拖到哪儿就摊到哪儿');
    // 松手停在原地：再等 3 秒也不会自己播完。
    final held = controller.progress;
    await tester.pump(const Duration(seconds: 3));
    expect(controller.progress, held);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tableDragToSpread = false → 展牌拖动不响应', (tester) async {
    double? reported;
    await tester.pumpWidget(
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
                fanAngle: 220,
                shadowColor: const Color(0x00000000),
                autoPlay: false,
                tableDragToSpread: false,
                onFanAngleChanged: (v) => reported = v,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final gesture = await tester.startGesture(const Offset(200, 300));
    await gesture.moveBy(const Offset(40, 30));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    expect(controller.progress, 0, reason: '关掉跟手开合后，展牌拖动完全不响应');
    expect(reported, isNull);
    expect(tester.takeException(), isNull);
  });

  test('fanAngle = 0 时所有牌目标角为 0，且牌仍收敛在画布内', () {
    for (final canvas in <Size>[const Size(400, 600), const Size(1000, 400)]) {
      final layout = CardSpreadLayout.compute(
        mode: FanSpreadMode.fan,
        canvas: canvas,
        cardCount: 52,
        fanAngle: 0,
        fanTierRatio: 0,
        fanPivotX: kDefaultFanPivotX,
        fanPivotLift: kDefaultFanPivotLift,
        tableStepRatio: 0.09,
        tableArcLift: -0.6,
        direction: SpreadDirection.leftToRight,
      ) as FanSpreadLayout;
      // 目标角全为 0 → 展开后仍是一叠完全重合的牌（即收拢状态）
      for (final a in layout.targetAngles) {
        expect(a, 0, reason: 'fanAngle = 0 时每张牌的目标角都应为 0');
      }
      expect(layout.cardWidth, lessThanOrEqualTo(canvas.width));
      expect(layout.cardHeight, lessThanOrEqualTo(canvas.height));
      expect(layout.cardWidth, greaterThan(0));
    }
  });

  testWidgets('fanAngle = 0 时，展开态与收拢态画面完全一致', (tester) async {
    final boundaryKey = GlobalKey();

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
              width: _canvas.width,
              height: _canvas.height,
              child: Container(
                color: const Color(0xFF000000),
                child: CardFanSpread(
                  controller: controller,
                  cardBack: TestCardImage(whiteCard),
                  fanAngle: 0,
                  shadowColor: const Color(0x00000000),
                  autoPlay: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // 等图片与精灵图就绪，保证两次采样走同一条绘制路径
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final collapsed = await fingerprint();

    controller.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.progress, 1);
    final spread = await fingerprint();

    expect(spread, collapsed, reason: 'fanAngle = 0 时展开后画面应与收拢态逐像素一致');
    expect(tester.takeException(), isNull);
  });

  testWidgets('反向跨过 ±180 后角度同样连续（收拢方向）', (tester) async {
    // 逆时针绕 260°：跨过不连续点后应稳定停在 20°，而不是跳回 360。
    final reports = await dragAlongPath(
      tester,
      mode: FanSpreadMode.fan,
      path: (fan) => clockwiseArc(
        fan,
        radius: 150,
        fromDeg: 110,
        toDeg: -150,
        stepDeg: -20,
      ),
    );
    expect(reports.length, greaterThan(8));
    for (var i = 1; i < reports.length; i++) {
      final jump = (reports[i] - reports[i - 1]).abs();
      expect(
        jump,
        lessThan(90),
        reason: '第 $i 步角度跳变 ${jump.toStringAsFixed(1)}°',
      );
    }
    // 继续逆时针越过了收拢角：换向之后朝另一侧接着张开，而不是被钳在 0°。
    expect(reports.last, greaterThan(kMinFanAngle));
    expect(tester.takeException(), isNull);
  });
}
