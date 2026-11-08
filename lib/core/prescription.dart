/// A prescription as it reads on the bottle label: drug, strength, dosage
/// form, and directions built from fixed choices, such as
/// "Take 1 tablet by mouth twice a day with food."
///
/// Plain Dart with no Flutter imports, so it is easy to test.
library;

import 'models.dart';

/// A dosage form (tablet, capsule, liquid...) and the words that go with it.
class DoseForm {
  const DoseForm(
    this.key,
    this.label, {
    required this.unit,
    required this.route,
    this.verb = 'Take',
  });

  final String key;

  /// As shown on a label, like "Extended-release tablet".
  final String label;

  /// The default unit key for directions, like "tablet".
  final String unit;

  /// The default route key, like "mouth".
  final String route;

  /// The first word of the directions, like "Take" or "Apply".
  final String verb;
}

const doseForms = <DoseForm>[
  DoseForm('tablet', 'Tablet', unit: 'tablet', route: 'mouth'),
  DoseForm(
    'er_tablet',
    'Extended-release tablet',
    unit: 'tablet',
    route: 'mouth',
  ),
  DoseForm(
    'dr_tablet',
    'Delayed-release tablet',
    unit: 'tablet',
    route: 'mouth',
  ),
  DoseForm('chewable', 'Chewable tablet', unit: 'tablet', route: 'mouth'),
  DoseForm('odt', 'Dissolving tablet (ODT)', unit: 'tablet', route: 'tongue'),
  DoseForm('capsule', 'Capsule', unit: 'capsule', route: 'mouth'),
  DoseForm(
    'er_capsule',
    'Extended-release capsule',
    unit: 'capsule',
    route: 'mouth',
  ),
  DoseForm(
    'dr_capsule',
    'Delayed-release capsule',
    unit: 'capsule',
    route: 'mouth',
  ),
  DoseForm('liquid', 'Liquid (solution)', unit: 'ml', route: 'mouth'),
  DoseForm('suspension', 'Suspension', unit: 'ml', route: 'mouth'),
  DoseForm('powder', 'Powder', unit: 'packet', route: 'mouth'),
  DoseForm(
    'inhaler',
    'Inhaler',
    unit: 'puff',
    route: 'inhaled',
    verb: 'Inhale',
  ),
  DoseForm(
    'nasal',
    'Nasal spray',
    unit: 'spray',
    route: 'nostril',
    verb: 'Use',
  ),
  DoseForm('eye_drops', 'Eye drops', unit: 'drop', route: 'eye', verb: 'Put'),
  DoseForm('ear_drops', 'Ear drops', unit: 'drop', route: 'ear', verb: 'Put'),
  DoseForm('patch', 'Patch', unit: 'patch', route: 'skin', verb: 'Apply'),
  DoseForm('cream', 'Cream', unit: 'application', route: 'skin', verb: 'Apply'),
  DoseForm(
    'ointment',
    'Ointment',
    unit: 'application',
    route: 'skin',
    verb: 'Apply',
  ),
  DoseForm('gel', 'Gel', unit: 'application', route: 'skin', verb: 'Apply'),
  DoseForm(
    'injection',
    'Injection',
    unit: 'ml',
    route: 'under_skin',
    verb: 'Inject',
  ),
  DoseForm(
    'suppository',
    'Suppository',
    unit: 'suppository',
    route: 'rectal',
    verb: 'Insert',
  ),
];

DoseForm doseFormFor(String key) =>
    doseForms.firstWhere((f) => f.key == key, orElse: () => doseForms.first);

/// Units for the "Take [1] [tablet]" blank: key -> (singular, plural).
const doseUnits = <String, (String, String)>{
  'tablet': ('tablet', 'tablets'),
  'capsule': ('capsule', 'capsules'),
  'ml': ('mL', 'mL'),
  'teaspoon': ('teaspoon', 'teaspoons'),
  'packet': ('packet', 'packets'),
  'puff': ('puff', 'puffs'),
  'spray': ('spray', 'sprays'),
  'drop': ('drop', 'drops'),
  'patch': ('patch', 'patches'),
  'application': ('thin layer', 'thin layers'),
  'unit': ('unit', 'units'),
  'suppository': ('suppository', 'suppositories'),
};

/// Routes for the "by [mouth]" blank: key -> words in the sentence.
const doseRoutes = <String, String>{
  'mouth': 'by mouth',
  'tongue': 'on or under the tongue',
  'inhaled': 'by inhalation',
  'nostril': 'in each nostril',
  'eye': 'in each eye',
  'ear': 'in each ear',
  'skin': 'to the skin',
  'under_skin': 'under the skin',
  'rectal': 'rectally',
  'vaginal': 'vaginally',
};

