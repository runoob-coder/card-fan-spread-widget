import 'dart:math' as math;
import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// 合成后为阴影预留的留白（逻辑像素）。
///
/// 必须大于 [kCardShadowBlur] * 3，否则高斯模糊会被裁出硬边。
const double kCardSpritePadding = 16;

/// 阴影的偏移、模糊半径与默认颜色。
///
/// 偏移刻意偏向**左下**：展牌时右侧的牌压住左边的牌，
/// 只有左下方向的投影会落在相邻牌的接缝和桌面上，右下方向的投影会被直接挡住。
///
/// 多张牌重合时阴影会层层累积（52 层 14% 也能叠成黑框），
/// 所以 [kCardShadowExtent] 之外的牌改用不带阴影的精灵（见 [_CardSpreadPainter]）。
const Offset kCardShadowOffset = Offset(-1.2, 2.4);
const double kCardShadowBlur = 5.0;
const Color kCardShadowColor = Color(0x24000000); // ~14% 黑
const double kCardBorderWidth = 0.7;
const Color kCardBorderColor = Color(0x2E000000); // ~18% 黑

/// 判定「两张牌是否已经重合到该跳过阴影」的距离阈值（逻辑像素）。
///
/// 只用于拦截真正的重合（收拢态）和动画中途极近的过渡帧；
/// 展牌的正常错位（4~7px）大于这个值，会保留投影。
const double kCardShadowExtent = 3.0;

/// 精灵图总显存预算（字节）。
///
/// 每种源图要合成两份（带阴影 / 纯净），52 张不重复牌面在平板尺寸下
/// 按 2x 合成可达 ~250MB。总估算超过预算时按比例下调 dpr
///（清晰度换内存），保证不被系统因内存压力杀掉。
///
/// 64MB 是「52 张不重复牌面仍有 ~1.35x 超采样」与「不拖垮低端设备 / Web」
/// 之间的折中；牌面少 / 卡片大的场景可以调大，见
/// [CardFanSpread.spriteMemoryBudget]。
const int kSpriteMemoryBudget = 64 * 1024 * 1024;

/// 精灵图尺寸量化步长（逻辑像素）。
///
/// 合成尺寸量化到步长的倍数：牌尺寸的小数位抖动（亚像素级）不会触发
/// 重新合成，绘制时按精确尺寸缩放，误差不超过半个步长。
const double kSpriteSizeStep = 4.0;

/// 尺寸档位阶梯的公比。
///
/// 牌尺寸**变大**时一次跳到阶梯上更高的一档（而非逐级跟着长）：
/// 一次从 300px 拖到 600px 的连续变化只换 ~5 档，而不是每 4px 换一次。
/// 往上取档意味着**过采样**（最多 15%），牌永远不会因为贴图分辨率不足而糊。
const double _spriteSizeRungRatio = 1.15;

/// 尺寸**变小**时的换档滞回系数。
///
/// 变小不影响清晰度、只影响显存占用，所以要迟钝一点：只有新尺寸比当前
/// 档位小 1/1.35 以上才降档，避免在阈值附近来回抖动导致反复合成。
const double _spriteShrinkRatio = 1.35;

/// 向上量化到 [kSpriteSizeStep] 的倍数（保证不小于原值）。
///
/// 只在「往阶梯上取档」时用：必须保证合成尺寸不低于需求，否则牌会糊。
double _ceilQuantize(double value) =>
    (value / kSpriteSizeStep).ceil() * kSpriteSizeStep;

/// 就近量化到 [kSpriteSizeStep] 的倍数。
///
/// 首次合成与降档时用：与改动前的取法一致（误差不超过半个步长，
/// 绘制时按精确尺寸缩放，肉眼不可见），避免无谓地改变既有画面的采样。
double _quantize(double value) =>
    (value / kSpriteSizeStep).round() * kSpriteSizeStep;

/// 尺寸阶梯上不低于 [value] 的那一档。
double _rungUp(double value) {
  final steps =
      math.log(math.max(value, kSpriteSizeStep) / kSpriteSizeStep) /
      math.log(_spriteSizeRungRatio);
  final k = math.max(0, steps.ceil());
  return kSpriteSizeStep * math.pow(_spriteSizeRungRatio, k);
}

