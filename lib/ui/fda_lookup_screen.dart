import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/gap_parser.dart';
import '../services/fda_client.dart';

/// Shows matching FDA labels. Picking one shows its dosing text and a
/// suggested gap. Returns the suggested minutes if the person chooses to use
/// it as a starting point. It still has to be confirmed before saving.
class FdaLookupScreen extends StatefulWidget {
  const FdaLookupScreen({super.key, required this.query});
  final String query;

  @override
  State<FdaLookupScreen> createState() => _FdaLookupScreenState();
}

class _FdaLookupScreenState extends State<FdaLookupScreen> {
  late Future<List<FdaLabel>> _results;

  @override
  void initState() {
    super.initState();
    _results = searchFdaLabels(widget.query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('FDA labels: ${widget.query}')),
      body: FutureBuilder<List<FdaLabel>>(
        future: _results,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _Message(
              '${snap.error}',
              retry: () {
                setState(() => _results = searchFdaLabels(widget.query));
              },
            );
          }
          final results = snap.data!;
          if (results.isEmpty) {
            return const _Message(
              'No FDA label found. Try the generic name, for example '
              '"ibuprofen" instead of a brand.',
            );
          }
          return ListView(
            children: [
              for (final r in results)
                ListTile(
                  title: Text(r.brand.isEmpty ? r.generic : r.brand),
                  subtitle: Text(
                    [r.generic, r.route].where((s) => s.isNotEmpty).join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final minutes = await Navigator.of(context).push<int>(
                      MaterialPageRoute(builder: (_) => _LabelScreen(label: r)),
                    );
                    if (minutes != null && context.mounted) {
                      Navigator.of(context).pop(minutes);
                    }
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.retry});
  final String text;
  final VoidCallback? retry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18),
          ),
          if (retry != null)
            TextButton(onPressed: retry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

class _LabelScreen extends StatelessWidget {
  const _LabelScreen({required this.label});
  final FdaLabel label;

  @override
  Widget build(BuildContext context) {
    final suggestion = suggestGap(label.dosingText);
    return Scaffold(
      appBar: AppBar(
        title: Text(label.brand.isEmpty ? label.generic : label.brand),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (suggestion != null) ...[
                    Text(
                      'Suggested minimum gap: ${gapText(suggestion.minutes)}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text('From the words "${suggestion.phrase}".'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () =>
                          Navigator.of(context).pop(suggestion.minutes),
                      child: Text(
                        'Use ${gapText(suggestion.minutes)} as a starting point',
                      ),
                    ),
                  ] else
                    Text(
                      'No clear interval found in this label.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    'For reference only. Always follow the prescription and your '
                    'pharmacist. You will confirm the gap before it is saved.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Label dosing text',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SelectableText(
            label.dosingText.isEmpty
                ? '(This label has no dosing section.)'
                : label.dosingText,
          ),
        ],
      ),
    );
  }
}
