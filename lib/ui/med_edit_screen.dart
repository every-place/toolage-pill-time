import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../services/store.dart';
import 'fda_lookup_screen.dart';
import 'store_scope.dart';

/// Add or edit a med. Saving always asks the person to confirm the minimum
/// gap when it is new or has changed.
class MedEditScreen extends StatefulWidget {
  const MedEditScreen({super.key, this.med});
  final Med? med;

  @override
  State<MedEditScreen> createState() => _MedEditScreenState();
}

class _MedEditScreenState extends State<MedEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _notes;
  late bool _useTimes;
  late double _hours;
  late List<ClockTime> _times;
  late int _gapMinutes;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final m = widget.med;
    _name = TextEditingController(text: m?.name ?? '');
    _notes = TextEditingController(text: m?.notes ?? '');
    _active = m?.active ?? true;
    _gapMinutes = m?.minGapMinutes ?? 0;
    switch (m?.schedule) {
      case TimesSchedule(:final times):
        _useTimes = true;
        _times = [...times];
        _hours = 12;
      case IntervalSchedule(:final hours):
        _useTimes = false;
        _hours = hours;
        _times = [const ClockTime(8, 0)];
      case null:
        _useTimes = false;
        _hours = 6;
        _times = [const ClockTime(8, 0)];
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final minutes = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => FdaLookupScreen(query: _name.text.trim()),
      ),
    );
    if (minutes == null) return;
    setState(() {
      _gapMinutes = minutes;
      if (!_useTimes) _hours = minutes / 60;
    });
  }

  Future<void> _addTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (t == null) return;
    setState(() => _times = [..._times, ClockTime(t.hour, t.minute)]..sort());
  }

  Future<void> _changeTime(int i) async {
    final cur = _times[i];
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: cur.hour, minute: cur.minute),
    );
    if (t == null) return;
    setState(() {
      _times = [..._times]
        ..[i] = ClockTime(t.hour, t.minute)
        ..sort();
    });
  }

  void _error(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return _error('Enter the med name.');
    if (_useTimes && _times.isEmpty) {
      return _error('Add at least one clock time.');
    }
    if (_gapMinutes <= 0) return _error('Set a minimum gap between doses.');

    final old = widget.med;
    var confirmedAt = old?.gapConfirmedAt;
    final gapChanged = old == null || old.minGapMinutes != _gapMinutes;
    if (gapChanged || confirmedAt == null) {
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm minimum gap'),
          content: Text(
            'Minimum time between doses of $name is ${gapText(_gapMinutes)}.\n\n'
            'Check this against the prescription label. Pill Time will never '
            'schedule the next dose sooner than this.',
            style: const TextStyle(fontSize: 18),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Go back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Yes, ${gapText(_gapMinutes)} is correct'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      confirmedAt = DateTime.now();
    }

    final med = Med(
      id: old?.id ?? Store.newId(),
      name: name,
      schedule: _useTimes ? TimesSchedule(_times) : IntervalSchedule(_hours),
      minGapMinutes: _gapMinutes,
      gapConfirmedAt: confirmedAt,
      active: _active,
      notes: _notes.text.trim(),
    );
    await StoreScope.read(context).upsertMed(med);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final med = widget.med!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${med.name}?'),
        content: const Text('Past doses stay in the history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await StoreScope.read(context).deleteMed(med);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final big = Theme.of(context).textTheme.titleLarge;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.med == null ? 'Add a med' : 'Edit med'),
        actions: [
          if (widget.med != null)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          TextButton(
            onPressed: _save,
            child: const Text('Save', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Med name',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _name.text.trim().isEmpty ? null : _lookup,
            icon: const Icon(Icons.search),
            label: const Text('Look up the FDA label'),
          ),
          const SizedBox(height: 24),
          Text('Schedule', style: big),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Every X hours')),
              ButtonSegment(value: true, label: Text('Clock times')),
            ],
            selected: {_useTimes},
            onSelectionChanged: (v) => setState(() => _useTimes = v.first),
          ),
          const SizedBox(height: 8),
          if (!_useTimes)
            _Stepper(
              label: 'Every ${hoursText(_hours)} hours',
              onMinus: _hours > 0.5
                  ? () => setState(() => _hours -= 0.5)
                  : null,
              onPlus: _hours < 72 ? () => setState(() => _hours += 0.5) : null,
            )
          else ...[
            for (final (i, t) in _times.indexed)
              ListTile(
                title: Text(clockTimeText(t), style: big),
                onTap: () => _changeTime(i),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () =>
                      setState(() => _times = [..._times]..removeAt(i)),
                ),
              ),
            TextButton.icon(
              onPressed: _addTime,
              icon: const Icon(Icons.add),
              label: const Text('Add a time'),
            ),
          ],
          const SizedBox(height: 24),
          Text('Minimum gap between doses', style: big),
          const Text(
            'The next dose is never scheduled sooner than this, even if '
            'a dose was taken late.',
          ),
          const SizedBox(height: 8),
          _Stepper(
            label: _gapMinutes == 0 ? 'Not set' : gapText(_gapMinutes),
            onMinus: _gapMinutes >= 15
                ? () => setState(() => _gapMinutes -= 15)
                : null,
            onPlus: () => setState(() => _gapMinutes += 15),
            onLongMinus: _gapMinutes >= 60
                ? () => setState(() => _gapMinutes -= 60)
                : null,
            onLongPlus: () => setState(() => _gapMinutes += 60),
            hint: 'Tap for 15 minutes, hold for 1 hour',
          ),
          if (widget.med?.gapConfirmedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Confirmed ${whenText(widget.med!.gapConfirmedAt, DateTime.now())}',
              ),
            ),
          const SizedBox(height: 24),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Active'),
            subtitle: const Text('Turn off to pause reminders for this med'),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.onMinus,
    required this.onPlus,
    this.onLongMinus,
    this.onLongPlus,
    this.hint,
  });

  final String label;
  final VoidCallback? onMinus, onPlus, onLongMinus, onLongPlus;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            GestureDetector(
              onLongPress: onLongMinus,
              child: IconButton.filledTonal(
                iconSize: 32,
                onPressed: onMinus,
                icon: const Icon(Icons.remove),
              ),
            ),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            GestureDetector(
              onLongPress: onLongPlus,
              child: IconButton.filledTonal(
                iconSize: 32,
                onPressed: onPlus,
                icon: const Icon(Icons.add),
              ),
            ),
          ],
        ),
        if (hint != null)
          Text(hint!, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
