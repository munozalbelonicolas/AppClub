/// Utilities for Official UCIV League Jornadas and Standings Calculation.
/// Mirrors the logic implemented in the web application (jornadaExcelParser.js & Deportes.jsx).
library;

const List<String> kDefaultCategories = [
  '2011',
  '2012',
  '2013',
  '2014',
  '2015',
  '2019',
  '2018',
  '2017',
  '2016',
];

const Map<String, String> kClubAliases = {
  // Jorge Newbery
  'NEWBERY': 'Jorge Newbery',
  'J. NEWBERY': 'Jorge Newbery',
  'J NEWBERY': 'Jorge Newbery',
  'JORGE NEWBERY': 'Jorge Newbery',
  'JN': 'Jorge Newbery',
  'CLUB JORGE NEWBERY': 'Jorge Newbery',
  'CSD JORGE NEWBERY': 'Jorge Newbery',
  'C.S.D. JORGE NEWBERY': 'Jorge Newbery',

  // Agrupación Varelense
  'AGRUPACION': 'Agrupación Varelense',
  'AGRUPACIÓN': 'Agrupación Varelense',
  'AGRUPACION VARELENSE': 'Agrupación Varelense',
  'AGRUPACIÓN VARELENSE': 'Agrupación Varelense',
  'AGRUP. VARELENSE': 'Agrupación Varelense',
  'AGRUP VARELENSE': 'Agrupación Varelense',

  // Medalla Milagrosa
  'MEDALLA': 'Medalla milagrosa',
  'MEDALLA MILAGROSA': 'Medalla milagrosa',
  'MEDALLA MILAGROSA FC': 'Medalla milagrosa',
  'MEDALLA MILAGROSA F.C.': 'Medalla milagrosa',

  // Villa Angélica
  'VILLA ANGELICA': 'Villa Angelica',
  'VILLA ANGÉLICA': 'Villa Angelica',
  'V. ANGELICA': 'Villa Angelica',
  'V. ANGÉLICA': 'Villa Angelica',
  'V ANGELICA': 'Villa Angelica',
  'V ANGÉLICA': 'Villa Angelica',
  'ANGELICA': 'Villa Angelica',
  'ANGÉLICA': 'Villa Angelica',

  // San Eduardo
  'SAN EDUARDO': 'San Eduardo',
  'S. EDUARDO': 'San Eduardo',
  'S EDUARDO': 'San Eduardo',

  // Monte Cudine
  'MONTECUDINE': 'Monte Cudine',
  'MONTE CUDINE': 'Monte Cudine',
  'MONTECUCINE': 'Monte Cudine',
  'MONTE CUCINE': 'Monte Cudine',
  'M. CUDINE': 'Monte Cudine',
  'M CUDINE': 'Monte Cudine',

  // Rivadavia
  'RIVADAVIA': 'Rivadavia',
  'C.A. RIVADAVIA': 'Rivadavia',
  'CA RIVADAVIA': 'Rivadavia',

  // Los Pibes
  'LOS PIBES': 'Los Pibes',
  'PIBES': 'Los Pibes',
  'CLUB LOS PIBES': 'Los Pibes',

  // Junior
  'JUNIOR': 'Junior',
  'JUNIORS': 'Junior',
  'DEP. JUNIOR': 'Junior',
  'DEPORTIVO JUNIOR': 'Junior',

  // San Jorge
  'SAN JORGE': 'San Jorge',
  'S. JORGE': 'San Jorge',
  'S JORGE': 'San Jorge',

  // Kilómetro 26
  'KM 26': 'Kilómetro 26',
  'KM. 26': 'Kilómetro 26',
  'KM26': 'Kilómetro 26',
  'KILOMETRO 26': 'Kilómetro 26',
  'KILÓMETRO 26': 'Kilómetro 26',
  'KILOMETRO26': 'Kilómetro 26',
  'KILÓMETRO26': 'Kilómetro 26',

  // Belgrano
  'BELGRANO': 'Gral Belgrano',
  'GRAL. BELGRANO': 'Gral Belgrano',
  'GRAL BELGRANO': 'Gral Belgrano',
  'GENERAL BELGRANO': 'Gral Belgrano',

  // San Cayetano
  'SAN CAYETANO': 'San Cayetano',
  'S. CAYETANO': 'San Cayetano',
  'S CAYETANO': 'San Cayetano',

  // San Pedro
  'SAN PEDRO': 'San Pedro',
  'S. PEDRO': 'San Pedro',
  'S PEDRO': 'San Pedro',

  // Marconi
  'MARCONI': 'Marconi',
  'SOC. DE FOM. MARCONI': 'Marconi',
  'S.F. MARCONI': 'Marconi',
  'SF MARCONI': 'Marconi',

  // Villa Aurora
  'VILLA AURORA': 'Villa Aurora',
  'V. AURORA': 'Villa Aurora',
  'AURORA': 'Villa Aurora',

  // San Carlos
  'SAN CARLOS': 'San Carlos',
  'S. CARLOS': 'San Carlos',
  'S CARLOS': 'San Carlos',

  // Alianza
  'ALIANZA': 'Alianza',
  'SOC. DE FOM. ALIANZA': 'Alianza',
  'S.F. ALIANZA': 'Alianza',
  'SF ALIANZA': 'Alianza',

  // Ave Fénix
  'AVE FENIX': 'Ave Fénix',
  'AVE FÉNIX': 'Ave Fénix',
  'FENIX': 'Ave Fénix',
  'FÉNIX': 'Ave Fénix',
  'CLUB AVE FENIX': 'Ave Fénix',

  // Los Rojos
  'LOS ROJOS': 'Los Rojos',
  'ROJOS': 'Los Rojos',
  'CLUB LOS ROJOS': 'Los Rojos',
};

String simplifyClubName(String? str) {
  if (str == null) return '';
  String s = str.toLowerCase().trim();
  const withAccents = 'áéíóúüñÁÉÍÓÚÜÑ';
  const withoutAccents = 'aeiouunAEIOUUN';
  for (int i = 0; i < withAccents.length; i++) {
    s = s.replaceAll(withAccents[i], withoutAccents[i]);
  }
  return s.replaceAll(RegExp(r'[^a-z0-9]'), '');
}

String normalizeClubName(String? rawName) {
  if (rawName == null || rawName.trim().isEmpty) return '';
  final clean = rawName.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
  if (kClubAliases.containsKey(clean)) return kClubAliases[clean]!;
  final simple = simplifyClubName(rawName);
  for (final entry in kClubAliases.entries) {
    if (simplifyClubName(entry.key) == simple) {
      return entry.value;
    }
  }
  return rawName.trim();
}

String stripClubAffixes(String? str) {
  if (str == null) return '';
  String s = simplifyClubName(str);
  const affixes = [
    'sociedaddefomento',
    'socdefom',
    'centrosocialydeportivo',
    'clubsocialydeportivo',
    'centrodefomento',
    'clubatletico',
    'asociacion',
    'deportivo',
    'socfom',
    'club',
    'csyd',
    'csd',
    'sdf',
    'dep',
    'fc',
    'ca',
    'sf',
    'cf',
  ];
  for (final affix in affixes) {
    if (s.startsWith(affix) && s.length > affix.length + 2) {
      s = s.substring(affix.length);
    }
  }
  return s;
}

