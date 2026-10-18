import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:card_fan_spread/card_fan_spread.dart';
import 'package:card_fan_spread/src/card_layout.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_card_image.dart';

const Size _canvas = Size(400, 600);

FanSpreadLayout _sFanLayout({
  double fanAngle = 240,
  int cardCount = 53,
  Size canvas = _canvas,
  double tierRatio = 0,
  SpreadDirection direction = SpreadDirection.leftToRight,
}) {
  return CardSpreadLayout.compute(
    mode: FanSpreadMode.sFan,
    direction: direction,
    canvas: canvas,
    cardCount: cardCount,
    fanAngle: fanAngle,
    fanTierRatio: tierRatio,
    fanPivotX: kDefaultFanPivotX,
    fanPivotLift: kDefaultFanPivotLift,
    tableStepRatio: 0.09,
    tableArcLift: -0.6,
  ) as FanSpreadLayout;
}

/// 第 [i] 张牌在进度 [p] 时的画布中心（与画家同一套变换）。
Offset _cardCenter(FanSpreadLayout layout, int i, double p) {
  final angle = layout.targetAngles[i] * p;
  final pivot = layout.origin + layout.pivotOffsets[i] * p;
  final local = Offset(
    layout.cardWidth / 2 - layout.pivotOffset.dx,
    layout.cardHeight / 2 - layout.pivotOffset.dy,
  );
  return pivot +
      Offset(
        local.dx * math.cos(angle) - local.dy * math.sin(angle),
        local.dx * math.sin(angle) + local.dy * math.cos(angle),
      );
}

/// 第 [i] 张牌的四个角在画布中的坐标（含层间错落）。
List<Offset> _cardCorners(FanSpreadLayout layout, int i) {
  final angle = layout.targetAngles[i];
  final tier = layout.tierOffsets[i];
  final cos = math.cos(angle);
  final sin = math.sin(angle);
  return <Offset>[
    for (final corner in <Offset>[
      Offset.zero,
      Offset(layout.cardWidth, 0),
      Offset(0, layout.cardHeight),
      Offset(layout.cardWidth, layout.cardHeight),
    ])
      layout.origin +
          layout.pivotOffsets[i] +
          Offset(
            (corner.dx - layout.pivotOffset.dx) * cos -
                (corner.dy - layout.pivotOffset.dy - tier) * sin,
            (corner.dx - layout.pivotOffset.dx) * sin +
                (corner.dy - layout.pivotOffset.dy - tier) * cos,
          ),
  ];
}

Widget _app({
  required ui.Image back,
  required CardFanSpreadController controller,
  double fanAngle = 240,
  ValueChanged<double>? onFanAngleChanged,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: _canvas.width,
        height: _canvas.height,
        child: CardFanSpread(
          mode: FanSpreadMode.sFan,
          controller: controller,
          cardBack: TestCardImage(back),
          fanAngle: fanAngle,
          autoPlay: false,
          onFanAngleChanged: onFanAngleChanged,
        ),
      ),
    ),
  );
}

/// 从「最顶那张牌」起，沿它自己枢轴的圆弧掠 [sweepDeg] 度
/// （正 = 顺时针，与开扇拖动的方向定义一致）。
///
/// 试一下拖动逻辑：S 扇的顶牌枢轴不在公共原点上（沿脊线排开），
/// 触点必须绕**它自己的枢轴**划弧，才对应「牌跟着手指转」。
Future<void> _sweepTopCard(
  WidgetTester tester, {
  required double startFanAngle,
  required double sweepDeg,
}) async {
  const cardCount = 52; // 与 `_app` 用的默认值一致
  final fan = _sFanLayout(fanAngle: startFanAngle, cardCount: cardCount);
  final i = fan.drawOrder.last;
  final pivot = fan.origin + fan.pivotOffsets[i];
  final center = _cardCenter(fan, i, 1);
  final radius = (center - pivot).distance;
  final base = math.atan2(center.dx - pivot.dx, -(center.dy - pivot.dy));

  final gesture = await tester.startGesture(center);
  const steps = 10;
  for (var k = 1; k <= steps; k++) {
    final a = base + sweepDeg * math.pi / 180 * k / steps;
    await gesture.moveTo(
      pivot + Offset(radius * math.sin(a), -radius * math.cos(a)),
    );
    await tester.pump();
  }
  await gesture.up();
  await tester.pump();
}

