import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/trigger.dart';
import '../services/timer_service.dart';
import '../services/storage_service.dart';
import '../screens/create_trigger_screen.dart';

class SequenceConfigSheet extends StatefulWidget {
  const SequenceConfigSheet({super.key});

  @override
  State<SequenceConfigSheet> createState() => _SequenceConfigSheetState();
}

class _SequenceConfigSheetState extends State<SequenceConfigSheet> {
  @override
  void initState() {
    super.initState();
    _loadSavedTriggers();
  }

  List<Trigger> _savedTriggers = [];

  Future<void> _loadSavedTriggers() async {
    final triggers = await StorageService().loadSavedTriggers();
    if (mounted) {
      setState(() {
        _savedTriggers = triggers;
      });
    }
  }

  void _addSavedTrigger(Trigger t) {
    final timerService = context.read<TimerService>();
    // Create a copy with new ID so we can add multiple times?
    // Or reuse ID? If reuse, removing one might remove others if logic relies on ID.
    // TimerService uses ID to remove. So we MUST regenerate ID.
    final newId = const Uuid().v4();

    Trigger newTrigger;
    if (t.type == TriggerType.interval) {
      newTrigger = Trigger(
        id: newId,
        type: t.type,
        action: t.action,
        enabled: t.enabled,
        description: t.description,
        intervalSeconds: t.intervalSeconds,
        repeatCount: t.repeatCount,
      );
    } else {
      newTrigger = Trigger(
        id: newId,
        type: t.type,
        action: t.action,
        enabled: t.enabled,
        description: t.description,
        sequenceSteps: t
            .sequenceSteps, // Reference same steps list is fine as they are immutable-ish or we don't modify them in place
        sequenceRepeatCount: t.sequenceRepeatCount,
      );
    }

    timerService.addTrigger(newTrigger);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added "${t.description ?? "Saved Trigger"}"')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      height: MediaQuery.of(context).size.height * 0.8, // Taller sheet
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add Trigger',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const Gap(20),

          Expanded(
            child: ListView(
              children: [
                if (_savedTriggers.isNotEmpty) ...[
                  const Text(
                    'Saved Library',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const Gap(8),
                  ..._savedTriggers
                      .map(
                        (t) => ListTile(
                          title: Text(t.description ?? 'Untitled Trigger'),
                          subtitle: Text(
                            t.type == TriggerType.interval
                                ? 'Interval: ${t.intervalSeconds}s'
                                : 'Sequence: ${t.sequenceSteps?.length ?? 0} steps',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, size: 20),
                            onPressed: () async {
                              await StorageService().deleteTrigger(t.id);
                              _loadSavedTriggers();
                            },
                          ),
                          onTap: () => _addSavedTrigger(t),
                          tileColor: Colors.white10,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      )
                      ,
                  const Gap(8),
                  const Divider(),
                  const Gap(8),
                ],

                
              ],
            ),
          ),

          const Gap(12),
          const Divider(),
          const Gap(12),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context); // Close sheet
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateTriggerScreen()),
              );
            },
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Create Custom Trigger...'),
          ),
          const Gap(20),
        ],
      ),
    );
  }
}
