// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web 端：同步在新标签页打开链接，避免被弹窗拦截。
Future<void> openExternalUrl(String url) async {
  // 在 async 函数的同步部分（首个 await 之前）调用，保留用户手势。
  html.window.open(url, '_blank');
}
