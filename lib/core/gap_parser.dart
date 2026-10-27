/// Reads a suggested minimum gap out of FDA label wording such as
/// "every 4 to 6 hours" or "twice daily".
///
/// This is only a hint shown next to the label text. The app never saves a
/// gap until a person confirms it.
library;

class GapSuggestion {
  const GapSuggestion(this.minutes, this.phrase);
  final int minutes;
  final String phrase;
}

const _words = {
  'twenty-four': 24.0,
  'twelve': 12.0,
  'eight': 8.0,
  'three': 3.0,
  'four': 4.0,
  'five': 5.0,
  'one': 1.0,
  'two': 2.0,
  'six': 6.0,
};

final _num = '(\\d+(?:\\.\\d+)?|${_words.keys.join('|')})';
final _every = RegExp(
  'every\\s+$_num(?:\\s*(?:to|-|or)\\s*$_num)?\\s*(?:hours|hrs|hour)\\b',
);

final _perDay = <(RegExp, int)>[
  (RegExp(r'\bonce (?:a |per )?da(?:y|ily)\b'), 24),
  (
    RegExp(r'\btwice (?:a |per )?da(?:y|ily)\b|\btwo times (?:a |per )?day\b'),
    12,
  ),
  (RegExp(r'\bthree times (?:a |per )?da(?:y|ily)\b'), 8),
  (RegExp(r'\bfour times (?:a |per )?da(?:y|ily)\b'), 6),
];

GapSuggestion? suggestGap(String text) {
  final lower = text.toLowerCase();
  final m = _every.firstMatch(lower);
  if (m != null) {
    final low = m.group(1)!;
    final hours = double.tryParse(low) ?? _words[low];
    if (hours != null) return GapSuggestion((hours * 60).round(), m.group(0)!);
  }
  for (final (re, hours) in _perDay) {
    final pm = re.firstMatch(lower);
    if (pm != null) return GapSuggestion(hours * 60, pm.group(0)!);
  }
  return null;
}
