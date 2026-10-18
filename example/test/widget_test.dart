import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:card_fan_spread/card_fan_spread.dart';
import 'package:card_fan_spread/src/card_layout.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/widgets.dart' as w;
import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

Future<void> _pumpDemo(WidgetTester tester) async {
  // 默认语言为英文，显式固定 locale 以保证断言稳定。
  await tester.binding.setLocale('en', 'US');
  await tester.pumpWidget(const CardFanSpreadExampleApp());
  // Ticker 首帧不积累时间，先空推进一帧，再推进动画时长。
  await tester.pump();
  await tester.pump(const Duration(seconds: 3));
}

/// 推进一段时间（先空推进一帧让 Ticker 起跑）。
Future<void> _advance(WidgetTester tester, Duration d) async {
  await tester.pump();
  await tester.pump(d);
}

/// 拖动控制面板里某个滑块。
///
/// 控制面板是限高可滚动的（`maxHeight: 视口 × 0.45`），靠下的滑块在默认的
/// 800×600 测试窗口里落在视口外；直接 `drag` 不会报错、只是打空（值不变），
/// 所以必须先滚进视口再拖。
Future<void> _dragSlider(
  WidgetTester tester,
  String label,
  Offset delta,
) async {
  final slider = find.descendant(
    of: find.widgetWithText(Row, label),
    matching: find.byType(Slider),
  );
  expect(slider, findsOneWidget);
  await tester.ensureVisible(slider);
  await tester.pump();
  await tester.drag(slider, delta);
}

/// 牌区画布的屏幕位置与尺寸。
///
/// [CardFanSpread] 用 LayoutBuilder 的 `constraints.biggest` 当画布尺寸
/// （`_boundedCanvas`），所以直接问那个 RenderBox 的约束就拿到精确值，不用去猜
/// 视口里 Expanded 分到了多少高度。
ui.Rect _cardCanvas(WidgetTester tester) {
  w.RenderBox? box;
  void visit(w.Element e) {
    if (box != null) return;
    if (e is w.RenderObjectElement) {
      box = e.renderObject as w.RenderBox;
      return;
    }
    e.visitChildElements(visit);
  }

  tester.element(find.byType(CardFanSpread)).visitChildElements(visit);
  final found = box!;
  return found.localToGlobal(ui.Offset.zero) & found.constraints.biggest;
}

/// 完全展开状态下第 [i] 张牌在画布里的中心（与画家同一套数学）。
ui.Offset _cardCenter(FanSpreadLayout fan, int i) {
  final angle = fan.targetAngles[i];
  final local = ui.Offset(
    fan.cardWidth / 2 - fan.pivotOffset.dx,
    fan.cardHeight / 2 - fan.pivotOffset.dy,
  );
  return fan.origin +
      ui.Offset(
        local.dx * math.cos(angle) - local.dy * math.sin(angle),
        local.dx * math.sin(angle) + local.dy * math.cos(angle),
      );
}

/// 「扇形角度」滑块（Slider / Row 都来自 material_ui）。
Slider _fanAngleSlider(WidgetTester tester) {
  expect(find.widgetWithText(Row, 'Fan Angle'), findsOneWidget);
  return tester.widget<Slider>(
    find.descendant(
      of: find.widgetWithText(Row, 'Fan Angle'),
      matching: find.byType(Slider),
    ),
  );
}

