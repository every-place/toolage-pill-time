import 'dart:async';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/scheduler.dart';
import '../services/reminders.dart';
import 'colors.dart';
import 'dose_screen.dart';
import 'history_screen.dart';
import 'meds_screen.dart';
import 'store_scope.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Keep "due" and "too early" current while the screen is open.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
    Reminders.instance.openDoseRequested.addListener(_openFromReminder);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openFromReminder());
  }

  @override
  void dispose() {
    _tick?.cancel();
    Reminders.instance.openDoseRequested.removeListener(_openFromReminder);
    super.dispose();
  }

  /// Tapping a reminder goes straight to logging a dose.
  void _openFromReminder() {
    if (!Reminders.instance.openDoseRequested.value || !mounted) return;
    Reminders.instance.openDoseRequested.value = false;
    if (StoreScope.read(context).meds.isNotEmpty) _openDose();
  }

  Future<void> _openDose() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => const DoseScreen(),
      fullscreenDialog: true,
    ),
  );

  Future<void> _takeMeds(List<MedStatus> statuses) async {
    if (!statuses.any((s) => s.due)) {
      final next = statuses.where((s) => s.nextDue != null).toList();
      final msg = next.isEmpty
          ? 'Nothing is scheduled.'
          : 'Next: ${next.first.med.name} at ${whenText(next.first.nextDue, DateTime.now())}.';
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Nothing is due yet'),
          content: Text(msg, style: const TextStyle(fontSize: 18)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Go back'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Log a dose anyway'),
            ),
          ],
        ),
      );
      if (go != true) return;
    }
    await _openDose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final statuses = store.statuses(now);
    final anyDue = statuses.any((s) => s.due);
    final unconfirmed = store.meds
        .where((m) => m.active && !m.gapConfirmed)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pill Time'),
        leading: IconButton(
          tooltip: 'Meds',
          icon: const Icon(Icons.medication_outlined),
          onPressed: () =>
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const MedsScreen())),
        ),
        actions: [
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const HistoryScreen())),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            ValueListenableBuilder<String?>(
              valueListenable: store.savedMessage,
              builder: (context, msg, _) => msg == null
                  ? const SizedBox.shrink()
                  : MaterialBanner(
                      backgroundColor: StatusColors.due.withValues(alpha: 0.15),
                      leading: const Icon(
                        Icons.check_circle,
                        color: StatusColors.due,
                      ),
                      content: Text(msg, style: const TextStyle(fontSize: 18)),
                      actions: [
                        TextButton(
                          onPressed: () => store.savedMessage.value = null,
                          child: const Text('OK'),
                        ),
                      ],
                    ),
            ),
            if (unconfirmed > 0)
              ListTile(
                tileColor: StatusColors.warning.withValues(alpha: 0.12),
                leading: const Icon(
                  Icons.warning_amber,
                  color: StatusColors.warning,
                ),
                title: Text(
                  unconfirmed == 1
                      ? '1 med needs its minimum gap confirmed'
                      : '$unconfirmed meds need their minimum gap confirmed',
                ),
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const MedsScreen())),
              ),
            Expanded(
              child: store.meds.isEmpty
                  ? const _EmptyState()
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [for (final s in statuses) _StatusCard(s, now)],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 120,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: anyDue
                        ? StatusColors.due
                        : Colors.grey.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: store.meds.isEmpty
                      ? null
                      : () => _takeMeds(statuses),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'TAKE MEDS',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (!anyDue && store.meds.isNotEmpty)
                        const Text(
                          'nothing due yet',
                          style: TextStyle(fontSize: 16),
                        ),
                    ],
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.medication_outlined, size: 64),
          const SizedBox(height: 12),
          Text('No meds yet', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'Tap the pill icon at the top left to add your meds.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard(this.s, this.now);
  final MedStatus s;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final (String state, Color color) = s.tooEarly
        ? ('NOT YET. Safe at ${whenText(s.safeAt, now)}', StatusColors.tooEarly)
        : s.due
        ? ('DUE NOW', StatusColors.due)
        : (
            'Next: ${whenText(s.nextDue, now)}',
            Theme.of(context).colorScheme.onSurfaceVariant,
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.med.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              state,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            if (s.shifted && !s.due)
              const Text(
                'Moved later because the last dose was late',
                style: TextStyle(fontSize: 15),
              ),
            const SizedBox(height: 4),
            Text(
              'Last: ${whenText(s.last, now)}',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
