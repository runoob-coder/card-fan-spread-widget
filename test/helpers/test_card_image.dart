import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// 测试用的纸牌图：指定颜色，尺寸按真实牌图比例（650x916）。
class TestCardImage extends ImageProvider<TestCardImage> {
  TestCardImage(this.image);

  final ui.Image image;

  @override
  Future<TestCardImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<TestCardImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    TestCardImage key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(
      Future<ImageInfo>.value(ImageInfo(image: key.image)),
    );
  }
}

Future<ui.Image> solidCardImage([
  ui.Color color = const ui.Color(0xFFFFFFFF),
]) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder)
      .drawRect(const Rect.fromLTWH(0, 0, 650, 916), Paint()..color = color);
  return recorder.endRecording().toImage(650, 916);
}
