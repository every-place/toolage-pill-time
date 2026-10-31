import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/format.dart';
import '../core/scheduler.dart';
import 'colors.dart';
import 'store_scope.dart';

/// Take a photo, tick the meds, save. Due meds are already ticked.
class DoseScreen extends StatefulWidget {
  const DoseScreen({super.key});

  @override
  State<DoseScreen> createState() => _DoseScreenState();
}

class _DoseScreenState extends State<DoseScreen> {
  late DateTime _takenAt;
  late List<MedStatus> _statuses;
  final _checked = <String>{};
  String? _photoPath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _takenAt = DateTime.now();
    _statuses = StoreScope.read(context).statuses(_takenAt);
    _checked.addAll(_statuses.where((s) => s.due).map((s) => s.med.id));
    WidgetsBinding.instance.addPostFrameCallback((_) => _takePhoto());
  }

  Future<void> _takePhoto() async {
    try {
      final shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 75,
      );
      if (shot != null && mounted) {
        setState(() {
          _photoPath = shot.path;
          _takenAt = DateTime.now();
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Camera not available. You can still save without a photo.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _toggle(MedStatus s) async {
    final id = s.med.id;
    if (_checked.contains(id)) {
      setState(() => _checked.remove(id));
      return;
    }
    if (s.tooEarly) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.block, color: StatusColors.tooEarly, size: 48),
          title: Text('Too early for ${s.med.name}'),
          content: Text(
            'Last dose: ${whenText(s.last, _takenAt)}\n'
            'Minimum gap: ${gapText(s.med.minGapMinutes)}\n'
            'Safe at: ${whenText(s.safeAt, _takenAt)}',
            style: const TextStyle(fontSize: 18),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Don't take it"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(
                foregroundColor: StatusColors.tooEarly,
              ),
              child: const Text('I already took it, log it'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _checked.add(id));
  }

  Future<void> _save() async {
    if (_checked.isEmpty || _saving) return;
    setState(() => _saving = true);
    final store = StoreScope.read(context);
    final entry = await store.logDose(_checked, _takenAt, _photoPath);
    store.savedMessage.value =
        'Saved ${clockText(entry.takenAt)}: ${entry.medNames.join(', ')}';
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('What did you take?')),
      body: SafeArea(
        child: Column(
          children: [
            _PhotoStrip(path: _photoPath, onRetake: _takePhoto),
            Expanded(
              child: ListView(
                children: [
                  for (final s in _statuses)
                    _MedRow(
                      status: s,
                      now: _takenAt,
                      checked: _checked.contains(s.med.id),
                      onTap: () => _toggle(s),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 84,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: StatusColors.due,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: _checked.isEmpty || _saving ? null : _save,
                  child: Text(
                    _checked.isEmpty
                        ? 'Tick what you took'
                        : 'SAVE (${_checked.length})',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.path, required this.onRetake});
  final String? path;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 96,
              height: 96,
              child: path == null
                  ? ColoredBox(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: const Icon(
                        Icons.no_photography_outlined,
                        size: 40,
                      ),
                    )
                  : Image.file(File(path!), fit: BoxFit.cover, cacheWidth: 300),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onRetake,
              icon: const Icon(Icons.photo_camera),
              label: Text(
                path == null ? 'Take photo' : 'Retake photo',
                style: const TextStyle(fontSize: 18),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MedRow extends StatelessWidget {
  const _MedRow({
    required this.status,
    required this.now,
    required this.checked,
    required this.onTap,
  });
  final MedStatus status;
  final DateTime now;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = status;
    final (String sub, Color color) = s.tooEarly
        ? (
            'TOO EARLY. Safe at ${whenText(s.safeAt, now)}',
            StatusColors.tooEarly,
          )
        : s.due
        ? ('Due now', StatusColors.due)
        : (
            'Not due until ${whenText(s.nextDue, now)}',
            Theme.of(context).colorScheme.onSurfaceVariant,
          );
    return ListTile(
      minVerticalPadding: 16,
      onTap: onTap,
      leading: Icon(
        checked ? Icons.check_circle : Icons.circle_outlined,
        size: 44,
        color: checked ? StatusColors.due : null,
      ),
      title: Text(
        s.med.name,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(sub, style: TextStyle(fontSize: 18, color: color)),
    );
  }
}
