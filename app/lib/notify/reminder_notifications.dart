import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' hide Day;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/reminder.dart';
import '../state/app_state.dart';
import '../util/day.dart';

/// Phone notifications, scheduled on the phone with no server (stack plan: Spark has no
/// Cloud Functions, so reminders are local):
/// - each care task, ahead of its time (FR11);
/// - one "time to log" reminder on a day with no log (FR21; report Table 3.2), with
///   Log now and Later buttons (report Table 4.4 screen 1; Figma screen 01).
class ReminderNotifications {
  ReminderNotifications(this.state, {required this.onLogNow});

  final AppState state;

  /// Opens the quick log for a pet when Log now or the notification is tapped.
  final void Function(String petId) onLogNow;

  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _dailyCategory = 'daily_log';
  static const _laterId = 900000;

  /// Time the "not logged yet" reminder fires, minutes after midnight (Figma: "Due by 9:00 pm").
  static const dailyLogMinutes = 21 * 60;

  /// iOS keeps at most 64 scheduled notifications per app.
  static const _max = 60;

  String _lastSignature = '';
  Timer? _debounce;
  bool _asked = false;

  static Future<void> _initTimeZone() async {
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  static InitializationSettings get _settings => InitializationSettings(
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [
            DarwinNotificationCategory(_dailyCategory, actions: [
              DarwinNotificationAction.plain('log_now', 'Log now',
                  options: {DarwinNotificationActionOption.foreground}),
              DarwinNotificationAction.plain('later', 'Later'),
            ]),
          ],
        ),
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
      );

  Future<void> start() async {
    await _initTimeZone();
    await _plugin.initialize(
      settings: _settings,
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse: onBackgroundResponse,
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final r = launch?.notificationResponse;
    if (launch?.didNotificationLaunchApp == true && r != null) _onResponse(r);
    state.addListener(_changed);
    _changed();
  }

  void _onResponse(NotificationResponse r) {
    if (r.actionId == 'later') {
      unawaited(snooze(r.payload));
      return;
    }
    final petId = r.payload;
    if (petId != null && petId.isNotEmpty) onLogNow(petId);
  }

  void _changed() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 1), () => unawaited(sync()));
  }

  Future<bool> _permission() async {
    if (_asked) return true;
    _asked = true;
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    final android =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final ok = await ios?.requestPermissions(alert: true, sound: true, badge: false) ??
        await android?.requestNotificationsPermission() ??
        false;
    return ok;
  }

  static NotificationDetails _details({bool daily = false}) => NotificationDetails(
        iOS: DarwinNotificationDetails(categoryIdentifier: daily ? _dailyCategory : null),
        android: AndroidNotificationDetails(
          daily ? 'daily_log' : 'care',
          daily ? 'Daily log reminder' : 'Care reminders',
          actions: daily
              ? const [
                  AndroidNotificationAction('log_now', 'Log now', showsUserInterface: true),
                  AndroidNotificationAction('later', 'Later'),
                ]
              : null,
        ),
      );

  /// What would be scheduled, so nothing is redone when nothing changed.
  @visibleForTesting
  static List<PlannedNotification> plan(AppState s) {
    final now = s.now();
    final today = Day.of(now);
    final out = <PlannedNotification>[];
    final pets = s.activePets;
    if (pets.isEmpty) return out;

    for (var i = 0; i < 7; i++) {
      final d = today.addDays(i);
      final at = DateTime(d.year, d.month, d.dayOfMonth, dailyLogMinutes ~/ 60, dailyLogMinutes % 60);
      if (!at.isAfter(now)) continue;
      final due = i == 0 ? pets.where((p) => !s.loggedToday(p.id)).toList() : pets;
      if (due.isEmpty) continue;
      final names = due.map((p) => p.name).toList();
      final who = names.length == 1
          ? "${names.first}'s"
          : "${names.sublist(0, names.length - 1).join(', ')} and ${names.last}'s";
      out.add(PlannedNotification(at, 'Time to log $who day', 'Takes about 5 seconds.', due.first.id, true));
    }

    final tasks = <PlannedNotification>[];
    for (final p in pets) {
      for (final Reminder r in s.remindersOf(p.id).where((r) => r.active)) {
        for (final o in r.occurrences(today, today.addDays(6))) {
          final at = o.subtract(Duration(minutes: r.notifyBefore));
          if (!at.isAfter(now)) continue;
          final when = r.notifyBefore == 0 ? 'Now' : 'In ${r.notifyBefore >= 60 ? '${r.notifyBefore ~/ 60} hour' : '${r.notifyBefore} minutes'}';
          tasks.add(PlannedNotification(at, '${p.name}: ${r.title}', '$when. Tick it off on Today.', p.id, false));
        }
      }
    }
    tasks.sort((a, b) => a.at.compareTo(b.at));
    out.addAll(tasks.take(_max - out.length));
    return out;
  }

  Future<void> sync() async {
    final planned = plan(state);
    final sig = planned.map((p) => '${p.at}|${p.title}|${p.petId}').join(';');
    if (sig == _lastSignature) return;
    _lastSignature = sig;
    if (planned.isNotEmpty && !await _permission()) return;
    await _plugin.cancelAll();
    var id = 1;
    for (final p in planned) {
      await _plugin.zonedSchedule(
        id: id++,
        scheduledDate: tz.TZDateTime.from(p.at, tz.local),
        notificationDetails: _details(daily: p.daily),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: p.title,
        body: p.body,
        payload: p.petId,
      );
    }
  }

  /// "Later": remind again in an hour.
  static Future<void> snooze(String? petId) async {
    await _plugin.zonedSchedule(
      id: _laterId,
      scheduledDate: tz.TZDateTime.now(tz.local).add(const Duration(hours: 1)),
      notificationDetails: _details(daily: true),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: 'Time to log today',
      body: 'Takes about 5 seconds.',
      payload: petId,
    );
  }
}

/// Runs when Later is tapped while the app is closed.
@pragma('vm:entry-point')
Future<void> onBackgroundResponse(NotificationResponse r) async {
  if (r.actionId != 'later') return;
  await ReminderNotifications._initTimeZone();
  await ReminderNotifications._plugin.initialize(settings: ReminderNotifications._settings);
  await ReminderNotifications.snooze(r.payload);
}

class PlannedNotification {
  final DateTime at;
  final String title;
  final String body;
  final String petId;
  final bool daily;
  const PlannedNotification(this.at, this.title, this.body, this.petId, this.daily);
}
