import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../../features/communications/presentation/screens/communications_screen.dart';
import '../../features/inbox/presentation/screens/chat_screen.dart';
import '../../features/settings/presentation/screens/admin_user_profile_screen.dart';
import '../../features/settings/presentation/screens/director_console_screen.dart';
import '../../features/store/presentation/screens/admin_order_detail_screen.dart';
import '../config/onesignal_config.dart';
import 'app_logger.dart';
import 'navigation_service.dart';
import 'notification_service.dart';

class OneSignalService {
  static final OneSignalService _instance = OneSignalService._internal();
  factory OneSignalService() => _instance;
  OneSignalService._internal();

  bool _initialized = false;
  String? _currentUserId;

  /// Retorna el ID del usuario actualmente autenticado en OneSignal
  String? get currentUserId => _currentUserId;

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
        handleNotificationPayload(event.notification.additionalData);
      });

      // Listener para cuando se recibe una notificación en primer plano
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        final data = event.notification.additionalData;
        final authorId = data?['authorId']?.toString();

        // 1. Si la notificación fue generada por el usuario actual, prevenir banner duplicado
        if (authorId != null &&
            authorId.isNotEmpty &&
            _currentUserId != null &&
            authorId == _currentUserId) {
          AppLogger.debug(
            '🛑 Notificación push prevenida para el propio autor: ${event.notification.title}',
            tag: 'OneSignal',
          );
          event.preventDefault();
          return;
        }

        // 2. Prevenir duplicados entre Firestore stream / FCM / OneSignal
        final title = event.notification.title ?? '';
        final body = event.notification.body ?? '';
        if (NotificationService.isDuplicateAndRecord(title, body)) {
          AppLogger.debug(
            '🛑 Notificación duplicada prevenida en OneSignal: $title',
            tag: 'OneSignal',
          );
          event.preventDefault();
          return;
        }
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
    _currentUserId = userId;
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
    _currentUserId = null;
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

  /// Segmento de OneSignal con todos los dispositivos suscriptos. Debe existir en el panel:
  /// si se manda un nombre inexistente (ej. 'Subscribed Users') la API rechaza el envío.
  static const String broadcastSegment = 'Total Subscriptions';

  /// OneSignal puede responder 200 con `errors` (ej. sin destinatarios): eso no es un envío exitoso.
  static bool isSuccessfulResponse(int statusCode, String body) {
    if (statusCode != 200 && statusCode != 201) return false;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final errors = decoded['errors'];
        if (errors is List && errors.isNotEmpty) return false;
        if (errors is Map && errors.isNotEmpty) return false;
        final id = decoded['id']?.toString() ?? '';
        if (decoded.containsKey('id') && id.isEmpty) return false;
      }
    } catch (_) {}
    return true;
  }

  /// Categorías de comunicados que no son categorías de jugadores: van a todos.
  static const Set<String> _broadcastCategories = {
    'all',
    'todos',
    'general',
    'club',
    'deportivo',
    'administrativo',
    'institucional',
  };

  static bool isBroadcastCategory(String? category) {
    final normalized = (category ?? '').trim().toLowerCase();
    return normalized.isEmpty || _broadcastCategories.contains(normalized);
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
        'existing_android_channel_id': 'high_importance_channel',
        'priority': 10,
        'data': ?data,
      };

      if (targetUserId != null &&
          targetUserId.isNotEmpty &&
          targetUserId != 'all') {
        payload['include_aliases'] = {
          'external_id': [targetUserId]
        };
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
      } else if (targetCategory != null && !isBroadcastCategory(targetCategory)) {
        final catClean = targetCategory.toLowerCase().trim();
        payload['filters'] = [
          {
            'field': 'tag',
            'key': 'category',
            'relation': '=',
            'value': targetCategory,
          },
          {
            'operator': 'OR',
          },
          {
            'field': 'tag',
            'key': 'cat_$catClean',
            'relation': '=',
            'value': 'true',
          }
        ];
      } else {
        payload['included_segments'] = [broadcastSegment];
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

      final ok = isSuccessfulResponse(response.statusCode, response.body);
      if (ok) {
        AppLogger.debug(
          '📡 OneSignal Push Response [${response.statusCode}]: ${response.body}',
          tag: 'OneSignal',
        );
      } else {
        AppLogger.warning(
          '⚠️ OneSignal rechazó el push "$title" [${response.statusCode}]: ${response.body}',
          tag: 'OneSignal',
        );
      }
      return ok;
    } catch (e) {
      AppLogger.error('❌ Error enviando Push por OneSignal', error: e, tag: 'OneSignal');
      return false;
    }
  }

  /// Procesa los datos adjuntos de la notificación para navegación interna.
  void handleNotificationPayload(Map<String, dynamic>? additionalData) {
    if (additionalData == null) return;
    AppLogger.debug('🚀 Procesando deep-link desde OneSignal: $additionalData', tag: 'OneSignal');

    try {
      final type = additionalData['type']?.toString();
      final threadId = additionalData['threadId']?.toString();

      // 1. Mensaje de Chat
      if (type == 'chat' || (threadId != null && threadId.isNotEmpty)) {
        final otherUserId = additionalData['otherUserId']?.toString();
        final otherUserName = additionalData['otherUserName']?.toString() ?? 'Conversación';
        final otherUserRole = additionalData['otherUserRole']?.toString() ?? 'usuario';

        if (threadId != null && threadId.isNotEmpty) {
          NavigationService.navigateTo(
            ChatScreen(
              threadId: threadId,
              otherUserId: otherUserId,
              otherUserName: otherUserName,
              otherUserRole: otherUserRole,
            ),
          );
          return;
        }
      }

      // 2. Comunicados / Novedades
      if (type == 'announcement' ||
          type == 'comunicado' ||
          type == 'novedad' ||
          type == 'novedades') {
        NavigationService.navigateTo(const CommunicationsScreen());
        return;
      }

      // 3. Compras en Tienda
      if (type == 'store_purchase' || type == 'store_receipt_uploaded' || type == 'order') {
        final orderId = additionalData['orderId']?.toString();
        if (orderId != null && orderId.isNotEmpty) {
          NavigationService.navigateTo(AdminOrderDetailScreen(orderId: orderId));
          return;
        }
      }

      // 4. Usuario pendiente de aprobación / Registro de jugador / Co-tutor
      final bool isPendingUserType = type == 'new_user_pending' ||
          type == 'player_registration' ||
          type == 'pending_approval' ||
          type == 'co_tutor_request' ||
          type == 'user_registration';

      final title = additionalData['title']?.toString().toLowerCase() ?? '';
      final body = additionalData['body']?.toString().toLowerCase() ?? '';
      final bool matchesPendingKeywords = title.contains('registro') ||
          title.contains('pendiente') ||
          title.contains('aprobación') ||
          title.contains('aprobacion') ||
          body.contains('aprobación') ||
          body.contains('aprobacion') ||
          body.contains('registro');

      if (isPendingUserType || matchesPendingKeywords) {
        final targetId = additionalData['userId']?.toString() ??
            additionalData['tutorId']?.toString() ??
            additionalData['authorId']?.toString() ??
            additionalData['playerId']?.toString();
        if (targetId != null && targetId.isNotEmpty && targetId != 'system') {
          NavigationService.navigateTo(AdminUserProfileScreen(userId: targetId));
          return;
        } else {
          NavigationService.navigateTo(const DirectorConsoleScreen());
          return;
        }
      }

      // 5. Convocatoria al partido
      if (type == 'convocatoria') {
        NavigationService.popToRoot();
        return;
      }
    } catch (e) {
      AppLogger.error('Error procesando deep-link de notificación', error: e, tag: 'OneSignal');
    }
  }
}
