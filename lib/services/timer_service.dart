import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/timer_state.dart';
import '../models/trigger.dart';
import 'feedback_service.dart';

class TimerService extends ChangeNotifier {
  Timer? _timer;
  final FeedbackService _feedbackService = FeedbackService();

  TimerState _state = TimerState(
    elapsedSeconds: 0,
    isRunning: false,
    triggers: [],
  );

  TimerState get state => _state;

  void start() {
    if (_state.isRunning) return;

    _state = _state.copyWith(isRunning: true);
    notifyListeners();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _tick();
    });
  }

  void pause() {
    _timer?.cancel();
    _state = _state.copyWith(isRunning: false);
    notifyListeners();
  }

  void reset() {
    pause();
    _state = _state.copyWith(elapsedSeconds: 0, activeTriggerId: null);
    notifyListeners();
  }

  void addTrigger(Trigger trigger) {
    // Ideally we would ensure IDs are unique
    final triggers = List<Trigger>.from(_state.triggers)..add(trigger);
    _state = _state.copyWith(triggers: triggers);
    notifyListeners();
  }

  void clearTriggers() {
    _state = _state.copyWith(triggers: []);
    notifyListeners();
  }

  void removeTrigger(String id) {
    final triggers = List<Trigger>.from(_state.triggers)
      ..removeWhere((t) => t.id == id);
    _state = _state.copyWith(triggers: triggers);
    notifyListeners();
  }

  void _tick() {
    final newElapsed = _state.elapsedSeconds + 1;
    _state = _state.copyWith(elapsedSeconds: newElapsed);

    // Check triggers
    // We check all triggers to see if they match the current second
    String? activeId;

    for (final trigger in _state.triggers) {
      if (trigger.shouldFire(newElapsed)) {
        activeId = trigger.id;
        _feedbackService.triggerFeedback(trigger.action);
        // For now, we only highlight the last fired trigger if multiple fire at once
      }
    }

    // Clear active ID if we want it to be transient,
    // OR keep it until next second?
    // Let's keep it transient for this tick update.
    _state = _state.copyWith(activeTriggerId: activeId);

    // Auto-stop logic
    // Determine the maximum finite duration required by current triggers
    // If ANY trigger is infinite, we do NOT auto-stop (unless we only want to follow the longest finite one? Safe bet is infinite)
    int maxDuration = 0;
    bool hasInfinite = false;

    if (_state.triggers.isNotEmpty) {
      for (final t in _state.triggers) {
        final duration = t.totalDuration;
        if (duration == null) {
          hasInfinite = true;
          break; // One infinite trigger means the timer runs forever
        }
        if (duration > maxDuration) {
          maxDuration = duration;
        }
      }

      // If we have no infinite triggers, and we've reached the max duration, stop.
      if (!hasInfinite && maxDuration > 0 && newElapsed >= maxDuration) {
        pause();
      }
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
