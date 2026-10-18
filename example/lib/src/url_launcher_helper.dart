// 跨平台的「在外部浏览器打开链接」封装。
//
// Web 上 `url_launcher` 的 `launchUrl` 是 async 的：在 await 间隙浏览器会丢失
// 用户手势，导致 `window.open` 被当成弹窗拦截，表现为「点了没反应 / 不新开窗口」。
// 因此 Web 端直接用 `dart:html` 同步调用 `window.open(..., '_blank')`，
// 其余平台仍走 `url_launcher`。
export 'url_launcher_helper_io.dart'
    if (dart.library.html) 'url_launcher_helper_web.dart';