String? extractClubLogo(Map<String, dynamic>? c) {
  if (c == null) return null;
  final url = c['logoUrl'] ??
      c['shieldUrl'] ??
      c['imageUrl'] ??
      c['logo'] ??
      c['image'] ??
      c['photoUrl'] ??
      c['url'] ??
      c['badgeUrl'] ??
      c['escudoUrl'] ??
      c['escudo'] ??
      c['shield'];
  final str = url?.toString().trim();
  return (str != null && str.isNotEmpty && str != 'null') ? str : null;
}

Map<String, dynamic>? findMatchingClub(List<Map<String, dynamic>> clubs, String? rawTeamName) {
  if (rawTeamName == null || rawTeamName.trim().isEmpty) return null;
  final trimmed = rawTeamName.trim();
  final canonical = normalizeClubName(trimmed);
  final simpleRaw = simplifyClubName(trimmed);
  final simpleCanonical = simplifyClubName(canonical);
  final strippedRaw = stripClubAffixes(trimmed);
  final strippedCanonical = stripClubAffixes(canonical);

  // Helper to build resolved club output from a matched club 'c'
  Map<String, dynamic> buildResult(Map<String, dynamic> c) {
    final cName = (c['name']?.toString() ?? '').trim();
    final isJN = c['isLocal'] == true ||
        cName.toLowerCase().contains('newbery') ||
        cName.toLowerCase().contains('jn') ||
        simpleRaw.contains('newbery') ||
        simpleRaw.contains('jn');
    final isFirestoreId = trimmed.length >= 15 && !trimmed.contains(' ');
    final resolvedName = isJN
        ? 'Jorge Newbery'
        : (cName.isNotEmpty
            ? normalizeClubName(cName)
            : (isFirestoreId ? 'Club' : canonical));
    return {
      ...c,
      'name': resolvedName,
      'isLocal': isJN ? true : (c['isLocal'] == true),
      'logoUrl': extractClubLogo(c),
    };
  }

  // Jorge Newbery Check
  if (simpleRaw.contains('newbery') || simpleRaw.contains('jn') || simpleCanonical.contains('newbery')) {
    final jnClub = clubs.where((c) {
      final name = simplifyClubName(c['name']?.toString());
      return c['isLocal'] == true || name.contains('newbery') || name.contains('jn');
    }).firstOrNull;

    if (jnClub != null) {
      return buildResult(jnClub);
    }

    return {
      'id': 'jn',
      'name': 'Jorge Newbery',
      'isLocal': true,
      'logoUrl': null,
    };
  }

  // 1. Direct ID match
  for (final c in clubs) {
    if (c['id'] != null && c['id'].toString().trim() == trimmed) {
      return buildResult(c);
    }
  }

  // 2. Direct match with canonical name or normalized club name
  for (final c in clubs) {
    final cName = (c['name']?.toString() ?? '').trim();
    final cCanonical = normalizeClubName(cName);
    if (cName.toLowerCase() == canonical.toLowerCase() ||
        cCanonical.toLowerCase() == canonical.toLowerCase() ||
        cName.toLowerCase() == trimmed.toLowerCase()) {
      return buildResult(c);
    }
  }

  // 3. Simplified exact match
  for (final c in clubs) {
    final cName = c['name']?.toString();
    final sc = simplifyClubName(cName);
    final scCanonical = simplifyClubName(normalizeClubName(cName));
    if (sc == simpleRaw || sc == simpleCanonical || scCanonical == simpleCanonical) {
      return buildResult(c);
    }
  }

  // 4. Stripped affixes match
  for (final c in clubs) {
    final cName = c['name']?.toString();
    final strippedC = stripClubAffixes(cName);
    final strippedCCanonical = stripClubAffixes(normalizeClubName(cName));
    if (strippedC.isNotEmpty &&
        (strippedC == strippedRaw ||
            strippedC == strippedCanonical ||
            strippedCCanonical == strippedCanonical)) {
      return buildResult(c);
    }
  }

  // 5. Substring / contains match
  for (final c in clubs) {
    final cName = c['name']?.toString();
    final sc = simplifyClubName(cName);
    final strippedC = stripClubAffixes(cName);
    if (sc.isNotEmpty &&
        (sc.contains(simpleCanonical) ||
            simpleCanonical.contains(sc) ||
            sc.contains(simpleRaw) ||
            simpleRaw.contains(sc) ||
            (strippedC.length >= 4 && strippedCanonical.contains(strippedC)) ||
            (strippedCanonical.length >= 4 && strippedC.contains(strippedCanonical)))) {
      return buildResult(c);
    }
  }

  // 6. Fallback synthetic map with canonical name
  final isFirestoreId = trimmed.length >= 15 && !trimmed.contains(' ') && RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(trimmed);
  return {
    'id': simpleCanonical,
    'name': isFirestoreId ? 'Club' : canonical,
    'logoUrl': null,
  };
}

/// Helper to get goals safely from match categories object
dynamic getCategoryGoals(Map<String, dynamic>? matchCategories, String cat, String type) {
  if (matchCategories == null) return null;
  final catClean = cat.trim();

  // Find matching key case-insensitively / trimmed
  String? foundKey;
  for (final k in matchCategories.keys) {
    if (k.toString().trim() == catClean) {
      foundKey = k;
      break;
    }
  }

  final scoreObj = foundKey != null ? matchCategories[foundKey] : matchCategories[cat];
  if (scoreObj == null || scoreObj is! Map) return null;

  final val = type == 'home'
      ? (scoreObj['homeGoals'] ?? scoreObj['homeScore'] ?? scoreObj['local'])
      : (scoreObj['awayGoals'] ?? scoreObj['awayScore'] ?? scoreObj['visitante']);

  if (val != null && val.toString().trim().isNotEmpty) {
    return val;
  }
  return null;
}

/// Calculate match points for a tira/enfrentamiento:
/// Win = 2 pts, Draw = 1 pt, Loss = 0 pts.
Map<String, int> calculateMatchPoints(Map<String, dynamic>? matchCategories, [List<String>? categories]) {
  int homePts = 0;
  int awayPts = 0;

  final cats = categories ?? (matchCategories?.keys.map((k) => k.toString()).toList() ?? kDefaultCategories);

  for (final cat in cats) {
    final h = getCategoryGoals(matchCategories, cat, 'home');
    final a = getCategoryGoals(matchCategories, cat, 'away');

    if (h != null && a != null) {
      final hNum = int.tryParse(h.toString()) ?? 0;
      final aNum = int.tryParse(a.toString()) ?? 0;

      if (hNum > aNum) {
        homePts += 2;
      } else if (hNum < aNum) {
        awayPts += 2;
      } else {
        homePts += 1;
        awayPts += 1;
      }
    }
  }

  return {'homePts': homePts, 'awayPts': awayPts};
}

/// Format display date (e.g. 2026-08-26 -> 26/08/2026)
String formatDisplayDate(String? dateStr) {
  if (dateStr == null || dateStr.trim().isEmpty) return '';
  try {
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateStr)) {
      final parts = dateStr.split('-');
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    }
    final d = DateTime.tryParse(dateStr);
    if (d != null) {
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }
  } catch (_) {}
  return dateStr;
}