void main() {
  late ui.Image back;

  setUpAll(() async {
    back = await solidCardImage(const ui.Color(0xFF333366));
  });

  test('S 扇：牌垂直于脊线辐射，两端朝向相同、中段反弯后转回', () {
    const fanAngle = 240.0;
    final layout = _sFanLayout(fanAngle: fanAngle);
    final n = layout.cardCount;
    final turn = fanAngle * math.pi / 180 / 2;

    // 牌垂直于脊线切向：起点切向 φ0 = Δ/2，所以首尾两张牌朝向相同。
    final endAngle = turn / 2 - math.pi / 2;
    expect(layout.targetAngles[0], closeTo(endAngle, 1e-9));
    expect(layout.targetAngles[n - 1], closeTo(endAngle, 1e-9));

    // 脊线中点（拐点）处切向摆到 φ0 − Δ，牌正好转到极值；
    // 摆开的全程就是 Δ，和脊线切向的摆幅一致（牌垂直于脊线）。
    final mid = (n - 1) ~/ 2;
    expect(layout.targetAngles[mid], closeTo(-(math.pi / 2 + turn / 2), 1e-6));

    // 「转出去再转回来」——角度先单调减、再单调增。普通开扇是单向扫过，
    // 这正是 S 扇与非 S 开扇的分水岭。
    for (var i = 1; i <= mid; i++) {
      expect(layout.targetAngles[i], lessThan(layout.targetAngles[i - 1]));
    }
    for (var i = mid + 1; i < n; i++) {
      expect(layout.targetAngles[i], greaterThan(layout.targetAngles[i - 1]));
    }
  });

  test('S 扇：脊线中段反弯（曲率符号翻转一次）', () {
    final layout = _sFanLayout();
    // 相邻枢轴连线的转向：第一段往一侧拐，最后一段往另一侧拐。
    double cross(int k) {
      final a = layout.pivotOffsets[k + 1] - layout.pivotOffsets[k];
      final b = layout.pivotOffsets[k + 2] - layout.pivotOffsets[k + 1];
      return a.dx * b.dy - a.dy * b.dx;
    }

    expect(cross(0), lessThan(0));
    expect(cross(layout.cardCount - 3), greaterThan(0));
    // 全程只翻一次向（交界处那一段可能落在中间值上，允许一次额外抖动）。
    var flips = 0;
    var last = cross(0).sign;
    for (var k = 1; k < layout.cardCount - 2; k++) {
      final value = cross(k);
      if (value.abs() < 1e-12) continue;
      if (value.sign != last) {
        flips++;
        last = value.sign;
      }
    }
    expect(flips, lessThanOrEqualTo(1), reason: 'S 形脊线应当只有一个拐点');
  });

  test('S 扇：牌心沿脊线等距排开，且随角度一起生长', () {
    final layout = _sFanLayout(fanAngle: 240);

    // 牌心严格沿脊线等距排开：两段圆弧是解析取点的，弧长按 i·step 均匀分。
    final centerSteps = <double>[
      for (var i = 1; i < layout.cardCount; i++)
        (_cardCenter(layout, i, 1) - _cardCenter(layout, i - 1, 1)).distance,
    ];
    final centerMean = centerSteps.reduce((a, b) => a + b) / centerSteps.length;
    for (final step in centerSteps) {
      expect(step, closeTo(centerMean, centerMean * 1e-6), reason: '牌心等距');
    }

    // 枢轴是牌心沿牌朝向反推 `_sFanPivotToCenter`（= 0.44 张牌）得到的，
    // 因此落在脊线的**平行曲线**上：弧的内侧被压缩、外侧被拉开，相对偏差
    // 约等于 `_sFanPivotToCenter / _sFanRadius`——半径越紧偏差越大
    // （1.4 时约 31%，1.0 时约 44%）。所以这里只守「大致均匀」，
    // 真正的视觉不变量是下一步的「重叠始终足够深、不出缝隙」。
    final steps = <double>[];
    for (var i = 1; i < layout.cardCount; i++) {
      steps.add((layout.pivotOffsets[i] - layout.pivotOffsets[i - 1]).distance);
    }
    final mean = steps.reduce((a, b) => a + b) / steps.length;
    for (final step in steps) {
      expect(step, closeTo(mean, mean * 0.5), reason: '沿脊线大致等距');
      expect(step, lessThan(layout.cardHeight * 0.5));
    }

    final span =
        (layout.pivotOffsets.last - layout.pivotOffsets.first).distance;
    expect(span, greaterThan(layout.cardHeight));

    // 角度越大，脊线越长（0° 时归零 = 完全收拢）。
    expect(
      _sFanLayout(fanAngle: 120).pivotOffsets.last.distance,
      lessThan(span),
    );
    // 收拢时所有枢轴重合成一处（整体偏移一个常量：牌竖直时枢轴在牌心下方）。
    final collapsed = _sFanLayout(fanAngle: 0);
    for (final offset in collapsed.pivotOffsets) {
      expect(offset, collapsed.pivotOffsets.first);
    }
    for (final angle in collapsed.targetAngles) {
      expect(angle, 0);
    }
  });

  test('S 扇：整条牌带 180° 旋转对称（上下两个碗一样大）', () {
    // 枢轴到牌心的距离，与布局层同一套算法。
    const centerToPivot = 0.5 + kDefaultFanPivotLift;
    for (final cardCount in <int>[52, 53]) {
      final layout = _sFanLayout(cardCount: cardCount);
      final n = layout.cardCount;
      Offset center(int i) {
        final angle = layout.targetAngles[i];
        return layout.origin +
            layout.pivotOffsets[i] +
            Offset(math.sin(angle), -math.cos(angle)) *
                (centerToPivot * layout.cardHeight);
      }

      // 旋转中心：奇数张正好是中间那张的牌心，偶数张是中间两张的中点。
      final hub = n.isOdd
          ? center((n - 1) ~/ 2)
          : (center(n ~/ 2 - 1) + center(n ~/ 2)) / 2;
      for (var i = 0; i < n; i++) {
        final j = n - 1 - i;
        // 牌心关于拐点互为 180°，牌带轮廓才能上下对称。
        expect(
          (center(i) + center(j) - hub * 2).distance,
          lessThan(1e-9),
          reason: '牌心应关于 S 的拐点 180° 对称',
        );
        // 朝向 likewise：对面的牌朝向完全相同（牌背对称，视觉上就是转过来的
        // 同一张牌），所以两个碗不只是面积相等，纹路也一致。
        expect(
          (layout.targetAngles[j] - layout.targetAngles[i]).abs(),
          lessThan(1e-9),
        );
      }
    }
  });

  test('S 扇：0° 时与「收拢」一致，展开后仍是一叠重合的牌', () {
    final layout = _sFanLayout(fanAngle: 0);
    final centers = <Offset>[
      for (var i = 0; i < layout.cardCount; i++) _cardCenter(layout, i, 1),
    ];
    for (final center in centers) {
      expect((center - centers.first).distance, lessThan(1e-9));
    }
  });

  test('S 扇：进度 0 时整叠牌从同一个枢轴出发', () {
    final layout = _sFanLayout();
    final centers = <Offset>[
      for (var i = 0; i < layout.cardCount; i++) _cardCenter(layout, i, 0),
    ];
    for (final center in centers) {
      expect((center - centers.first).distance, lessThan(1e-9));
    }
    // 逐张错峰的推进顺序与开扇一致：贴着起手位置那几张先出发，牌带末端跟上。
    expect(
      layout.cardProgressAt(0, 0.5, stagger: 0.55, curve: Curves.linear),
      greaterThan(
        layout.cardProgressAt(
          layout.cardCount - 1,
          0.5,
          stagger: 0.55,
          curve: Curves.linear,
        ),
      ),
    );
  });

  test('S 扇：整副牌始终落在画布内', () {
    for (final fanAngle in <double>[90, 240, 360]) {
      for (final canvas in <Size>[
        const Size(400, 600),
        const Size(1000, 400),
        const Size(640, 640),
      ]) {
        final layout = _sFanLayout(fanAngle: fanAngle, canvas: canvas);
        var minX = double.infinity;
        var maxX = -double.infinity;
        var minY = double.infinity;
        var maxY = -double.infinity;
        for (var i = 0; i < layout.cardCount; i++) {
          for (final p in _cardCorners(layout, i)) {
            minX = math.min(minX, p.dx);
            maxX = math.max(maxX, p.dx);
            minY = math.min(minY, p.dy);
            maxY = math.max(maxY, p.dy);
          }
        }
        expect(minX, greaterThanOrEqualTo(-0.5));
        expect(maxX, lessThanOrEqualTo(canvas.width + 0.5));
        expect(minY, greaterThanOrEqualTo(-0.5));
        expect(maxY, lessThanOrEqualTo(canvas.height + 0.5));
      }
    }
  });

  test('S 扇 rightToLeft 是 leftToRight 的水平镜像（脊线取反 + 牌序反转）', () {
    final ltr = _sFanLayout();
    final rtl = _sFanLayout(direction: SpreadDirection.rightToLeft);
    final n = ltr.cardCount;
    for (var i = 0; i < n; i++) {
      // 第 i 张落到镜像脊线的第 n−1−i 个位置上：横向取反、朝向角取反。
      expect(
        rtl.pivotOffsets[i].dx,
        closeTo(-ltr.pivotOffsets[n - 1 - i].dx, 1e-9),
      );
      expect(
        rtl.pivotOffsets[i].dy,
        closeTo(ltr.pivotOffsets[n - 1 - i].dy, 1e-9),
      );
      expect(rtl.targetAngles[i], closeTo(-ltr.targetAngles[n - 1 - i], 1e-9));
    }
    // 绘制顺序同样反序，镜像后的叠压层次才对得上。
    expect(rtl.drawOrder.first, ltr.drawOrder.last);
    expect(rtl.drawOrder.last, ltr.drawOrder.first);
    // 出牌顺序也反过来（沿脊线从起点走到末端）。
    expect(rtl.delayOf(n - 1), closeTo(ltr.delayOf(0), 1e-9));
    expect(rtl.delayOf(0), closeTo(ltr.delayOf(n - 1), 1e-9));
    // 方向要进布局指纹，否则切方向不会重排。
    expect(rtl.key, isNot(ltr.key));
  });

  test('S 扇：布局指纹随模式与角度变化（shouldRepaint 不会漏判）', () {
    final a = _sFanLayout(fanAngle: 240);
    final b = _sFanLayout(fanAngle: 300);
    final fan = CardSpreadLayout.compute(
      mode: FanSpreadMode.fan,
      canvas: _canvas,
      cardCount: 53,
      fanAngle: 240,
      fanTierRatio: 0,
      fanPivotX: kDefaultFanPivotX,
      fanPivotLift: kDefaultFanPivotLift,
      tableStepRatio: 0.09,
      tableArcLift: -0.6,
      direction: SpreadDirection.leftToRight,
    );
    expect(a.key, isNot(b.key));
    expect(a.key, isNot(fan.key));
    // 普通开扇不受新增的逐张枢轴影响：偏移全为 0。
    for (final offset in (fan as FanSpreadLayout).pivotOffsets) {
      expect(offset, Offset.zero);
    }
  });

  test('S 扇：忽略双层错落（fanTierRatio）', () {
    final plain = _sFanLayout();
    final tiered = _sFanLayout(tierRatio: 0.44);
    for (final offset in tiered.tierOffsets) {
      expect(offset, 0);
    }
    // 参数既然被忽略，布局指纹就应当一致——否则拖滑块会白重排一次。
    expect(tiered.key, plain.key);

    // 对照：开扇模式下双层错落照旧生效。
    final fan = CardSpreadLayout.compute(
      mode: FanSpreadMode.fan,
      canvas: _canvas,
      cardCount: 53,
      fanAngle: 240,
      fanTierRatio: 0.44,
      fanPivotX: kDefaultFanPivotX,
      fanPivotLift: kDefaultFanPivotLift,
      tableStepRatio: 0.09,
      tableArcLift: -0.6,
      direction: SpreadDirection.leftToRight,
    ) as FanSpreadLayout;
    expect(fan.tierOffsets[1], greaterThan(0));
  });

  testWidgets('S 扇：展开 / 收拢动画跑通且不抛异常', (tester) async {
    final controller = CardFanSpreadController();
    await tester.pumpWidget(_app(back: back, controller: controller));
    await tester.pump();
    expect(controller.progress, 0);

    controller.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.progress, 1);
    expect(tester.takeException(), isNull);

    controller.close();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.progress, 0);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('S 扇：拖动最顶的牌 → 开扇角跟着变，且不再一拖就顶到 0 / 360', (tester) async {
    final controller = CardFanSpreadController();
    final reports = <double>[];
    await tester.pumpWidget(
      _app(back: back, controller: controller, onFanAngleChanged: reports.add),
    );
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.progress, 1);

    // 顶牌在牌带末端（离枢轴 0.44 张牌高）：增益取 4 × 0.44 ≈ 1.76，也就是
    // 「手指划过的弧长」决定开扇角——绕枢轴掠 20° 只该 +35°。
    // 若改回严格几何的常数 4，这里会 +80°；在扁画布上更会十几像素就顶到 360
    // （实测 30px 直线拖动：修前 220 → 直接 360 并卡死，修后 220 → 354 全程平滑）。
    await _sweepTopCard(tester, startFanAngle: 240, sweepDeg: 20);
    expect(reports, isNotEmpty);
    expect(reports.last, closeTo(240 + 35, 8));
    expect(reports.last, lessThan(300), reason: '不能一拖就顶到上限');
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('S 扇：逆时针拖 → 开扇角变小（方向与开扇一致）', (tester) async {
    final controller = CardFanSpreadController();
    final reports = <double>[];
    await tester.pumpWidget(
      _app(back: back, controller: controller, onFanAngleChanged: reports.add),
    );
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    await _sweepTopCard(tester, startFanAngle: 240, sweepDeg: -20);
    expect(reports, isNotEmpty);
    expect(reports.last, closeTo(240 - 35, 8));
    controller.dispose();
  });

  testWidgets('S 扇：受控回填（示例工程的用法）下拖动照常跟手', (tester) async {
    // 拖动过程中 fanAngle 一路变大 → 顶牌枢轴沿脊线往前挪；指针角度是绕
    // **起拖时冻结**的枢轴测的，所以回填再多也不会把拖动带偏。
    var angle = 240.0;
    final controller = CardFanSpreadController();
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => _app(
          back: back,
          controller: controller,
          fanAngle: angle,
          onFanAngleChanged: (v) => setState(() => angle = v),
        ),
      ),
    );
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    await _sweepTopCard(tester, startFanAngle: 240, sweepDeg: 20);
    expect(angle, closeTo(275, 8));
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('S 扇：触摸没落在最顶的那张牌上 → 不调角度', (tester) async {
    final controller = CardFanSpreadController();
    final reports = <double>[];
    await tester.pumpWidget(
      _app(back: back, controller: controller, onFanAngleChanged: reports.add),
    );
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    // 牌带另一端（第一张牌）的牌心：离顶牌很远，不该被当成顶牌。
    final layout = _sFanLayout(cardCount: 52);
    final gesture = await tester.startGesture(_cardCenter(layout, 0, 1));
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(reports, isEmpty);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  test('S 扇：角度上限放宽到 540°，其余模式仍是 360°', () {
    expect(kMaxSFanAngle, 540);
    expect(kMaxFanAngle, 360);

    // S 扇的 fanAngle 是脊线切向的总摆幅，能卷过一整圈。
    // 注意：这里刻意不写 `const`——const 构造会在编译期求值，越界直接是
    // 编译错误（const_eval_throws_exception）而不是运行期断言。
    for (final angle in <double>[360, 450, kMaxSFanAngle]) {
      expect(
        () => CardFanSpread(mode: FanSpreadMode.sFan, fanAngle: angle),
        returnsNormally,
        reason: 'S 扇 $angle° 应当合法',
      );
    }
    expect(
      () =>
          CardFanSpread(mode: FanSpreadMode.sFan, fanAngle: kMaxSFanAngle + 1),
      throwsAssertionError,
    );

    // 开扇不受影响：超过一整圈没有意义（只是绕回来盖住自己），两个方向都一样。
    for (final direction in SpreadDirection.values) {
      expect(
        () => CardFanSpread(
          mode: FanSpreadMode.fan,
          direction: direction,
          fanAngle: kMaxFanAngle,
        ),
        returnsNormally,
      );
      expect(
        () => CardFanSpread(
          mode: FanSpreadMode.fan,
          direction: direction,
          fanAngle: kMaxFanAngle + 1,
        ),
        throwsAssertionError,
      );
    }
  });

  testWidgets('S 扇：拖动顶牌能一路卷到 540°（不再卡在 360°）', (tester) async {
    final controller = CardFanSpreadController();
    final reports = <double>[];
    await tester.pumpWidget(
      _app(
        back: back,
        controller: controller,
        fanAngle: 520,
        onFanAngleChanged: reports.add,
      ),
    );
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.progress, 1);

    // 绕顶牌自己的枢轴掠 40°：增益约 1.76 → 约 +70°，520 + 70 > 540，
    // 所以回调应停在 540（旧上限 360 时这里会立刻被钳死、根本到不了这么多）。
    await _sweepTopCard(tester, startFanAngle: 520, sweepDeg: 40);
    expect(reports, isNotEmpty);
    expect(reports.last, kMaxSFanAngle);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });
}
