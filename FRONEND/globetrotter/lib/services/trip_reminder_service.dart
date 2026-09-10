import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Programme un rappel local (notification système, pas juste "dans
/// l'app") la veille au matin de la date de début d'un itinéraire prévu.
///
/// NOTE dépendances : nécessite `flutter_local_notifications` et
/// `timezone` dans pubspec.yaml (aucun des deux n'était présent avant) :
///   flutter_local_notifications: ^18.0.1
///   timezone: ^0.9.4
///
/// NOTE plateforme (pas fait ici - ce projet n'inclut pas les dossiers
/// android/ios) :
/// - Android : ajouter la permission POST_NOTIFICATIONS (Android 13+) et
///   SCHEDULE_EXACT_ALARM si des rappels précis sont nécessaires dans
///   AndroidManifest.xml, et une icône de notification
///   (res/drawable/ic_notification).
/// - iOS : les permissions sont demandées au runtime par ce service
///   (requestPermissions), mais le projet Xcode doit avoir les
///   "Background Modes" appropriés si des rappels doivent survivre un
///   redémarrage de l'appareil.
class TripReminderService {
  TripReminderService._();
  static final TripReminderService instance = TripReminderService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  /// [itineraryId] doit être stable pour la même sortie (utilisé comme
  /// id de notification, tronqué en int) - reprogrammer avec le même id
  /// remplace silencieusement le rappel précédent, plutôt que d'en
  /// empiler un deuxième.
  Future<bool> scheduleReminder({
    required String itineraryId,
    required String title,
    required DateTime startDate,
  }) async {
    await init();

    // Rappel la veille à 9h locale - si la sortie commence dans moins de
    // 24h, on ne programme rien plutôt que d'envoyer une notification
    // "pour hier" ou immédiate et surprenante.
    final reminderTime = DateTime(startDate.year, startDate.month, startDate.day - 1, 9);
    if (reminderTime.isBefore(DateTime.now())) return false;

    final id = itineraryId.hashCode & 0x7fffffff;
    final scheduled = tz.TZDateTime.from(reminderTime, tz.local);

    await _plugin.zonedSchedule(
      id,
      'Sortie demain : $title',
      "N'oubliez pas votre sortie prévue demain sur GlobeTrotter Yaoundé.",
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'trip_reminders',
          'Rappels de sortie',
          channelDescription: 'Rappel la veille d\'une sortie planifiée',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    return true;
  }

  Future<void> cancelReminder(String itineraryId) async {
    final id = itineraryId.hashCode & 0x7fffffff;
    await _plugin.cancel(id);
  }
}
