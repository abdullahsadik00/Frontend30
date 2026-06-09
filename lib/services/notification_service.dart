import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Schedules a daily 8 PM "Streak at Risk" reminder.
///
/// Platform setup: see platform_setup.md in the project root.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  static const _channelId   = 'frontend30_streak';
  static const _channelName = 'Streak Reminders';
  static const _dailyId     = 1;

  static const _androidDetails = AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: 'Daily reminder to keep your learning streak alive',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    icon: '@mipmap/ic_launcher',
  );

  static const _notifDetails = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready   = false;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_ready) return;
    tz.initializeTimeZones();

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(initSettings);
    _ready = true;
  }

  // ── Permissions ───────────────────────────────────────────────────────────

  Future<bool> requestPermission() async {
    if (!_ready) return false;

    // iOS
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true, badge: true, sound: true) ??
          false;
    }

    // Android 13+
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }

    return true;
  }

  // ── Scheduling ────────────────────────────────────────────────────────────

  /// Schedules the daily 8 PM reminder starting from the next occurrence.
  /// No-op if a reminder is already pending.
  Future<void> scheduleDailyReminder() async {
    if (!_ready) return;

    final pending = await _plugin.pendingNotificationRequests();
    if (pending.any((n) => n.id == _dailyId)) return;

    await _scheduleAt(_nextOccurrence(hour: 20));
  }

  /// Cancels today's reminder and reschedules from tomorrow.
  /// Called when the user passes a test so they aren't notified today.
  Future<void> rescheduleForTomorrow() async {
    if (!_ready) return;
    await _plugin.cancel(_dailyId);
    await _scheduleAt(_nextOccurrence(hour: 20, skipToday: true));
  }

  // ── Private ───────────────────────────────────────────────────────────────

  Future<void> _scheduleAt(tz.TZDateTime target) => _plugin.zonedSchedule(
        _dailyId,
        '🔥 Streak at Risk!',
        "Don't forget — complete today's test before midnight.",
        target,
        _notifDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time, // repeats daily
      );

  /// Returns the next TZDateTime for [hour]:00:00.
  /// If [skipToday] is true, always returns tomorrow even if it hasn't
  /// passed today yet — used after a test is already completed.
  static tz.TZDateTime _nextOccurrence({
    required int hour,
    bool skipToday = false,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    var target =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);

    if (skipToday || target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }
    return target;
  }
}