/// Tabla histórica acumulada oficial consolidada hasta la Fecha 22 (antes de la digitalización de planillas).
/// Sirve como ancla base inmutable para que cualquier fecha nueva (de la 23 a la 30) se sume automáticamente.
const List<Map<String, dynamic>> kFecha22BaseRows = [
  {'name': 'Junior', 'pj': 22, 'pg': 21, 'pe': 1, 'pp': 0, 'pts': 293, 'gf': 486, 'gc': 141, 'dg': 345, 'id': '6yoY9kVQwrTUvjdIW9BV', 'isLocal': false},
  {'name': 'Los Pibes', 'pj': 22, 'pg': 18, 'pe': 1, 'pp': 3, 'pts': 270, 'gf': 420, 'gc': 209, 'dg': 211, 'id': 'mr1wU69yCHyZJ11Aha4o', 'isLocal': false},
  {'name': 'Los Rojos', 'pj': 22, 'pg': 17, 'pe': 2, 'pp': 3, 'pts': 241, 'gf': 403, 'gc': 232, 'dg': 171, 'id': 'w2XPM3CmyxzR7yYUsoiN', 'isLocal': false},
  {'name': 'San Carlos', 'pj': 22, 'pg': 17, 'pe': 1, 'pp': 4, 'pts': 239, 'gf': 397, 'gc': 251, 'dg': 146, 'id': 'SDspjxGjKvZJUFYoAsfp', 'isLocal': false},
  {'name': 'San Cayetano', 'pj': 22, 'pg': 14, 'pe': 1, 'pp': 7, 'pts': 233, 'gf': 432, 'gc': 282, 'dg': 150, 'id': '6JliKhYeSuI9rHZPy3VG', 'isLocal': false},
  {'name': 'Rivadavia', 'pj': 22, 'pg': 13, 'pe': 0, 'pp': 9, 'pts': 224, 'gf': 364, 'gc': 257, 'dg': 107, 'id': 'TlsUq2XE4DIgx4w0RekC', 'isLocal': false},
  {'name': 'Jorge Newbery', 'pj': 22, 'pg': 10, 'pe': 0, 'pp': 12, 'pts': 220, 'gf': 387, 'gc': 336, 'dg': 51, 'id': 'HA3INYaIiElQ2gEajVZc', 'isLocal': true},
  {'name': 'San Jorge', 'pj': 22, 'pg': 11, 'pe': 1, 'pp': 10, 'pts': 208, 'gf': 357, 'gc': 332, 'dg': 25, 'id': 'e9CEdLl0WayfISs0Pec4', 'isLocal': false},
  {'name': 'San Eduardo', 'pj': 22, 'pg': 16, 'pe': 0, 'pp': 6, 'pts': 207, 'gf': 436, 'gc': 330, 'dg': 106, 'id': 'iivrmEcJXcuMAMRNLOwp', 'isLocal': false},
  {'name': 'Alianza', 'pj': 22, 'pg': 11, 'pe': 3, 'pp': 8, 'pts': 206, 'gf': 395, 'gc': 305, 'dg': 53, 'id': 'JFRbNA6RW4gVej4KTXRg', 'isLocal': false},
  {'name': 'Gral Belgrano', 'pj': 22, 'pg': 12, 'pe': 1, 'pp': 9, 'pts': 206, 'gf': 358, 'gc': 305, 'dg': 53, 'id': 'UKaqxe2PKSqExV1CeARa', 'isLocal': false},
  {'name': 'Marconi', 'pj': 22, 'pg': 15, 'pe': 0, 'pp': 7, 'pts': 201, 'gf': 384, 'gc': 319, 'dg': 65, 'id': 'OzYKKaG4eZ3pX5ScoS14', 'isLocal': false},
  {'name': 'Agrupación Varelense', 'pj': 22, 'pg': 10, 'pe': 1, 'pp': 11, 'pts': 196, 'gf': 345, 'gc': 353, 'dg': -8, 'id': 'g0N8pnVPQAh3MDWQRuUO', 'isLocal': false},
  {'name': 'Kilómetro 26', 'pj': 22, 'pg': 9, 'pe': 2, 'pp': 11, 'pts': 194, 'gf': 296, 'gc': 271, 'dg': 25, 'id': 'jUzQFArpTq2b63l0Hl4O', 'isLocal': false},
  {'name': 'Villa Aurora', 'pj': 22, 'pg': 6, 'pe': 1, 'pp': 15, 'pts': 177, 'gf': 284, 'gc': 391, 'dg': -107, 'id': 'LWuchU9YgUaZCAHx4lzN', 'isLocal': false},
  {'name': 'Medalla milagrosa', 'pj': 22, 'pg': 3, 'pe': 1, 'pp': 18, 'pts': 177, 'gf': 252, 'gc': 385, 'dg': -133, 'id': 'TGzfk8mtwzVWjLu4P8rY', 'isLocal': false},
  {'name': 'Villa Angelica', 'pj': 22, 'pg': 4, 'pe': 1, 'pp': 17, 'pts': 165, 'gf': 267, 'gc': 374, 'dg': -107, 'id': 'rnGWsA0BY6jYlb0j3EoU', 'isLocal': false},
  {'name': 'San Pedro', 'pj': 22, 'pg': 3, 'pe': 1, 'pp': 18, 'pts': 140, 'gf': 232, 'gc': 489, 'dg': -257, 'id': 'SjMMlgaZPaVCKL1D0tmN', 'isLocal': false},
  {'name': 'Ave Fénix', 'pj': 22, 'pg': 1, 'pe': 0, 'pp': 21, 'pts': 100, 'gf': 143, 'gc': 566, 'dg': -423, 'id': 'wx0UAmpaR8yK2jScPDIq', 'isLocal': false},
  {'name': 'Monte Cudine', 'pj': 22, 'pg': 0, 'pe': 0, 'pp': 22, 'pts': 68, 'gf': 111, 'gc': 627, 'dg': -516, 'id': 'OnxOBoYFfa4jcFsdFKtf', 'isLocal': false},
];

