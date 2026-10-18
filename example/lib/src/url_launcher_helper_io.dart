import 'package:url_launcher/url_launcher.dart';

/// 非 Web 平台：优先用外部应用打开，失败再回退平台默认方式。
Future<void> openExternalUrl(String url) async {
  final uri = Uri.parse(url);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    await launchUrl(uri, mode: LaunchMode.platformDefault);
  }
}
