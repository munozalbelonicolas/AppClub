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

    test('extractCategoriesFromJornadas extracts and sorts categories', () {
      final jornadas = [
        {
          'categories': ['2014', '2011', 'Cat. 2013'],
          'matches': [
            {
              'categories': {
                '2012': {'homeGoals': 1, 'awayGoals': 0},
                '2015': {'homeGoals': 2, 'awayGoals': 2},
              }
            }
          ]
        }
      ];

      final cats = extractCategoriesFromJornadas(jornadas);
      expect(cats, ['2011', '2012', '2013', '2014', '2015']);
    });

    test('Category specific mode starts at 0 and calculates baby fútbol points', () {
      final jornada1 = {
        'id': 'jornada_20',
        'fechaNumber': 20,
        'tournament': 'anual',
        'matches': [
          {
            'homeTeam': 'Marconi',
            'awayTeam': 'Jorge Newbery',
            'categories': {
              '2011': {'homeGoals': 4, 'awayGoals': 1},
            },
          },
          {
            'homeTeam': 'Junior',
            'awayTeam': 'Los Pibes',
            'categories': {
              '2011': {'homeGoals': 2, 'awayGoals': 2},
            },
          }
        ],
      };

      final res2011 = computeStandingsWithJornadas(
        jornadas: [jornada1],
        clubs: [],
        category: '2011',
      );

      expect(res2011.latestFecha, 20);
      expect(res2011.appliedFechas, [20]);

      // Marconi ganó: 2 pts, 4 GF, 1 GC, DG +3
      final marconi = res2011.rows.firstWhere((r) => r['name'] == 'Marconi');
      expect(marconi['pj'], 1);
      expect(marconi['pg'], 1);
      expect(marconi['pe'], 0);
      expect(marconi['pp'], 0);
      expect(marconi['pts'], 2);
      expect(marconi['gf'], 4);
      expect(marconi['gc'], 1);
      expect(marconi['dg'], 3);

      // Newbery perdió: 0 pts, 1 GF, 4 GC, DG -3
      final newbery = res2011.rows.firstWhere((r) => (r['name'] as String).contains('Newbery'));
      expect(newbery['pj'], 1);
      expect(newbery['pp'], 1);
      expect(newbery['pts'], 0);
      expect(newbery['gf'], 1);
      expect(newbery['gc'], 4);
      expect(newbery['dg'], -3);

      // Junior empató: 1 pt
      final junior = res2011.rows.firstWhere((r) => r['name'] == 'Junior');
      expect(junior['pj'], 1);
      expect(junior['pe'], 1);
      expect(junior['pts'], 1);

      // Los Pibes empató: 1 pt
      final losPibes = res2011.rows.firstWhere((r) => r['name'] == 'Los Pibes');
      expect(losPibes['pj'], 1);
      expect(losPibes['pe'], 1);
      expect(losPibes['pts'], 1);

      // Clubes que no jugaron quedan con 0 pj y 0 pts
      final sanCarlos = res2011.rows.firstWhere((r) => r['name'] == 'San Carlos');
      expect(sanCarlos['pj'], 0);
      expect(sanCarlos['pts'], 0);
    });

    test('Torneo Clausura sums fechas 20-38 while Torneo Apertura stays at 0 when only 20-23 exist', () {
      final jornadas = [
        {
          'id': 'jornada_20',
          'fechaNumber': 20,
          'tournamentType': 'clausura',
          'matches': [
            {
              'homeTeam': 'Marconi',
              'awayTeam': 'Jorge Newbery',
              'categories': {
                '2011': {'homeGoals': 4, 'awayGoals': 1},
              },
            }
          ],
        },
        {
          'id': 'jornada_21',
          'fechaNumber': 21,
          'tournamentType': 'clausura',
          'matches': [
            {
              'homeTeam': 'Junior',
              'awayTeam': 'Jorge Newbery',
              'categories': {
                '2011': {'homeGoals': 2, 'awayGoals': 0},
              },
            }
          ],
        }
      ];

      // Clausura: suma las 2 fechas
      final resClausura = computeStandingsWithJornadas(
        jornadas: jornadas,
        clubs: [],
        category: '2011',
      );
      expect(resClausura.appliedFechas, [20, 21]);
      final marconi = resClausura.rows.firstWhere((r) => r['name'] == 'Marconi');
      expect(marconi['pj'], 1);
      expect(marconi['pts'], 2);

      // Apertura: ninguna fecha corresponde a Apertura (1 a 19), todo queda en 0
      final resApertura = computeStandingsWithJornadas(
        jornadas: jornadas,
        clubs: [],
        category: '2011',
        tournament: 'apertura',
      );
      expect(resApertura.appliedFechas.isEmpty, true);
      final marconiAp = resApertura.rows.firstWhere((r) => r['name'] == 'Marconi');
      expect(marconiAp['pj'], 0);
      expect(marconiAp['pts'], 0);
      final newberyAp = resApertura.rows.firstWhere((r) => (r['name'] as String).contains('Newbery'));
      expect(newberyAp['pj'], 0);
      expect(newberyAp['pts'], 0);
    });
  });
}