/// How often, for the "[twice a day]" blank.
class Frequency {
  const Frequency(this.key, this.label, {this.times, this.everyHours});

  final String key;
  final String label;

  /// Default clock times for "N times a day" directions.
  final List<ClockTime>? times;

  /// For "every N hours" directions.
  final int? everyHours;
}

const frequencies = <Frequency>[
  Frequency('daily1', 'once a day', times: [ClockTime(8, 0)]),
  Frequency(
    'daily2',
    'twice a day',
    times: [ClockTime(8, 0), ClockTime(20, 0)],
  ),
  Frequency(
    'daily3',
    '3 times a day',
    times: [ClockTime(8, 0), ClockTime(14, 0), ClockTime(20, 0)],
  ),
  Frequency(
    'daily4',
    '4 times a day',
    times: [
      ClockTime(8, 0),
      ClockTime(12, 0),
      ClockTime(16, 0),
      ClockTime(20, 0),
    ],
  ),
  Frequency('bedtime', 'at bedtime', times: [ClockTime(21, 0)]),
  Frequency('q4h', 'every 4 hours', everyHours: 4),
  Frequency('q6h', 'every 6 hours', everyHours: 6),
  Frequency('q8h', 'every 8 hours', everyHours: 8),
  Frequency('q12h', 'every 12 hours', everyHours: 12),
  Frequency('q24h', 'every 24 hours', everyHours: 24),
];

Frequency frequencyFor(String key) =>
    frequencies.firstWhere((f) => f.key == key, orElse: () => frequencies[1]);

/// The optional last blank.
const doseExtras = <String, String>{
  '': '(nothing more)',
  'food': 'with food',
  'water': 'with a full glass of water',
  'empty': 'on an empty stomach',
  'meals': 'with meals',
};

const doseAmounts = <double>[0.5, 1, 1.5, 2, 2.5, 3, 4, 5, 7.5, 10, 15, 20];

/// "1", "1/2" or "1 1/2", as on a pharmacy label.
String amountText(double a) {
  final whole = a.floor();
  final half = a - whole >= 0.5;
  if (!half) return a == whole ? '$whole' : a.toString();
  return whole == 0 ? '1/2' : '$whole 1/2';
}

/// The directions, as a set of blanks.
class Directions {
  const Directions({
    required this.amount,
    required this.unit,
    required this.route,
    required this.frequency,
    this.extra = '',
    this.asNeeded = false,
    this.asNeededFor = '',
  });

  /// Defaults that fit a dosage form: "Take 1 tablet by mouth twice a day".
  factory Directions.forForm(DoseForm form) => Directions(
    amount: 1,
    unit: form.unit,
    route: form.route,
    frequency: 'daily2',
  );

  final double amount;
  final String unit;
  final String route;
  final String frequency;
  final String extra;

  /// "As needed" (PRN): no alarms, but the minimum gap still applies.
  final bool asNeeded;

  /// What it's for when taken as needed, like "pain". May be empty.
  final String asNeededFor;

  Directions copyWith({
    double? amount,
    String? unit,
    String? route,
    String? frequency,
    String? extra,
    bool? asNeeded,
    String? asNeededFor,
  }) => Directions(
    amount: amount ?? this.amount,
    unit: unit ?? this.unit,
    route: route ?? this.route,
    frequency: frequency ?? this.frequency,
    extra: extra ?? this.extra,
    asNeeded: asNeeded ?? this.asNeeded,
    asNeededFor: asNeededFor ?? this.asNeededFor,
  );

  String unitWord() {
    final (one, many) = doseUnits[unit] ?? (unit, unit);
    return amount <= 1 ? one : many;
  }

  /// "Take 1 tablet by mouth twice a day with food." or
  /// "Take 1 tablet by mouth every 6 hours as needed for pain."
  String sentence(DoseForm form) {
    final why = asNeededFor.trim();
    final parts = [
      form.verb,
      amountText(amount),
      unitWord(),
      doseRoutes[route] ?? route,
      frequencyFor(frequency).label,
      if (asNeeded) 'as needed',
      if (asNeeded && why.isNotEmpty) 'for $why',
      if (extra.isNotEmpty) doseExtras[extra] ?? extra,
    ];
    return '${parts.join(' ')}.';
  }

  /// The dose schedule these directions give, before any edits.
  /// As-needed meds get an interval, used only for their spacing.
  DoseSchedule defaultSchedule() {
    final f = frequencyFor(frequency);
    if (f.everyHours != null) return IntervalSchedule(f.everyHours!.toDouble());
    if (asNeeded) return IntervalSchedule(24 / f.times!.length);
    return TimesSchedule([...f.times!]);
  }

