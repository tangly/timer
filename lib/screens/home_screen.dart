import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:gap/gap.dart';
import '../models/trigger.dart'; // Added import
import '../services/timer_service.dart';
import 'create_trigger_screen.dart';
import '../widgets/timer_controls.dart';
import '../widgets/sequence_config_sheet.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final timerService = context.watch<TimerService>();
    final state = timerService.state;

    // Format time MM:SS
    final minutes = (state.elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (state.elapsedSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sequence Timer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (_) => const SequenceConfigSheet(),
                isScrollControlled: true,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // Timer Display
            Text(
              '$minutes:$seconds',
              style: GoogleFonts.outfit(
                fontSize: 90,
                fontWeight: FontWeight.w200,
                color: Colors.white,
                fontFeatures: [const FontFeature.tabularFigures()],
              ),
            ),
            const Text(
              'ELAPSED TIME',
              style: TextStyle(letterSpacing: 2, color: Colors.grey),
            ),

            // Current Step Display
            if (state.isRunning && state.triggers.isNotEmpty)
              Builder(
                builder: (context) {
                  // Find the primary sequence trigger to show status for
                  // Or show multiple? Let's pick the first sequence or interval.
                  // Prioritize Sequence as it has named steps.
                  final seqTrigger = state.triggers.cast<Trigger?>().firstWhere(
                    (t) => t?.type == TriggerType.sequence,
                    orElse: () => null,
                  );

                  if (seqTrigger != null) {
                    final step = seqTrigger.getActiveSequenceStep(
                      state.elapsedSeconds,
                    );
                    if (step != null &&
                        step.description != null &&
                        step.description!.isNotEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 20.0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            step.description!,
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                      );
                    }
                  }
                  return const SizedBox.shrink();
                },
              ),

            const Spacer(),

            // Trigger List Summary
            if (state.triggers.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Active Triggers',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.clear_all, size: 20),
                          onPressed: timerService.clearTriggers,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24),
                    ...state.triggers.map((t) {
                      String label = 'Unknown Trigger';

                      if (t.type == TriggerType.interval &&
                          t.intervalSeconds != null) {
                        label =
                            'Every ${t.intervalSeconds! ~/ 60}m ${t.intervalSeconds! % 60}s';
                      } else if (t.type == TriggerType.sequence &&
                          t.sequenceSteps != null) {
                        label =
                            'Seq: ${t.sequenceSteps!.map((s) {
                              final duration = '${s.duration ~/ 60}m ${s.duration % 60}s';
                              return s.description != null && s.description!.isNotEmpty ? '${s.description} ($duration)' : duration;
                            }).join(', ')}';
                      }

                      final isActive = t.id == state.activeTriggerId;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CreateTriggerScreen(triggerToEdit: t),
                                  ),
                                );
                              },
                              child: Icon(
                                isActive
                                    ? Icons.notifications_active
                                    : Icons.notifications_outlined,
                                color: isActive ? Colors.amber : Colors.grey,
                                size: 16,
                              ),
                            ),
                            const Gap(8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (t.description != null &&
                                      t.description!.isNotEmpty)
                                    Text(
                                      t.description!,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color:
                                          (t.description != null &&
                                              t.description!.isNotEmpty)
                                          ? Colors.white70
                                          : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white38,
                              ),
                              onPressed: () => timerService.removeTrigger(t.id),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

            const Spacer(),
            const TimerControls(),
            const Gap(40),
          ],
        ),
      ),
    );
  }
}
