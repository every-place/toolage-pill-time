import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/scheduler.dart';

/// Sets loud alarms and follow-up reminders for upcoming doses.
///
/// - iPhone (iOS 26+): real system alarms through AlarmKit, using a small
///   bridge in ios/Runner/AppDelegate.swift. Older iPhones get notifications.
/// - Android: alarm-clock notifications that use the alarm sound, keep ringing
///   until dismissed, and can show full screen over the lock screen.
///
/// Everything is cleared and rebuilt after each change, so a late dose moves
/// every alarm that follows it.
class Reminders {
  Reminders._();
  static final instance = Reminders._();

  static const _alarmChannel = MethodChannel('pilltime/alarms');
  final _notes = FlutterLocalNotificationsPlugin();

  /// Follow-up reminders after a dose is due, in case it still isn't logged.
  static const nagMinutes = [10, 20, 30];
  static const maxGroups = 8;

  /// Set when the person taps a reminder, so the app can open the dose screen.
  final openDoseRequested = ValueNotifier<bool>(false);

  bool iosAlarmsSupported = false;
  bool? alarmsAllowed;
  bool? notificationsAllowed;

  Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Falls back to UTC math, which is still correct for absolute times.
    }

    await _notes.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (_) => openDoseRequested.value = true,
    );
    final launch = await _notes.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      openDoseRequested.value = true;
    }

    if (Platform.isIOS) {
      try {
        iosAlarmsSupported =
            await _alarmChannel.invokeMethod<bool>('isSupported') ?? false;
      } catch (_) {
        iosAlarmsSupported = false;
      }
    }
  }

  Future<void> requestPermissions() async {
    if (Platform.isIOS) {
      notificationsAllowed = await _notes
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, sound: true, badge: true);
      if (iosAlarmsSupported) {
        alarmsAllowed = await _alarmChannel.invokeMethod<bool>(
          'requestAuthorization',
        );
      }
    } else if (Platform.isAndroid) {
      final android = _notes
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      notificationsAllowed = await android?.requestNotificationsPermission();
      if (!(await android?.canScheduleExactNotifications() ?? true)) {
        await android?.requestExactAlarmsPermission();
      }
      await android?.requestFullScreenIntentPermission();
      alarmsAllowed = await android?.canScheduleExactNotifications();
    }
  }

  Future<void> reschedule(List<MedStatus> statuses) async {
    final now = DateTime.now();
    final groups = upcomingAlerts(statuses, now).take(maxGroups).toList();
    await _notes.cancelAll();

    var iosAlarmsSet = false;
    if (Platform.isIOS && iosAlarmsSupported) {
      try {
        iosAlarmsSet =
            await _alarmChannel.invokeMethod<bool>('reschedule', [
              for (final g in groups)
                {
                  'time': g.time.millisecondsSinceEpoch,
                  'title': 'Meds: ${g.names.join(', ')}',
                },
            ]) ??
            false;
        alarmsAllowed = iosAlarmsSet;
      } catch (e) {
        debugPrint('Alarm scheduling failed: $e');
      }
    }

    var id = 0;
    for (final g in groups) {
      final names = g.names.join(', ');
      // With iPhone alarms on, the alarm covers the due time and notifications
      // only follow up afterwards.
      if (!iosAlarmsSet) {
        await _schedule(id++, 'Time for your meds', names, g.time, alarm: true);
      }
      for (final m in nagMinutes) {
        await _schedule(
          id++,
          'Still need to log your meds',
          names,
          g.time.add(Duration(minutes: m)),
        );
      }
    }
  }

  Future<void> _schedule(
    int id,
    String title,
    String body,
    DateTime when, {
    bool alarm = false,
  }) async {
    final android = alarm
        ? AndroidNotificationDetails(
            'dose_alarm',
            'Dose alarms',
            channelDescription: 'Loud alarm when a dose is due',
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            fullScreenIntent: true,
            audioAttributesUsage: AudioAttributesUsage.alarm,
            sound: const UriAndroidNotificationSound(
              'content://settings/system/alarm_alert',
            ),
            // FLAG_INSISTENT: keep ringing until the alarm is dismissed.
            additionalFlags: Int32List.fromList(<int>[4]),
            visibility: NotificationVisibility.public,
            autoCancel: true,
          )
        : const AndroidNotificationDetails(
            'dose_followup',
            'Follow-up reminders',
            channelDescription: 'Reminders when a due dose has not been logged',
            importance: Importance.high,
            priority: Priority.high,
          );
    final ios = DarwinNotificationDetails(
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );
    try {
      await _notes.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: NotificationDetails(android: android, iOS: ios),
        androidScheduleMode: alarm
            ? AndroidScheduleMode.alarmClock
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      // Usually a missing exact-alarm permission on Android; fall back.
      debugPrint('Could not schedule reminder: $e');
      if (alarm) {
        await _notes.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tz.TZDateTime.from(when, tz.local),
          notificationDetails: NotificationDetails(android: android, iOS: ios),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    }
  }
}
