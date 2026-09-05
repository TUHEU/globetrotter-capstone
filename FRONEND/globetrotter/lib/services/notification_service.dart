import 'notification_service_io.dart'
    if (dart.library.html) 'notification_service_web.dart' as impl;

/// Foreground notifications for new chat activity.
///
/// IMPORTANT — scope of what this actually does: this only fires while the
/// app/tab is open and running. It is NOT push notifications — true
/// background/closed-app delivery needs a push service (Firebase Cloud
/// Messaging or the Web Push API) wired to a server that sends a push on
/// each new message, plus setup (a service worker for web, or
/// google-services.json/APNs certs for mobile) that needs your own
/// Firebase project. This gives "a notification appears while the app is
/// open", which the existing live WebSocket connection can support without
/// that extra infrastructure.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _impl = impl.NotificationServiceImpl();

  Future<void> init() => _impl.init();

  Future<void> showMessage({required String title, required String body}) =>
      _impl.showMessage(title: title, body: body);
}
