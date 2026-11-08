import 'dart:async';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/prescription.dart';
import '../services/drug_search.dart';
import '../services/store.dart';
import 'brand.dart';
import 'med_edit_screen.dart';
import 'store_scope.dart';

/// Add a med the way it reads on the bottle label: the drug name (with
/// suggestions as you type), the strength and dosage form, and directions
/// built from blanks, like "Take [1] [tablet] [by mouth] [twice a day]".
/// The directions set the dose times and a suggested minimum gap.
class PrescriptionScreen extends StatefulWidget {
  const PrescriptionScreen({super.key, this.med});
  final Med? med;

  @override
  State<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends State<PrescriptionScreen> {
  final _search = DrugSearch();
  late final TextEditingController _drug;
  late final TextEditingController _strength;
  final _drugFocus = FocusNode();

  // Label details, all optional.
  late final TextEditingController _whyNeeded;
  late final TextEditingController _rxNumber;
  late final TextEditingController _pharmacy;
  late final TextEditingController _pharmacyPhone;
  late final TextEditingController _prescriber;
  late final TextEditingController _quantity;
  late final TextEditingController _refills;
  late final TextEditingController _price;
  DateTime? _rxDate;

  Timer? _debounce;
  int _searchSeq = 0;
  bool _searching = false;
  List<DrugMatch> _matches = [];
  DrugMatch? _picked;

  late String _form;
  late Directions _dir;
  late List<ClockTime> _times;
  late int _gapMinutes;
  late bool _gapTouched;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final m = widget.med;
    final rx = m?.rx;
    _drug = TextEditingController(text: rx?.drug ?? '');
    _strength = TextEditingController(text: rx?.strength ?? '');
    _form = rx?.form ?? 'tablet';
    final d = rx?.details ?? const LabelDetails();
    _whyNeeded = TextEditingController(text: rx?.directions.asNeededFor ?? '');
    _rxNumber = TextEditingController(text: d.rxNumber);
    _pharmacy = TextEditingController(text: d.pharmacy);
    _pharmacyPhone = TextEditingController(text: d.pharmacyPhone);
    _prescriber = TextEditingController(text: d.prescriber);
    _quantity = TextEditingController(text: d.quantity);
    _refills = TextEditingController(text: d.refills?.toString() ?? '');
    _price = TextEditingController(
      text: d.price == null ? '' : d.price!.toStringAsFixed(2),
    );
    _rxDate = d.rxDate;
    _dir = rx?.directions ?? Directions.forForm(doseFormFor(_form));
    _active = m?.active ?? true;
    _gapTouched = m != null;
    _gapMinutes = m?.minGapMinutes ?? _dir.suggestedGapMinutes();
    _times = switch (m?.schedule ?? _dir.defaultSchedule()) {
      TimesSchedule(:final times) => [...times],
      IntervalSchedule() => [],
    };
    if (_times.isEmpty && _isTimes) {
      _times = [...frequencyFor(_dir.frequency).times!];
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _drug.dispose();
    _strength.dispose();
    _drugFocus.dispose();
    for (final c in [
      _whyNeeded,
      _rxNumber,
      _pharmacy,
      _pharmacyPhone,
      _prescriber,
      _quantity,
      _refills,
      _price,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isTimes =>
      !_dir.asNeeded && frequencyFor(_dir.frequency).everyHours == null;

  Prescription get _rx => Prescription(
    drug: _drug.text.trim(),
    strength: _strength.text.trim(),
    form: _form,
    directions: _dir.copyWith(asNeededFor: _whyNeeded.text.trim()),
    details: LabelDetails(
      rxNumber: _rxNumber.text.trim(),
      rxDate: _rxDate,
      pharmacy: _pharmacy.text.trim(),
      pharmacyPhone: _pharmacyPhone.text.trim(),
      prescriber: _prescriber.text.trim(),
      quantity: _quantity.text.trim(),
      refills: int.tryParse(_refills.text.trim()),
      price: double.tryParse(_price.text.trim().replaceAll(r'$', '')),
    ),
  );

  /// Pharmacies already used on other meds, with their phone numbers.
  Map<String, String> _knownPharmacies() {
    final out = <String, String>{};
    for (final m in StoreScope.maybeRead(context)?.meds ?? const <Med>[]) {
      final d = m.rx?.details;
      if (d == null || d.pharmacy.isEmpty) continue;
      if ((out[d.pharmacy] ?? '').isEmpty) out[d.pharmacy] = d.pharmacyPhone;
    }
    return out;
  }

  Future<void> _pickRxDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _rxDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now.add(const Duration(days: 30)),
      helpText: 'Date on the label',
    );
    if (d != null) setState(() => _rxDate = d);
  }

  // ---- drug name ----

  void _onDrugChanged(String text) {
    _debounce?.cancel();
    if (_picked != null && text.trim() != _picked!.name) _picked = null;
    if (text.trim().length < minSearchLetters) {
      setState(() {
        _matches = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final seq = ++_searchSeq;
      final found = await _search.search(text);
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _matches = found;
        _searching = false;
      });
    });
  }

  void _pickDrug(DrugMatch m) {
    _drugFocus.unfocus();
    setState(() {
      _picked = m;
      _matches = [];
      _searching = false;
      _drug.text = m.name;
      if (m.options.length == 1) _pickStrength(m.options.single);
    });
  }

  void _pickStrength(StrengthForm o) {
    setState(() {
      _strength.text = o.strength;
      _setForm(o.form);
    });
  }

  void _setForm(String key) {
    if (key == _form) return;
    _form = key;
    final f = doseFormFor(key);
    _dir = _dir.copyWith(unit: f.unit, route: f.route);
  }

  // ---- directions and schedule ----

  void _setDirections(Directions d) {
    final changed =
        d.frequency != _dir.frequency || d.asNeeded != _dir.asNeeded;
    setState(() {
      _dir = d;
      if (changed) {
        final f = frequencyFor(d.frequency);
        _times = f.times == null ? [] : [...f.times!];
        if (!_gapTouched) _gapMinutes = d.suggestedGapMinutes();
      }
    });
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

  void _changeGap(int by) => setState(() {
    _gapTouched = true;
    _gapMinutes = (_gapMinutes + by).clamp(0, 72 * 60);
  });

  // ---- save ----

  void _error(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _save() async {
    final rx = _rx;
    if (rx.drug.isEmpty) return _error('Enter the drug name from the label.');
    if (_gapMinutes <= 0) return _error('Set a minimum gap between doses.');

    final old = widget.med;
    var confirmedAt = old?.gapConfirmedAt;
    if (old == null ||
        old.minGapMinutes != _gapMinutes ||
        confirmedAt == null) {
      final ok = await confirmGap(context, rx.medName, _gapMinutes);
      if (!ok || !mounted) return;
      confirmedAt = DateTime.now();
    }

    final schedule = _isTimes
        ? TimesSchedule([..._times]..sort())
        : _dir.defaultSchedule();
    final med = Med(
      id: old?.id ?? Store.newId(),
      name: rx.medName,
      schedule: schedule,
      minGapMinutes: _gapMinutes,
      gapConfirmedAt: confirmedAt,
      active: _active,
      notes: old?.notes ?? '',
      rx: rx,
    );
    await StoreScope.read(context).upsertMed(med);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final med = widget.med!;
    if (!await confirmDeleteMed(context, med) || !mounted) return;
    await StoreScope.read(context).deleteMed(med);
    if (mounted) Navigator.of(context).pop();
  }

  // ---- layout ----

  @override
  Widget build(BuildContext context) {
    final big = Theme.of(context).textTheme.titleLarge;
    final muted = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final form = doseFormFor(_form);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.med == null ? 'Add a prescription' : 'Prescription'),
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
        children: [
          Text(
            'Copy what the pharmacy label on the bottle says.',
            style: muted,
          ),
          const SizedBox(height: 16),

          // 1. Drug name
          Text('Drug name', style: big),
          const SizedBox(height: 8),
          TextField(
            controller: _drug,
            focusNode: _drugFocus,
            textCapitalization: TextCapitalization.words,
            autocorrect: false,
            style: const TextStyle(fontSize: 20),
            decoration: InputDecoration(
              hintText: 'Start typing, like "metf"',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.medication_outlined),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            onChanged: _onDrugChanged,
          ),
          if (_matches.isNotEmpty)
            Card(
              margin: const EdgeInsets.only(top: 4),
              child: Column(
                children: [
                  for (final m in _matches.take(8))
                    ListTile(
                      title: Text(m.name, style: const TextStyle(fontSize: 18)),
                      subtitle: m.hint.isEmpty ? null : Text(m.hint),
                      onTap: () => _pickDrug(m),
                    ),
                ],
              ),
            )
          else if (!_searching &&
              _picked == null &&
              _drug.text.trim().length >= minSearchLetters &&
              _drugFocus.hasFocus)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'No matches. You can keep the name as typed.',
                style: muted,
              ),
            ),
          const SizedBox(height: 24),

          // 2. Strength and dosage form
          Text('Strength and dosage form', style: big),
          const SizedBox(height: 8),
          if (_picked != null && _picked!.options.length > 1) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in _picked!.options)
                  ChoiceChip(
                    label: Text(o.label, style: const TextStyle(fontSize: 16)),
                    selected:
                        o.strength == _strength.text.trim() && o.form == _form,
                    onSelected: (_) => _pickStrength(o),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _strength,
                  style: const TextStyle(fontSize: 18),
                  decoration: const InputDecoration(
                    labelText: 'Strength',
                    hintText: '1000 mg',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: _form,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Dosage form',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final f in doseForms)
                      DropdownMenuItem(value: f.key, child: Text(f.label)),
                  ],
                  onChanged: (v) => setState(() => _setForm(v!)),
                  key: ValueKey(_form),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 3. Directions
          Text('Directions', style: big),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 8,
            children: [
              _Word(form.verb),
              _Blank<double>(
                value: _dir.amount,
                items: {for (final a in doseAmounts) a: amountText(a)},
                onChanged: (v) => _setDirections(_dir.copyWith(amount: v)),
              ),
              _Blank<String>(
                value: _dir.unit,
                items: {
                  for (final MapEntry(:key, :value) in doseUnits.entries)
                    key: _dir.amount <= 1 ? value.$1 : value.$2,
                },
                onChanged: (v) => _setDirections(_dir.copyWith(unit: v)),
              ),
              _Blank<String>(
                value: _dir.route,
                items: doseRoutes,
                onChanged: (v) => _setDirections(_dir.copyWith(route: v)),
              ),
              _Blank<String>(
                value: _dir.frequency,
                items: {for (final f in frequencies) f.key: f.label},
                onChanged: (v) => _setDirections(_dir.copyWith(frequency: v)),
              ),
              _Blank<String>(
                value: _dir.extra,
                items: doseExtras,
                emptyLabel: '+ more',
                onChanged: (v) => _setDirections(_dir.copyWith(extra: v)),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('As needed', style: TextStyle(fontSize: 18)),
            subtitle: const Text(
              'Only when you need it, like for pain. No alarms, but the '
              'minimum gap still applies.',
            ),
            value: _dir.asNeeded,
            onChanged: (v) => _setDirections(_dir.copyWith(asNeeded: v)),
          ),
          if (_dir.asNeeded)
            TextField(
              controller: _whyNeeded,
              decoration: const InputDecoration(
                labelText: 'For (optional)',
                hintText: 'pain',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          const SizedBox(height: 12),
          _LabelPreview(rx: _rx),
          const SizedBox(height: 24),

          // 4. Dose times
          Text('Dose times', style: big),
          const SizedBox(height: 4),
          if (_isTimes) ...[
            Text(
              'Set from the directions. Tap a time to fit it to your day.',
              style: muted,
            ),
            for (final (i, t) in _times.indexed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.alarm),
                title: Text(clockTimeText(t), style: big),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _changeTime(i),
              ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _dir.asNeeded
                    ? 'None. Log a dose whenever you take one, and Pill Time '
                          'shows when the next one is safe.'
                    : '${scheduleText(_dir.defaultSchedule())}, counted from '
                          'the last dose you log.',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          const SizedBox(height: 24),

          // 5. Minimum gap
          Text('Minimum gap between doses', style: big),
          Text(
            'The next dose is never scheduled sooner than this, even if '
            'a dose was taken late. This is filled in from the directions '
            'as a starting point. Check it with your pharmacist.',
            style: muted,
          ),
          const SizedBox(height: 8),
          ValueStepper(
            label: _gapMinutes == 0 ? 'Not set' : gapText(_gapMinutes),
            onMinus: _gapMinutes >= 15 ? () => _changeGap(-15) : null,
            onPlus: () => _changeGap(15),
            onLongMinus: _gapMinutes >= 60 ? () => _changeGap(-60) : null,
            onLongPlus: () => _changeGap(60),
            hint: 'Tap for 15 minutes, hold for 1 hour',
          ),
          if (widget.med?.gapConfirmedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Confirmed '
                '${whenText(widget.med!.gapConfirmedAt, DateTime.now())}',
              ),
            ),
          const SizedBox(height: 24),

          // 6. The rest of the label
          _LabelDetailsSection(
            rxNumber: _rxNumber,
            pharmacy: _pharmacy,
            pharmacyPhone: _pharmacyPhone,
            prescriber: _prescriber,
            quantity: _quantity,
            refills: _refills,
            price: _price,
            rxDate: _rxDate,
            onPickDate: _pickRxDate,
            knownPharmacies: _knownPharmacies(),
            initiallyExpanded: !(widget.med?.rx?.details.isEmpty ?? true),
          ),
          if (widget.med != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              subtitle: const Text('Turn off to pause reminders for this med'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
          if (widget.med == null) ...[
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const MedEditScreen()),
                ),
                child: const Text('No label? Set up a med by hand'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Rx number, date, pharmacy, prescriber, quantity, refills and price.
class _LabelDetailsSection extends StatelessWidget {
  const _LabelDetailsSection({
    required this.rxNumber,
    required this.pharmacy,
    required this.pharmacyPhone,
    required this.prescriber,
    required this.quantity,
    required this.refills,
    required this.price,
    required this.rxDate,
    required this.onPickDate,
    required this.knownPharmacies,
    required this.initiallyExpanded,
  });

  final TextEditingController rxNumber,
      pharmacy,
      pharmacyPhone,
      prescriber,
      quantity,
      refills,
      price;
  final DateTime? rxDate;
  final VoidCallback onPickDate;
  final Map<String, String> knownPharmacies;
  final bool initiallyExpanded;

  Widget _field(
    TextEditingController c,
    String label, {
    String? hint,
    TextInputType? keyboard,
    String? prefix,
  }) => TextField(
    controller: c,
    keyboardType: keyboard,
    textCapitalization: keyboard == null
        ? TextCapitalization.words
        : TextCapitalization.none,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefix,
      border: const OutlineInputBorder(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12, width: 12);
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        shape: const Border(),
        title: Text(
          'Pharmacy and label details',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        subtitle: const Text('Optional: Rx number, date, refills, price'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          Row(
            children: [
              Expanded(child: _field(rxNumber, 'Rx number', hint: '1234567')),
              gap,
              Expanded(
                child: InkWell(
                  onTap: onPickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Rx date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(rxDate == null ? 'Pick' : dateText(rxDate!)),
                  ),
                ),
              ),
            ],
          ),
          gap,
          _field(pharmacy, 'Pharmacy', hint: 'Walgreens #1234'),
          if (knownPharmacies.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final MapEntry(key: name, value: phone)
                    in knownPharmacies.entries)
                  ActionChip(
                    avatar: const Icon(Icons.local_pharmacy_outlined),
                    label: Text(name),
                    onPressed: () {
                      pharmacy.text = name;
                      if (phone.isNotEmpty) pharmacyPhone.text = phone;
                    },
                  ),
              ],
            ),
          ],
          gap,
          _field(
            pharmacyPhone,
            'Pharmacy phone',
            hint: '(555) 555-1234',
            keyboard: TextInputType.phone,
          ),
          gap,
          _field(prescriber, 'Prescriber', hint: 'Dr. Smith'),
          gap,
          Row(
            children: [
              Expanded(
                child: _field(
                  quantity,
                  'Quantity',
                  hint: '180',
                  keyboard: TextInputType.number,
                ),
              ),
              gap,
              Expanded(
                child: _field(
                  refills,
                  'Refills',
                  hint: '3',
                  keyboard: TextInputType.number,
                ),
              ),
              gap,
              Expanded(
                child: _field(
                  price,
                  'Price',
                  hint: '12.50',
                  prefix: r'$',
                  keyboard: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Word extends StatelessWidget {
  const _Word(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
  );
}

/// One fill-in blank in the directions sentence.
class _Blank<T> extends StatelessWidget {
  const _Blank({
    required this.value,
    required this.items,
    required this.onChanged,
    this.emptyLabel,
  });

  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  /// Shown on the button when the empty-string choice is picked.
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A menu button sized to the chosen words only, so long choices like
    // "with a full glass of water" don't make every blank wide.
    return PopupMenuButton<T>(
      initialValue: items.containsKey(value) ? value : null,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final MapEntry(:key, :value) in items.entries)
          PopupMenuItem(
            value: key,
            child: Text(value, style: const TextStyle(fontSize: 18)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        decoration: BoxDecoration(
          color: context.status.wash,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                value == '' && emptyLabel != null
                    ? emptyLabel!
                    : items[value] ?? '',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}

/// The finished directions, styled like a pharmacy label.
class _LabelPreview extends StatelessWidget {
  const _LabelPreview({required this.rx});
  final Prescription rx;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rx.drug.isEmpty ? 'Drug name' : rx.labelLine,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            rx.directionsText,
            style: const TextStyle(
              fontFamily: ToolageFonts.body,
              fontSize: 20,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
