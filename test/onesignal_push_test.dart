import 'package:flutter_test/flutter_test.dart';
import 'package:jorge_newbery_app/core/services/onesignal_service.dart';

void main() {
  group('OneSignalService', () {
    test('el envío masivo usa un segmento que existe en el panel', () {
      expect(OneSignalService.broadcastSegment, 'Total Subscriptions');
    });

    test('200 con id y sin errors es éxito', () {
      expect(OneSignalService.isSuccessfulResponse(200, '{"id":"abc","recipients":5}'), isTrue);
    });

    test('200 con errors NO es éxito', () {
      expect(
        OneSignalService.isSuccessfulResponse(200, '{"id":"","errors":["All included players are not subscribed"]}'),
        isFalse,
      );
    });

    test('400 por segmento inválido NO es éxito', () {
      expect(
        OneSignalService.isSuccessfulResponse(400, '{"errors":["Segment \'Subscribed Users\' is not valid"]}'),
        isFalse,
      );
    });

    test('categorías institucionales de comunicados van a todos', () {
      for (final cat in ['deportivo', 'Administrativo', 'institucional', 'todos', 'all', 'general', '', null]) {
        expect(OneSignalService.isBroadcastCategory(cat), isTrue, reason: '$cat');
      }
    });

    test('una categoría de jugadores no es envío masivo', () {
      expect(OneSignalService.isBroadcastCategory('2015'), isFalse);
      expect(OneSignalService.isBroadcastCategory('admin'), isFalse);
    });
  });
}