/// Encuentra la fila correspondiente a un club dentro de las filas de la tabla de posiciones.
Map<String, dynamic>? matchClubToRow(
  String? rawName,
  List<Map<String, dynamic>> rows, {
  List<Map<String, dynamic>> clubs = const [],
}) {
  if (rawName == null || rawName.trim().isEmpty || rows.isEmpty) return null;
  final clean = rawName.trim();
  final simple = simplifyClubName(clean);

  // 1. Coincidencia exacta por nombre o nombre simplificado o ID
  for (final r in rows) {
    final rName = (r['name']?.toString() ?? '').trim();
    if (rName.toLowerCase() == clean.toLowerCase() ||
        simplifyClubName(rName) == simple ||
        (r['id'] != null && r['id'].toString() == clean)) {
      return r;
    }
  }

  // 2. Coincidencia por normalización / alias
  final norm = normalizeClubName(clean);
  if (norm.isNotEmpty) {
    final simpleNorm = simplifyClubName(norm);
    for (final r in rows) {
      final rSimple = simplifyClubName(r['name']?.toString());
      if (rSimple == simpleNorm || rSimple == simple) {
        return r;
      }
    }
  }

  // 3. Raíces conocidas
  if (simple.contains('newbery') || simple.contains('jn')) {
    return rows.where((r) {
      final n = (r['name']?.toString() ?? '').toLowerCase();
      return n.contains('newbery') || r['isLocal'] == true;
    }).firstOrNull;
  }
  if (simple.contains('cucine') || simple.contains('cudine')) {
    return rows.where((r) =>
        (r['name']?.toString() ?? '').toLowerCase().contains('cudine')).firstOrNull;
  }
  if (simple.contains('angelica')) {
    return rows.where((r) =>
        (r['name']?.toString() ?? '').toLowerCase().contains('angelica')).firstOrNull;
  }
  if (simple.contains('belgrano')) {
    return rows.where((r) =>
        (r['name']?.toString() ?? '').toLowerCase().contains('belgrano')).firstOrNull;
  }
  if (simple.contains('pibes')) {
    return rows.where((r) =>
        (r['name']?.toString() ?? '').toLowerCase().contains('pibes')).firstOrNull;
  }
  if (simple.contains('rojos')) {
    return rows.where((r) =>
        (r['name']?.toString() ?? '').toLowerCase().contains('rojos')).firstOrNull;
  }
  if (simple.contains('medalla') || simple.contains('milagrosa')) {
    return rows.where((r) =>
        (r['name']?.toString() ?? '').toLowerCase().contains('medalla')).firstOrNull;
  }
  if (simple.contains('agrupacion') || simple.contains('varelense')) {
    return rows.where((r) =>
        (r['name']?.toString() ?? '').toLowerCase().contains('agrupacion')).firstOrNull;
  }
  if (simple.contains('aurora')) {
    return rows.where((r) =>
        (r['name']?.toString() ?? '').toLowerCase().contains('aurora')).firstOrNull;
  }
  if (simple.contains('carlos')) {
    return rows.where((r) =>
        (r['name']?.toString() ?? '').toLowerCase().contains('carlos')).firstOrNull;
  }
  if (simple.contains('cayetano')) {
    return rows.where((r) =>
        (r['name']?.toString() ?? '').toLowerCase().contains('cayetano')).firstOrNull;
  }
  if (simple.contains('eduardo')) {
    return rows.where((r) =>
        (r['name']?.toString() ?? '').toLowerCase().contains('eduardo')).firstOrNull;
  }
  if (simple.contains('jorge') && !simple.contains('newbery')) {
    return rows.where((r) =>
        (r['name']?.toString() ?? '').toLowerCase().contains('san jorge')).firstOrNull;
  }
  if (simple.contains('pedro')) {
    return rows.where((r) =>
        (r['name']?.toString() ?? '').toLowerCase().contains('pedro')).firstOrNull;
  }
  if (simple.contains('rivadavia')) {
    return rows.where((r) =>
        (r['name']?.toString() ?? '').toLowerCase().contains('rivadavia')).firstOrNull;
  }
  if (simple.contains('junior')) {
    return rows.where((r) =>
        (r['name']?.toString() ?? '').toLowerCase().contains('junior')).firstOrNull;
  }
  if (simple.contains('alianza')) {
    return rows.where((r) =>
        (r['name']?.toString() ?? '').toLowerCase().contains('alianza')).firstOrNull;
  }
  if (simple.contains('marconi')) {
    return rows.where((r) =>
        (r['name']?.toString() ?? '').toLowerCase().contains('marconi')).firstOrNull;
  }
  if (simple.contains('kilometro') || simple.contains('km26')) {
    return rows.where((r) =>
        (r['name']?.toString() ?? '').toLowerCase().contains('26')).firstOrNull;
  }
  if (simple.contains('fenix')) {
    return rows.where((r) =>
        (r['name']?.toString() ?? '').toLowerCase().contains('fenix')).firstOrNull;
  }

  // 4. Buscar a través del listado de clubs de Firestore
  if (clubs.isNotEmpty) {
    final matchedClub = clubs.where((c) {
      final cName = c['name']?.toString();
      final sc = simplifyClubName(cName);
      return sc == simple ||
          (cName != null && sc.contains(simple)) ||
          (simple.isNotEmpty && sc.isNotEmpty && simple.contains(sc));
    }).firstOrNull;

    if (matchedClub != null) {
      final matchId = matchedClub['id']?.toString();
      final matchSimple = simplifyClubName(matchedClub['name']?.toString());
      for (final r in rows) {
        if (r['id']?.toString() == matchId ||
            simplifyClubName(r['name']?.toString()) == matchSimple) {
          return r;
        }
      }
    }
  }

  // 5. Parcial (uno contiene al otro)
  for (final r in rows) {
    final sr = simplifyClubName(r['name']?.toString());
    if (sr.isNotEmpty && simple.isNotEmpty && (sr.contains(simple) || simple.contains(sr))) {
      return r;
    }
  }

  return null;
}

/// Obtiene todas las categorías únicas a partir de las planillas en league_jornadas.
/// Recorre jornada.categories y las claves de match.categories en cada partido.
/// Si no hubiera planillas, usa por defecto ['2011'..'2019'] ordenadas numéricamente.
List<String> extractCategoriesFromJornadas(List<Map<String, dynamic>> jornadas) {
  final Set<String> foundCats = {};

  for (final j in jornadas) {
    if (j['isStandings'] == true ||
        j['type'] == 'custom_standings' ||
        (j['id']?.toString().startsWith('standings_') ?? false)) {
      continue;
    }

    if (j['categories'] is List) {
      for (final c in (j['categories'] as List)) {
        final clean = c.toString().replaceAll(RegExp(r'^cat\.?\s*', caseSensitive: false), '').trim();
        if (clean.isNotEmpty && clean != '2020' && clean != '2021') {
          foundCats.add(clean);
        }
      }
    }

    final matches = List<dynamic>.from(j['matches'] ?? []);
    for (final rawM in matches) {
      if (rawM is! Map) continue;
      final catsMap = rawM['categories'];
      if (catsMap is Map) {
        for (final k in catsMap.keys) {
          final clean = k.toString().replaceAll(RegExp(r'^cat\.?\s*', caseSensitive: false), '').trim();
          if (clean.isNotEmpty && clean != '2020' && clean != '2021') {
            foundCats.add(clean);
          }
        }
      }
    }
  }

  if (foundCats.isEmpty) {
    return ['2011', '2012', '2013', '2014', '2015', '2016', '2017', '2018', '2019'];
  }

  final list = foundCats.toList();
  list.sort((a, b) {
    final numA = int.tryParse(a) ?? 0;
    final numB = int.tryParse(b) ?? 0;
    return numA.compareTo(numB);
  });
  return list;
}

class StandingsComputationResult {
  final List<Map<String, dynamic>> rows;
  final int baseFecha;
  final int latestFecha;
  final List<int> appliedFechas;

  const StandingsComputationResult({
    required this.rows,
    required this.baseFecha,
    required this.latestFecha,
    required this.appliedFechas,
  });
}

