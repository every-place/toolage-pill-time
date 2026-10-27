import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/format.dart';
import '../core/models.dart';
import 'store_scope.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<void> _share(BuildContext context) async {
    final file = await StoreScope.read(context).exportCsv();
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: 'Pill Time log'),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, DoseEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this dose?'),
        content: Text(
          '${whenText(e.takenAt, DateTime.now())}: ${e.medNames.join(', ')}\n\n'
          'Only do this if it was logged by mistake. The schedule will be '
          'recalculated without it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final log = store.log.reversed.toList();
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            tooltip: 'Share log as a spreadsheet (CSV)',
            icon: const Icon(Icons.ios_share),
            onPressed: log.isEmpty ? null : () => _share(context),
          ),
        ],
      ),
      body: log.isEmpty
          ? const Center(
              child: Text(
                'No doses logged yet.',
                style: TextStyle(fontSize: 18),
              ),
            )
          : ListView.separated(
              itemCount: log.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final e = log[i];
                final photo = store.photoFile(e);
                return Dismissible(
                  key: ValueKey(e.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) => _confirmDelete(context, e),
                  onDismissed: (_) => store.deleteEntry(e),
                  child: ListTile(
                    minVerticalPadding: 12,
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: photo == null
                            ? const Icon(Icons.no_photography_outlined)
                            : Image.file(
                                photo,
                                fit: BoxFit.cover,
                                cacheWidth: 168,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.broken_image),
                              ),
                      ),
                    ),
                    title: Text(
                      whenText(e.takenAt, now),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(e.medNames.join(', ')),
                    onTap: photo == null
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _PhotoScreen(
                                file: photo,
                                title: whenText(e.takenAt, now),
                              ),
                            ),
                          ),
                  ),
                );
              },
            ),
    );
  }
}

class _PhotoScreen extends StatelessWidget {
  const _PhotoScreen({required this.file, required this.title});
  final File file;
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(title: Text(title)),
    body: Center(child: InteractiveViewer(child: Image.file(file))),
  );
}
