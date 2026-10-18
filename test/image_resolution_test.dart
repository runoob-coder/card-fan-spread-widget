import 'dart:ui' as ui;

import 'package:card_fan_spread/card_fan_spread.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 记录 [obtainKey] 收到的 [ImageConfiguration] 与 resolve 次数的测试用 provider。
///
/// 注意：用 [obtainKey] 计数而不是 `loadImage` 计数——
/// `ImageProvider.resolve` 每次都会调 obtainKey，但 loadImage 会被
/// 全局 `ImageCache` 按 key 挡住（命中缓存时不重新加载）。
class _RecordingImageProvider extends ImageProvider<_RecordingImageProvider> {
  _RecordingImageProvider(this.name);

  final String name;

  /// 每次 resolve 时记下当时的 devicePixelRatio。
  final List<double?> dprLog = <double?>[];

  /// resolve 次数（= dprLog.length）。
  int get resolveCount => dprLog.length;

  @override
  Future<_RecordingImageProvider> obtainKey(ImageConfiguration configuration) {
    dprLog.add(configuration.devicePixelRatio);
    return SynchronousFuture<_RecordingImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _RecordingImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(_load());
  }

  Future<ImageInfo> _load() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 650, 916),
      Paint()..color = const ui.Color(0xFF334455),
    );
    final image = await recorder.endRecording().toImage(650, 916);
    return ImageInfo(image: image);
  }
}

Widget _host(ImageProvider back) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(
      width: 400,
      height: 600,
      child: CardFanSpread(cardBack: back, autoPlay: false),
    ),
  );
}

void main() {
  testWidgets('图片解析带上真实 devicePixelRatio（不再永远加载 1.0x）', (tester) async {
    final back = _RecordingImageProvider('back');

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(400, 600), devicePixelRatio: 3.0),
        child: _host(back),
      ),
    );
    await tester.pump();

    expect(
      back.dprLog,
      isNotEmpty,
      reason: 'resolve 应带上 MediaQuery 的 devicePixelRatio',
    );
    expect(
      back.dprLog.last,
      3.0,
      reason: 'ImageConfiguration.empty 会丢掉 dpr，导致资源永远按 1.0x 加载',
    );
  });

  testWidgets('devicePixelRatio 变化时按新 dpr 重新解析资源', (tester) async {
    final back = _RecordingImageProvider('back');

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(400, 600), devicePixelRatio: 3.0),
        child: _host(back),
      ),
    );
    await tester.pump();
    expect(back.dprLog.last, 3.0);

    // 窗口跨屏移动：dpr 3.0 → 2.0
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(400, 600), devicePixelRatio: 2.0),
        child: _host(back),
      ),
    );
    await tester.pump();

    expect(back.resolveCount, greaterThan(1), reason: 'dpr 变化后应失效并按新配置重新解析');
    expect(back.dprLog.last, 2.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dpr 没变时不会重复解析（配置相同应幂等）', (tester) async {
    final back = _RecordingImageProvider('back');

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(400, 600), devicePixelRatio: 2.0),
        child: _host(back),
      ),
    );
    await tester.pump();
    expect(back.resolveCount, 1);

    // 同样的 MediaQuery 数据重新 pump：依赖没变，不应失效重解析
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(400, 600), devicePixelRatio: 2.0),
        child: _host(back),
      ),
    );
    await tester.pump();
    expect(back.resolveCount, 1, reason: '配置相同时应保持幂等');
    expect(tester.takeException(), isNull);
  });

  testWidgets('更换 provider 后旧的图片 entry 被回收（换回来会重新 resolve）', (tester) async {
    final a = _RecordingImageProvider('a');
    final b = _RecordingImageProvider('b');

    await tester.pumpWidget(_host(a));
    await tester.pump();
    expect(a.resolveCount, 1);

    // 换成 b：a 的 entry 应被回收
    await tester.pumpWidget(_host(b));
    await tester.pump();
    expect(b.resolveCount, 1);
    expect(a.resolveCount, 1, reason: 'a 已不在使用中，不应被重复 resolve');

    // 再换回 a：若 entry 未被回收，不会重新 resolve（resolveCount 停在 1）
    await tester.pumpWidget(_host(a));
    await tester.pump();
    expect(a.resolveCount, 2, reason: '旧 entry 应已回收，换回时需要重新 resolve');
    expect(tester.takeException(), isNull);
  });

  testWidgets('牌面列表变化时同理：减少牌数会回收多余 entry', (tester) async {
    final faces = List.generate(4, (i) => _RecordingImageProvider('face$i'));
    final back = _RecordingImageProvider('back');

    Widget host(int count) => Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 400,
        height: 600,
        child: CardFanSpread(
          cardBack: back,
          cardFaces: faces.take(count).toList(),
          showFace: true,
          autoPlay: false,
        ),
      ),
    );

    await tester.pumpWidget(host(4));
    await tester.pump();
    for (final f in faces) {
      expect(f.resolveCount, 1);
    }

    await tester.pumpWidget(host(2));
    await tester.pump();
    // 换回 4 张：被回收的两张应重新 resolve，仍在用的不应重复
    await tester.pumpWidget(host(4));
    await tester.pump();
    expect(faces[2].resolveCount, 2, reason: '被回收的 entry 应重新 resolve');
    expect(faces[3].resolveCount, 2);
    expect(faces[0].resolveCount, 1, reason: '仍在使用的 entry 不应重复 resolve');
    expect(faces[1].resolveCount, 1);
    expect(tester.takeException(), isNull);
  });
}
