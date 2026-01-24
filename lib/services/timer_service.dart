import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/timer_state.dart';
import '../models/trigger.dart';
import 'feedback_service.dart';

class TimerService extends ChangeNotifier with WidgetsBindingObserver {
  Timer? _timer;
  final FeedbackService _feedbackService = FeedbackService();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  DateTime? _lastTickTime;

  TimerState _state = TimerState(
    elapsedSeconds: 0,
    isRunning: false,
    triggers: [],
  );

  TimerState get state => _state;

  TimerService() {
    WidgetsBinding.instance.addObserver(this);
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _notificationsPlugin.initialize(settings);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleAppResumed();
    } else if (state == AppLifecycleState.paused) {
      _handleAppPaused();
    }
  }

  void _handleAppResumed() {
    if (_state.isRunning && _lastTickTime != null) {
      final now = DateTime.now();
      final diff = now.difference(_lastTickTime!).inSeconds;
      if (diff > 0) {
        final newElapsed = _state.elapsedSeconds + diff;
        _state = _state.copyWith(elapsedSeconds: newElapsed);
        _lastTickTime = now;
        notifyListeners();
      }
    }
  }

  void _handleAppPaused() {
    // No specific action needed on pause, notifications are scheduled at start/update
  }

  void start() {
    if (_state.isRunning) return;

    _state = _state.copyWith(isRunning: true);
    notifyListeners();

    WakelockPlus.enable();
    _scheduleNotifications();
    _lastTickTime = DateTime.now();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _tick();
    });
  }

  void pause() {
    _timer?.cancel();
    _state = _state.copyWith(isRunning: false);
    notifyListeners();
    WakelockPlus.disable();
    _cancelNotifications();
  }

  void reset() {
    pause();
    _state = _state.copyWith(elapsedSeconds: 0, activeTriggerId: null);
    notifyListeners();
  }

  void addTrigger(Trigger trigger) {
    final triggers = List<Trigger>.from(_state.triggers)..add(trigger);
    _state = _state.copyWith(triggers: triggers);
    if (_state.isRunning) {
      _cancelNotifications();
      _scheduleNotifications();
    }
    notifyListeners();
  }

  void clearTriggers() {
    _state = _state.copyWith(triggers: []);
    if (_state.isRunning) _cancelNotifications();
    notifyListeners();
  }

  void removeTrigger(String id) {
    final triggers = List<Trigger>.from(_state.triggers)
      ..removeWhere((t) => t.id == id);
    _state = _state.copyWith(triggers: triggers);
    if (_state.isRunning) {
      _cancelNotifications();
      _scheduleNotifications();
    }
    notifyListeners();
  }

  void _tick() {
    final now = DateTime.now();
    _lastTickTime = now;

    final newElapsed = _state.elapsedSeconds + 1;
    _state = _state.copyWith(elapsedSeconds: newElapsed);

    String? activeId;

    for (final trigger in _state.triggers) {
      if (trigger.shouldFire(newElapsed)) {
        activeId = trigger.id;
        _feedbackService.triggerFeedback(trigger.action);
      }
    }

    _state = _state.copyWith(activeTriggerId: activeId);

    // Auto-stop logic
    int maxDuration = 0;
    bool hasInfinite = false;

    if (_state.triggers.isNotEmpty) {
      for (final t in _state.triggers) {
        final duration = t.totalDuration;
        if (duration == null) {
          hasInfinite = true;
          break;
        }
        if (duration > maxDuration) {
          maxDuration = duration;
        }
      }

      if (!hasInfinite && maxDuration > 0 && newElapsed >= maxDuration) {
        pause();
      }
    }

    notifyListeners();
  }

  Future<void> _scheduleNotifications() async {
    final now = DateTime.now();
    int scheduledCount = 0;
    int tempElapsed = _state.elapsedSeconds;

    List<Map<String, dynamic>> futureEvents = [];

    for (final trigger in _state.triggers) {
      if (!trigger.enabled) continue;

      if (trigger.type == TriggerType.interval) {
        if (trigger.intervalSeconds == null || trigger.intervalSeconds! <= 0) {
          continue;
        }

        int startFactor = (tempElapsed ~/ trigger.intervalSeconds!) + 1;

        int count = 0;
        while (scheduledCount + count < 50) {
          int nextSeconds = startFactor * trigger.intervalSeconds!;
          if (trigger.repeatCount != null &&
              startFactor > trigger.repeatCount!) {
            break;
          }

          int relativeSeconds = nextSeconds - tempElapsed;
          if (relativeSeconds > 0) {
            futureEvents.add({
              'secondsFromNow': relativeSeconds,
              'trigger': trigger,
            });
          }
          startFactor++;
          count++;
          if (count > 100) break;
        }
      } else if (trigger.type == TriggerType.sequence) {
        if (trigger.sequenceSteps == null || trigger.sequenceSteps!.isEmpty) {
          continue;
        }

        final steps = trigger.sequenceSteps!;
        int seqDuration = steps.fold(0, (sum, step) => sum + step.duration);
        if (seqDuration == 0) continue;

        int currentCycle = tempElapsed ~/ seqDuration;

        int count = 0;
        while (scheduledCount + count < 50) {
          int cycleStart = currentCycle * seqDuration;
          int runningSum = 0;
          for (final step in steps) {
            runningSum += step.duration;
            int fireTime = cycleStart + runningSum;

            if (trigger.sequenceRepeatCount != null &&
                currentCycle >= trigger.sequenceRepeatCount!) {
              break;
            }

            int relativeSeconds = fireTime - tempElapsed;
            if (relativeSeconds > 0) {
              futureEvents.add({
                'secondsFromNow': relativeSeconds,
                'trigger': trigger,
              });
            }
          }
          if (trigger.sequenceRepeatCount != null &&
              currentCycle >= trigger.sequenceRepeatCount!) {
            break;
          }

          currentCycle++;
          count++;
          if (count > 50) break;
        }
      }
    }

    futureEvents.sort(
      (a, b) =>
          (a['secondsFromNow'] as int).compareTo(b['secondsFromNow'] as int),
    );

    if (futureEvents.length > 50) {
      futureEvents = futureEvents.sublist(0, 50);
    }

    int idCounter = 0;
    for (final event in futureEvents) {
      final sec = event['secondsFromNow'] as int;
      final trig = event['trigger'] as Trigger;

      String body = "Timer Alert!";
      if (trig.description != null && trig.description!.isNotEmpty) {
        body = trig.description!;
      } else if (trig.type == TriggerType.sequence) {
        body = "Sequence Step Complete";
      }

      await _notificationsPlugin.zonedSchedule(
        idCounter++,
        'Timer',
        body,
        tz.TZDateTime.from(now.add(Duration(seconds: sec)), tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'timer_channel',
            'Timer Notifications',
            channelDescription: 'Notifications for timer triggers',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        // uiLocalNotificationDateInterpretation:
        //     UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  Future<void> _cancelNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    super.dispose();
  }
}