/// 装饰（阴影 + 描边）随相邻牌错位距离淡入的强度：0 = 纯净，1 = 完整装饰。
///
/// 用平滑阶跃而不是硬阈值：牌距在阈值附近变化时（尤其是展开 / 收拢过程中），
/// 暗边会连续地变浓或变淡，不会突然出现或消失。
double cardDecorationAlpha(double distance) {
  if (distance <= 0) return 0;
  if (distance >= kCardShadowExtent) return 1;
  final t = distance / kCardShadowExtent;
  return t * t * (3 - 2 * t); // smoothstep
}

/// 牌尺寸停止变化后，才把「旧尺寸精灵换成新尺寸」的等待时长。
///
/// 拖动开扇角度 / 拖滑块时牌的尺寸是**连续**变化的（布局按内容包围盒自适应
/// 缩放，一次开合牌高能变 2 倍）。旧实现一跨过尺寸档位就立刻重新合成，于是一次
/// 拖动会触发 3~8 轮 ×（源图数 × 2）次离屏渲染；52 张不重复牌面时一轮就是
/// 上百次 `Picture.toImage`（实测 8 源图 / 16 精灵 ≈ 92ms，按此折算 53 源图
/// ≈ 600ms）。牌尺寸在动的时候旧精灵**仍然可用**（绘制时按精确尺寸缩放，只是
/// 分辨率略偏），所以完全可以等它稳定下来再换一次。
///
/// 首次合成不受此限：那时还没有任何精灵可用，推迟只会让画面走逐帧 clip + 模糊
/// 的回退路径（更慢）。
const Duration kSpriteSettleDelay = Duration(milliseconds: 120);

/// 同一批里同时合成的源图数（每张源图两个变体，即 2× 个离屏渲染）。
///
/// 一次性把上百个 `Picture.toImage` 全丢给栅格线程会把它独占住（期间帧根本出
/// 不来）：牌背 → 牌面切换时 53 张源图就是 106 次离屏渲染，实测连着跑要将近
/// 1s，画面直接卡住。一批只排这么几张、批与批之间让出事件循环
///（见 [_drainQueue]），合成就与动画帧交错推进。
const int kSpriteMaxConcurrentSources = 2;

/// 队列里还剩多少张源图时，才在批与批之间让出事件循环（见 [_drainQueue]）。
///
/// 短队列（几张牌面 / 只有牌背）一口气做完更快，也没必要让出；真正需要让出的是
/// 「牌背 → 牌面」那种一次入队几十张的场景。
const int kSpriteBurstThreshold = 8;

/// 一个待执行的离屏合成任务（一张源图 = 带装饰 / 纯净两个变体）。
///
/// 两个变体放在**同一个任务**里完成、再一起发布：只发布了其中一个时，重合的牌
/// 会走到「只有装饰层」那条分支——而装饰层强度随重合度趋近 0，整叠牌会瞬间变
/// 透明（闪一下）。成对发布就没有中间态。
class _SpriteJob {
  const _SpriteJob({
    required this.image,
    required this.width,
    required this.height,
    required this.dpr,
    required this.shadowColor,
    required this.generation,
  });

  final ui.Image image;
  final double width;
  final double height;
  final double dpr;
  final Color shadowColor;

  /// 入队时的 `_generation`；尺寸又变了（generation 前进）时这个任务作废。
  final int generation;
}

/// 一份被推迟的「换尺寸」请求（等牌尺寸稳定后执行）。
class _PendingResize {
  const _PendingResize({
    required this.images,
    required this.width,
    required this.height,
    required this.dpr,
    required this.shadowColor,
    required this.key,
  });

  final List<ui.Image> images;
  final double width;
  final double height;
  final double dpr;
  final Color shadowColor;
  final String key;
}

