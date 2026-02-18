import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

enum ScheduleResult {
  scheduledExact,
  scheduledInexact,
  permissionDenied,
  initFailed,
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    await _initTimezone();

    try {
      await _initNotificationPlugin();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Notification plugin init error: $e');
    }
  }

  Future<void> _initTimezone() async {
    try {
      tz.initializeTimeZones();
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (e) {
      // Timezone lookup can fail on some devices/ROMs; keep notifications alive.
      debugPrint('Timezone init warning: $e');
      tz.setLocalLocation(tz.UTC);
    }
  }

  Future<void> _initNotificationPlugin() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    final darwinSettings = DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );

    final settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _notificationsPlugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
      },
    );
  }

  Future<void> requestPermissions() async {
    try {
      await init();

      if (Platform.isIOS) {
        await _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      } else if (Platform.isAndroid) {
        final androidImplementation = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

        final notificationsEnabled = await androidImplementation
            ?.areNotificationsEnabled();
        if (notificationsEnabled != true) {
          await androidImplementation?.requestNotificationsPermission();
        }
      }
    } catch (e) {
      debugPrint('Notification permission error: $e');
    }
  }

  Future<ScheduleResult> scheduleMonthlyReminder({
    required int id,
    required String title,
    required String body,
    required int dayOfMonth,
    required int hour,
    required int minute,
  }) async {
    final scheduledDate = _nextInstanceOfDay(dayOfMonth, hour, minute);
    return _scheduleAt(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
    );
  }

  Future<void> cancelReminder(int id) async {
    final initialized = await _ensureInitialized();
    if (!initialized) return;

    await _notificationsPlugin.cancel(id: id);
  }

  Future<ScheduleResult> _scheduleAt({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    final initialized = await _ensureInitialized();
    if (!initialized) return ScheduleResult.initFailed;

    final notificationsEnabled = await _areNotificationsEnabled();
    if (notificationsEnabled == false) return ScheduleResult.permissionDenied;

    final canScheduleExact = await _canScheduleExactNotifications();
    final scheduleMode = canScheduleExact == true
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    try {
      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'subscription_reminders',
            'Subscription Reminders',
            channelDescription: 'Reminders for upcoming subscription payments',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: scheduleMode,
        matchDateTimeComponents: matchDateTimeComponents,
      );
      return scheduleMode == AndroidScheduleMode.exactAllowWhileIdle
          ? ScheduleResult.scheduledExact
          : ScheduleResult.scheduledInexact;
    } catch (e) {
      debugPrint('Notification scheduling error: $e');
      return ScheduleResult.initFailed;
    }
  }

  Future<bool> _ensureInitialized() async {
    await init();
    return _isInitialized;
  }

  Future<bool?> _areNotificationsEnabled() async {
    try {
      if (Platform.isAndroid) {
        final androidImplementation = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await androidImplementation?.areNotificationsEnabled();
      }
      if (Platform.isIOS) {
        final iosImplementation = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        final iosPermissions = await iosImplementation?.checkPermissions();
        return iosPermissions?.isAlertEnabled ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('Notification enablement check error: $e');
      return null;
    }
  }

  Future<bool?> _canScheduleExactNotifications() async {
    if (!Platform.isAndroid) return null;

    try {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await androidImplementation?.canScheduleExactNotifications();
    } catch (e) {
      debugPrint('Exact alarm capability check error: $e');
      return null;
    }
  }

  tz.TZDateTime _nextInstanceOfDay(int day, int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    final adjustedDay = _clampDayToMonth(now.year, now.month, day);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      adjustedDay,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      final nextMonth = now.month == 12 ? 1 : now.month + 1;
      final nextYear = now.month == 12 ? now.year + 1 : now.year;
      final nextMonthAdjustedDay = _clampDayToMonth(nextYear, nextMonth, day);
      scheduledDate = tz.TZDateTime(
        tz.local,
        nextYear,
        nextMonth,
        nextMonthAdjustedDay,
        hour,
        minute,
      );
    }
    return scheduledDate;
  }

  int _clampDayToMonth(int year, int month, int day) {
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    return day.clamp(1, lastDayOfMonth);
  }
}
