import * as admin from 'firebase-admin';

if (!admin.apps.length) {
  admin.initializeApp();
}

export * from './socialExport';
export * from './authHooks';
export * from './notifications';