/// 把「牌图 + 圆角裁剪 + 阴影模糊 + 描边」预先合成成一张位图。
///
/// 一帧里 52 张牌各自执行 clipRRect + MaskFilter 模糊 + 大图缩放是主要开销，
/// 而这些内容其实与动画无关：把它离屏合成一次，之后每帧只做一次
/// `drawImageRect`（贴图，几乎零成本）。
///
/// 因为所有牌共用同一批源图（牌背 1 张 + 牌面若干），
/// 缓存条目数等于「不同源图」的数量，而不是牌的数量。
class CardSpriteCache {
  CardSpriteCache();

  final Map<ui.Image, ui.Image> _sprites = <ui.Image, ui.Image>{};
  final Map<ui.Image, ui.Image> _flatSprites = <ui.Image, ui.Image>{};
  final Map<ui.Image, String> _keys = <ui.Image, String>{};

  /// 每张精灵里「牌身」那块区域的逻辑尺寸（不含阴影留白）。
  ///
  /// 牌身之外的留白是合成时按 [kCardSpritePadding] 加的，而绘制时的牌尺寸
  /// （布局算出来的）未必等于合成时的尺寸：若把整张精灵直接拉到
  /// `rect.inflate(kCardSpritePadding)`，留白会被一起缩放，牌身就被画大 / 画小
  /// 了（精灵比牌大 15% 时牌会被画大 2%，差一倍时差 10%）。画家靠这张表把
  /// 「精灵里的牌身」精确对齐到布局给的尺寸。
  final Map<ui.Image, Size> _cardSizes = <ui.Image, Size>{};

  String _activeKey = '';
  int _generation = 0;
  bool _disposed = false;

  /// 当前精灵的合成高度（逻辑像素，已按档位取过）；0 = 还没有任何精灵。
  double _activeHeight = 0;

  /// 每次有新精灵可用时自增，用于驱动重绘。
  int version = 0;

  /// 离屏合成任务队列（分批推进，见 [kSpriteMaxConcurrentSources]）。
  final ListQueue<_SpriteJob> _queue = ListQueue<_SpriteJob>();
  bool _draining = false;

  /// 等牌尺寸稳定后才执行的换档请求（见 [kSpriteSettleDelay]）。
  _PendingResize? _pendingResize;
  Timer? _settleTimer;

  /// 批与批之间的「让出一帧」计时器（[dispose] 时要撤掉，否则销毁后还会触发，
  /// 测试里也会留下「A Timer is still pending」）。
  Timer? _yieldTimer;

  /// 最近一次 [update] 传进来的回调（合并通知时用它）。
  VoidCallback? _onReady;
  bool _notifyScheduled = false;

  /// 带阴影的精灵图。
  Map<ui.Image, ui.Image> get sprites => _sprites;

  /// 不带阴影的精灵图（只有圆角、牌面与描边）。
  ///
  /// 相邻牌几乎重合时用这一套，避免多张牌的投影叠成黑边。
  Map<ui.Image, ui.Image> get flatSprites => _flatSprites;

  /// 每张精灵里「牌身」那块区域的逻辑尺寸（见 [_cardSizes]）。
  ///
  /// 与 [sprites] / [flatSprites] 一样按引用共享，成对发布时一起写入。
  Map<ui.Image, Size> get spriteCardSizes => _cardSizes;

  /// 队列里还没开始合成的任务数（测试用：验证合成确实是分批推进的）。
  @visibleForTesting
  int get pendingJobCount => _queue.length;

