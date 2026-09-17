import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jorge_newbery_app/core/services/onesignal_service.dart';

/// Pruebas del contrato con la API REST de OneSignal.
///
/// El bug original: en los envíos "a todo el mundo" se mandaba
/// `included_segments: ['Total Subscriptions', 'All', 'Subscribed Users']`.
/// OneSignal valida TODOS los nombres y si uno no existe en la app rechaza el
/// request completo (HTTP 400), así que el push no le llegaba a nadie.
/// Además `android_channel_id` espera un UUID del panel de OneSignal, no el
/// id del canal Android creado por la app.
void main() {
  setUp(OneSignalService.resetBroadcastSegmentCache);
  tearDown(() {
    OneSignalService().httpClientForTesting = null;
    OneSignalService.resetBroadcastSegmentCache();
  });

  group('buildPushPayload', () {
    test('envío masivo usa un único segmento por request', () {
      final payload = OneSignalService.buildPushPayload(
        title: 'Resultados',
        body: 'Jorge Newbery 2 - 1 Rival',
        targetUserId: 'all',
        targetCategory: 'all',
      );

      final segments = payload['included_segments'] as List;
      expect(segments.length, 1);
      expect(segments.first, 'Total Subscriptions');
      expect(segments.contains('All'), isFalse,
          reason: '"All" no es un segmento válido de OneSignal');
    });

    test('no manda android_channel_id (espera un UUID); usa el campo correcto', () {
      final payload = OneSignalService.buildPushPayload(
        title: 't',
        body: 'b',
        targetCategory: 'all',
      );

      expect(payload.containsKey('android_channel_id'), isFalse);
      expect(payload['existing_android_channel_id'], 'high_importance_channel');
      expect(payload['priority'], 10);
    });

    test('targetCategory "todos"/"general" también son envío masivo', () {
      for (final cat in ['all', 'todos', 'general', null]) {
        final payload = OneSignalService.buildPushPayload(
          title: 't',
          body: 'b',
          targetUserId: 'all',
          targetCategory: cat,
        );
        expect(payload.containsKey('included_segments'), isTrue,
            reason: 'categoría "$cat" debería ser broadcast');
      }
    });

    test('usuario puntual usa include_aliases y no segmentos', () {
      final payload = OneSignalService.buildPushPayload(
        title: 't',
        body: 'b',
        targetUserId: 'uid-123',
      );

      expect(payload.containsKey('included_segments'), isFalse);
      expect(
        (payload['include_aliases'] as Map)['external_id'],
        ['uid-123'],
      );
      expect(payload['target_channel'], 'push');
    });

    test('categoría deportiva usa filtros por tag', () {
      final payload = OneSignalService.buildPushPayload(
        title: 't',
        body: 'b',
        targetUserId: 'all',
        targetCategory: '2011',
      );

      expect(payload.containsKey('included_segments'), isFalse);
      final filters = payload['filters'] as List;
      expect(filters.first['key'], 'category');
      expect(filters.last['key'], 'cat_2011');
    });
  });

  group('lectura de la respuesta de OneSignal', () {
    test('400 con "Segment is not valid" es un fallo reintentable', () {
      const body = '{"errors":["Segment is not valid"]}';
      expect(OneSignalService.isSuccessfulResponse(400, body), isFalse);
      expect(OneSignalService.isRetryableSegmentFailure(400, body), isTrue);
    });

    test('200 con errors en el cuerpo NO es éxito', () {
      const body =
          '{"id":"","recipients":0,"errors":["All included players are not subscribed"]}';
      expect(OneSignalService.isSuccessfulResponse(200, body), isFalse);
    });

    test('200 con recipients > 0 es éxito', () {
      const body = '{"id":"abc-123","recipients":42}';
      expect(OneSignalService.isSuccessfulResponse(200, body), isTrue);
    });

    test('401 (key inválida) no es éxito ni se reintenta por segmento', () {
      const body = '{"errors":["Invalid or missing authentication token"]}';
      expect(OneSignalService.isSuccessfulResponse(401, body), isFalse);
      expect(OneSignalService.isRetryableSegmentFailure(401, body), isFalse);
    });
  });

  group('sendPushNotification (con cliente HTTP simulado)', () {
    test('reintenta con el siguiente segmento si el primero no existe',
        () async {
      final enviados = <List<String>>[];

      OneSignalService().httpClientForTesting = MockClient((request) async {
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        final segs = List<String>.from(payload['included_segments'] as List);
        enviados.add(segs);

        if (segs.first == 'Subscribed Users') {
          return http.Response('{"id":"ok-1","recipients":120}', 200);
        }
        return http.Response('{"errors":["Segment is not valid"]}', 400);
      });

      final ok = await OneSignalService().sendPushNotification(
        title: '⚽ ¡Resultado final!',
        body: 'Jorge Newbery 2 - 1 Rival',
        targetUserId: 'all',
        targetCategory: 'all',
      );

      expect(ok, isTrue);
      expect(enviados.length, 2);
      expect(enviados[0].single, 'Total Subscriptions');
      expect(enviados[1].single, 'Subscribed Users');
    });

    test('recuerda el segmento que funcionó para los envíos siguientes',
        () async {
      var llamadas = 0;

      OneSignalService().httpClientForTesting = MockClient((request) async {
        llamadas++;
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        final seg = (payload['included_segments'] as List).first;
        if (seg == 'Subscribed Users') {
          return http.Response('{"id":"ok","recipients":10}', 200);
        }
        return http.Response('{"errors":["Segment is not valid"]}', 400);
      });

      await OneSignalService().sendPushNotification(
        title: 'a', body: 'b', targetUserId: 'all', targetCategory: 'all');
      expect(llamadas, 2);

      llamadas = 0;
      final ok = await OneSignalService().sendPushNotification(
        title: 'c', body: 'd', targetUserId: 'all', targetCategory: 'all');

      expect(ok, isTrue);
      expect(llamadas, 1, reason: 'debe ir directo al segmento que ya funcionó');
    });

    test('devuelve false si ningún segmento es aceptado', () async {
      OneSignalService().httpClientForTesting = MockClient((_) async =>
          http.Response('{"errors":["Segment is not valid"]}', 400));

      final ok = await OneSignalService().sendPushNotification(
        title: 'a', body: 'b', targetUserId: 'all', targetCategory: 'all');

      expect(ok, isFalse);
    });

    test('un envío a un usuario puntual no reintenta segmentos', () async {
      var llamadas = 0;
      OneSignalService().httpClientForTesting = MockClient((_) async {
        llamadas++;
        return http.Response('{"id":"x","recipients":1}', 200);
      });

      final ok = await OneSignalService().sendPushNotification(
        title: 'a', body: 'b', targetUserId: 'uid-9');

      expect(ok, isTrue);
      expect(llamadas, 1);
    });

    test('la cabecera Authorization usa el prefijo Key para llaves os_v2',
        () async {
      String? auth;
      OneSignalService().httpClientForTesting = MockClient((request) async {
        auth = request.headers['Authorization'];
        return http.Response('{"id":"x","recipients":5}', 200);
      });

      await OneSignalService().sendPushNotification(
        title: 'a', body: 'b', targetUserId: 'all', targetCategory: 'all');

      expect(auth, isNotNull);
      expect(auth!.startsWith('Key os_v2_'), isTrue);
    });
  });
}
