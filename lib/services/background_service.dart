import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/trigger.dart';
import 'feedback_service.dart';

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Only available for flutter 3.0.0 and later
  // Only available for flutter 3.0.0 and later
  try {
    DartPluginRegistrant.ensureInitialized();
  } catch (e) {
    // Calling ensureInitialized can throw if flutter_background_service_android
    // tries to register itself in the background isolate. We can ignore this
    // specific error as long as other plugins (like local_notifications) work.
    // print('Plugin registration error: $e');
  }

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Bring to foreground
  Timer? timer;
  int elapsedSeconds = 0;
  List<Trigger> triggers = [];

  service.on('setAsForeground').listen((event) {
    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
    }
  });

  service.on('setAsBackground').listen((event) {
    if (service is AndroidServiceInstance) {
      service.setAsBackgroundService();
    }
  });

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  service.on('setTriggers').listen((event) {
    if (event != null && event['triggers'] != null) {
      final List<dynamic> jsonList = event['triggers'];
      triggers = jsonList
          .map((e) => Trigger.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
  });

  service.on('startTimer').listen((event) {
    if (timer != null && timer!.isActive) return;
    elapsedSeconds = event?['elapsedSeconds'] ?? 0;
    // Also update triggers if passed
    if (event != null && event['triggers'] != null) {
      final List<dynamic> jsonList = event['triggers'];
      triggers = jsonList
          .map((e) => Trigger.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      elapsedSeconds++;

      // Helper to check triggers
      String? activeTriggerDescription;
      for (final trigger in triggers) {
        if (trigger.shouldFire(elapsedSeconds)) {
          // Fire!
          String body = "Timer Alert!";
          if (trigger.description != null && trigger.description!.isNotEmpty) {
            body = trigger.description!;
            activeTriggerDescription = body;
          } else if (trigger.type == TriggerType.sequence) {
            // Try to find the step description if possible or generic
            body = "Sequence Step Complete";
          }

          // Trigger custom feedback
          FeedbackService().triggerFeedback(trigger.action);

          flutterLocalNotificationsPlugin.show(
            1000 + elapsedSeconds, // Unique ID per second/trigger
            'Timer Alert',
            body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                'timer_channel',
                'Timer Notifications',
                channelDescription: 'Notifications for timer triggers',
                importance: Importance.max,
                priority: Priority.high,
                playSound: false, // Handled by FeedbackService
                enableVibration: false, // Handled by FeedbackService
              ),
              iOS: DarwinNotificationDetails(
                presentSound: false, // Handled by FeedbackService
                presentAlert: true,
                presentBanner: true,
              ),
            ),
          );
        }
      }

      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          flutterLocalNotificationsPlugin.show(
            888,
            'Timer Running',
            activeTriggerDescription != null
                ? 'Last: $activeTriggerDescription'
                : 'Elapsed: ${elapsedSeconds}s',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'timer_foreground',
                'Timer Service',
                icon: 'ic_bg_service_small',
                ongoing: true,
                playSound: false,
                enableVibration: false,
              ),
            ),
          );
        }
      }

      service.invoke('update', {'elapsedSeconds': elapsedSeconds});
    });
  });

  service.on('pauseTimer').listen((event) {
    timer?.cancel();
  });

  service.on('resetTimer').listen((event) {
    timer?.cancel();
    elapsedSeconds = 0;
    service.invoke('update', {'elapsedSeconds': elapsedSeconds});
  });

  service.on('updateState').listen((event) {
    // In case we want to sync state from UI to Service more complexly later
    if (event != null && event.containsKey('elapsedSeconds')) {
      elapsedSeconds = event['elapsedSeconds'] as int;
    }
  });

  service.invoke('serviceReady');
}

class BackgroundService {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    /// OPTIONAL, using custom notification channel id
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'timer_foreground', // id
      'Timer Service', // title
      description:
          'This channel is used for important notifications.', // description
      importance: Importance.low, // importance must be at low or higher level
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    if (Platform.isAndroid) {
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(channel);
        await androidPlugin.requestNotificationsPermission();
      }
    }

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        // this will be executed when app is in foreground or background in separated isolate
        onStart: onStart,

        // auto start service
        autoStart: false,
        isForegroundMode: true,

        notificationChannelId: 'timer_foreground',
        initialNotificationTitle: 'Timer Service',
        initialNotificationContent: 'Initializing',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        // auto start service
        autoStart: false,

        // this will be executed when app is in foreground in separated isolate
        onForeground: onStart,

        // you have to enable background fetch capability on xcode project
        onBackground: onIosBackground,
      ),
    );
  }
}
