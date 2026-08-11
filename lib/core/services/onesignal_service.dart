import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../config/onesignal_config.dart';

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
      if (kDebugMode) {
        print(
          '⚠️ OneSignal Warning: App ID no configurado en lib/core/config/onesignal_config.dart',
        );
      }
      return;
    }

    _initialized = true;

    try {
      if (kDebugMode) {
        OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      }

      // Inicializar el SDK con el App ID
      OneSignal.initialize(OneSignalConfig.appId);

      // Solicitar permiso de notificaciones push
      await OneSignal.Notifications.requestPermission(true);

      // Listener para cuando el usuario hace clic/tap en una notificación
      OneSignal.Notifications.addClickListener((OSNotificationClickEvent event) {
        if (kDebugMode) {
          print(
            '🔔 OneSignal Notification Clicked: ${event.notification.title} - ${event.notification.additionalData}',
          );
        }
        _handleNotificationClick(event.notification.additionalData);
      });

      // Listener para cuando se recibe una notificación en primer plano
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        if (kDebugMode) {
          print(
            '🔔 OneSignal Notification Foreground Received: ${event.notification.title}',
          );
        }
        // Permitir que la notificación se muestre en pantalla
        event.notification.display();
      });

      if (kDebugMode) {
        print('✅ OneSignal Service inicializado correctamente.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al inicializar OneSignal: $e');
      }
    }
  }

  /// Asocia el ID de usuario de la app (Firebase Auth UID) con OneSignal.
  Future<void> loginUser(String userId) async {
    if (!_initialized) return;
    try {
      await OneSignal.login(userId);
      if (kDebugMode) {
        print('👤 OneSignal User logged in: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error en OneSignal.login: $e');
      }
    }
  }

  /// Desvincula al usuario al cerrar sesión en la app.
  Future<void> logoutUser() async {
    if (!_initialized) return;
    try {
      await OneSignal.logout();
      if (kDebugMode) {
        print('🚪 OneSignal User logged out');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error en OneSignal.logout: $e');
      }
    }
  }

  /// Define etiquetas (Tags) en OneSignal para segmentación (ej. rol, categoría, etc.)
  Future<void> setUserTags(Map<String, String> tags) async {
    if (!_initialized) return;
    try {
      await OneSignal.User.addTags(tags);
      if (kDebugMode) {
        print('🏷️ OneSignal Tags guardadas: $tags');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error en OneSignal.setUserTags: $e');
      }
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
        'target_channel': 'push',
        if (data != null) 'data': data,
      };

      if (targetUserId != null &&
          targetUserId.isNotEmpty &&
          targetUserId != 'all') {
        payload['include_aliases'] = {
          'external_id': [targetUserId]
        };
        payload['include_external_user_ids'] = [targetUserId];
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

      if (kDebugMode) {
        print(
          '📡 OneSignal Push Response [${response.statusCode}]: ${response.body}',
        );
      }

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error enviando Push por OneSignal: $e');
      }
      return false;
    }
  }

  /// Procesa los datos adjuntos de la notificación para navegación interna.
  void _handleNotificationClick(Map<String, dynamic>? additionalData) {
    if (additionalData == null) return;

    // Aquí se procesan rutas o acciones avanzadas al tocar una notificación
    final route = additionalData['route'];
    if (route != null && kDebugMode) {
      print('🚀 Navegar a ruta desde notificación OneSignal: $route');
    }
  }
}