  /// 为 [images] 准备 [width] × [height] 尺寸的精灵图。
  ///
  /// 幂等：牌的尺寸没变则不会重复合成。
  ///
  /// 尺寸**变化**时分两类处理：
  /// - 还没有精灵的源图（首次合成 / 新出现的牌面）：立刻合成——推迟只会让画面
  ///   走逐帧 clip + 模糊的回退路径，那比离屏合成慢得多；
  /// - 已有精灵、只是尺寸不对的源图：等牌尺寸稳定 [kSpriteSettleDelay] 再换。
  ///   牌尺寸在拖动开扇角度 / 拖滑块 / 缩放窗口时是连续变化的，追着它换会让
  ///   一次拖动产生上百次离屏渲染（见 [kSpriteSettleDelay]）。
  void update({
    required Iterable<ui.Image> images,
    required double width,
    required double height,
    required double dpr,
    required Color shadowColor,
    required VoidCallback onReady,
    int maxMemoryBytes = kSpriteMemoryBudget,
  }) {
    if (_disposed || width <= 1 || height <= 1) return;
    _onReady = onReady;
    final sources = images.toList(growable: false);
    // 尺寸按档位切换：牌尺寸会随布局连续变化（拖动开扇角度、窗口缩放、调牌数），
    // 若每 4px 都重新合成，一次拖动就是上百次离屏渲染（52 张牌面时上千次）。
    // 只量化主维度（高）并按比例推导宽，保持宽高比；绘制时仍按精确尺寸缩放，
    // 误差不超过半个步长，配合 FilterQuality.medium 不可见。
    final spriteHeight = _targetHeight(height);
    _activeHeight = spriteHeight;
    final spriteWidth = spriteHeight * (width / height);
    // 单份精灵的字节数（含阴影留白）；每种源图需要 2 份。
    final bytesPerSource =
        2 *
        (spriteWidth + kCardSpritePadding * 2) *
        (spriteHeight + kCardSpritePadding * 2) *
        4;
    // 预算内可达到的 dpr：总量 ≈ sources × bytesPerSource × dpr²。
    final dprByBudget = sources.isEmpty
        ? dpr
        : math.sqrt(maxMemoryBytes / (bytesPerSource * sources.length));
    // 限制在 2x，兼顾清晰度与内存 / 生成耗时；
    // 源图很多时（52 张不重复牌面）进一步向显存预算让步。
    final effectiveDpr = math
        .min(dpr.clamp(1.0, 2.0), dprByBudget)
        .clamp(1.0, 2.0);
    final key =
        '${spriteWidth.round()}x${spriteHeight.round()}@'
        '${(effectiveDpr * 10).round()}#${shadowColor.toARGB32()}';
    if (key != _activeKey) {
      _activeKey = key;
      _generation++;
    }

    final fresh = <ui.Image>[];
    final stale = <ui.Image>[];
    for (final image in sources) {
      if (_keys[image] == key) continue;
      if (_sprites.containsKey(image)) {
        stale.add(image);
      } else {
        fresh.add(image);
      }
    }
    if (fresh.isNotEmpty) {
      _enqueue(fresh, spriteWidth, spriteHeight, effectiveDpr, shadowColor);
    }
    if (stale.isEmpty) {
      // 没有需要换尺寸的了：撤掉上一轮还没执行的换档请求
      //（尺寸可能又变回了旧档位，那一轮已经没必要跑）。
      _cancelPendingResize();
    } else {
      _pendingResize = _PendingResize(
        images: stale,
        width: spriteWidth,
        height: spriteHeight,
        dpr: effectiveDpr,
        shadowColor: shadowColor,
        key: key,
      );
      // 尺寸每动一次就把等待重新计时：拖到哪儿都不换，松手后只换一次。
      _settleTimer?.cancel();
      _settleTimer = Timer(kSpriteSettleDelay, _runPendingResize);
    }
    _evictAbsent(sources);
  }

  /// 入队一批源图（每张两个变体），并推进队列。
  void _enqueue(
    List<ui.Image> images,
    double width,
    double height,
    double dpr,
    Color shadowColor,
  ) {
    final generation = _generation;
    final key = _activeKey;
    for (final image in images) {
      _keys[image] = key;
      _queue.add(
        _SpriteJob(
          image: image,
          width: width,
          height: height,
          dpr: dpr,
          shadowColor: shadowColor,
          generation: generation,
        ),
      );
    }
    _pumpQueue();
  }

  /// 牌尺寸稳定了：把被推迟的换档请求真正执行掉。
  void _runPendingResize() {
    _settleTimer = null;
    final pending = _pendingResize;
    _pendingResize = null;
    if (_disposed || pending == null) return;
    _enqueue(
      pending.images,
      pending.width,
      pending.height,
      pending.dpr,
      pending.shadowColor,
    );
  }

  void _cancelPendingResize() {
    _settleTimer?.cancel();
    _settleTimer = null;
    _pendingResize = null;
  }

