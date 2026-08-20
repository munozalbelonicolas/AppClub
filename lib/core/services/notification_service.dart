import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'app_logger.dart';
import 'onesignal_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  AppLogger.debug('Handling background FCM message: ${message.messageId}', tag: 'FCM');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'Notificaciones Importantes',
    description: 'Canal principal de avisos, partidos y novedades del club',
    importance: Importance.max,
  );

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Request Permission
    final settings = await _messaging.requestPermission();

    AppLogger.debug('User granted notification permission: ${settings.authorizationStatus}', tag: 'FCM');

    // 2. Setup Local Notifications for Foreground
    const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        AppLogger.debug('Notification tapped in foreground: ${response.payload}', tag: 'FCM');
      },
    );

    // Create Android notification channel
    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(_channel);
    }

    // Set foreground notification options for iOS
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 3. Listen for Foreground FCM Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final android = message.notification?.android;

      if (notification != null && !kIsWeb) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              icon: android?.smallIcon ?? 'ic_stat_onesignal_default',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: message.data.toString(),
        );
      }
    });

    // 4. Listen for Background tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      AppLogger.debug('Notification clicked (App opened from background): ${message.data}', tag: 'FCM');
    });

    // Check if app was opened from terminated state by a notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      AppLogger.debug('App launched from terminated state via notification: ${initialMessage.data}', tag: 'FCM');
    }
  }

  /// Save or update user FCM Token in Firestore profile
  Future<void> saveTokenUser(String userId) async {
    try {
      if (userId.isEmpty) return;
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'fcmToken': token,
          'fcmTokens': FieldValue.arrayUnion([token]),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        AppLogger.debug('FCM Token successfully registered for user $userId', tag: 'FCM');
      }

      // Listen for token updates
      _messaging.onTokenRefresh.listen((newToken) async {
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'fcmToken': newToken,
          'fcmTokens': FieldValue.arrayUnion([newToken]),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } catch (e) {
      AppLogger.error('Error saving FCM Token for user $userId', error: e, tag: 'FCM');
    }
  }

  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  DateTime _sessionStartTime = DateTime.now();

  /// Listens to real-time notifications in Firestore and displays local notifications
  void startNotificationStream(String currentUserId, {String? userCategory}) {
    _notificationSubscription?.cancel();
    _sessionStartTime = DateTime.now().subtract(const Duration(seconds: 5));

    _notificationSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_sessionStartTime))
        .snapshots()
        .listen(
      (snapshot) {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data == null) continue;

            final authorId = data['authorId']?.toString() ?? '';
            if (authorId == currentUserId) continue; // Don't notify self

            final targetUserId = data['targetUserId']?.toString() ?? '';
            final targetCategory = data['targetCategory']?.toString() ?? '';

            bool isForMe = false;
            if (targetUserId.isNotEmpty && targetUserId != 'all') {
              isForMe = (targetUserId == currentUserId);
            } else if (targetCategory == 'private') {
              isForMe = false;
            } else if (targetCategory.isNotEmpty &&
                targetCategory != 'all' &&
                targetCategory != 'todos') {
              isForMe = userCategory != null &&
                  userCategory.isNotEmpty &&
                  userCategory.toLowerCase() == targetCategory.toLowerCase();
            } else {
              isForMe = true;
            }

            if (isForMe) {
              final title = data['title']?.toString() ?? 'Nueva Notificación';
              final body = data['body']?.toString() ?? '';
              showLocalNotification(
                id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                title: title,
                body: body,
              );
            }
          }
        }
      },
      onError: (error) {
        AppLogger.error('Notification stream error (non-fatal)', error: error, tag: 'FCM');
        // Do NOT rethrow - errors here must not affect other Firestore streams
      },
    );
  }

  /// Displays a local banner notification with sound
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _localNotifications.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: 'ic_stat_onesignal_default',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  /// Helper to push a new notification document to Firestore and trigger OneSignal Push
  Future<void> sendNotification({
    required String title,
    required String body,
    required String authorId,
    String targetUserId = 'all',
    String targetCategory = 'all',
  }) async {
    try {
      // 1. Guardar documento en Firestore (para notificaciones en tiempo real in-app)
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': title,
        'body': body,
        'authorId': authorId,
        'targetUserId': targetUserId,
        'targetCategory': targetCategory,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Enviar notificación Push real a los dispositivos vía OneSignal
      await OneSignalService().sendPushNotification(
        title: title,
        body: body,
        targetUserId: targetUserId,
        targetCategory: targetCategory,
      );
    } catch (e) {
      AppLogger.error('Error sending notification doc', error: e, tag: 'FCM');
    }
  }
}