  /// A starting point for the minimum gap. The person always confirms it.
  ///
  /// For "every N hours" it is N hours. For "N times a day" it is three
  /// quarters of the spacing (twice a day: 9 hours), so a dose taken a bit
  /// late doesn't push the next one far off its time. As needed, it is the
  /// whole spacing ("up to 3 times a day" is at least 8 hours apart).
  int suggestedGapMinutes() {
    final f = frequencyFor(frequency);
    if (f.everyHours != null) return f.everyHours! * 60;
    final perDay = f.times!.length;
    final spacing = 24 * 60 ~/ perDay;
    if (asNeeded) return spacing;
    return (spacing * 3 ~/ 4) ~/ 30 * 30;
  }

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'unit': unit,
    'route': route,
    'frequency': frequency,
    'extra': extra,
    if (asNeeded) 'asNeeded': true,
    if (asNeededFor.isNotEmpty) 'asNeededFor': asNeededFor,
  };

  factory Directions.fromJson(Map<String, dynamic> j) => Directions(
    amount: (j['amount'] as num).toDouble(),
    unit: j['unit'] as String,
    route: j['route'] as String,
    frequency: j['frequency'] as String,
    extra: j['extra'] as String? ?? '',
    asNeeded: j['asNeeded'] as bool? ?? false,
    asNeededFor: j['asNeededFor'] as String? ?? '',
  );
}

/// The rest of the pharmacy label. Every field is optional.
class LabelDetails {
  const LabelDetails({
    this.rxNumber = '',
    this.rxDate,
    this.pharmacy = '',
    this.pharmacyPhone = '',
    this.prescriber = '',
    this.quantity = '',
    this.refills,
    this.price,
  });

  final String rxNumber;

  /// The date on the label (when it was filled).
  final DateTime? rxDate;
  final String pharmacy;
  final String pharmacyPhone;
  final String prescriber;

  /// How many came in the bottle, like "180".
  final String quantity;

  /// Refills left.
  final int? refills;

  /// What it cost, in dollars.
  final double? price;

  bool get isEmpty =>
      rxNumber.isEmpty &&
      rxDate == null &&
      pharmacy.isEmpty &&
      pharmacyPhone.isEmpty &&
      prescriber.isEmpty &&
      quantity.isEmpty &&
      refills == null &&
      price == null;

  Map<String, dynamic> toJson() => {
    if (rxNumber.isNotEmpty) 'rxNumber': rxNumber,
    if (rxDate != null) 'rxDate': _dateOnly(rxDate!),
    if (pharmacy.isNotEmpty) 'pharmacy': pharmacy,
    if (pharmacyPhone.isNotEmpty) 'pharmacyPhone': pharmacyPhone,
    if (prescriber.isNotEmpty) 'prescriber': prescriber,
    if (quantity.isNotEmpty) 'quantity': quantity,
    if (refills != null) 'refills': refills,
    if (price != null) 'price': price,
  };

  factory LabelDetails.fromJson(Map<String, dynamic> j) => LabelDetails(
    rxNumber: j['rxNumber'] as String? ?? '',
    rxDate: j['rxDate'] == null ? null : DateTime.parse(j['rxDate'] as String),
    pharmacy: j['pharmacy'] as String? ?? '',
    pharmacyPhone: j['pharmacyPhone'] as String? ?? '',
    prescriber: j['prescriber'] as String? ?? '',
    quantity: j['quantity'] as String? ?? '',
    refills: j['refills'] as int?,
    price: (j['price'] as num?)?.toDouble(),
  );
}

String _dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Like "$12.50", or empty.
String priceText(double? price) =>
    price == null ? '' : '\$${price.toStringAsFixed(2)}';

/// What's on the bottle label.
class Prescription {
  const Prescription({
    required this.drug,
    required this.strength,
    required this.form,
    required this.directions,
    this.details = const LabelDetails(),
  });

  /// Like "Metformin".
  final String drug;

  /// Like "1000 mg". May be empty.
  final String strength;

  /// A [DoseForm] key, like "tablet".
  final String form;
  final Directions directions;
  final LabelDetails details;

  DoseForm get doseForm => doseFormFor(form);

  /// The med's name in lists and alarms: "Metformin 1000 mg".
  String get medName => strength.isEmpty ? drug : '$drug $strength';

  /// "Metformin 1000 mg Tablet".
  String get labelLine =>
      [drug, strength, doseForm.label].where((s) => s.isNotEmpty).join(' ');

  String get directionsText => directions.sentence(doseForm);

  Map<String, dynamic> toJson() => {
    'drug': drug,
    'strength': strength,
    'form': form,
    'directions': directions.toJson(),
    if (!details.isEmpty) 'details': details.toJson(),
  };

