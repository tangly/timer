import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import '../services/timer_service.dart';

class TimerControls extends StatelessWidget {
  const TimerControls({super.key});

  @override
  Widget build(BuildContext context) {
    final timerService = context.watch<TimerService>();
    final isRunning = timerService.state.isRunning;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (timerService.state.elapsedSeconds > 0) ...[
          FloatingActionButton(
            onPressed: timerService.reset,
            backgroundColor: Colors.grey[800],
            heroTag: 'reset',
            child: const Icon(Icons.refresh, color: Colors.white),
          ).animate().scale(),
          const Gap(20),
        ],
        FloatingActionButton.large(
          onPressed: isRunning ? timerService.pause : timerService.start,
          backgroundColor: isRunning ? Colors.amber[900] : Colors.green[600],
          foregroundColor: Colors.white,
          heroTag: 'play_pause',
          child: Icon(isRunning ? Icons.pause : Icons.play_arrow),
        ).animate().scale(),
      ],
    );
  }
}
