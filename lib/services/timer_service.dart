import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../models/timer_state.dart';
import '../models/trigger.dart';

class TimerService extends ChangeNotifier with WidgetsBindingObserver {
  TimerState _state = TimerState(
    elapsedSeconds: 0,
    isRunning: false,
    triggers: [],
  );

  TimerState get state => _state;

  TimerService() {
    WidgetsBinding.instance.addObserver(this);
    _initServiceListener();
  }

  void _initServiceListener() {
    FlutterBackgroundService().on('update').listen((event) {
      if (event != null && event.containsKey('elapsedSeconds')) {
        final int newElapsed = event['elapsedSeconds'] as int;
        if (_state.elapsedSeconds != newElapsed) {
          _state = _state.copyWith(elapsedSeconds: newElapsed);
          notifyListeners();
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // We can use this to sync if needed, but the stream listener handles updates.
  }

  Future<void> start() async {
    if (_state.isRunning) return;

    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      await service.startService();
      // Give the isolate time to spin up and register listeners
      await Future.delayed(const Duration(seconds: 1));
    }

    // Send current state to ensure sync
    service.invoke('startTimer', {
      'elapsedSeconds': _state.elapsedSeconds,
      'triggers': _state.triggers.map((e) => e.toJson()).toList(),
    });

    _state = _state.copyWith(isRunning: true);
    notifyListeners();
  }

  void pause() {
    final service = FlutterBackgroundService();
    service.invoke('pauseTimer');
    _state = _state.copyWith(isRunning: false);
    notifyListeners();
  }

  void reset() {
    final service = FlutterBackgroundService();
    service.invoke('resetTimer');
    _state = _state.copyWith(
      elapsedSeconds: 0,
      activeTriggerId: null,
      isRunning: false,
    );
    notifyListeners();
  }

  void addTrigger(Trigger trigger) {
    final triggers = List<Trigger>.from(_state.triggers)..add(trigger);
    _state = _state.copyWith(triggers: triggers);
    _syncTriggers();
    notifyListeners();
  }

  void clearTriggers() {
    _state = _state.copyWith(triggers: []);
    _syncTriggers();
    notifyListeners();
  }

  void removeTrigger(String id) {
    final triggers = List<Trigger>.from(_state.triggers)
      ..removeWhere((t) => t.id == id);
    _state = _state.copyWith(triggers: triggers);
    _syncTriggers();
    notifyListeners();
  }

  void updateTrigger(Trigger updatedTrigger) {
    final triggers = List<Trigger>.from(_state.triggers);
    final index = triggers.indexWhere((t) => t.id == updatedTrigger.id);
    if (index != -1) {
      triggers[index] = updatedTrigger;
      _state = _state.copyWith(triggers: triggers);
      _syncTriggers();
      notifyListeners();
    }
  }

  void _syncTriggers() {
    FlutterBackgroundService().invoke('setTriggers', {
      'triggers': _state.triggers.map((e) => e.toJson()).toList(),
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
