import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Used on every platform EXCEPT web (see the conditional import in
/// notification_service.dart). Only actually exercised once this project
/// grows android/ios/windows platform folders — today's build only ships
/// web, where notification_service_web.dart is used instead.
class NotificationServiceImpl {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  int _nextId = 0;

  Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const windows = WindowsInitializationSettings(
      appName: 'GlobeTrotter',
      appUserModelId: 'com.globetrotter.app',
      guid: 'a2b6c9e0-6b7a-4b2c-9c1d-7f0f9b3a1234',
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: android,
        iOS: ios,
        macOS: ios,
        windows: windows,
      ),
    );
    // Android 13+ requires this explicit runtime request or notifications
    // never show, even with the manifest permission declared.
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _ready = true;
  }

  Future<void> showMessage({required String title, required String body}) async {
    if (!_ready) await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'chat_messages',
        'Messages',
        channelDescription: 'Nouveaux messages du chat GlobeTrotter',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );
    await _plugin.show(
      id: _nextId++,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}
