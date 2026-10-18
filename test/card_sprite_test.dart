import 'dart:ui' as ui;

import 'package:card_fan_spread/card_fan_spread.dart';
import 'package:card_fan_spread/src/card_layout.dart';
import 'package:card_fan_spread/src/card_sprite.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> _whiteSource() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 650, 916),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  return recorder.endRecording().toImage(650, 916);
}

/// 等一次「离屏合成 → 通知」真正落地。
///
/// 分两步：`pump` 推进 fake 时钟（换档计时器是 fake Timer，runAsync 期间不推进），
/// 再 `runAsync` 给真实的 `Picture.toImage` 留出时间。
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(kSpriteSettleDelay * 2);
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
}

void main() {
  testWidgets('精灵图按目标尺寸与 dpr 合成一次', (tester) async {
    final source = await tester.runAsync(_whiteSource);

    final cache = CardSpriteCache();
    addTearDown(cache.dispose);
    var readyCount = 0;

    cache.update(
      images: <ui.Image>[source!],
      width: 100,
      height: 140,
      dpr: 2,
      shadowColor: kCardShadowColor,
      onReady: () => readyCount++,
    );

    // 合成是异步的（离屏渲染后取位图）。
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    await tester.pump();

    // 每张源图生成两个变体：带阴影 / 不带阴影
    expect(cache.sprites.length, 1, reason: '应为该源图生成带阴影的精灵图');
    expect(cache.flatSprites.length, 1, reason: '同时生成不带阴影的精灵图');
    expect(cache.version, 2, reason: '两个变体都应合成出来');
    expect(
      readyCount,
      greaterThanOrEqualTo(1),
      reason: '至少要通知宿主一次重绘（同一轮里的多次通知会被合并）',
    );
    final sprite = cache.sprites[source]!;
    // (100 + 16*2) * 2  x  (140 + 16*2) * 2
    expect(sprite.width, 264);
    expect(sprite.height, 344);

    // 幂等：同尺寸再次调用不会重复生成
    cache.update(
      images: <ui.Image>[source],
      width: 100,
      height: 140,
      dpr: 2,
      shadowColor: kCardShadowColor,
      onReady: () => readyCount++,
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    expect(cache.version, 2, reason: '同尺寸不应重复合成');
    expect(cache.sprites[source], same(sprite));

    // 尺寸变化后置换新生成（已有精灵只是尺寸过期：等尺寸稳定后才换档）
    cache.update(
      images: <ui.Image>[source],
      width: 160,
      height: 224,
      dpr: 2,
      shadowColor: kCardShadowColor,
      onReady: () => readyCount++,
    );
    await _settle(tester);
    expect(cache.version, 4, reason: '两个变体都应按新尺寸重新合成');
    expect(cache.sprites[source], isNot(same(sprite)));
    expect(cache.sprites.length, 1);
    expect(cache.flatSprites.length, 1);
  });

  testWidgets('阴影：浓度够但不重，且不被裁切', (tester) async {
    final source = await tester.runAsync(_whiteSource);

    final cache = CardSpriteCache();
    addTearDown(cache.dispose);
    cache.update(
      images: <ui.Image>[source!],
      width: 100,
      height: 140,
      dpr: 2,
      shadowColor: kCardShadowColor,
      onReady: () {},
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );

    final sprite = cache.sprites[source]!;
    final data = (await tester.runAsync(
      () => sprite.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
    ))!;
    final bytes = data.buffer.asUint8List();
    final w = sprite.width;
    final h = sprite.height;
    int alphaAt(int x, int y) => bytes[(y * w + x) * 4 + 3];

    final pad = (kCardSpritePadding * 2).round();
    final cardW = (100 * 2).round();
    final cardH = (140 * 2).round();

    // 牌区域都不透明
    expect(alphaAt(w ~/ 2, pad + 70), 255, reason: '牌面区域应完全不透明');

    // 扫描牌区四周的留白：阴影应该铺开且完整
    var maxShadowAlpha = 0;
    for (var x = 0; x < w; x += 3) {
      for (final y in [pad - 1, pad + cardH + 2]) {
        if (y >= 0 && y < h) {
          final a = alphaAt(x, y);
          if (a > maxShadowAlpha) maxShadowAlpha = a;
        }
      }
    }
    for (var y = 0; y < h; y += 3) {
      for (final x in [pad - 1, pad + cardW + 2]) {
        if (x >= 0 && x < w) {
          final a = alphaAt(x, y);
          if (a > maxShadowAlpha) maxShadowAlpha = a;
        }
      }
    }

    expect(
      maxShadowAlpha,
      allOf(greaterThanOrEqualTo(15), lessThanOrEqualTo(90)),
      reason: '单张牌的投影应在 15~90/255 之间（当前 $maxShadowAlpha）',
    );

    // 精灵最外圈必须完全透明：否则高斯模糊会被裁出硬边
    expect(alphaAt(1, 1), 0, reason: '阴影扩散被留白裁切了');
    expect(alphaAt(w - 2, h - 2), 0, reason: '阴影扩散被留白裁切了');
  });

  testWidgets('无阴影变体确实是纯牌面（用于重合的牌）', (tester) async {
    final source = await tester.runAsync(_whiteSource);

    final cache = CardSpriteCache();
    addTearDown(cache.dispose);
    cache.update(
      images: <ui.Image>[source!],
      width: 100,
      height: 140,
      dpr: 2,
      shadowColor: kCardShadowColor,
      onReady: () {},
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );

    final flat = cache.flatSprites[source]!;
    final data = (await tester.runAsync(
      () => flat.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
    ))!;
    final bytes = data.buffer.asUint8List();
    var maxAlpha = 0;
    for (var i = 3; i < bytes.length; i += 4) {
      if (bytes[i] > maxAlpha) maxAlpha = bytes[i];
    }
    // 只有牌本身不透明，四周没有任何投影或描边
    expect(maxAlpha, 255);
    final pad = (kCardSpritePadding * 2).round();
    expect(bytes[(pad - 1) * 4 + 3], 0, reason: '留白区域必须完全透明');
    expect(bytes[((flat.height - 2) * flat.width + flat.width - 2) * 4 + 3], 0);
  });

  testWidgets('显存预算超限时自动下调 dpr', (tester) async {
    final source = await tester.runAsync(_whiteSource);

    final cache = CardSpriteCache();
    addTearDown(cache.dispose);
    // 8 个源图、预算恰好等于 dpr=1 的总量 → dpr 被钳到 1.0。
    // 单份精灵像素数 = (100+16*2) * (140+16*2)，每源图 2 变体，4 字节/像素。
    final budgetAtDpr1 = 8 * 2 * 132 * 172 * 4;
    cache.update(
      images: List<ui.Image>.filled(8, source!),
      width: 100,
      height: 140,
      dpr: 2,
      shadowColor: kCardShadowColor,
      onReady: () {},
      maxMemoryBytes: budgetAtDpr1,
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );

    final sprite = cache.sprites[source]!;
    expect(sprite.width, 132, reason: '预算内 dpr 应为 1.0：(100+16*2)*1');
    expect(sprite.height, 172);
  });

  testWidgets('牌尺寸连续变化时不重新合成，稳定后才换一次档', (tester) async {
    final source = await tester.runAsync(_whiteSource);

    final cache = CardSpriteCache();
    addTearDown(cache.dispose);
    var readyCount = 0;

    Future<void> atHeight(double h) async {
      cache.update(
        images: <ui.Image>[source!],
        width: h * 0.7,
        height: h,
        dpr: 2,
        shadowColor: kCardShadowColor,
        onReady: () => readyCount++,
      );
      // 只等 30ms（远小于 kSpriteSettleDelay）：模拟拖动时每帧都在改尺寸。
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
    }

    // 起步：牌高 600，合成出第一批精灵。
    await atHeight(600);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    final initial = cache.sprites[source]!;
    final initialFlat = cache.flatSprites[source]!;
    expect(cache.version, 2, reason: '两个变体都应合成出来');

    // 一次「拖动开扇角度」等价于牌高从 600 连续变到 300（每步 20px，16 步）。
    // 尺寸一直在动，一次都不该重新合成——旧精灵按精确尺寸缩放继续用。
    for (var h = 580.0; h >= 300; h -= 20) {
      await atHeight(h);
    }
    expect(cache.version, 2, reason: '拖动过程中（尺寸持续变化）不应重新合成精灵');
    expect(cache.sprites[source], same(initial));

    // 尺寸稳定下来之后才换一次档（而不是把上面 16 步逐档补回来）。
    await _settle(tester);
    expect(cache.version, 4, reason: '稳定后只换一次档（两个变体）');
    expect(cache.sprites[source], isNot(same(initial)));
    expect(cache.flatSprites[source], isNot(same(initialFlat)));

    // 反向拖回去（牌变大）同样是「动的过程中不换、稳定后换一次」。
    final settled = cache.sprites[source]!;
    for (var h = 320.0; h <= 600; h += 20) {
      await atHeight(h);
    }
    expect(cache.sprites[source], same(settled), reason: '反向拖动过程中同样不换档');
    await _settle(tester);
    expect(cache.version, 6);
    expect(cache.sprites[source], isNot(same(settled)));

    // 档位内的微小变化（滞回区间）完全不重新合成。
    final before = cache.version;
    await atHeight(590);
    await atHeight(580);
    await _settle(tester);
    expect(
      cache.version,
      before,
      reason:
          '滞回区间内的尺寸变化应复用现有精灵（实际合成了 '
          '${cache.version - before} 次）',
    );
    expect(readyCount, greaterThanOrEqualTo(1));
  });

  testWidgets('不再使用的源图会被自动淘汰', (tester) async {
    final source = await tester.runAsync(_whiteSource);
    final other = await tester.runAsync(_whiteSource);

    final cache = CardSpriteCache();
    addTearDown(cache.dispose);
    cache.update(
      images: <ui.Image>[source!, other!],
      width: 100,
      height: 140,
      dpr: 2,
      shadowColor: kCardShadowColor,
      onReady: () {},
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    expect(cache.sprites.length, 2);
    expect(cache.flatSprites.length, 2);

    // 只留一张源图（相当于关掉牌面 / 换牌背 / 减少牌数）
    cache.update(
      images: <ui.Image>[source],
      width: 100,
      height: 140,
      dpr: 2,
      shadowColor: kCardShadowColor,
      onReady: () {},
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    expect(cache.sprites.length, 1, reason: '不再使用的源图应被淘汰');
    expect(cache.flatSprites.length, 1);
    expect(cache.sprites.containsKey(source), isTrue);
  });

  testWidgets('源图被 evict 后释放对应精灵，重新出现会再合成', (tester) async {
    final source = await tester.runAsync(_whiteSource);

    final cache = CardSpriteCache();
    addTearDown(cache.dispose);
    cache.update(
      images: <ui.Image>[source!],
      width: 100,
      height: 140,
      dpr: 2,
      shadowColor: kCardShadowColor,
      onReady: () {},
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    final sprite = cache.sprites[source]!;
    expect(cache.sprites.length, 1);

    cache.evict(source);
    expect(cache.sprites, isEmpty, reason: 'evict 后应释放带阴影的精灵');
    expect(cache.flatSprites, isEmpty, reason: 'evict 后应释放纯净的精灵');

    // 同一源图再次出现时重新合成
    var readyCount = 0;
    cache.update(
      images: <ui.Image>[source],
      width: 100,
      height: 140,
      dpr: 2,
      shadowColor: kCardShadowColor,
      onReady: () => readyCount++,
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    expect(cache.version, greaterThan(2), reason: '应重新合成两个变体');
    expect(readyCount, greaterThanOrEqualTo(1));
    expect(cache.sprites[source], isNot(same(sprite)));
    expect(cache.sprites.length, 1);
  });

  testWidgets('源图很多时合成分批推进（不一次性排空队列）', (tester) async {
    final sources = <ui.Image>[];
    await tester.runAsync(() async {
      for (var i = 0; i < 20; i++) {
        sources.add(await _whiteSource());
      }
    });

    final cache = CardSpriteCache();
    addTearDown(cache.dispose);
    cache.update(
      images: sources,
      width: 100,
      height: 140,
      dpr: 2,
      shadowColor: kCardShadowColor,
      onReady: () {},
    );

    // 一次只启动一批：剩下的一多半还压在队列里，而不是同时丢给栅格线程
    //（牌背 → 牌面切换时 53 张源图若一次排完，画面会直接卡住）。
    expect(cache.pendingJobCount, 20 - kSpriteMaxConcurrentSources);

    // 分批推进靠「让出一个事件循环回合」，fake-async 下要推进时钟才会继续，
    // 所以这里用 pump 而不是 runAsync（与真实 app 里帧持续推进等价）。
    for (var i = 0; i < 60 && cache.sprites.length < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
    }
    expect(cache.sprites.length, 20);
    expect(cache.flatSprites.length, 20);
    expect(cache.pendingJobCount, 0);
  });

  testWidgets('两个变体成对发布：不会出现只有装饰层的中间态', (tester) async {
    final sources = <ui.Image>[];
    await tester.runAsync(() async {
      for (var i = 0; i < 6; i++) {
        sources.add(await _whiteSource());
      }
    });

    final cache = CardSpriteCache();
    addTearDown(cache.dispose);
    cache.update(
      images: sources,
      width: 100,
      height: 140,
      dpr: 2,
      shadowColor: kCardShadowColor,
      onReady: () {},
    );

    // 每一时刻都必须是「要么两个变体都在、要么都不在」：先只到装饰层时，重合的
    // 牌会走「只剩装饰层」那条分支，而装饰层强度随重合度趋近 0，整叠牌会整张
    // 变透明（闪一下）。所以两个变体放在同一个任务里一起发布。
    await tester.runAsync(() async {
      for (var i = 0; i < 5000 && cache.version < sources.length * 2; i++) {
        expect(
          cache.sprites.length,
          cache.flatSprites.length,
          reason: '两个变体必须成对发布（已发布 ${cache.version ~/ 2} 张）',
        );
        await Future<void>.delayed(Duration.zero);
      }
    });
    expect(cache.version, sources.length * 2);
    expect(cache.sprites.length, sources.length);
    expect(cache.flatSprites.length, sources.length);
  });

  testWidgets('一次完整的开扇角度拖动：拖的过程中零重合成，松手后只换一次档', (tester) async {
    final source = await tester.runAsync(_whiteSource);

    final cache = CardSpriteCache();
    addTearDown(cache.dispose);

    /// 真实布局下「把开扇角度从 20° 拖到上限」时牌高的变化序列。
    List<double> heightsOf(FanSpreadMode mode) {
      final maxAngle = switch (mode) {
        FanSpreadMode.sFan => kMaxSFanAngle,
        FanSpreadMode.twoHandFan => kMaxTwoHandFanAngle,
        _ => kMaxFanAngle,
      };
      return <double>[
        for (var a = 20.0; a <= maxAngle; a += 5)
          CardSpreadLayout.compute(
            mode: mode,
            canvas: const Size(640, 640),
            cardCount: 52,
            fanAngle: a,
            fanTierRatio: 0,
            fanPivotX: kDefaultFanPivotX,
            fanPivotLift: kDefaultFanPivotLift,
            tableStepRatio: 0.09,
            tableArcLift: -0.6,
            direction: SpreadDirection.leftToRight,
          ).cardHeight,
      ];
    }

    Future<void> atHeight(double h) async {
      cache.update(
        images: <ui.Image>[source!],
        width: h * 0.7,
        height: h,
        dpr: 2,
        shadowColor: kCardShadowColor,
        onReady: () {},
      );
      // 30ms：模拟手指每帧改一次角度（远小于 kSpriteSettleDelay）。
      await tester.pump(const Duration(milliseconds: 30));
    }

    for (final mode in <FanSpreadMode>[
      FanSpreadMode.fan,
      FanSpreadMode.sFan,
      FanSpreadMode.twoHandFan,
    ]) {
      final heights = heightsOf(mode);
      expect(heights.length, greaterThan(1));

      // 起步：按第一个角度合成出第一批精灵。
      await atHeight(heights.first);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      final started = cache.version;
      final firstSprite = cache.sprites[source]!;

      // 拖：牌尺寸一直在变。
      for (final h in heights.skip(1)) {
        await atHeight(h);
      }
      expect(
        cache.version,
        started,
        reason:
            '${mode.name}：拖动过程中不应重新合成精灵（实际多了 '
            '${cache.version - started} 次）',
      );
      expect(cache.sprites[source], same(firstSprite));

      // 松手：尺寸稳定后才换一次档。
      await _settle(tester);
      expect(
        cache.version,
        started + 2,
        reason:
            '${mode.name}：松手后应只换一次档（两个变体），实际多了 '
            '${cache.version - started} 次',
      );
      expect(cache.sprites[source], isNot(same(firstSprite)));
    }
  });
}