/// Calcula la tabla de posiciones acumulada (General o por Categoría específica)
/// sumando sobre la base guardada todas las jornadas oficiales de Firestore.
StandingsComputationResult computeStandingsWithJornadas({
  Map<String, dynamic>? customSavedStandings,
  required List<Map<String, dynamic>> jornadas,
  List<Map<String, dynamic>> clubs = const [],
  String category = 'all',
  String tournament = 'clausura',
}) {
  final cleanCategory = category.replaceAll(RegExp(r'^cat\.?\s*', caseSensitive: false), '').trim();
  final isGeneral = cleanCategory.isEmpty || cleanCategory.toLowerCase() == 'all';
  final effectiveTournament = isGeneral ? 'anual' : (tournament.trim().toLowerCase() == 'apertura' ? 'apertura' : 'clausura');

  int minFecha = 1;
  int maxFecha = 38;
  if (!isGeneral) {
    if (effectiveTournament == 'apertura') {
      minFecha = 1;
      maxFecha = 19;
    } else {
      minFecha = 20;
      maxFecha = 38;
    }
  }

  // 1. Determinar base inicial:
  List<Map<String, dynamic>> baseRows = [];
  int baseFecha = 0;

  if (isGeneral) {
    baseRows = kFecha22BaseRows;
    baseFecha = 22;

    if (customSavedStandings != null &&
        customSavedStandings['initialBaseRows'] is List &&
        (customSavedStandings['initialBaseRows'] as List).isNotEmpty) {
      baseRows = (customSavedStandings['initialBaseRows'] as List)
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      baseFecha = int.tryParse(customSavedStandings['initialBaseFecha']?.toString() ?? '22') ?? 22;
    } else if (customSavedStandings != null &&
        customSavedStandings['isManualOverride'] == true &&
        customSavedStandings['rows'] is List &&
        (customSavedStandings['rows'] as List).isNotEmpty) {
      baseRows = (customSavedStandings['rows'] as List)
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      baseFecha = int.tryParse(customSavedStandings['baseFecha']?.toString() ?? '22') ?? 22;
    }
  } else {
    // Por categoría individual: todos los 20 clubes arrancan en 0
    baseFecha = 0;
    if (customSavedStandings != null &&
        customSavedStandings['isManualOverride'] == true &&
        customSavedStandings['rows'] is List &&
        (customSavedStandings['rows'] as List).isNotEmpty) {
      baseRows = (customSavedStandings['rows'] as List)
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      baseFecha = int.tryParse(customSavedStandings['baseFecha']?.toString() ?? '0') ?? 0;
    } else {
      baseRows = kFecha22BaseRows.map((c) {
        final cName = (c['name']?.toString() ?? '').trim();
        final isNewbery = c['isLocal'] == true ||
            cName.toLowerCase().contains('newbery') ||
            cName.toLowerCase().contains('jn');
        final matchedClub = findMatchingClub(clubs, cName);
        return <String, dynamic>{
          'id': c['id']?.toString() ?? matchedClub?['id']?.toString(),
          'name': cName,
          'isLocal': isNewbery,
          'logoUrl': extractClubLogo(matchedClub) ?? c['logoUrl'] ?? c['logo'],
          'pj': 0, 'pg': 0, 'pe': 0, 'pp': 0, 'gf': 0, 'gc': 0, 'dg': 0, 'pts': 0,
        };
      }).toList();
    }
  }

  // Inicializar filas de trabajo clonadas
  final workingRows = baseRows.map((r) => <String, dynamic>{
    'id': r['id']?.toString(),
    'name': r['name']?.toString() ?? '',
    'isLocal': r['isLocal'] == true ||
        (r['name']?.toString() ?? '').toLowerCase().contains('newbery') ||
        (r['name']?.toString() ?? '').toLowerCase().contains('jn'),
    'logoUrl': r['logoUrl'] ?? r['logo'],
    'pj': int.tryParse(r['pj']?.toString() ?? '0') ?? 0,
    'pg': int.tryParse(r['pg']?.toString() ?? '0') ?? 0,
    'pe': int.tryParse(r['pe']?.toString() ?? '0') ?? 0,
    'pp': int.tryParse(r['pp']?.toString() ?? '0') ?? 0,
    'gf': int.tryParse(r['gf']?.toString() ?? '0') ?? 0,
    'gc': int.tryParse(r['gc']?.toString() ?? '0') ?? 0,
    'dg': (int.tryParse(r['gf']?.toString() ?? '0') ?? 0) -
          (int.tryParse(r['gc']?.toString() ?? '0') ?? 0),
    'pts': int.tryParse(r['pts']?.toString() ?? '0') ?? 0,
  }).toList();

  // Asegurar que Jorge Newbery esté presente
  if (!workingRows.any((r) =>
      (r['name']?.toString() ?? '').toLowerCase().contains('newbery') ||
      r['isLocal'] == true)) {
    workingRows.add({
      'id': 'jn',
      'name': 'Jorge Newbery',
      'isLocal': true,
      'pj': 0, 'pg': 0, 'pe': 0, 'pp': 0, 'gf': 0, 'gc': 0, 'dg': 0, 'pts': 0,
    });
  }

  // Filtrar jornadas oficiales que no sean documentos de tabla
  final validJornadas = jornadas.where((j) {
    final isStandings = j['isStandings'] == true ||
        j['type'] == 'custom_standings' ||
        (j['id']?.toString().startsWith('standings_') ?? false);
    return !isStandings;
  }).toList();

  validJornadas.sort((a, b) {
    final fA = int.tryParse(a['fechaNumber']?.toString() ?? '0') ?? 0;
    final fB = int.tryParse(b['fechaNumber']?.toString() ?? '0') ?? 0;
    return fA.compareTo(fB);
  });

  // Filtrar las jornadas según si es General o por Torneo/Fechas
  final jornadasToApply = validJornadas.where((j) {
    final fNum = int.tryParse(j['fechaNumber']?.toString() ?? '0') ?? 0;
    if (isGeneral) {
      return fNum > baseFecha;
    } else {
      final jType = (j['tournamentType'] ?? j['torneo'] ?? j['tournament'] ?? '')
          .toString()
          .toLowerCase()
          .trim();

      bool matchesTournament = false;
      if (effectiveTournament == 'apertura') {
        matchesTournament = jType == 'apertura' ||
            ((jType.isEmpty || jType == 'anual') && fNum >= 1 && fNum <= 19);
      } else if (effectiveTournament == 'clausura') {
        matchesTournament = jType == 'clausura' ||
            ((jType.isEmpty || jType == 'anual') && fNum >= 20 && fNum <= 38);
      } else {
        matchesTournament = fNum >= minFecha && fNum <= maxFecha;
      }

      return matchesTournament && fNum > baseFecha;
    }
  }).toList();

  final List<int> appliedFechas = [];

  for (final jornada in jornadasToApply) {
    final fNum = int.tryParse(jornada['fechaNumber']?.toString() ?? '0') ?? 0;

    final matches = List<dynamic>.from(jornada['matches'] ?? []);
    for (final rawM in matches) {
      if (rawM is! Map) continue;
      final m = Map<String, dynamic>.from(rawM);

      final rawH = (m['homeTeam']?.toString() ?? '').trim();
      final rawA = (m['awayTeam']?.toString() ?? '').trim();
      if (rawH.isEmpty ||
          rawA.isEmpty ||
          rawH == 'Local' ||
          rawA == 'Visitante' ||
          rawH == 'Libre' ||
          rawA == 'Libre') {
        continue;
      }

      final hRow = matchClubToRow(rawH, workingRows, clubs: clubs);
      final aRow = matchClubToRow(rawA, workingRows, clubs: clubs);

      if (hRow == null || aRow == null) {
        continue;
      }

      if (isGeneral) {
        // CÁLCULO GENERAL DE TIRA COMPLETA
        int hTotalGoals = 0;
        int aTotalGoals = 0;
        bool hasAnyCategoryScore = false;

        final categoriesMap = m['categories'] as Map<String, dynamic>? ?? {};
        for (final score in categoriesMap.values) {
          if (score is Map) {
            final hg = score['homeGoals'] ?? score['homeScore'] ?? score['local'];
            final ag = score['awayGoals'] ?? score['awayScore'] ?? score['visitante'];
            if (hg != null &&
                ag != null &&
                hg.toString().trim().isNotEmpty &&
                ag.toString().trim().isNotEmpty) {
              hTotalGoals += int.tryParse(hg.toString()) ?? 0;
              aTotalGoals += int.tryParse(ag.toString()) ?? 0;
              hasAnyCategoryScore = true;
            }
          }
        }

        // Calcular puntos de la jornada
        int hPts = 0;
        int aPts = 0;
        if (m['homeReportedPts'] != null && m['homeReportedPts'].toString().trim().isNotEmpty) {
          hPts = int.tryParse(m['homeReportedPts'].toString()) ?? 0;
        } else if (m['calculatedHomePts'] != null) {
          hPts = int.tryParse(m['calculatedHomePts'].toString()) ?? 0;
        } else if (hasAnyCategoryScore) {
          final calc = calculateMatchPoints(categoriesMap);
          hPts = calc['homePts'] ?? 0;
        }

        if (m['awayReportedPts'] != null && m['awayReportedPts'].toString().trim().isNotEmpty) {
          aPts = int.tryParse(m['awayReportedPts'].toString()) ?? 0;
        } else if (m['calculatedAwayPts'] != null) {
          aPts = int.tryParse(m['calculatedAwayPts'].toString()) ?? 0;
        } else if (hasAnyCategoryScore) {
          final calc = calculateMatchPoints(categoriesMap);
          aPts = calc['awayPts'] ?? 0;
        }

        // Solo sumamos si hubo partidos disputados o puntos registrados
        if (hasAnyCategoryScore || hPts > 0 || aPts > 0) {
          hRow['pj'] = (hRow['pj'] as int) + 1;
          aRow['pj'] = (aRow['pj'] as int) + 1;

          hRow['pts'] = (hRow['pts'] as int) + hPts;
          aRow['pts'] = (aRow['pts'] as int) + aPts;

          hRow['gf'] = (hRow['gf'] as int) + hTotalGoals;
          hRow['gc'] = (hRow['gc'] as int) + aTotalGoals;
          aRow['gf'] = (aRow['gf'] as int) + aTotalGoals;
          aRow['gc'] = (aRow['gc'] as int) + hTotalGoals;

          hRow['dg'] = (hRow['gf'] as int) - (hRow['gc'] as int);
          aRow['dg'] = (aRow['gf'] as int) - (aRow['gc'] as int);

          if (hPts > aPts) {
            hRow['pg'] = (hRow['pg'] as int) + 1;
            aRow['pp'] = (aRow['pp'] as int) + 1;
          } else if (hPts < aPts) {
            aRow['pg'] = (aRow['pg'] as int) + 1;
            hRow['pp'] = (hRow['pp'] as int) + 1;
          } else {
            hRow['pe'] = (hRow['pe'] as int) + 1;
            aRow['pe'] = (aRow['pe'] as int) + 1;
          }

          if (fNum > 0 && !appliedFechas.contains(fNum)) {
            appliedFechas.add(fNum);
          }
        }
      } else {
        // CÁLCULO ESPECÍFICO POR CATEGORÍA
        final categoriesMap = m['categories'] as Map<String, dynamic>? ?? {};
        String? foundKey;
        for (final k in categoriesMap.keys) {
          final kClean = k.toString().replaceAll(RegExp(r'^cat\.?\s*', caseSensitive: false), '').trim();
          if (kClean == cleanCategory) {
            foundKey = k.toString();
            break;
          }
        }

        final scoreObj = foundKey != null ? categoriesMap[foundKey] : categoriesMap[cleanCategory];
        if (scoreObj is Map) {
          final hg = scoreObj['homeGoals'] ?? scoreObj['homeScore'] ?? scoreObj['local'];
          final ag = scoreObj['awayGoals'] ?? scoreObj['awayScore'] ?? scoreObj['visitante'];

          if (hg != null &&
              ag != null &&
              hg.toString().trim().isNotEmpty &&
              ag.toString().trim().isNotEmpty) {
            final hs = int.tryParse(hg.toString()) ?? 0;
            final as = int.tryParse(ag.toString()) ?? 0;

            hRow['pj'] = (hRow['pj'] as int) + 1;
            aRow['pj'] = (aRow['pj'] as int) + 1;

            hRow['gf'] = (hRow['gf'] as int) + hs;
            hRow['gc'] = (hRow['gc'] as int) + as;
            aRow['gf'] = (aRow['gf'] as int) + as;
            aRow['gc'] = (aRow['gc'] as int) + hs;

            hRow['dg'] = (hRow['gf'] as int) - (hRow['gc'] as int);
            aRow['dg'] = (aRow['gf'] as int) - (aRow['gc'] as int);

            if (hs > as) {
              hRow['pg'] = (hRow['pg'] as int) + 1;
              hRow['pts'] = (hRow['pts'] as int) + 2;
              aRow['pp'] = (aRow['pp'] as int) + 1;
            } else if (hs < as) {
              aRow['pg'] = (aRow['pg'] as int) + 1;
              aRow['pts'] = (aRow['pts'] as int) + 2;
              hRow['pp'] = (hRow['pp'] as int) + 1;
            } else {
              hRow['pe'] = (hRow['pe'] as int) + 1;
              hRow['pts'] = (hRow['pts'] as int) + 1;
              aRow['pe'] = (aRow['pe'] as int) + 1;
              aRow['pts'] = (aRow['pts'] as int) + 1;
            }

            if (fNum > 0 && !appliedFechas.contains(fNum)) {
              appliedFechas.add(fNum);
            }
          }
        }
      }
    }
  }

  // Resolver logos de la colección clubs
  for (final row in workingRows) {
    final matchedClub = findMatchingClub(clubs, row['name']?.toString());
    final logo = extractClubLogo(matchedClub);
    if (logo != null && logo.isNotEmpty) {
      row['logoUrl'] = logo;
    }
    if (row['isLocal'] == true) {
      row['isLocal'] = true;
    }
  }

  // Ordenar por Puntos, luego Diferencia de Gol, luego Goles a Favor, luego Nombre
  workingRows.sort((a, b) {
    final ptsA = a['pts'] as int;
    final ptsB = b['pts'] as int;
    if (ptsB != ptsA) return ptsB.compareTo(ptsA);

    final dgA = a['dg'] as int;
    final dgB = b['dg'] as int;
    if (dgB != dgA) return dgB.compareTo(dgA);

    final gfA = a['gf'] as int;
    final gfB = b['gf'] as int;
    if (gfB != gfA) return gfB.compareTo(gfA);

    final nameA = a['name']?.toString() ?? '';
    final nameB = b['name']?.toString() ?? '';
    return nameA.compareTo(nameB);
  });

  final latestFecha = appliedFechas.isNotEmpty
      ? appliedFechas.reduce((curr, next) => curr > next ? curr : next)
      : baseFecha;

  return StandingsComputationResult(
    rows: workingRows,
    baseFecha: baseFecha,
    latestFecha: latestFecha,
    appliedFechas: appliedFechas,
  );
}

