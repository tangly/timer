import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/trigger.dart';
import '../services/timer_service.dart';
import '../services/storage_service.dart';

class CreateTriggerScreen extends StatefulWidget {
  final Trigger? triggerToEdit;
  const CreateTriggerScreen({super.key, this.triggerToEdit});

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

    if (widget.triggerToEdit != null) {
      _loadTriggerData(widget.triggerToEdit!);
    } else {
      _addSequenceStep(); // Start with one empty step
    }
  }

  void _loadTriggerData(Trigger t) {
    _selectedAction = t.action;

    if (t.type == TriggerType.interval) {
      _tabController.index = 0;
      if (t.intervalSeconds != null) {
        _intervalMinCtrl.text = (t.intervalSeconds! ~/ 60).toString();
        _intervalSecCtrl.text = (t.intervalSeconds! % 60).toString();
      }
      if (t.repeatCount != null) {
        _intervalRepeatCtrl.text = t.repeatCount.toString();
      } else {
        _intervalRepeatCtrl.text = '0';
      }
      if (t.description != null) {
        _intervalDescCtrl.text = t.description!;
      }
      // Ensure at least one sequence step exists even if not on that tab
      _addSequenceStep();
    } else {
      _tabController.index = 1;
      if (t.sequenceSteps != null) {
        for (final step in t.sequenceSteps!) {
          _sequenceSteps.add((
            min: TextEditingController(text: (step.duration ~/ 60).toString()),
            sec: TextEditingController(text: (step.duration % 60).toString()),
            desc: TextEditingController(text: step.description ?? ''),
          ));
        }
      }
      if (_sequenceSteps.isEmpty) _addSequenceStep();

      if (t.sequenceRepeatCount != null) {
        _sequenceRepeatCtrl.text = t.sequenceRepeatCount.toString();
      } else {
        _sequenceRepeatCtrl.text = '0';
      }
      if (t.description != null) {
        _sequenceDescCtrl.text = t.description!;
      }
    }
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

  // Trigger Action State
  TriggerAction _selectedAction = TriggerAction.soundAndVibrate;

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

    // If editing, use existing ID, else generate new
    final triggerId = widget.triggerToEdit?.id ?? _uuid.v4();

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
        id: triggerId,
        type: TriggerType.interval,
        action: _selectedAction,
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
        id: triggerId,
        type: TriggerType.sequence,
        action: _selectedAction,
        sequenceSteps: sequenceSteps,
        sequenceRepeatCount: repeatCount,
        description: description,
      );
    }

    if (widget.triggerToEdit != null) {
      timerService.updateTrigger(newTrigger);
    } else {
      timerService.addTrigger(newTrigger);
    }

    // Persist for reuse
    StorageService().saveTrigger(newTrigger);

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.triggerToEdit != null
              ? 'Trigger updated!'
              : 'Trigger added and saved to library!',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.triggerToEdit != null ? 'Edit Trigger' : 'New Trigger',
        ),
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
        label: Text(widget.triggerToEdit != null ? 'Update' : 'Save & Add'),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildIntervalForm(), _buildSequenceForm()],
      ),
    );
  }

  Widget _buildActionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Trigger Action:', style: Theme.of(context).textTheme.titleMedium),
        const Gap(8),
        SegmentedButton<TriggerAction>(
          segments: const [
            ButtonSegment(
              value: TriggerAction.sound,
              icon: Icon(Icons.music_note),
              label: Text('Sound'),
            ),
            ButtonSegment(
              value: TriggerAction.vibrate,
              icon: Icon(Icons.vibration),
              label: Text('Vibrate'),
            ),
            ButtonSegment(
              value: TriggerAction.soundAndVibrate,
              icon: Icon(Icons.notifications_active),
              label: Text('Both'),
            ),
          ],
          selected: {_selectedAction},
          onSelectionChanged: (Set<TriggerAction> newSelection) {
            setState(() {
              _selectedAction = newSelection.first;
            });
          },
          showSelectedIcon: false,
        ),
      ],
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
          _buildActionSelector(),
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
        _buildActionSelector(),
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