/// 分步把滑块拖到最右端。
///
/// 不能用 `tester.drag(slider, Offset(400, 0))`：Slider 在按下那一刻就把值
/// 跳到指针位置（滑块中点 ≈ 量程一半），之后单次大位移只再挪一点，实测
/// 0~220 的滑块从默认 220 出发反而落在 120。逐段推进才真正拖到顶。
Future<void> _dragSliderToEnd(WidgetTester tester, String label) async {
  final finder = find.descendant(
    of: find.widgetWithText(Row, label),
    matching: find.byType(Slider),
  );
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pump();
  final box = tester.renderObject<RenderBox>(finder);
  final center = box.localToGlobal(box.size.center(Offset.zero));
  final gesture = await tester.startGesture(center);
  await tester.pump();
  for (var i = 1; i <= 8; i++) {
    await gesture.moveTo(center + Offset(box.size.width / 8 * i, 0));
    await tester.pump();
  }
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('示例首页可以完成一次展牌动画', (tester) async {
    await _pumpDemo(tester);
    expect(find.text('Card Fan by noob-coder'), findsOneWidget);
    expect(find.byType(CardFanSpread), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('可以切换到开扇、调角度，并把方向改成 rightToLeft', (tester) async {
    await _pumpDemo(tester);

    await tester.tap(find.text('Open Fan'));
    await _advance(tester, const Duration(seconds: 3));
    expect(tester.takeException(), isNull);

    final angleBefore = tester
        .widget<CardFanSpread>(find.byType(CardFanSpread))
        .fanAngle;
    await _dragSlider(tester, 'Fan Angle', const Offset(-120, 0));
    await _advance(tester, const Duration(seconds: 3));
    // 往左拖 → 角度变小（原来只断言「不报错」，拖动打空也会通过）。
    expect(
      tester.widget<CardFanSpread>(find.byType(CardFanSpread)).fanAngle,
      lessThan(angleBefore),
    );
    expect(tester.takeException(), isNull);

    // 反开扇不再是独立模式：同一个开扇模式把 direction 切到 rightToLeft。
    // 方向现在排在参数第一位，前面的滑块拖动会把面板滚下去，先滚回来再点。
    await tester.ensureVisible(find.text('Right → Left'));
    await tester.pump();
    await tester.tap(find.text('Right → Left'));
    await _advance(tester, const Duration(seconds: 3));
    expect(
      tester.widget<CardFanSpread>(find.byType(CardFanSpread)).direction,
      SpreadDirection.rightToLeft,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('拖动顶牌调开扇角度时，底部角度滑块同步跟随', (tester) async {
    await _pumpDemo(tester);
    await tester.tap(find.text('Open Fan'));
    await _advance(tester, const Duration(seconds: 3));

    final spread = tester.widget<CardFanSpread>(find.byType(CardFanSpread));
    final before = _fanAngleSlider(tester).value;
    // 前置条件：滑块显示的就是当前生效值。
    expect(before, spread.fanAngle);

    // 顶牌 = drawOrder 里最后画的那张；用与组件同一套布局算出它的位置。
    final canvas = _cardCanvas(tester);
    final layout = CardSpreadLayout.compute(
      mode: spread.mode,
      canvas: canvas.size,
      cardCount: spread.cardCount,
      fanAngle: spread.fanAngle,
      fanTierRatio: spread.fanTierRatio,
      fanPivotX: spread.fanPivotX,
      fanPivotLift: spread.fanPivotLift,
      tableStepRatio: spread.tableStepRatio,
      tableArcLift: spread.tableArcLift,
      direction: spread.direction,
    ) as FanSpreadLayout;
    final top = layout.drawOrder.last;
    final center = _cardCenter(layout, top);
    // 普通开扇所有牌钉在同一个枢轴上：绕它顺时针划一道弧 = 张开。
    final pivot = layout.origin;
    final radius = (center - pivot).distance;
    final startRad = math.atan2(center.dx - pivot.dx, -(center.dy - pivot.dy));

    final gesture = await tester.startGesture(canvas.topLeft + center);
    await tester.pump();
    for (final deg in const <double>[6, 12, 18, 24, 30]) {
      final a = startRad + deg * math.pi / 180;
      await gesture.moveTo(
        canvas.topLeft + pivot + ui.Offset(math.sin(a), -math.cos(a)) * radius,
      );
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();

    // 关键：顶牌拖动只写 ValueNotifier，不 setState 整页，
    // 滑块必须自己订阅它才跟得上。
    final after = _fanAngleSlider(tester).value;
    expect(after, isNot(before), reason: '拖动顶牌后「扇形角度」滑块应同步变化（实际仍为 $before）');
    expect(
      after,
      closeTo(
        tester.widget<CardFanSpread>(find.byType(CardFanSpread)).fanAngle,
        1e-6,
      ),
      reason: '滑块显示值应与生效的开扇角度一致',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('开扇可叠加双层错落（大扇）', (tester) async {
    await _pumpDemo(tester);

    // 展牌模式下没有「双层错落」滑块，开扇模式下才有。
    expect(find.widgetWithText(Row, 'Tier Offset'), findsNothing);

    await tester.tap(find.text('Open Fan'));
    await _advance(tester, const Duration(seconds: 3));

    final spread = tester.widget<CardFanSpread>(find.byType(CardFanSpread));
    expect(spread.mode, FanSpreadMode.fan);
    expect(spread.fanTierRatio, 0);

    expect(find.widgetWithText(Row, 'Tier Offset'), findsOneWidget);
    await _dragSlider(tester, 'Tier Offset', const Offset(120, 0));
    await _advance(tester, const Duration(seconds: 3));

    final after = tester.widget<CardFanSpread>(find.byType(CardFanSpread));
    expect(after.fanTierRatio, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('可以切换到 S 扇：能拖顶牌调角度、没有双层错落 / 枢轴', (tester) async {
    await _pumpDemo(tester);

    await tester.tap(find.text('S Fan'));
    await _advance(tester, const Duration(seconds: 3));

    final spread = tester.widget<CardFanSpread>(find.byType(CardFanSpread));
    expect(spread.mode, FanSpreadMode.sFan);
    // 切到 S 扇直接张开到最大（脊线切向的总摆幅能卷过一整圈）。
    expect(spread.fanAngle, kMaxSFanAngle);
    // 反弯幅度仍由开扇角度控制；顶牌在牌带末端，但朝向同样跟着 fanAngle 走，
    // 所以拖动能调角度，提示也照给。
    expect(find.text('You can also drag the top card'), findsOneWidget);
    expect(find.widgetWithText(Row, 'Fan Angle'), findsOneWidget);
    // 双层错落只属于开扇 / 反开扇，枢轴参数对 S 扇无效。
    expect(find.widgetWithText(Row, 'Tier Offset'), findsNothing);
    expect(find.widgetWithText(Row, 'Pivot Position'), findsNothing);
    // S 扇的 fanAngle 是脊线切向的总摆幅，能卷过一整圈：滑块上限 540°。
    expect(_fanAngleSlider(tester).max, kMaxSFanAngle);
    expect(tester.takeException(), isNull);
  });

  testWidgets('S 扇切回开扇：开扇回到初始 220°、上限仍是 360°', (tester) async {
    await _pumpDemo(tester);

    await tester.tap(find.text('S Fan'));
    await _advance(tester, const Duration(seconds: 3));
    expect(_fanAngleSlider(tester).max, kMaxSFanAngle);

    await _dragSliderToEnd(tester, 'Fan Angle');
    expect(
      tester.widget<CardFanSpread>(find.byType(CardFanSpread)).fanAngle,
      kMaxSFanAngle,
    );

    // 上一步把控制面板滚下去了，模式 chip 要先滚回可见再点。
    await tester.ensureVisible(find.text('Open Fan'));
    await tester.pump();
    await tester.tap(find.text('Open Fan'));
    await _advance(tester, const Duration(seconds: 3));

    final spread = tester.widget<CardFanSpread>(find.byType(CardFanSpread));
    expect(spread.mode, FanSpreadMode.fan);
    // 开扇切回来按自己的初始角度 220° 张开（不是继承 S 扇的 540° 再去钳）。
    expect(spread.fanAngle, 220);
    expect(_fanAngleSlider(tester).max, kMaxFanAngle);
    expect(tester.takeException(), isNull);
  });

  testWidgets('S 扇拖到最大后切回展牌：残留的 540° 不触发构造断言', (tester) async {
    await _pumpDemo(tester);

    await tester.tap(find.text('S Fan'));
    await _advance(tester, const Duration(seconds: 3));
    await _dragSliderToEnd(tester, 'Fan Angle');
    expect(
      tester.widget<CardFanSpread>(find.byType(CardFanSpread)).fanAngle,
      kMaxSFanAngle,
    );

    // 上一步把控制面板滚下去了，模式 chip 要先滚回可见再点。
    await tester.ensureVisible(find.text('Table Spread'));
    await tester.pump();
    await tester.tap(find.text('Table Spread'));
    await _advance(tester, const Duration(seconds: 3));

    final spread = tester.widget<CardFanSpread>(find.byType(CardFanSpread));
    expect(spread.mode, FanSpreadMode.tableSpread);
    // 展牌不消费 fanAngle，但构造断言要求它落在 0~360°：
    // 切过来时残留的 540° 必须被钳回，否则会抛断言。
    expect(spread.fanAngle, lessThanOrEqualTo(kMaxFanAngle));
    expect(tester.takeException(), isNull);
  });

  testWidgets('可以切换到双手开扇：枢轴可调、没有双层错落、角度封顶 220°', (tester) async {
    await _pumpDemo(tester);

    // 先把开扇的角度拖到高位（> 220°），用来验证切到双手开扇时会被钳回去。
    await tester.tap(find.text('Open Fan'));
    await _advance(tester, const Duration(seconds: 3));
    await _dragSliderToEnd(tester, 'Fan Angle');
    expect(
      tester.widget<CardFanSpread>(find.byType(CardFanSpread)).fanAngle,
      greaterThan(kMaxTwoHandFanAngle),
    );

    // 上一步把控制面板滚下去了，模式 chip 要先滚回可见再点
    //（控制面板限高可滚动，直接 tap 会打空）。
    await tester.ensureVisible(find.text('Two-Hand Fan'));
    await tester.pump();
    await tester.tap(find.text('Two-Hand Fan'));
    await _advance(tester, const Duration(seconds: 3));

    final spread = tester.widget<CardFanSpread>(find.byType(CardFanSpread));
    expect(spread.mode, FanSpreadMode.twoHandFan);
    // 每一边封顶 220°：切过来时角度被钳住，滑块上限同样是 220°。
    expect(spread.fanAngle, kMaxTwoHandFanAngle);
    expect(_fanAngleSlider(tester).max, kMaxTwoHandFanAngle);
    // 参数与开扇 / 反开扇一致：角度与枢轴都在（S 扇才没有枢轴）。
    expect(find.widgetWithText(Row, 'Pivot Position'), findsOneWidget);
    expect(find.widgetWithText(Row, 'Pivot Depth'), findsOneWidget);
    expect(find.text('You can also drag the top card'), findsOneWidget);
    // 双层错落只属于开扇 / 反开扇。
    expect(find.widgetWithText(Row, 'Tier Offset'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('可以切换牌背', (tester) async {
    await _pumpDemo(tester);

    // 牌背选择器：8 张缩略图（Rider Back + 7 张 Bicycle 牌背）
    final picker = find.byType(ListView);
    expect(picker, findsOneWidget);
    expect(find.byType(Image), findsWidgets);

    final spread = tester.widget<CardFanSpread>(find.byType(CardFanSpread));
    final before = _assetOf(spread.cardBack!);

    // 点击最后一张缩略图
    final lastThumb = find.byType(Image).last;
    await tester.tap(lastThumb);
    await _advance(tester, const Duration(milliseconds: 300));

    final after = _assetOf(
      tester.widget<CardFanSpread>(find.byType(CardFanSpread)).cardBack!,
    );
    expect(after, 'assets/back/462.webp');
    expect(after, isNot(before));
    expect(tester.takeException(), isNull);
  });

  testWidgets('牌面模式下随机展示 52 张，并可重新洗牌', (tester) async {
    await _pumpDemo(tester);

    // 默认是牌背模式，先切到牌面
    await tester.tap(find.text('Face'));
    await _advance(tester, const Duration(seconds: 3));
    expect(tester.takeException(), isNull);

    final spread = tester.widget<CardFanSpread>(find.byType(CardFanSpread));
    expect(spread.showFace, isTrue);
    final faces = spread.cardFaces!;
    expect(faces.length, 52);
    // 每个 provider 都来自示例素材
    for (final f in faces) {
      expect(_assetOf(f), startsWith('assets/rider_cards/'));
    }
    // 随机分配 → 不应全部相同
    expect(
      _assetOf(faces.first) != _assetOf(faces[1]) ||
          _assetOf(faces.first) != _assetOf(faces[10]),
      isTrue,
    );

    final firstBefore = _assetOf(faces.first);
    await tester.tap(find.text('Reshuffle'));
    await _advance(tester, const Duration(milliseconds: 300));
    final facesAfter = tester
        .widget<CardFanSpread>(find.byType(CardFanSpread))
        .cardFaces!;
    expect(facesAfter.length, 52);
    // 重新随机后对象身份应发生变化
    expect(identical(facesAfter, faces), isFalse);
    expect(_assetOf(facesAfter.first), isA<String>());
    expect(firstBefore, isA<String>());
    expect(tester.takeException(), isNull);
  });

  testWidgets('展牌支持切换叠压方向、上翘可为负值', (tester) async {
    await _pumpDemo(tester);

    // 默认左→右；切到右→左应重播且不报错
    await tester.tap(find.text('Right → Left'));
    await _advance(tester, const Duration(seconds: 3));
    final spread = tester.widget<CardFanSpread>(find.byType(CardFanSpread));
    expect(spread.direction, SpreadDirection.rightToLeft);

    // 默认 tableArcLift = -0.6（两端下翘）；拖到正值 → 标签翻转为「两端上翘」
    expect(find.widgetWithText(Row, 'Both Ends Down'), findsOneWidget);
    await _dragSlider(tester, 'Both Ends Down', const Offset(400, 0));
    await _advance(tester, const Duration(seconds: 3));
    expect(find.text('Both Ends Up'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('牌面 / 牌背 与播放控制可用', (tester) async {
    await _pumpDemo(tester);

    await tester.tap(find.text('Face'));
    await _advance(tester, const Duration(seconds: 3));

    await tester.tap(find.text('Close'));
    await _advance(tester, const Duration(seconds: 3));

    await tester.tap(find.text('Play'));
    await _advance(tester, const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('跟随系统语言切换为中文', (tester) async {
    tester.binding.platformDispatcher.localesTestValue = const [
      Locale('zh', 'CN'),
    ];
    await tester.pumpWidget(const CardFanSpreadExampleApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // 中文文案出现，英文文案不再出现。
    expect(find.text('展牌'), findsWidgets);
    expect(find.text('Table Spread'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Material 本地化来自 material_ui，而不是英文兜底', (tester) async {
    await _pumpDemo(tester);

    // 若 localizationsDelegates 里放的是 package:flutter_localizations 的旧版
    // delegate，它的类型与 material_ui 的 MaterialLocalizations 对不上，
    // MaterialApp 会静默回退到 DefaultMaterialLocalizations（恒为英文）。
    final context = tester.element(find.byType(CardFanSpread));
    expect(
      MaterialLocalizations.of(context),
      isNot(isA<DefaultMaterialLocalizations>()),
    );
  });
}

/// 从 AssetImage 中取出资源路径。
String _assetOf(ImageProvider provider) {
  expect(provider, isA<AssetImage>());
  return (provider as AssetImage).assetName;
}