  /// 让出一个事件循环回合（不占用时间，只是把控制权交还给引擎）。
  ///
  /// 返回的 Future 在下一个定时器回合完成；[dispose] 会撤掉这个计时器，
  /// 所以销毁后不会有残留定时器。
  Future<void> _yield() {
    final completer = Completer<void>();
    _yieldTimer = Timer(Duration.zero, () {
      _yieldTimer = null;
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  /// 推进合成队列（幂等：正在推进时不会重复开一条链）。
  void _pumpQueue() {
    if (_draining || _disposed || _queue.isEmpty) return;
    _draining = true;
    _drainQueue().ignore();
  }

  /// 一批一批地合成，批与批之间**让出事件循环**。
  ///
  /// 牌背 → 牌面切换时 52 张牌面一次性入队（106 次离屏渲染），若一口气排完，
  /// 栅格队列被 `Picture.toImage` 塞满、帧排不进去，画面就是卡住；分批 + 让出
  /// 之后，每批之间至少能插进一帧，切换过程始终是连续的。
  /// 还没合成到的源图由画家走回退路径（clip + 贴图，样式与精灵一致），
  /// 精灵陆续到位后自动升级，不会出现空档。
  Future<void> _drainQueue() async {
    try {
      while (!_disposed && _queue.isNotEmpty) {
        final batch = <Future<void>>[];
        while (batch.length < kSpriteMaxConcurrentSources &&
            _queue.isNotEmpty) {
          batch.add(_runJob(_queue.removeFirst()));
        }
        await Future.wait(batch);
        if (_disposed || _queue.isEmpty) break;
        // 队列还长才让出：让出本身有开销，短队列一路做完更快。
        if (_queue.length >= kSpriteBurstThreshold) {
          await _yield();
          if (_disposed) break;
        }
      }
    } finally {
      _draining = false;
    }
  }

  Future<void> _runJob(_SpriteJob job) async {
    // 过期任务：尺寸又变了（generation 前进）或源图已被 evict。
    if (_disposed ||
        job.generation != _generation ||
        !_keys.containsKey(job.image)) {
      return;
    }
    final List<ui.Image?> pair;
    try {
      pair = await Future.wait(<Future<ui.Image>>[
        _render(
          job.image,
          job.width,
          job.height,
          job.dpr,
          job.shadowColor,
          withDecoration: true,
        ),
        _render(
          job.image,
          job.width,
          job.height,
          job.dpr,
          job.shadowColor,
          withDecoration: false,
        ),
      ]);
    } catch (_) {
      return; // 合成失败：保留旧精灵继续用，不影响绘制。
    }
    // 丢弃过期结果：尺寸已变化（generation 不符）、缓存已 dispose，
    // 或合成期间源图已被 evict（`_keys` 里没有它了）。
    if (_disposed ||
        job.generation != _generation ||
        !_keys.containsKey(job.image)) {
      for (final sprite in pair) {
        sprite?.dispose();
      }
      return;
    }
    // 两个变体一起发布（见 [_SpriteJob]）：缺一个都不换，避免中间态下重合的牌
    // 只剩装饰层、整叠变透明。
    _sprites[job.image]?.dispose();
    _flatSprites[job.image]?.dispose();
    _sprites[job.image] = pair[0]!;
    _flatSprites[job.image] = pair[1]!;
    _cardSizes[job.image] = Size(job.width, job.height);
    version += 2;
    _notifyReady();
  }

  /// 通知「有新精灵可用」。
  ///
  /// 同一轮里几十上百个精灵是先后落地的，逐个通知会让宿主 `setState` 几十上百
  /// 次、每次都重建并整幅重绘一次画布（52 张牌）。合并到同一个微任务里只通知
  /// 一次：精灵图是**按引用共享**的 map，最后一次重绘就能看到全部新精灵。
  void _notifyReady() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      if (_disposed) return;
      _onReady?.call();
    });
  }