/// Standings Calculation engine that replicates Deportes.jsx logic:
/// Supports 'anual' | 'apertura' | 'clausura' tournaments and 'all' or category-specific views.
List<Map<String, dynamic>> calculateStandings({
  required List<Map<String, dynamic>> leagueJornadas,
  required List<Map<String, dynamic>> fixtures,
  required List<Map<String, dynamic>> clubs,
  required String tournament, // 'anual' | 'apertura' | 'clausura'
  required String category,   // 'all' | '2011' | '2012' ...
}) {
  final String sType = tournament.toLowerCase().trim();
  final String cleanCategory = category.replaceAll(RegExp(r'^cat\.?\s*', caseSensitive: false), '').toLowerCase().trim();

  // Buscar si existe un documento de standings personalizado en league_jornadas
  final customDoc = leagueJornadas.firstWhere(
    (j) => (j['isStandings'] == true || j['type'] == 'custom_standings' || (j['id'] != null && j['id'].toString().startsWith('standings_'))) &&
           (j['tournament']?.toString().toLowerCase().trim() == sType || (j['id'] != null && j['id'].toString().contains(sType))),
    orElse: () => <String, dynamic>{},
  );

  // Si es torneo anual o categoría, calcular dinámicamente con computeStandingsWithJornadas
  if (sType == 'anual' || sType == 'todos' || sType == 'general' || cleanCategory != 'all') {
    final computed = computeStandingsWithJornadas(
      customSavedStandings: cleanCategory == 'all' || cleanCategory.isEmpty ? (customDoc.isNotEmpty ? customDoc : null) : null,
      jornadas: leagueJornadas,
      clubs: clubs,
      category: cleanCategory.isEmpty ? 'all' : cleanCategory,
      tournament: sType,
    );
    return computed.rows;
  }

  // Si existe un documento guardado manual para otra categoría/torneo específico con filas:
  if (customDoc.isNotEmpty && customDoc['rows'] is List && (customDoc['rows'] as List).isNotEmpty) {
    final customRows = List<dynamic>.from(customDoc['rows'] as List);
    final List<Map<String, dynamic>> result = [];
    for (final rawRow in customRows) {
      if (rawRow is! Map) continue;
      final row = Map<String, dynamic>.from(rawRow);
      final rawName = row['name']?.toString().trim() ?? '';
      final isNewbery = (row['isLocal'] == true) || rawName.toLowerCase().contains('newbery') || rawName.toLowerCase().contains('jn');
      final matchingClub = findMatchingClub(clubs, rawName);

      result.add({
        'id': row['id'] ?? matchingClub?['id'] ?? rawName,
        'name': rawName,
        'logoUrl': extractClubLogo(matchingClub) ?? row['logo'] ?? row['logoUrl'],
        'isLocal': isNewbery,
        'pj': num.tryParse(row['pj']?.toString() ?? '0') ?? 0,
        'pg': num.tryParse(row['pg']?.toString() ?? '0') ?? 0,
        'pe': num.tryParse(row['pe']?.toString() ?? '0') ?? 0,
        'pp': num.tryParse(row['pp']?.toString() ?? '0') ?? 0,
        'gf': num.tryParse(row['gf']?.toString() ?? '0') ?? 0,
        'gc': num.tryParse(row['gc']?.toString() ?? '0') ?? 0,
        'dg': num.tryParse(row['dg']?.toString() ?? '0') ?? 0,
        'pts': num.tryParse(row['pts']?.toString() ?? '0') ?? 0,
      });
    }

    result.sort((a, b) {
      if (b['pts'] != a['pts']) return (b['pts'] as num).compareTo(a['pts'] as num);
      if (b['dg'] != a['dg']) return (b['dg'] as num).compareTo(a['dg'] as num);
      if (b['gf'] != a['gf']) return (b['gf'] as num).compareTo(a['gf'] as num);
      return (a['name'] as String).compareTo(b['name'] as String);
    });

    return result;
  }

  final Map<String, Map<String, dynamic>> table = {};

  // Filter official league jornadas by tournament (if 'anual', sum both apertura & clausura)
  final relevantJornadas = leagueJornadas.where((j) {
    if (sType == 'anual' || sType == 'todos' || sType == 'general') return true;
    final jType = (j['tournamentType'] ?? j['tournament'] ?? 'apertura').toString().toLowerCase().trim();
    if (jType == 'anual' || jType == 'todos' || jType == 'general') return true;
    return jType == sType;
  }).toList();

  if (leagueJornadas.isNotEmpty) {
    // 1. Pre-fill registered clubs
    for (final c in clubs) {
      final name = c['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      final isNewbery = (c['isLocal'] == true) ||
          name.toLowerCase().contains('newbery') ||
          name.toLowerCase().contains('jn');
      final canonicalName = isNewbery ? 'Jorge Newbery' : normalizeClubName(name);

      table[canonicalName] = {
        'id': c['id'],
        'name': canonicalName,
        'logoUrl': extractClubLogo(c),
        'isLocal': isNewbery,
        'pj': 0,
        'pg': 0,
        'pe': 0,
        'pp': 0,
        'gf': 0,
        'gc': 0,
        'dg': 0,
        'pts': 0,
      };
    }

    if (!table.containsKey('Jorge Newbery')) {
      table['Jorge Newbery'] = {
        'id': 'jn',
        'name': 'Jorge Newbery',
        'logoUrl': null,
        'isLocal': true,
        'pj': 0,
        'pg': 0,
        'pe': 0,
        'pp': 0,
        'gf': 0,
        'gc': 0,
        'dg': 0,
        'pts': 0,
      };
    }

    // 2. Iterate official league jornadas
    for (final j in relevantJornadas) {
      final matches = List<dynamic>.from(j['matches'] ?? []);
      final cats = List<String>.from(j['categories'] ?? kDefaultCategories);

      for (final rawM in matches) {
        if (rawM is! Map) continue;
        final m = Map<String, dynamic>.from(rawM);

        final rawH = (m['homeTeam']?.toString() ?? '').trim();
        final rawA = (m['awayTeam']?.toString() ?? '').trim();
        if (rawH.isEmpty || rawA.isEmpty || rawH == 'Local' || rawA == 'Visitante' || rawH == 'Libre' || rawA == 'Libre') {
          continue;
        }

        final isHNewbery = rawH.toLowerCase().contains('newbery') || rawH.toLowerCase().contains('jn');
        final isANewbery = rawA.toLowerCase().contains('newbery') || rawA.toLowerCase().contains('jn');

        final hClub = findMatchingClub(clubs, rawH);
        final aClub = findMatchingClub(clubs, rawA);

        final hName = isHNewbery ? 'Jorge Newbery' : (hClub?['name']?.toString() ?? rawH);
        final aName = isANewbery ? 'Jorge Newbery' : (aClub?['name']?.toString() ?? rawA);

        if (!table.containsKey(hName)) {
          table[hName] = {
            'id': hClub?['id'] ?? hName,
            'name': hName,
            'logoUrl': extractClubLogo(hClub),
            'isLocal': isHNewbery,
            'pj': 0, 'pg': 0, 'pe': 0, 'pp': 0, 'gf': 0, 'gc': 0, 'dg': 0, 'pts': 0,
          };
        } else if (table[hName]!['logoUrl'] == null && extractClubLogo(hClub) != null) {
          table[hName]!['logoUrl'] = extractClubLogo(hClub);
        }

        if (!table.containsKey(aName)) {
          table[aName] = {
            'id': aClub?['id'] ?? aName,
            'name': aName,
            'logoUrl': extractClubLogo(aClub),
            'isLocal': isANewbery,
            'pj': 0, 'pg': 0, 'pe': 0, 'pp': 0, 'gf': 0, 'gc': 0, 'dg': 0, 'pts': 0,
          };
        } else if (table[aName]!['logoUrl'] == null && extractClubLogo(aClub) != null) {
          table[aName]!['logoUrl'] = extractClubLogo(aClub);
        }

        final matchCatsMap = m['categories'] as Map<String, dynamic>?;

        for (final cat in cats) {
          final cleanCat = cat.replaceAll(RegExp(r'^cat\.?\s*', caseSensitive: false), '').trim();
          final cleanCategoryFilter = category.replaceAll(RegExp(r'^cat\.?\s*', caseSensitive: false), '').trim();

          if (category != 'all' && cleanCat != cleanCategoryFilter) {
            continue;
          }

          final hGoals = getCategoryGoals(matchCatsMap, cat, 'home');
          final aGoals = getCategoryGoals(matchCatsMap, cat, 'away');

          if (hGoals != null && aGoals != null) {
            final hs = int.tryParse(hGoals.toString()) ?? 0;
            final as = int.tryParse(aGoals.toString()) ?? 0;

            final hRow = table[hName]!;
            final aRow = table[aName]!;

            hRow['pj'] = (hRow['pj'] as int) + 1;
            aRow['pj'] = (aRow['pj'] as int) + 1;
            hRow['gf'] = (hRow['gf'] as int) + hs;
            hRow['gc'] = (hRow['gc'] as int) + as;
            aRow['gf'] = (aRow['gf'] as int) + as;
            aRow['gc'] = (aRow['gc'] as int) + hs;

            if (hs > as) {
              hRow['pg'] = (hRow['pg'] as int) + 1;
              hRow['pts'] = (hRow['pts'] as int) + 2; // 2 puntos victoria
              aRow['pp'] = (aRow['pp'] as int) + 1;
            } else if (hs < as) {
              aRow['pg'] = (aRow['pg'] as int) + 1;
              aRow['pts'] = (aRow['pts'] as int) + 2; // 2 puntos victoria
              hRow['pp'] = (hRow['pp'] as int) + 1;
            } else {
              hRow['pe'] = (hRow['pe'] as int) + 1;
              hRow['pts'] = (hRow['pts'] as int) + 1; // 1 punto empate
              aRow['pe'] = (aRow['pe'] as int) + 1;
              aRow['pts'] = (aRow['pts'] as int) + 1; // 1 punto empate
            }
          }
        }
      }
    }
  } else {
    // Fallback if no league_jornadas exist
    for (final c in clubs) {
      final name = c['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      final isNewbery = (c['isLocal'] == true) ||
          name.toLowerCase().contains('newbery') ||
          name.toLowerCase().contains('jn');
      final canonicalName = isNewbery ? 'Jorge Newbery' : normalizeClubName(name);

      table[canonicalName] = {
        'id': c['id'],
        'name': canonicalName,
        'logoUrl': c['logoUrl'] ?? c['logo'] ?? c['imageUrl'] ?? c['shieldUrl'] ?? c['badgeUrl'],
        'isLocal': isNewbery,
        'pj': 0, 'pg': 0, 'pe': 0, 'pp': 0, 'gf': 0, 'gc': 0, 'dg': 0, 'pts': 0,
      };
    }

    final relevantFixtures = fixtures.where((f) {
      if (sType == 'anual' || sType == 'todos' || sType == 'general') return true;
      final fType = (f['tournamentType'] ?? f['tournament'] ?? 'apertura').toString().toLowerCase().trim();
      if (fType == 'anual' || fType == 'todos' || fType == 'general') return true;
      return fType == sType;
    }).toList();

    for (final f in relevantFixtures) {
      final matches = (f['matches'] as List?) ?? [];
      for (final rawM in matches) {
        if (rawM is! Map) continue;
        final m = Map<String, dynamic>.from(rawM);

        if (m['isPromotional'] == true || m['isPromo'] == true) continue;

        if (category != 'all' && m['category'] != null && m['category'].toString() != category) {
          continue;
        }

        final hClub = findMatchingClub(clubs, m['homeClubId']?.toString() ?? m['homeTeam']?.toString());
        final aClub = findMatchingClub(clubs, m['awayClubId']?.toString() ?? m['awayTeam']?.toString());

        final isHomeNewbery = hClub?['isLocal'] == true ||
            (m['homeTeam']?.toString() ?? '').toLowerCase().contains('newbery') ||
            (m['homeTeam']?.toString() ?? '').toLowerCase().contains('jn');

        final hName = isHomeNewbery ? 'Jorge Newbery' : (hClub?['name']?.toString() ?? m['homeTeam']?.toString() ?? '').trim();
        final aName = (aClub?['name']?.toString() ?? m['awayTeam']?.toString() ?? '').trim();

        if (hName.isEmpty || aName.isEmpty || hName == 'Local' || aName == 'Visitante') continue;

        table.putIfAbsent(hName, () => {
          'name': hName, 'logoUrl': hClub?['logoUrl'], 'isLocal': isHomeNewbery,
          'pj': 0, 'pg': 0, 'pe': 0, 'pp': 0, 'gf': 0, 'gc': 0, 'dg': 0, 'pts': 0,
        });
        table.putIfAbsent(aName, () => {
          'name': aName, 'logoUrl': aClub?['logoUrl'], 'isLocal': false,
          'pj': 0, 'pg': 0, 'pe': 0, 'pp': 0, 'gf': 0, 'gc': 0, 'dg': 0, 'pts': 0,
        });

        final hScore = m['homeScore'] != null ? int.tryParse(m['homeScore'].toString()) : null;
        final aScore = m['awayScore'] != null ? int.tryParse(m['awayScore'].toString()) : null;
        final status = m['status']?.toString() ?? '';

        if (hScore != null && aScore != null && status != 'scheduled' && status != 'suspended') {
          final hRow = table[hName]!;
          final aRow = table[aName]!;

          hRow['pj'] = (hRow['pj'] as int) + 1;
          aRow['pj'] = (aRow['pj'] as int) + 1;
          hRow['gf'] = (hRow['gf'] as int) + hScore;
          hRow['gc'] = (hRow['gc'] as int) + aScore;
          aRow['gf'] = (aRow['gf'] as int) + aScore;
          aRow['gc'] = (aRow['gc'] as int) + hScore;

          if (hScore > aScore) {
            hRow['pg'] = (hRow['pg'] as int) + 1;
            hRow['pts'] = (hRow['pts'] as int) + 2;
            aRow['pp'] = (aRow['pp'] as int) + 1;
          } else if (hScore < aScore) {
            aRow['pg'] = (aRow['pg'] as int) + 1;
            aRow['pts'] = (aRow['pts'] as int) + 2;
            hRow['pp'] = (hRow['pp'] as int) + 1;
          } else {
            hRow['pe'] = (hRow['pe'] as int) + 1;
            hRow['pts'] = (hRow['pts'] as int) + 1;
            aRow['pe'] = (aRow['pe'] as int) + 1;
            aRow['pts'] = (aRow['pts'] as int) + 1;
          }
        }
      }
    }
  }

  final list = table.values.where((t) {
    final n = t['name']?.toString() ?? '';
    return n != 'Local' && n != 'Visitante' && n != 'Libre';
  }).toList();

  for (final t in list) {
    t['dg'] = (t['gf'] as int) - (t['gc'] as int);
  }

  list.sort((a, b) {
    final ptsA = a['pts'] as int;
    final ptsB = b['pts'] as int;
    if (ptsB != ptsA) return ptsB.compareTo(ptsA);

    final dgA = a['dg'] as int;
    final dgB = b['dg'] as int;
    if (dgB != dgA) return dgB.compareTo(dgA);

    final gfA = a['gf'] as int;
    final gfB = b['gf'] as int;
    if (gfB != gfA) return gfB.compareTo(gfA);

    final nameA = a['name']?.toString() ?? '';
    final nameB = b['name']?.toString() ?? '';
    return nameA.compareTo(nameB);
  });

  return list;
}
