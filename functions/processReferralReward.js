/**
 * processReferralReward — Cloud Function (Node.js 20, europe-west1)
 *
 * Trigger: Firestore onDocumentUpdated  users/{uid}
 * Fires when a user document changes.
 * Logic:
 *   - Only acts when firstCashbackEarned flips from false → true
 *   - Checks that referredByUid exists and referralRewarded is false
 *   - Credits £2 to the referrer's wallet (FieldValue.increment)
 *   - Adds a transaction record to the referrer's transactions sub-collection
 *   - Adds a Firestore notification to the referrer's notifications sub-collection
 *   - Sends FCM push notification to the referrer
 *   - Sets referralRewarded: true on the new user's document (idempotency guard)
 *
 * Deploy:
 *   firebase deploy --only functions:processReferralReward
 */

const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { initializeApp }     = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging }      = require('firebase-admin/messaging');

try { initializeApp(); } catch (_) {}  // guard against double-init

const db        = getFirestore();
const messaging = getMessaging();

exports.processReferralReward = onDocumentUpdated(
  {
    document: 'users/{uid}',
    region:   'europe-west1',
  },
  async (event) => {
    const before = event.data.before.data();
    const after  = event.data.after.data();
    const uid    = event.params.uid;

    // Only fire when firstCashbackEarned flips false → true
    if (before.firstCashbackEarned === true)  return null;
    if (after.firstCashbackEarned  !== true)  return null;

    // Must have a referrer and not already rewarded
    const referrerUid = after.referredByUid;
    if (!referrerUid)                         return null;
    if (after.referralRewarded === true)      return null;

    // Mark as rewarded immediately (idempotency guard)
    await db.collection('users').doc(uid).update({ referralRewarded: true });

    // ── Credit £2 to referrer's wallet ───────────────────────────────────
    const referrerRef = db.collection('users').doc(referrerUid);
    const referrerSnap = await referrerRef.get();
    if (!referrerSnap.exists) return null;

    await referrerRef.update({
      walletBalance: FieldValue.increment(2.0),
    });

    // ── Transaction record for referrer's Activity screen ────────────────
    const newUserName = after.fullName || 'a friend';
    const now         = new Date();
    const months      = ['January','February','March','April','May','June',
                         'July','August','September','October','November','December'];
    const month       = `${months[now.getMonth()]} ${now.getFullYear()}`;
    const h           = now.getHours() % 12 || 12;
    const min         = String(now.getMinutes()).padStart(2, '0');
    const ampm        = now.getHours() < 12 ? 'AM' : 'PM';
    const dateFormatted = `Today, ${h}:${min} ${ampm}`;

    await referrerRef.collection('transactions').add({
      title:           `Referral Reward — ${newUserName} joined`,
      amount:          2.0,
      amountFormatted: '+£2.00',
      dateFormatted,
      month,
      type:            'Referral Reward',
      iconKey:         'gift',
      positive:        true,
      status:          'Completed',
      note:            `${newUserName} signed up and placed their first order.`,
      createdAt:       FieldValue.serverTimestamp(),
    });

    // ── Firestore notification (shows in app Notifications screen) ────────
    await referrerRef.collection('notifications').add({
      title:     'You earned £2!',
      body:      `${newUserName} just placed their first order using your invite code. £2 has been added to your GoOuts wallet.`,
      type:      'referral_reward',
      read:      false,
      route:     '/refer-friend',
      createdAt: FieldValue.serverTimestamp(),
    });

    // ── FCM push notification ─────────────────────────────────────────────
    const fcmToken = referrerSnap.data().fcmToken;
    if (fcmToken) {
      try {
        await messaging.send({
          token: fcmToken,
          notification: {
            title: 'You earned £2! 🎉',
            body:  `${newUserName} placed their first order with your code. £2 is now in your wallet.`,
          },
          data: {
            screen: 'refer_friend',
            type:   'referral_reward',
          },
          android: { priority: 'high' },
          apns:    { payload: { aps: { sound: 'default', badge: 1 } } },
        });
      } catch (fcmErr) {
        console.warn('FCM send failed (non-fatal):', fcmErr.message);
      }
    }

    console.log(`Referral reward: £2 credited to ${referrerUid} for referring ${uid}`);
    return null;
  }
);
