import * as admin from 'firebase-admin';

if (!admin.apps.length) {
  admin.initializeApp();
}

export * from './socialExport';
export * from './authHooks';
// NOTE: Push notifications via Cloud Functions (notifications.ts) require Firebase Blaze plan
// (outbound network calls to FCM API are blocked on Spark free plan).
// Real-time in-app notifications are handled client-side via Firestore listeners in
// notification_service.dart → startNotificationStream().
// To re-enable server-side push, upgrade to Blaze and uncomment:
// export * from './notifications';