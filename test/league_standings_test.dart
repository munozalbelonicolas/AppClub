import 'package:flutter_test/flutter_test.dart';
import 'package:jorge_newbery_app/features/results/presentation/utils/league_jornada_utils.dart';

void main() {
  group('UCIV Standings & Fecha 22 Base Accumulator', () {
    test('Fecha 22 Base Rows contains exactly 20 clubs and correct initial values', () {
      expect(kFecha22BaseRows.length, 20);

      final junior = kFecha22BaseRows.firstWhere((r) => r['name'] == 'Junior');
      expect(junior['pj'], 22);
      expect(junior['pts'], 293);
      expect(junior['gf'], 486);
      expect(junior['gc'], 141);
      expect(junior['dg'], 345);

      final newbery = kFecha22BaseRows.firstWhere((r) => r['name'] == 'Jorge Newbery');
      expect(newbery['pj'], 22);
      expect(newbery['pts'], 220);
      expect(newbery['gf'], 387);
      expect(newbery['gc'], 336);
      expect(newbery['dg'], 51);
    });

    test('Fecha 23 accumulation matches expected values', () {
      // Simular Fecha 23 tal como viene en Firestore `league_jornadas`
      final fecha23 = {
        'id': 'jornada_23',
        'fechaNumber': 23,
        'tournament': 'anual',
        'isStandings': false,
        'matches': [
          // Junior suma 12 pts (PJ 23 -> 305 pts)
          {
            'homeTeam': 'Junior',
            'awayTeam': 'San Pedro',
            'homeReportedPts': 12,
            'awayReportedPts': 0,
            'categories': {
              '2011': {'homeGoals': 3, 'awayGoals': 0},
              '2012': {'homeGoals': 2, 'awayGoals': 0},
            },
          },
          // Los Pibes suma 12 pts (PJ 23 -> 282 pts)
          {
            'homeTeam': 'Los Pibes',
            'awayTeam': 'Ave Fénix',
            'homeReportedPts': 12,
            'awayReportedPts': 0,
            'categories': {
              '2011': {'homeGoals': 4, 'awayGoals': 1},
            },
          },
          // Jorge Newbery contra Belgrano: JN suma 8 pts, 398 GF (+11), 348 GC (+12), DG 50
          {
            'homeTeam': 'JN',
            'awayTeam': 'GENERAL BELGRANO',
            'homeReportedPts': 8,
            'awayReportedPts': 4,
            'categories': {
              '2011': {'homeGoals': 4, 'awayGoals': 3},
              '2012': {'homeGoals': 3, 'awayGoals': 4},
              '2013': {'homeGoals': 4, 'awayGoals': 5},
            },
          },
        ],
      };

      final result = computeStandingsWithJornadas(
        jornadas: [fecha23],
        clubs: [],
      );

      expect(result.appliedFechas, [23]);
      expect(result.latestFecha, 23);

      final junior = result.rows.firstWhere((r) => r['name'] == 'Junior');
      expect(junior['pj'], 23);
      expect(junior['pts'], 305);

      final losPibes = result.rows.firstWhere((r) => r['name'] == 'Los Pibes');
      expect(losPibes['pj'], 23);
      expect(losPibes['pts'], 282);

      final newbery = result.rows.firstWhere((r) => (r['name'] as String).contains('Newbery'));
      expect(newbery['pj'], 23);
      expect(newbery['pts'], 228);
      expect(newbery['gf'], 398);
      expect(newbery['gc'], 348);
      expect(newbery['dg'], 50);

      // Gral Belgrano jugó también contra JN
      final belgrano = result.rows.firstWhere((r) => (r['name'] as String).contains('Belgrano'));
      expect(belgrano['pj'], 23);
      expect(belgrano['pts'], 206 + 4);
    });
  });
}
