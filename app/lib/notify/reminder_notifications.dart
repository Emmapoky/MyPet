import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' hide Day;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/reminder.dart';
import 'notification_log.dart';
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
              // Log without opening the app: everything usual, or say/type how the day went.
              DarwinNotificationAction.plain(allNormalAction, 'All normal'),
              DarwinNotificationAction.text(tellAction, 'Tell us about today',
                  buttonTitle: 'Log', placeholder: 'e.g. ate well, a bit tired, normal poo'),
              DarwinNotificationAction.plain('log_now', 'Open the log',
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
    // Pets load a moment after start; then add any answers left while the app was closed.
    for (var i = 0; i < 30 && !state.petsLoaded; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    await drain();
    state.addListener(_changed);
    _changed();
  }

  void _onResponse(NotificationResponse r) {
    if (r.actionId == 'later') {
      unawaited(snooze(r.payload));
      return;
    }
    final pets = payloadPets(r.payload);
    if (r.actionId == allNormalAction || r.actionId == tellAction) {
      unawaited(logFromNotification(state, r.actionId!, r.input, pets, DateTime.now()));
      return;
    }
    if (pets.isNotEmpty) onLogNow(pets.first);
  }

  /// Adds answers given on the notification while MyPet was closed.
  Future<void> drain() => drainInbox(state);

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
                  AndroidNotificationAction(allNormalAction, 'All normal'),
                  AndroidNotificationAction(tellAction, 'Tell us',
                      inputs: [AndroidNotificationActionInput(label: 'e.g. ate well, a bit tired')]),
                  AndroidNotificationAction('log_now', 'Open', showsUserInterface: true),
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
      out.add(PlannedNotification(at, 'Time to log $who day', 'Hold to answer here, or tap to open.', due.first.id, true,
          pets: [for (final p in due) p.id]));
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
        payload: p.daily ? dailyPayload(state, p.pets.isEmpty ? [p.petId] : p.pets) : p.petId,
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

/// Runs when a notification button is used while the app is closed.
@pragma('vm:entry-point')
Future<void> onBackgroundResponse(NotificationResponse r) async {
  if (r.actionId == allNormalAction || r.actionId == tellAction) {
    await saveToInbox(r.payload, r.actionId!, r.input, DateTime.now());
    return;
  }
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

  /// Every pet a daily reminder is about (it can be answered for all of them at once).
  final List<String> pets;
  const PlannedNotification(this.at, this.title, this.body, this.petId, this.daily, {this.pets = const []});
}
