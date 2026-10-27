import 'dart:convert';

import 'package:http/http.dart' as http;

/// A drug label from the FDA's free openFDA database.
class FdaLabel {
  const FdaLabel({
    required this.brand,
    required this.generic,
    required this.route,
    required this.dosingText,
  });

  final String brand;
  final String generic;
  final String route;

  /// The label's dosing section, in plain English.
  final String dosingText;
}

class FdaLookupError implements Exception {
  FdaLookupError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Searches openFDA drug labels by brand or generic name.
Future<List<FdaLabel>> searchFdaLabels(String name, {int limit = 8}) async {
  final words = name
      .replaceAll('"', '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map(Uri.encodeQueryComponent)
      .join('+');
  final search =
      'openfda.brand_name:%22$words%22+openfda.generic_name:%22$words%22';
  final url = Uri.parse(
    'https://api.fda.gov/drug/label.json?search=$search&limit=$limit',
  );

  final http.Response res;
  try {
    res = await http.get(url).timeout(const Duration(seconds: 20));
  } catch (_) {
    throw FdaLookupError(
      'Could not reach the FDA database. Check the internet connection.',
    );
  }
  if (res.statusCode == 404) return []; // openFDA's "no matches"
  if (res.statusCode != 200) {
    throw FdaLookupError(
      'The FDA database answered with error ${res.statusCode}. Try again later.',
    );
  }

  final body = jsonDecode(res.body) as Map<String, dynamic>;
  String join(dynamic list, String sep) =>
      list is List ? list.map((e) => e.toString()).join(sep) : '';

  return [
    for (final r
        in (body['results'] as List? ?? []).cast<Map<String, dynamic>>())
      FdaLabel(
        brand: join(r['openfda']?['brand_name'], ', '),
        generic: join(r['openfda']?['generic_name'], ', '),
        route: join(r['openfda']?['route'], ', '),
        dosingText: join(
          r['dosage_and_administration'] ?? r['directions'],
          '\n\n',
        ).trim(),
      ),
  ];
}