  /// 本次该合成的高度（逻辑像素）：放大立即换档、缩小滞回换档、其余复用。
  ///
  /// 牌尺寸连续变化时（拖动开扇角度、窗口缩放、调牌数），「每次变动都重新合成」
  /// 会让一次拖动产生上百次离屏渲染；这里只在跨过档位时才换。
  double _targetHeight(double height) {
    final active = _activeHeight;
    if (active <= 0) return _quantize(height);
    // 容差取半个步长：当前档位是就近量化来的，可能比实际牌高小最多半步，
    // 不把这个误差算进去的话「尺寸没变」也会被判成变大、白换一次档。
    if (height > active + kSpriteSizeStep / 2) {
      // 变大：跳到阶梯上更高的一档（过采样，牌不会糊）。
      // 就近量化可能落回当前档位，所以这里必须先向上取档再量化。
      final rung = _ceilQuantize(_rungUp(height));
      return rung > active ? rung : active + kSpriteSizeStep;
    }
    if (height < active / _spriteShrinkRatio) {
      // 明显变小：降档，把多占的显存还回去。
      return _quantize(height);
    }
    return active;
  }

  /// 淘汰本次不再使用的源图（切换牌背、关掉牌面、牌数减少）。
  ///
  /// 缓存此前只增不减：源图集合变小后旧精灵会一直常驻（52 张牌面 ≈ 数十 MB），
  /// 而且显存预算是按**当前**源图数量反解的，漏掉淘汰会让预算账目失真。
  void _evictAbsent(List<ui.Image> sources) {
    // 源图为空说明图片还没解码好（或配置刚变化），此时不动缓存。
    if (sources.isEmpty) return;
    final live = <ui.Image>{...sources};
    var removed = 0;
    for (final image in _keys.keys.toList()) {
      if (live.contains(image)) continue;
      evict(image);
      removed++;
    }
    // 缓存内容变了要驱动重绘（画家按 spriteVersion 判断）。
    if (removed > 0) version++;
  }

  /// 源图不再被使用（调用方已 dispose）时，同步释放它占用的两份精灵。
  void evict(ui.Image image) {
    _keys.remove(image);
    _cardSizes.remove(image);
    _sprites.remove(image)?.dispose();
    _flatSprites.remove(image)?.dispose();
  }

  void dispose() {
    _disposed = true;
    // 撤掉还没执行的换档请求与排队任务（否则 Timer 会在销毁后还触发一次，
    // 测试里也会留下「A Timer is still pending」）。
    _cancelPendingResize();
    _yieldTimer?.cancel();
    _yieldTimer = null;
    _queue.clear();
    for (final sprite in _sprites.values) {
      sprite.dispose();
    }
    for (final sprite in _flatSprites.values) {
      sprite.dispose();
    }
    _sprites.clear();
    _flatSprites.clear();
    _keys.clear();
    _cardSizes.clear();
  }
}

Future<ui.Image> _render(
  ui.Image source,
  double width,
  double height,
  double dpr,
  Color shadowColor, {
  required bool withDecoration,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(dpr, dpr);

  final rect = Rect.fromLTWH(
    kCardSpritePadding,
    kCardSpritePadding,
    width,
    height,
  );
  final rrect = RRect.fromRectAndRadius(rect, Radius.circular(width * 0.07));

  if (withDecoration && shadowColor.a > 0) {
    canvas.drawRRect(
      rrect.shift(kCardShadowOffset),
      Paint()
        ..color = shadowColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, kCardShadowBlur),
    );
  }

  canvas
    ..save()
    ..clipRRect(rrect)
    ..drawImageRect(
      source,
      Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
      rect,
      Paint()..filterQuality = FilterQuality.medium,
    )
    ..restore();

  // 描边同样会随重叠张数累积：紧密重合时只保留牌面，轮廓交给最底层那张。
  // 注意描边与阴影是解耦的：即使关掉阴影（透明色）也仍然保留描边。
  if (withDecoration) {
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = kCardBorderWidth
        ..color = kCardBorderColor,
    );
  }

  final picture = recorder.endRecording();
  final totalW = (width + kCardSpritePadding * 2) * dpr;
  final totalH = (height + kCardSpritePadding * 2) * dpr;
  final image = await picture.toImage(totalW.round(), totalH.round());
  picture.dispose();
  return image;
}
