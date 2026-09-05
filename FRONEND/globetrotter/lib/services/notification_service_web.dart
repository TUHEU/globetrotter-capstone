import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Real browser notifications for the web build (the only platform this
/// project currently ships). Uses the native Notification API directly —
/// https://developer.mozilla.org/en-US/docs/Web/API/Notification — no
/// extra package needed since `web` is already a dependency.
///
/// Browsers only allow this while the tab/app is at least loaded in memory
/// (it can be backgrounded, but not fully closed) and only after the user
/// has granted permission — most browsers only show the permission prompt
/// in response to a real user gesture, so the first message of a session
/// may silently not show a notification if permission hasn't been granted
/// yet; every message after the user accepts the prompt will.
class NotificationServiceImpl {
  Future<void> init() async {
    try {
      if (web.Notification.permission == 'default') {
        await web.Notification.requestPermission().toDart;
      }
    } catch (_) {
      // Notification API unavailable (unsupported browser/webview) — the
      // rest of the chat still works fine without it.
    }
  }

  Future<void> showMessage({required String title, required String body}) async {
    try {
      if (web.Notification.permission != 'granted') {
        await web.Notification.requestPermission().toDart;
      }
      if (web.Notification.permission == 'granted') {
        web.Notification(title, web.NotificationOptions(body: body));
      }
    } catch (_) {
      // Same as above — never let a notification failure break the chat.
    }
  }
}
