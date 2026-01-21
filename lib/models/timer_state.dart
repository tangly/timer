import 'trigger.dart';

class TimerState {
  final int elapsedSeconds;
  final bool isRunning;
  final List<Trigger> triggers;
  final String? activeTriggerId; // To highlight active trigger in UI if needed

  TimerState({
    required this.elapsedSeconds,
    required this.isRunning,
    required this.triggers,
    this.activeTriggerId,
  });

  TimerState copyWith({
    int? elapsedSeconds,
    bool? isRunning,
    List<Trigger>? triggers,
    String? activeTriggerId,
  }) {
    return TimerState(
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      isRunning: isRunning ?? this.isRunning,
      triggers: triggers ?? this.triggers,
      activeTriggerId: activeTriggerId ?? this.activeTriggerId,
    );
  }
}
