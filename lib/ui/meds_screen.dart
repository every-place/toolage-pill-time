import 'package:flutter/material.dart';

import '../core/models.dart';

import '../core/format.dart';
import '../services/reminders.dart';
import 'colors.dart';
import 'med_edit_screen.dart';
import 'store_scope.dart';

class MedsScreen extends StatefulWidget {
  const MedsScreen({super.key});

  @override
  State<MedsScreen> createState() => _MedsScreenState();
}

class _MedsScreenState extends State<MedsScreen> {
  void _edit([Med? med]) =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => MedEditScreen(med: med)));

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final r = Reminders.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Meds')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Add a med'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          for (final m in store.meds)
            ListTile(
              onTap: () => _edit(m),
              title: Text(
                m.active ? m.name : '${m.name} (off)',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                '${scheduleText(m.schedule)}\n'
                'Minimum gap: ${gapText(m.minGapMinutes)}'
                '${m.gapConfirmed ? '' : '  (not confirmed)'}',
                style: TextStyle(
                  fontSize: 16,
                  color: m.gapConfirmed ? null : StatusColors.warning,
                ),
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
            ),
          if (store.meds.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No meds yet. Tap "Add a med".',
                style: TextStyle(fontSize: 18),
              ),
            ),
          const Divider(height: 32),
          ListTile(
            leading: Icon(
              r.alarmsAllowed == true ? Icons.alarm_on : Icons.alarm_off,
              color: r.alarmsAllowed == true
                  ? StatusColors.due
                  : StatusColors.warning,
            ),
            title: Text(
              r.alarmsAllowed == true
                  ? 'Alarms are on'
                  : 'Alarms are not allowed yet',
            ),
            subtitle: const Text(
              'Tap to ask again. If nothing happens, allow alarms and '
              'notifications for Pill Time in the phone\'s Settings.',
            ),
            onTap: () async {
              await r.requestPermissions();
              await r.reschedule(store.statuses());
              setState(() {});
            },
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Pill Time is a reminder and log, not medical advice. Always follow the '
              'prescription, and check every minimum gap with a pharmacist.',
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
