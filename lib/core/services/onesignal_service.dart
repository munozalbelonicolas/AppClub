import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../config/onesignal_config.dart';
import 'app_logger.dart';
import 'notification_service.dart';

class OneSignalService {
  static final OneSignalService _instance = OneSignalService._internal();
  factory OneSignalService() => _instance;
  OneSignalService._internal();

  bool _initialized = false;

  /// Inicializa el SDK de OneSignal si el App ID está configurado.
  Future<void> initialize() async {
    if (_initialized) return;

    if (OneSignalConfig.appId == 'YOUR_ONESIGNAL_APP_ID' ||
        OneSignalConfig.appId.isEmpty) {
      AppLogger.warning(
        '⚠️ OneSignal Warning: App ID no configurado en lib/core/config/onesignal_config.dart',
        tag: 'OneSignal',
      );
      return;
    }

    _initialized = true;

    try {
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

      // Inicializar el SDK con el App ID
      OneSignal.initialize(OneSignalConfig.appId);

      // Solicitar permiso de notificaciones push
      await OneSignal.Notifications.requestPermission(true);

      // Listener para cuando el usuario hace clic/tap en una notificación
      OneSignal.Notifications.addClickListener((OSNotificationClickEvent event) {
        AppLogger.debug(
          '🔔 OneSignal Notification Clicked: ${event.notification.title} - ${event.notification.additionalData}',
          tag: 'OneSignal',
        );
        _handleNotificationClick(event.notification.additionalData);
      });

      // Listener para cuando se recibe una notificación en primer plano
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        final title = event.notification.title ?? '';
        final body = event.notification.body ?? '';
        NotificationService.isDuplicateAndRecord(title, body);
        AppLogger.debug(
          '🔔 OneSignal Notification Foreground Received: $title',
          tag: 'OneSignal',
        );
        // Permitir que la notificación se muestre en pantalla
        event.notification.display();
      });

      AppLogger.debug('✅ OneSignal Service inicializado correctamente.', tag: 'OneSignal');
    } catch (e) {
      AppLogger.error('❌ Error al inicializar OneSignal', error: e, tag: 'OneSignal');
    }
  }

  /// Asocia el ID de usuario de la app (Firebase Auth UID) con OneSignal.
  Future<void> loginUser(String userId) async {
    if (!_initialized) return;
    try {
      await OneSignal.login(userId);
      AppLogger.debug('👤 OneSignal User logged in: $userId', tag: 'OneSignal');
    } catch (e) {
      AppLogger.error('❌ Error en OneSignal.login', error: e, tag: 'OneSignal');
    }
  }

  /// Desvincula al usuario al cerrar sesión en la app.
  Future<void> logoutUser() async {
    if (!_initialized) return;
    try {
      await OneSignal.logout();
      AppLogger.debug('🚪 OneSignal User logged out', tag: 'OneSignal');
    } catch (e) {
      AppLogger.error('❌ Error en OneSignal.logout', error: e, tag: 'OneSignal');
    }
  }

  /// Define etiquetas (Tags) en OneSignal para segmentación (ej. rol, categoría, etc.)
  Future<void> setUserTags(Map<String, String> tags) async {
    if (!_initialized) return;
    try {
      await OneSignal.User.addTags(tags);
      AppLogger.debug('🏷️ OneSignal Tags guardadas: $tags', tag: 'OneSignal');
    } catch (e) {
      AppLogger.error('❌ Error en OneSignal.setUserTags', error: e, tag: 'OneSignal');
    }
  }

  /// Asigna el rol del usuario (socio, profesor, directivo, admin)
  Future<void> setRoleTag(String role) async {
    await setUserTags({'role': role});
  }

  /// Asigna la categoría deportiva del usuario (ej. sub15, primera, etc.)
  Future<void> setCategoryTag(String category) async {
    await setUserTags({'category': category});
  }

  /// Envía una notificación Push vía OneSignal REST API.
  /// Se puede enviar a un usuario específico (targetUserId),
  /// a una categoría específica (targetCategory) o a todos los usuarios ('all').
  Future<bool> sendPushNotification({
    required String title,
    required String body,
    String? targetUserId,
    String? targetCategory,
    Map<String, dynamic>? data,
  }) async {
    try {
      final url = Uri.parse('https://onesignal.com/api/v1/notifications');

      final Map<String, dynamic> payload = {
        'app_id': OneSignalConfig.appId,
        'headings': {'es': title, 'en': title},
        'contents': {'es': body, 'en': body},
        'small_icon': 'ic_stat_onesignal_default',
        'target_channel': 'push',
        'data': ?data,
      };

      if (targetUserId != null &&
          targetUserId.isNotEmpty &&
          targetUserId != 'all') {
        payload['include_aliases'] = {
          'external_id': [targetUserId]
        };
        payload['include_external_user_ids'] = [targetUserId];
      } else if (targetCategory == 'admin' || targetCategory == 'directivo') {
        payload['filters'] = [
          {
            'field': 'tag',
            'key': 'role',
            'relation': '=',
            'value': 'directivo',
          },
          {
            'operator': 'OR',
          },
          {
            'field': 'tag',
            'key': 'role',
            'relation': '=',
            'value': 'secretario',
          },
          {
            'operator': 'OR',
          },
          {
            'field': 'tag',
            'key': 'role',
            'relation': '=',
            'value': 'admin',
          },
          {
            'operator': 'OR',
          },
          {
            'field': 'tag',
            'key': 'isAdmin',
            'relation': '=',
            'value': 'true',
          }
        ];
      } else if (targetCategory != null &&
          targetCategory.isNotEmpty &&
          targetCategory != 'all' &&
          targetCategory != 'todos') {
        payload['filters'] = [
          {
            'field': 'tag',
            'key': 'category',
            'relation': '=',
            'value': targetCategory,
          }
        ];
      } else {
        payload['included_segments'] = ['Subscribed Users', 'All'];
      }

      final Map<String, String> headers = {
        'Content-Type': 'application/json; charset=utf-8',
      };
      if (OneSignalConfig.restApiKey.isNotEmpty) {
        headers['Authorization'] = 'Basic ${OneSignalConfig.restApiKey}';
      }

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(payload),
      );

      AppLogger.debug(
        '📡 OneSignal Push Response [${response.statusCode}]: ${response.body}',
        tag: 'OneSignal',
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      AppLogger.error('❌ Error enviando Push por OneSignal', error: e, tag: 'OneSignal');
      return false;
    }
  }

  /// Procesa los datos adjuntos de la notificación para navegación interna.
  void _handleNotificationClick(Map<String, dynamic>? additionalData) {
    if (additionalData == null) return;

    // Aquí se procesan rutas o acciones avanzadas al tocar una notificación
    final route = additionalData['route'];
    if (route != null) {
      AppLogger.debug('🚀 Navegar a ruta desde notificación OneSignal: $route', tag: 'OneSignal');
    }
  }
}
