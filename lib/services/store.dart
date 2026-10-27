import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/csv_export.dart';
import '../core/models.dart';
import '../core/scheduler.dart';

const _uuid = Uuid();

/// Keeps meds, the dose log and photos as plain files in the app's documents
/// folder. On iPhone they also show up in the Files app under "Pill Time".
class Store extends ChangeNotifier {
  Store._(this._dir);

  final Directory _dir;
  List<Med> _meds = [];
  List<DoseEntry> _log = [];

  /// Called after every change so alarms can be rebuilt.
  void Function(List<MedStatus>)? onChanged;

  /// Shown as a banner on the home screen after a dose is saved.
  final savedMessage = ValueNotifier<String?>(null);

  List<Med> get meds => List.unmodifiable(_meds);
  List<DoseEntry> get log => List.unmodifiable(_log);

  Directory get photosDir => Directory('${_dir.path}/photos');
  File get _medsFile => File('${_dir.path}/meds.json');
  File get _logFile => File('${_dir.path}/log.json');

  static Future<Store> open() async {
    final store = Store._(await getApplicationDocumentsDirectory());
    await store.photosDir.create(recursive: true);
    await store._load();
    return store;
  }

  List<MedStatus> statuses([DateTime? now]) =>
      allStatuses(_meds, _log, now ?? DateTime.now());

  File? photoFile(DoseEntry e) =>
      e.photoFile == null ? null : File('${photosDir.path}/${e.photoFile}');

  // ---- meds ----

  static String newId() => _uuid.v4();

  Future<void> upsertMed(Med med) async {
    final i = _meds.indexWhere((m) => m.id == med.id);
    if (i >= 0) {
      _meds[i] = med;
    } else {
      _meds.add(med);
    }
    await _saveMeds();
    _changed();
  }

  Future<void> deleteMed(Med med) async {
    _meds.removeWhere((m) => m.id == med.id);
    await _saveMeds();
    _changed();
  }

  // ---- doses ----

  /// Saves a dose. [photoPath] is a temporary camera file, copied in here.
  Future<DoseEntry> logDose(
    Set<String> medIds,
    DateTime takenAt,
    String? photoPath,
  ) async {
    final chosen = _meds.where((m) => medIds.contains(m.id)).toList();
    final id = _uuid.v4();
    String? photoName;
    if (photoPath != null) {
      final t = takenAt;
      String two(int n) => n.toString().padLeft(2, '0');
      photoName =
          '${t.year}${two(t.month)}${two(t.day)}-'
          '${two(t.hour)}${two(t.minute)}${two(t.second)}-${id.substring(0, 6)}.jpg';
      await File(photoPath).copy('${photosDir.path}/$photoName');
    }
    final entry = DoseEntry(
      id: id,
      takenAt: takenAt,
      medIds: [for (final m in chosen) m.id],
      medNames: [for (final m in chosen) m.name],
      photoFile: photoName,
    );
    _log.add(entry);
    _log.sort((a, b) => a.takenAt.compareTo(b.takenAt));
    await _saveLog();
    _changed();
    return entry;
  }

  Future<void> deleteEntry(DoseEntry entry) async {
    _log.removeWhere((e) => e.id == entry.id);
    await _saveLog();
    final f = photoFile(entry);
    if (f != null && await f.exists()) await f.delete();
    _changed();
  }

  /// Writes the log as a CSV file and returns it, for sharing.
  Future<File> exportCsv() async {
    final f = File('${_dir.path}/Pill Time log.csv');
    await f.writeAsString(logToCsv(_log));
    return f;
  }

  // ---- files ----

  void _changed() {
    notifyListeners();
    onChanged?.call(statuses());
  }

  Future<void> _load() async {
    if (await _medsFile.exists()) {
      final list = jsonDecode(await _medsFile.readAsString()) as List;
      _meds = [for (final j in list) Med.fromJson(j as Map<String, dynamic>)];
    }
    if (await _logFile.exists()) {
      final list = jsonDecode(await _logFile.readAsString()) as List;
      _log = [
        for (final j in list) DoseEntry.fromJson(j as Map<String, dynamic>),
      ]..sort((a, b) => a.takenAt.compareTo(b.takenAt));
    }
  }

  static const _json = JsonEncoder.withIndent('  ');

  Future<void> _write(File f, Object value) async {
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(_json.convert(value), flush: true);
    await tmp.rename(f.path);
  }

  Future<void> _saveMeds() =>
      _write(_medsFile, [for (final m in _meds) m.toJson()]);
  Future<void> _saveLog() =>
      _write(_logFile, [for (final e in _log) e.toJson()]);
}
