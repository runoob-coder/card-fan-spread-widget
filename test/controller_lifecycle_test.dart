import 'dart:ui' as ui;

import 'package:card_fan_spread/card_fan_spread.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_card_image.dart';

/// 把组件放进有界画布里，避免无界约束干扰本文件的断言。
Widget _host(Widget child, {double top = 0}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: Stack(
        children: [
          Positioned(
            top: top,
            child: SizedBox(
              width: 400,
              height: 600,
              child: RepaintBoundary(
                child: Container(color: const Color(0xFF000000), child: child),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 采样像素指纹，用于判断某个区域是否真的在动。
Future<int> _fingerprint(WidgetTester tester, GlobalKey key) async {
  final render = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
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

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// 播放并等到动画真正结束（默认时长 1800ms，300ms 远不够）。
Future<void> _playToEnd(WidgetTester tester, CardFanSpreadController c) async {
  c.play();
  await tester.pump();
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  late ui.Image back;

  setUp(() async {
    back = await solidCardImage();
  });

  testWidgets('切换 controller 后 dispose 旧的不会收到动画通知', (tester) async {
    final oldController = CardFanSpreadController();
    final newController = CardFanSpreadController();

    Widget build(CardFanSpreadController? c) => _host(
      CardFanSpread(
        controller: c,
        cardBack: TestCardImage(back),
        autoPlay: false,
      ),
    );

    await tester.pumpWidget(build(oldController));
    await tester.pumpWidget(build(newController));

    // 用户按惯例释放不再使用的旧 controller
    oldController.dispose();

    // 驱动新动画到完成：若旧 controller 的 status 监听器泄漏，
    // 会向已 dispose 的 ChangeNotifier 发通知 → debug 断言抛错。
    newController.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
    expect(newController.progress, 1);
  });

  testWidgets('controller 绑定的组件卸载后，controller 仍可安全使用', (tester) async {
    final controller = CardFanSpreadController();

    await tester.pumpWidget(
      _host(
        CardFanSpread(
          controller: controller,
          cardBack: TestCardImage(back),
          autoPlay: false,
        ),
      ),
    );
    await _playToEnd(tester, controller);
    expect(controller.progress, 1);

    // 组件整体卸载
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox.shrink(),
      ),
    );

    // 之后调用 controller 不应抛「dispose 后仍被使用」之类的异常
    controller.replay();
    controller.toggle();
    controller.close();
    controller.reset();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('同一 controller 绑定多个组件：命令作用于全部，卸载其一后其余仍响应', (tester) async {
    final controller = CardFanSpreadController();
    final keyA = GlobalKey();
    final keyB = GlobalKey();

    Widget spread(GlobalKey key) => RepaintBoundary(
      key: key,
      child: SizedBox(
        width: 400,
        height: 600,
        child: Container(
          color: const Color(0xFF000000),
          child: CardFanSpread(
            controller: controller,
            cardBack: TestCardImage(back),
            autoPlay: false,
          ),
        ),
      ),
    );

    Widget buildBoth() => Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(children: [spread(keyA), spread(keyB)]),
    );
    Widget buildBOnly() => Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(children: [spread(keyB)]),
    );

    await tester.pumpWidget(buildBoth());
    await _settle(tester);
    final closedA = await _fingerprint(tester, keyA);
    final closedB = await _fingerprint(tester, keyB);

    // 一条命令驱动两个组件同时展开
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.progress, 1);
    expect(
      await _fingerprint(tester, keyA),
      isNot(closedA),
      reason: '共享 controller 后，组件 A 也应展开',
    );
    expect(
      await _fingerprint(tester, keyB),
      isNot(closedB),
      reason: '共享 controller 后，组件 B 也应展开',
    );

    // 卸载先绑定的组件（历史上的「主」组件），剩下的组件必须仍能响应
    await tester.pumpWidget(buildBOnly());
    controller.replay();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.progress, 1, reason: '卸载一个组件后，controller 不应与剩余组件失联');
    expect(tester.takeException(), isNull);
  });

  testWidgets('同一 controller 的组件卸载另一个后，play/close 仍有效', (tester) async {
    final controller = CardFanSpreadController();

    Widget spread({required bool visible}) => Visibility(
      visible: visible,
      child: SizedBox(
        width: 400,
        height: 600,
        child: CardFanSpread(
          controller: controller,
          cardBack: TestCardImage(back),
          autoPlay: false,
        ),
      ),
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(children: [spread(visible: true), spread(visible: true)]),
      ),
    );
    await _playToEnd(tester, controller);
    expect(controller.progress, 1);

    // 卸载后绑定的那个（主）组件
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(children: [spread(visible: true)]),
      ),
    );

    controller.close();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.progress, 0, reason: '卸载主组件后 close 应仍然生效');

    controller.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.progress, 1, reason: '卸载主组件后 play 应仍然生效');
    expect(tester.takeException(), isNull);
  });

  testWidgets('progress / isAnimating / isOpened 在未绑定时有安全默认值', (tester) async {
    final controller = CardFanSpreadController();
    expect(controller.progress, 0);
    expect(controller.isAnimating, isFalse);
    expect(controller.isOpened, isFalse);

    // 未绑定任何组件时调用控制方法不应抛异常
    controller.play();
    controller.close();
    controller.toggle();
    controller.replay();
    controller.reset();
    expect(controller.progress, 0);
  });
}
