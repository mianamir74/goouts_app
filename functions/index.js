const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { initializeApp }     = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging }      = require('firebase-admin/messaging');

try { initializeApp(); } catch (_) {}

const db        = getFirestore();
const messaging = getMessaging();

// ── processReferralReward ─────────────────────────────────────────────────
// Fires when a user's firstCashbackEarned flips to true.
// Credits £2 to the referrer, sends notification + FCM push.
exports.processReferralReward = onDocumentUpdated(
  {
    document: 'users/{uid}',
    region:   'europe-west1',
  },
  async (event) => {
    const before = event.data.before.data();
    const after  = event.data.after.data();
    const uid    = event.params.uid;

    if (before.firstCashbackEarned === true) return null;
    if (after.firstCashbackEarned  !== true) return null;

    const referrerUid = after.referredByUid;
    if (!referrerUid)                    return null;
    if (after.referralRewarded === true) return null;

    // Idempotency guard first
    await db.collection('users').doc(uid).update({ referralRewarded: true });

    const referrerRef  = db.collection('users').doc(referrerUid);
    const referrerSnap = await referrerRef.get();
    if (!referrerSnap.exists) return null;

    // Credit £2
    await referrerRef.update({ walletBalance: FieldValue.increment(2.0) });

    // Transaction record
    const newUserName = after.fullName || 'a friend';
    const now         = new Date();
    const months      = ['January','February','March','April','May','June',
                         'July','August','September','October','November','December'];
    const month       = `${months[now.getMonth()]} ${now.getFullYear()}`;
    const h           = now.getHours() % 12 || 12;
    const min         = String(now.getMinutes()).padStart(2, '0');
    const ampm        = now.getHours() < 12 ? 'AM' : 'PM';

    await referrerRef.collection('transactions').add({
      title:           `Referral Reward — ${newUserName} joined`,
      amount:          2.0,
      amountFormatted: '+£2.00',
      dateFormatted:   `Today, ${h}:${min} ${ampm}`,
      month,
      type:            'Referral Reward',
      iconKey:         'gift',
      positive:        true,
      status:          'Completed',
      note:            `${newUserName} signed up and placed their first order.`,
      createdAt:       FieldValue.serverTimestamp(),
    });

    // Firestore notification
    await referrerRef.collection('notifications').add({
      title:     'You earned £2!',
      body:      `${newUserName} just placed their first order using your invite code. £2 has been added to your GoOuts wallet.`,
      type:      'referral_reward',
      read:      false,
      route:     '/refer-friend',
      createdAt: FieldValue.serverTimestamp(),
    });

    // FCM push
    const fcmToken = referrerSnap.data().fcmToken;
    if (fcmToken) {
      try {
        await messaging.send({
          token: fcmToken,
          notification: {
            title: 'You earned £2!',
            body:  `${newUserName} placed their first order with your code. £2 is now in your wallet.`,
          },
          data: { screen: 'refer_friend', type: 'referral_reward' },
          android: { priority: 'high' },
          apns:    { payload: { aps: { sound: 'default', badge: 1 } } },
        });
      } catch (e) {
        console.warn('FCM send failed (non-fatal):', e.message);
      }
    }

    console.log(`Referral reward: £2 credited to ${referrerUid} for referring ${uid}`);
    return null;
  }
);
