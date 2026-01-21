import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/trigger.dart';
import '../services/timer_service.dart';
import '../services/storage_service.dart';

class CreateTriggerScreen extends StatefulWidget {
  const CreateTriggerScreen({super.key});

  @override
  State<CreateTriggerScreen> createState() => _CreateTriggerScreenState();
}

class _CreateTriggerScreenState extends State<CreateTriggerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _uuid = const Uuid();

  // Interval Form State
  final _intervalMinCtrl = TextEditingController();
  final _intervalSecCtrl = TextEditingController();

  // Sequence Form State
  // List of controllers for each step to handle inputs
  final List<
    ({
      TextEditingController min,
      TextEditingController sec,
      TextEditingController desc,
    })
  >
  _sequenceSteps = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _addSequenceStep(); // Start with one empty step
  }

  void _addSequenceStep() {
    setState(() {
      _sequenceSteps.add((
        min: TextEditingController(),
        sec: TextEditingController(),
        desc: TextEditingController(),
      ));
    });
  }

  void _removeSequenceStep(int index) {
    setState(() {
      _sequenceSteps.removeAt(index);
    });
  }

  // Repeat Count State
  final _intervalRepeatCtrl = TextEditingController(text: '0'); // 0 = Infinite
  final _sequenceRepeatCtrl = TextEditingController(text: '0'); // 0 = Infinite

  // Description State
  final _intervalDescCtrl = TextEditingController();
  final _sequenceDescCtrl = TextEditingController();

  @override
  void dispose() {
    _intervalMinCtrl.dispose();
    _intervalSecCtrl.dispose();
    _intervalRepeatCtrl.dispose();
    _sequenceRepeatCtrl.dispose();
    _intervalDescCtrl.dispose();
    _sequenceDescCtrl.dispose();
    for (final step in _sequenceSteps) {
      step.min.dispose();
      step.sec.dispose();
      step.desc.dispose();
    }
    _tabController.dispose();
    super.dispose();
  }

  void _saveTrigger() {
    final timerService = context.read<TimerService>();
    Trigger? newTrigger;

    if (_tabController.index == 0) {
      // Interval Mode
      final min = int.tryParse(_intervalMinCtrl.text) ?? 0;
      final sec = int.tryParse(_intervalSecCtrl.text) ?? 0;
      final totalSeconds = (min * 60) + sec;

      final repeatStr = _intervalRepeatCtrl.text;
      final repeatVal = int.tryParse(repeatStr) ?? 0;
      final repeatCount = repeatVal > 0
          ? repeatVal
          : null; // 0 means infinite -> null

      final description = _intervalDescCtrl.text.trim().isEmpty
          ? null
          : _intervalDescCtrl.text.trim();

      if (totalSeconds <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid interval duration.'),
          ),
        );
        return;
      }

      newTrigger = Trigger(
        id: _uuid.v4(),
        type: TriggerType.interval,
        intervalSeconds: totalSeconds,
        repeatCount: repeatCount,
        description: description,
      );
    } else {
      // Sequence Mode
      final List<SequenceStep> sequenceSteps = [];
      for (final step in _sequenceSteps) {
        final min = int.tryParse(step.min.text) ?? 0;
        final sec = int.tryParse(step.sec.text) ?? 0;
        final total = (min * 60) + sec;
        final desc = step.desc.text.trim().isEmpty
            ? null
            : step.desc.text.trim();

        if (total > 0) {
          sequenceSteps.add(SequenceStep(duration: total, description: desc));
        }
      }

      final repeatStr = _sequenceRepeatCtrl.text;
      final repeatVal = int.tryParse(repeatStr) ?? 0;
      final repeatCount = repeatVal > 0 ? repeatVal : null;

      final description = _sequenceDescCtrl.text.trim().isEmpty
          ? null
          : _sequenceDescCtrl.text.trim();

      if (sequenceSteps.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one valid step.')),
        );
        return;
      }

      newTrigger = Trigger(
        id: _uuid.v4(),
        type: TriggerType.sequence,
        sequenceSteps: sequenceSteps,
        sequenceRepeatCount: repeatCount,
        description: description,
      );
    }

    timerService.addTrigger(newTrigger);

    // Persist for reuse
    StorageService().saveTrigger(newTrigger);

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Trigger added and saved to library!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Trigger'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Interval'),
            Tab(text: 'Sequence'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveTrigger,
        icon: const Icon(Icons.check),
        label: const Text('Save & Add'),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildIntervalForm(), _buildSequenceForm()],
      ),
    );
  }

  Widget _buildIntervalForm() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: ListView(
        // Changed to ListView to scroll if keyboard opens
        children: [
          TextField(
            controller: _intervalDescCtrl,
            decoration: const InputDecoration(
              labelText: 'Description (Optional)',
              hintText: 'e.g., Warmup, High Intensity',
              border: OutlineInputBorder(),
            ),
          ),
          const Gap(24),
          Text('Repeat every:', style: Theme.of(context).textTheme.titleMedium),
          const Gap(16),
          Row(
            children: [
              Expanded(
                child: _TimeInput(
                  controller: _intervalMinCtrl,
                  label: 'Minutes',
                ),
              ),
              const Gap(16),
              Expanded(
                child: _TimeInput(
                  controller: _intervalSecCtrl,
                  label: 'Seconds',
                ),
              ),
            ],
          ),
          const Gap(24),
          const Divider(),
          const Gap(16),
          Text('Repetitions:', style: Theme.of(context).textTheme.titleMedium),
          const Gap(8),
          _TimeInput(
            controller: _intervalRepeatCtrl,
            label: 'Repeat Count (0 = Infinite)',
          ),
          const Gap(8),
          const Text(
            'If set to 0, this action will repeat indefinitely.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSequenceForm() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        TextField(
          controller: _sequenceDescCtrl,
          decoration: const InputDecoration(
            labelText: 'Description (Optional)',
            hintText: 'e.g., Interval Training',
            border: OutlineInputBorder(),
          ),
        ),
        const Gap(24),
        Text(
          'Custom Sequence Loop',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Gap(8),
        const Text(
          'Define a pattern of durations. The full sequence will repeat automatically.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const Gap(24),
        ..._sequenceSteps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Chip(label: Text('${index + 1}')),
                const Gap(12),
                Expanded(
                  child: Column(
                    children: [
                      TextField(
                        controller: step.desc,
                        decoration: const InputDecoration(
                          labelText: 'Step Description (Optional)',
                          hintText: 'e.g. Run, Rest',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                      const Gap(8),
                      Row(
                        children: [
                          Expanded(
                            child: _TimeInput(
                              controller: step.min,
                              label: 'Min',
                            ),
                          ),
                          const Gap(8),
                          Expanded(
                            child: _TimeInput(
                              controller: step.sec,
                              label: 'Sec',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _sequenceSteps.length > 1
                      ? () => _removeSequenceStep(index)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  color: Colors.redAccent,
                ),
              ],
            ),
          );
        }),
        ElevatedButton.icon(
          onPressed: _addSequenceStep,
          icon: const Icon(Icons.add),
          label: const Text('Add Step'),
        ),
        const Gap(24),
        const Divider(),
        const Gap(16),
        Text(
          'Sequence Repetitions:',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Gap(8),
        _TimeInput(
          controller: _sequenceRepeatCtrl,
          label: 'Loop Count (0 = Infinite)',
        ),
      ],
    );
  }
}

class _TimeInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _TimeInput({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white10,
      ),
    );
  }
}
