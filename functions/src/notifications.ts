import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

/**
 * Cloud Function triggered when a new document is added to 'novedades' collection.
 * Sends a real-time FCM Push Notification to all active user mobile devices.
 */
export const sendPushOnNovedadCreated = functions.firestore
  .document('novedades/{novedadId}')
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    if (!data) return null;

    const title: string = String(data.title || 'Nueva publicación en el club');
    const body: string = String(data.body || 'Entra para ver las novedades e información del equipo.');
    const category: string = String(data.category || 'all');

    // 1. Fetch active user FCM Tokens
    const usersSnap = await admin.firestore().collection('users').where('status', '==', 'active').get();
    const tokens: string[] = [];

    usersSnap.docs.forEach((doc) => {
      const userData = doc.data();
      const userCat = userData.category;
      const assignedCats: string[] = Array.isArray(userData.assignedCategories)
        ? userData.assignedCategories
        : [];

      // Filter by category visibility if not global
      const isTarget =
        category === 'all' ||
        category === 'todos' ||
        userCat === category ||
        assignedCats.includes(category) ||
        userData.role === 'directivo' ||
        userData.role === 'admin';

      if (isTarget) {
        if (userData.fcmToken && typeof userData.fcmToken === 'string') {
          tokens.push(userData.fcmToken);
        }
        if (Array.isArray(userData.fcmTokens)) {
          userData.fcmTokens.forEach((t: unknown) => {
            if (typeof t === 'string' && t.trim().length > 0 && !tokens.includes(t)) {
              tokens.push(t);
            }
          });
        }
      }
    });

    if (tokens.length === 0) {
      console.log('No active FCM tokens found for target category:', category);
      return null;
    }

    // Deduplicate tokens
    const uniqueTokens = Array.from(new Set(tokens));

    // 2. Prepare FCM Multicast payload
    const message: admin.messaging.MulticastMessage = {
      tokens: uniqueTokens,
      notification: {
        title: title,
        body: body,
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'high_importance_channel',
          priority: 'high',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
      data: {
        novedadId: String(context.params.novedadId || ''),
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
    };

    try {
      const response = await admin.messaging().sendEachForMulticast(message);
      console.log(
        `Successfully sent FCM push notification to ${response.successCount} devices. Failures: ${response.failureCount}`
      );
    } catch (error) {
      console.error('Error sending FCM push notification:', error);
    }

    return null;
  });

/**
 * Cloud Function triggered when a new document is added to 'notifications' collection.
 */
export const sendPushOnNotificationCreated = functions.firestore
  .document('notifications/{notifId}')
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    if (!data) return null;

    const title: string = String(data.title || 'Nueva notificación del club');
    const body: string = String(
      data.body || data.message || 'Tienes un nuevo aviso en la aplicación.'
    );

    const usersSnap = await admin.firestore().collection('users').where('status', '==', 'active').get();
    const tokens: string[] = [];

    usersSnap.docs.forEach((doc) => {
      const userData = doc.data();
      if (userData.fcmToken && typeof userData.fcmToken === 'string') {
        tokens.push(userData.fcmToken);
      }
      if (Array.isArray(userData.fcmTokens)) {
        userData.fcmTokens.forEach((t: unknown) => {
          if (typeof t === 'string' && t.trim().length > 0 && !tokens.includes(t)) {
            tokens.push(t);
          }
        });
      }
    });

    if (tokens.length === 0) return null;
    const uniqueTokens = Array.from(new Set(tokens));

    const message: admin.messaging.MulticastMessage = {
      tokens: uniqueTokens,
      notification: { title, body },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'high_importance_channel',
        },
      },
      data: {
        notificationId: String(context.params.notifId || ''),
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
    };

    try {
      await admin.messaging().sendEachForMulticast(message);
    } catch (error) {
      console.error('Error sending notification push:', error);
    }

    return null;
  });