  factory Prescription.fromJson(Map<String, dynamic> j) => Prescription(
    drug: j['drug'] as String,
    strength: j['strength'] as String? ?? '',
    form: j['form'] as String,
    directions: Directions.fromJson(j['directions'] as Map<String, dynamic>),
    details: j['details'] == null
        ? const LabelDetails()
        : LabelDetails.fromJson(j['details'] as Map<String, dynamic>),
  );
}

/// A strength and form choice from the drug list, like "1000 mg Tab".
class StrengthForm {
  const StrengthForm(this.strength, this.form, this.raw);
  final String strength;
  final String form;

  /// The list's own wording.
  final String raw;

  String get label =>
      [strength, doseFormFor(form).label].where((s) => s.isNotEmpty).join(' ');
}

final _strengthRe = RegExp(
  r'^(\d[\d.,]*\s*(?:mcg|mg|meq|g|ml|units?|unt|iu|%)'
  r'(?:\s*/\s*[\d.]*\s*(?:ml|actuat|hr|g|mg))?)\s*(.*)$',
  caseSensitive: false,
);

/// Splits an RxTerms entry such as "1000 mg Tab" or "500 mg 24HR XR Tab".
StrengthForm parseStrengthForm(String raw) {
  final m = _strengthRe.firstMatch(raw.trim());
  final strength = m == null ? '' : _tidyStrength(m.group(1)!);
  final rest = m == null ? raw : m.group(2)!;
  return StrengthForm(strength, formFromText(rest), raw);
}

String _tidyStrength(String s) => s
    .replaceAll(RegExp(r'\s*/\s*'), '/')
    .replaceAllMapped(RegExp(r'(\d)\s*([a-zA-Z%])'), (m) => '${m[1]} ${m[2]}')
    .replaceAll(RegExp(r'\bml\b', caseSensitive: false), 'mL')
    .replaceAll(RegExp(r'\bMG\b'), 'mg')
    .replaceAll(RegExp(r'\bMCG\b'), 'mcg')
    .replaceAll(RegExp(r'\bunt\b', caseSensitive: false), 'units');

/// Guesses the [DoseForm] key from label wording like "24HR XR Tab".
String formFromText(String text) {
  final t = text.toLowerCase();
  bool has(String pattern) => RegExp(pattern).hasMatch(t);
  final extended = has(r'\b(xr|er|sr|xl|cr|la|\d+\s*hr|extended)\b');
  final delayed = has(r'\b(dr|ec|delayed)\b');
  if (has(r'\b(odt|disintegrating|dissolv)')) return 'odt';
  if (has(r'\bchew')) return 'chewable';
  if (has(r'\btab')) {
    return extended ? 'er_tablet' : (delayed ? 'dr_tablet' : 'tablet');
  }
  if (has(r'\bcap')) {
    return extended ? 'er_capsule' : (delayed ? 'dr_capsule' : 'capsule');
  }
  if (has(r'\bsusp')) return 'suspension';
  if (has(r'\b(sol|solution|liquid|syrup|elixir)\b|oral sol')) return 'liquid';
  if (has(r'\b(inhal|aerosol|actuat|inh)\b|\binhal')) return 'inhaler';
  if (has(r'nasal')) return 'nasal';
  if (has(r'ophth|\beye')) return 'eye_drops';
  if (has(r'otic|\bear')) return 'ear_drops';
  if (has(r'patch|transdermal')) return 'patch';
  if (has(r'\bcream')) return 'cream';
  if (has(r'\boint')) return 'ointment';
  if (has(r'\bgel\b')) return 'gel';
  if (has(r'inj|syringe|pen\b|prefilled|vial')) return 'injection';
  if (has(r'supp')) return 'suppository';
  if (has(r'powder|packet|granule')) return 'powder';
  return 'tablet';
}

/// "metFORMIN (Oral Pill)" -> "Metformin". RxTerms uses Tall Man lettering
/// and puts the route in brackets; a label just says the name.
String tidyDrugName(String display) {
  final name = display.replaceAll(RegExp(r'\s*\(.*?\)\s*'), ' ').trim();
  return name
      .split(RegExp(r'\s+'))
      .map((w) {
        if (w.isEmpty || w == '/') return w;
        // Keep brand names like "XR" or acronyms that are all capitals and short.
        if (w.length <= 3 && w == w.toUpperCase()) return w;
        return w[0].toUpperCase() + w.substring(1).toLowerCase();
      })
      .join(' ');
}

/// The bracketed route group, like "Oral Pill", or empty.
String drugNameHint(String display) =>
    RegExp(r'\((.*?)\)').firstMatch(display)?.group(1) ?? '';
