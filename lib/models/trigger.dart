enum TriggerAction { sound, vibrate, soundAndVibrate }

enum TriggerType {
  interval, // e.g. every 3 mins
  sequence, // e.g. 1m, 1m, 3m
}

class SequenceStep {
  final int duration;
  final String? description;

  SequenceStep({required this.duration, this.description});

  Map<String, dynamic> toJson() => {
    'duration': duration,
    'description': description,
  };

  factory SequenceStep.fromJson(Map<String, dynamic> json) => SequenceStep(
    duration: json['duration'] as int,
    description: json['description'] as String?,
  );
}

class Trigger {
  final String id;
  final TriggerType type;
  final TriggerAction action;
  final bool enabled;
  final String? description; // Global description for the trigger

  // For interval triggers
  final int? intervalSeconds;
  final int? repeatCount; // null for infinite

  // For sequence triggers
  final List<SequenceStep>? sequenceSteps;
  final int? sequenceRepeatCount; // null for infinite

  Trigger({
    required this.id,
    required this.type,
    this.action = TriggerAction.soundAndVibrate,
    this.enabled = true,
    this.description,
    this.intervalSeconds,
    this.repeatCount,
    this.sequenceSteps,
    this.sequenceRepeatCount,
  });

  // Helper to check if a trigger should fire at a specific elapsed time
  bool shouldFire(int elapsedSeconds) {
    if (!enabled) return false;

    if (type == TriggerType.interval) {
      if (intervalSeconds == null || intervalSeconds! <= 0) return false;
      // Triggers at specific intervals: 1*interval, 2*interval, etc.
      if (elapsedSeconds > 0 && elapsedSeconds % intervalSeconds! == 0) {
        // Check repeat count limits
        if (repeatCount != null) {
          int occurrence = elapsedSeconds ~/ intervalSeconds!;
          if (occurrence > repeatCount!) return false;
        }
        return true;
      }
    } else if (type == TriggerType.sequence) {
      if (sequenceSteps == null || sequenceSteps!.isEmpty) return false;

      // Calculate total sequence duration
      int seqDuration = sequenceSteps!.fold(
        0,
        (sum, step) => sum + step.duration,
      );
      if (seqDuration == 0) return false;

      // Determine where we are in the sequence cycles
      int timeWithinCycle = elapsedSeconds % seqDuration;

      // If exactly 0 (end of cycle)
      if (timeWithinCycle == 0) timeWithinCycle = seqDuration;

      int runningSum = 0;
      for (final step in sequenceSteps!) {
        runningSum += step.duration;
        if (timeWithinCycle == runningSum) {
          return true;
        }
      }
    }
    return false;
  }

  // Get the current active step in the sequence based on elapsed time
  SequenceStep? getActiveSequenceStep(int elapsedSeconds) {
    if (type != TriggerType.sequence ||
        sequenceSteps == null ||
        sequenceSteps!.isEmpty) {
      return null;
    }

    int seqDuration = sequenceSteps!.fold(
      0,
      (sum, step) => sum + step.duration,
    );
    if (seqDuration == 0) return null;

    // Check total repeat count
    if (sequenceRepeatCount != null) {
      if (elapsedSeconds >= seqDuration * sequenceRepeatCount!) {
        return null; // Finished
      }
    }

    int timeWithinCycle = elapsedSeconds % seqDuration;

    int runningSum = 0;
    for (final step in sequenceSteps!) {
      runningSum += step.duration;
      // If timeWithinCycle is e.g. 0, and duration 60. 0 < 60. Returns Step 1.
      // If timeWithinCycle is 59. 59 < 60. Step 1.
      // If 60. Modulo seqDuration (say 120). 60 < 60 is false. Loop continues.
      // Next runningSum 120. 60 < 120. Step 2.
      if (timeWithinCycle < runningSum) {
        return step;
      }
    }
    return null;
  }

  int? get totalDuration {
    if (type == TriggerType.interval) {
      if (intervalSeconds == null || intervalSeconds! <= 0) return null;
      if (repeatCount == null) return null; // Infinite
      return intervalSeconds! * repeatCount!;
    } else if (type == TriggerType.sequence) {
      if (sequenceSteps == null || sequenceSteps!.isEmpty) return null;
      final seqDuration = sequenceSteps!.fold(
        0,
        (sum, step) => sum + step.duration,
      );
      if (sequenceRepeatCount == null) return null; // Infinite
      return seqDuration * sequenceRepeatCount!;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.index,
    'action': action.index,
    'enabled': enabled,
    'description': description,
    'intervalSeconds': intervalSeconds,
    'repeatCount': repeatCount,
    'sequenceSteps': sequenceSteps?.map((e) => e.toJson()).toList(),
    'sequenceRepeatCount': sequenceRepeatCount,
  };

  factory Trigger.fromJson(Map<String, dynamic> json) => Trigger(
    id: json['id'] as String,
    type: TriggerType.values[json['type'] as int],
    action: TriggerAction.values[json['action'] as int],
    enabled: json['enabled'] as bool? ?? true,
    description: json['description'] as String?,
    intervalSeconds: json['intervalSeconds'] as int?,
    repeatCount: json['repeatCount'] as int?,
    sequenceSteps: (json['sequenceSteps'] as List<dynamic>?)
        ?.map((e) => SequenceStep.fromJson(e as Map<String, dynamic>))
        .toList(),
    sequenceRepeatCount: json['sequenceRepeatCount'] as int?,
  );
}
