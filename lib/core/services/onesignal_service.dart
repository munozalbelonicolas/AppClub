import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;
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

  /// Endpoint REST de OneSignal para crear notificaciones.
  static const String notificationsEndpoint =
      'https://onesignal.com/api/v1/notifications';

  /// Segmentos que OneSignal crea automáticamente en cada app.
  /// El nombre depende de la antigüedad de la app: las creadas desde 2022 usan
  /// "Total Subscriptions" y las anteriores "Subscribed Users".
  ///
  /// IMPORTANTE: si en `included_segments` se manda UN SOLO nombre que no
  /// existe en la app, OneSignal rechaza el envío COMPLETO y nadie recibe la
  /// notificación. Por eso se prueban de a uno y se recuerda el que funcionó.
  static const List<String> broadcastSegmentCandidates = <String>[
    'Total Subscriptions',
    'Subscribed Users',
    'Active Subscriptions',
    'Active Users',
  ];

  static String? _cachedBroadcastSegment;

  /// Último error devuelto por OneSignal (código HTTP + cuerpo recortado).
  /// Se muestra en pantalla para no depender de los logs, que en una build
  /// de release están silenciados.
  static String? lastErrorDetail;

  /// Cliente HTTP inyectable (solo para pruebas unitarias).
  http.Client? _httpClientOverride;

  @visibleForTesting
  // ignore: avoid_setters_without_getters
  set httpClientForTesting(http.Client? client) => _httpClientOverride = client;

  @visibleForTesting
  static void resetBroadcastSegmentCache() => _cachedBroadcastSegment = null;

  /// Orden en que se prueban los segmentos: primero el último que funcionó.
  @visibleForTesting
  static List<String> broadcastSegmentsToTry() {
    final cached = _cachedBroadcastSegment;
    if (cached == null) return List<String>.from(broadcastSegmentCandidates);
    return <String>[
      cached,
      ...broadcastSegmentCandidates.where((s) => s != cached),
    ];
  }

  Future<http.Response> _post(
    Uri url,
    Map<String, String> headers,
    String body,
  ) {
    final override = _httpClientOverride;
    if (override != null) {
      return override.post(url, headers: headers, body: body);
    }
    return http.post(url, headers: headers, body: body);
  }

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

  /// Construye el cuerpo que se envía a la API REST de OneSignal.
  ///
  /// Se expone para poder validarlo en pruebas unitarias sin tocar la red.
  @visibleForTesting
  static Map<String, dynamic> buildPushPayload({
    required String title,
    required String body,
    String? targetUserId,
    String? targetCategory,
    Map<String, dynamic>? data,
    String broadcastSegment = 'Total Subscriptions',
  }) {
    final Map<String, dynamic> payload = {
      'app_id': OneSignalConfig.appId,
      'headings': {'es': title, 'en': title},
      'contents': {'es': body, 'en': body},
      'small_icon': 'ic_stat_onesignal_default',
      // 'android_channel_id' espera el UUID de una categoría creada en el panel
      // de OneSignal. Para un canal creado por la propia app (Flutter Local
      // Notifications) el campo correcto es 'existing_android_channel_id'.
      'existing_android_channel_id': 'high_importance_channel',
      'priority': 10,
      if (data != null) 'data': data,
    };

    if (targetUserId != null &&
        targetUserId.isNotEmpty &&
        targetUserId != 'all') {
      payload['include_aliases'] = {
        'external_id': [targetUserId]
      };
      payload['target_channel'] = 'push';
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
        targetCategory != 'todos' &&
        targetCategory != 'general') {
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
      // Envío masivo: UN solo segmento por request (ver broadcastSegmentCandidates).
      payload['included_segments'] = <String>[broadcastSegment];
    }

    return payload;
  }

  /// Un 2xx de OneSignal no garantiza entrega: el cuerpo puede traer `errors`
  /// o `recipients: 0`. Esta función decide si el envío realmente salió.
  @visibleForTesting
  static bool isSuccessfulResponse(int statusCode, String rawBody) {
    if (statusCode != 200 && statusCode != 201) return false;
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map) {
        final errors = decoded['errors'];
        if (errors is List && errors.isNotEmpty) return false;
        if (errors is Map && errors.isNotEmpty) return false;

        final recipients = decoded['recipients'];
        if (recipients is num && recipients <= 0) return false;

        final id = decoded['id'];
        if (id != null && id.toString().trim().isEmpty) return false;
      }
    } catch (_) {
      // Cuerpo no JSON con status 2xx: se asume enviado.
    }
    return true;
  }

  /// Indica si conviene reintentar el envío masivo con otro nombre de segmento.
  @visibleForTesting
  static bool isRetryableSegmentFailure(int statusCode, String rawBody) {
    final lower = rawBody.toLowerCase();
    if (lower.contains('segment')) return true;
    if (lower.contains('not subscribed')) return true;
    if (lower.contains('"recipients":0') || lower.contains('"recipients": 0')) {
      return true;
    }
    if (statusCode == 400 || statusCode == 404 || statusCode == 422) return true;
    return false;
  }

  /// Envía una notificación Push vía OneSignal REST API.
  /// Se puede enviar a un usuario específico (targetUserId),
  /// a una categoría específica (targetCategory) o a todos los usuarios ('all').
  ///
  /// Devuelve `true` sólo si OneSignal aceptó el envío y hubo destinatarios.
  Future<bool> sendPushNotification({
    required String title,
    required String body,
    String? targetUserId,
    String? targetCategory,
    Map<String, dynamic>? data,
  }) async {
    lastErrorDetail = null;

    final key = OneSignalConfig.restApiKey;
    if (key.isEmpty) {
      lastErrorDetail = 'Falta la REST API Key de OneSignal.';
      AppLogger.error(
        '❌ OneSignal: falta la REST API Key, no se puede enviar el push.',
        tag: 'OneSignal',
      );
      return false;
    }

    // v2 keys (os_v2_app_*) usan el prefijo 'Key'; las legacy usan 'Basic'.
    final prefix = key.startsWith('os_v2_') ? 'Key' : 'Basic';
    final Map<String, String> headers = {
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': '$prefix $key',
    };

    final url = Uri.parse(notificationsEndpoint);

    final basePayload = buildPushPayload(
      title: title,
      body: body,
      targetUserId: targetUserId,
      targetCategory: targetCategory,
      data: data,
    );
    final bool isBroadcast = basePayload.containsKey('included_segments');
    final List<String> segments =
        isBroadcast ? broadcastSegmentsToTry() : <String>[''];

    String lastResponse = '';

    for (final segment in segments) {
      final payload = isBroadcast
          ? buildPushPayload(
              title: title,
              body: body,
              targetUserId: targetUserId,
              targetCategory: targetCategory,
              data: data,
              broadcastSegment: segment,
            )
          : basePayload;

      try {
        final response = await _post(url, headers, jsonEncode(payload));
        lastResponse = response.body;

        final segmentInfo = isBroadcast ? ' segmento "$segment"' : '';
        AppLogger.debug(
          '📡 OneSignal Push [${response.statusCode}]$segmentInfo: ${response.body}',
          tag: 'OneSignal',
        );

        if (isSuccessfulResponse(response.statusCode, response.body)) {
          if (isBroadcast) _cachedBroadcastSegment = segment;
          lastErrorDetail = null;
          return true;
        }

        lastErrorDetail = 'HTTP ${response.statusCode}: '
            '${response.body.length > 180 ? response.body.substring(0, 180) : response.body}';

        if (!isBroadcast) return false;
        if (!isRetryableSegmentFailure(response.statusCode, response.body)) {
          return false;
        }
      } catch (e) {
        lastErrorDetail = 'Sin respuesta de OneSignal: $e';
        AppLogger.error('❌ Error enviando Push por OneSignal', error: e, tag: 'OneSignal');
        return false;
      }
    }

    lastErrorDetail ??= 'OneSignal rechazó todos los segmentos. $lastResponse';
    AppLogger.error(
      '❌ OneSignal rechazó el envío masivo con todos los segmentos conocidos. '
      'Última respuesta: $lastResponse',
      tag: 'OneSignal',
    );
    return false;
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
      if (type == 'announcement' || type == 'novedad' || type == 'novedades') {
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
