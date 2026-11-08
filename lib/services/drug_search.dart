import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/prescription.dart';

/// One drug name suggestion, with the strengths and forms it comes in.
class DrugMatch {
  const DrugMatch({
    required this.display,
    required this.name,
    required this.hint,
    required this.options,
  });

  /// The list's own wording, like "metFORMIN (Oral Pill)".
  final String display;

  /// Like "Metformin".
  final String name;

  /// Like "Oral Pill". May be empty.
  final String hint;
  final List<StrengthForm> options;
}

/// Type at least this many letters before suggestions show. Most drug
/// pickers (including the National Library of Medicine's own) start at 2-3.
const minSearchLetters = 3;

/// Looks up drug names as the person types, using RxTerms from the
/// National Library of Medicine (free, no key). RxTerms is built from
/// RxNorm, the US standard list of prescription drug names.
///
/// With no internet, it falls back to a short built-in list of common drugs.
class DrugSearch {
  DrugSearch({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final _cache = <String, List<DrugMatch>>{};

  Future<List<DrugMatch>> search(String text) async {
    final q = text.trim().toLowerCase();
    if (q.length < minSearchLetters) return [];
    final cached = _cache[q];
    if (cached != null) return cached;

    try {
      final url = Uri.https(
        'clinicaltables.nlm.nih.gov',
        '/api/rxterms/v3/search',
        {'terms': q, 'maxList': '15', 'ef': 'STRENGTHS_AND_FORMS'},
      );
      final res = await _client.get(url).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final found = parseRxTerms(res.body);
        _cache[q] = found;
        return found;
      }
    } catch (_) {
      // Offline or the service is down: use the built-in list below.
    }
    return offlineMatches(q);
  }
}

/// RxTerms answers with [total, [names], {STRENGTHS_AND_FORMS: [[...]]}, ...].
List<DrugMatch> parseRxTerms(String body) {
  final j = jsonDecode(body);
  if (j is! List || j.length < 2 || j[1] is! List) return [];
  final names = [for (final n in j[1] as List) n.toString()];
  final extra = j.length > 2 && j[2] is Map ? j[2] as Map : const {};
  final forms = extra['STRENGTHS_AND_FORMS'];
  return [
    for (final (i, display) in names.indexed)
      DrugMatch(
        display: display,
        name: tidyDrugName(display),
        hint: drugNameHint(display),
        options: [
          if (forms is List && i < forms.length && forms[i] is List)
            for (final s in forms[i] as List)
              parseStrengthForm(s.toString().trim()),
        ],
      ),
  ];
}

/// Common drugs for when there's no internet. Strengths come from RxTerms
/// where they are listed; for the rest the person types the strength.
const _offline = <String, List<String>>{
  'metFORMIN (Oral Pill)': [
    '500 mg Tab',
    '850 mg Tab',
    '1000 mg Tab',
    '500 mg 24HR XR Tab',
    '750 mg 24HR XR Tab',
    '1000 mg 24HR XR Tab',
  ],
  'metFORMIN (Oral Liquid)': ['500 mg/5 mL Oral Solution'],
  'Acetaminophen (Oral Pill)': [
    '325 mg Tab',
    '500 mg Tab',
    '650 mg 8HR ER Tab',
  ],
  'Albuterol (Inhalant)': ['90 mcg/actuat Inhaler'],
  'Amlodipine (Oral Pill)': ['2.5 mg Tab', '5 mg Tab', '10 mg Tab'],
  'Amoxicillin (Oral Pill)': ['250 mg Cap', '500 mg Cap', '875 mg Tab'],
  'Atorvastatin (Oral Pill)': [
    '10 mg Tab',
    '20 mg Tab',
    '40 mg Tab',
    '80 mg Tab',
  ],
  'Bupropion (Oral Pill)': [
    '150 mg 12HR SR Tab',
    '150 mg 24HR XL Tab',
    '300 mg 24HR XL Tab',
  ],
  'Cetirizine (Oral Pill)': ['10 mg Tab'],
  'Escitalopram (Oral Pill)': ['5 mg Tab', '10 mg Tab', '20 mg Tab'],
  'Gabapentin (Oral Pill)': [
    '100 mg Cap',
    '300 mg Cap',
    '400 mg Cap',
    '600 mg Tab',
  ],
  'hydroCHLOROthiazide (Oral Pill)': ['12.5 mg Cap', '25 mg Tab'],
  'Ibuprofen (Oral Pill)': [
    '200 mg Tab',
    '400 mg Tab',
    '600 mg Tab',
    '800 mg Tab',
  ],
  'Levothyroxine (Oral Pill)': [
    '25 mcg Tab',
    '50 mcg Tab',
    '75 mcg Tab',
    '100 mcg Tab',
  ],
  'Lisinopril (Oral Pill)': ['5 mg Tab', '10 mg Tab', '20 mg Tab', '40 mg Tab'],
  'Losartan (Oral Pill)': ['25 mg Tab', '50 mg Tab', '100 mg Tab'],
  'Metoprolol Succinate (Oral Pill)': [
    '25 mg 24HR ER Tab',
    '50 mg 24HR ER Tab',
  ],
  'Metoprolol Tartrate (Oral Pill)': ['25 mg Tab', '50 mg Tab'],
  'Montelukast (Oral Pill)': ['10 mg Tab'],
  'Omeprazole (Oral Pill)': ['20 mg DR Cap', '40 mg DR Cap'],
  'Pantoprazole (Oral Pill)': ['20 mg DR Tab', '40 mg DR Tab'],
  'predniSONE (Oral Pill)': ['5 mg Tab', '10 mg Tab', '20 mg Tab'],
  'Rosuvastatin (Oral Pill)': ['5 mg Tab', '10 mg Tab', '20 mg Tab'],
  'Sertraline (Oral Pill)': ['25 mg Tab', '50 mg Tab', '100 mg Tab'],
  'Simvastatin (Oral Pill)': ['10 mg Tab', '20 mg Tab', '40 mg Tab'],
  'traZODone (Oral Pill)': ['50 mg Tab', '100 mg Tab'],
};

List<DrugMatch> offlineMatches(String q) {
  final query = q.toLowerCase();
  final starts = <DrugMatch>[], contains = <DrugMatch>[];
  for (final MapEntry(key: display, value: forms) in _offline.entries) {
    final lower = display.toLowerCase();
    if (!lower.contains(query)) continue;
    final m = DrugMatch(
      display: display,
      name: tidyDrugName(display),
      hint: drugNameHint(display),
      options: [for (final f in forms) parseStrengthForm(f)],
    );
    (lower.startsWith(query) ? starts : contains).add(m);
  }
  return [...starts, ...contains];
}
