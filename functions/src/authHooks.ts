import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const onUserDeleted = functions.firestore
  .document('users/{userId}')
  .onDelete(async (snap, context) => {
    const userId = context.params.userId;
    try {
      await admin.auth().deleteUser(userId);
      console.log(`Successfully deleted user ${userId} from Firebase Auth.`);
    } catch (error) {
      console.error(`Error deleting user ${userId} from Firebase Auth:`, error);
    }
  });
