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
  'MEDALLA': 'Medalla Milagrosa',
  'MEDALLA MILAGROSA': 'Medalla Milagrosa',
  'MEDALLA MILAGROSA FC': 'Medalla Milagrosa',
  'MEDALLA MILAGROSA F.C.': 'Medalla Milagrosa',

  // Villa Angélica
  'VILLA ANGELICA': 'Villa Angélica',
  'VILLA ANGÉLICA': 'Villa Angélica',
  'V. ANGELICA': 'Villa Angélica',
  'V. ANGÉLICA': 'Villa Angélica',
  'ANGELICA': 'Villa Angélica',
  'ANGÉLICA': 'Villa Angélica',

  // San Eduardo
  'SAN EDUARDO': 'San Eduardo',
  'S. EDUARDO': 'San Eduardo',
  'S EDUARDO': 'San Eduardo',

  // Monte Cudine
  'MONTECUDINE': 'Monte Cudine',
  'MONTE CUDINE': 'Monte Cudine',
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
  'BELGRANO': 'Belgrano',
  'GRAL. BELGRANO': 'Belgrano',
  'GRAL BELGRANO': 'Belgrano',
  'GENERAL BELGRANO': 'Belgrano',

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
  final canonical = normalizeClubName(rawTeamName);
  final simpleRaw = simplifyClubName(rawTeamName);
  final simpleCanonical = simplifyClubName(canonical);
  final strippedRaw = stripClubAffixes(rawTeamName);
  final strippedCanonical = stripClubAffixes(canonical);

  // Jorge Newbery Check
  if (simpleRaw.contains('newbery') || simpleRaw.contains('jn') || simpleCanonical.contains('newbery')) {
    final jnClub = clubs.where((c) {
      final name = simplifyClubName(c['name']?.toString());
      return c['isLocal'] == true || name.contains('newbery') || name.contains('jn');
    }).firstOrNull;

    return {
      'id': jnClub?['id'] ?? 'jn',
      'name': 'Jorge Newbery',
      'isLocal': true,
      'logoUrl': extractClubLogo(jnClub),
    };
  }

  // 1. Direct ID match
  for (final c in clubs) {
    if (c['id'] != null && c['id'].toString() == rawTeamName.trim()) {
      return {
        ...c,
        'name': canonical,
        'logoUrl': extractClubLogo(c),
      };
    }
  }

  // 2. Direct match with canonical name or normalized club name
  for (final c in clubs) {
    final cName = (c['name']?.toString() ?? '').trim();
    final cCanonical = normalizeClubName(cName);
    if (cName.toLowerCase() == canonical.toLowerCase() ||
        cCanonical.toLowerCase() == canonical.toLowerCase() ||
        cName.toLowerCase() == rawTeamName.trim().toLowerCase()) {
      return {
        ...c,
        'name': canonical,
        'logoUrl': extractClubLogo(c),
      };
    }
  }

  // 3. Simplified exact match
  for (final c in clubs) {
    final cName = c['name']?.toString();
    final sc = simplifyClubName(cName);
    final scCanonical = simplifyClubName(normalizeClubName(cName));
    if (sc == simpleRaw || sc == simpleCanonical || scCanonical == simpleCanonical) {
      return {
        ...c,
        'name': canonical,
        'logoUrl': extractClubLogo(c),
      };
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
      return {
        ...c,
        'name': canonical,
        'logoUrl': extractClubLogo(c),
      };
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
      return {
        ...c,
        'name': canonical,
        'logoUrl': extractClubLogo(c),
      };
    }
  }

  // 6. Fallback synthetic map with canonical name
  return {
    'id': simpleCanonical,
    'name': canonical,
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

/// Standings Calculation engine that replicates Deportes.jsx logic:
/// Supports 'anual' | 'apertura' | 'clausura' tournaments and 'all' or category-specific views.
List<Map<String, dynamic>> calculateStandings({
  required List<Map<String, dynamic>> leagueJornadas,
  required List<Map<String, dynamic>> fixtures,
  required List<Map<String, dynamic>> clubs,
  required String tournament, // 'anual' | 'apertura' | 'clausura'
  required String category,   // 'all' | '2011' | '2012' ...
}) {
  final Map<String, Map<String, dynamic>> table = {};

  final String sType = tournament.toLowerCase().trim();

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
