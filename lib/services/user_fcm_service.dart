import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('FCM [goouts_app] background: ${message.messageId}');
}

class UserFcmService {
  UserFcmService._();
  static final UserFcmService instance = UserFcmService._();

  final FirebaseMessaging  _messaging = FirebaseMessaging.instance;
  final FirebaseAuth       _auth      = FirebaseAuth.instance;
  final FirebaseFirestore  _firestore = FirebaseFirestore.instance;

  final StreamController<RemoteMessage> _foregroundController =
      StreamController<RemoteMessage>.broadcast();
  final StreamController<RemoteMessage> _openedController =
      StreamController<RemoteMessage>.broadcast();

  StreamSubscription<User?>?       _authSub;
  StreamSubscription<String>?      _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;

  bool           _initialized          = false;
  RemoteMessage? _initialOpenedMessage;

  Stream<RemoteMessage> get foregroundMessages => _foregroundController.stream;
  Stream<RemoteMessage> get openedMessages     => _openedController.stream;

  // ── Initialise ────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await _messaging.setAutoInitEnabled(true);

    // Permission is requested later via askPermissionWithRationale()
    // so we just sync whatever the current status is
    await _syncToken(notificationsEnabled: await _notificationsEnabled());

    _foregroundSub =
        FirebaseMessaging.onMessage.listen(_onForeground);
    _openedSub =
        FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);
    _initialOpenedMessage = await _messaging.getInitialMessage();

    _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) async {
      await _saveToken(
        token: token,
        notificationsEnabled: await _notificationsEnabled(),
      );
    });

    _authSub = _auth.authStateChanges().listen((user) async {
      if (user != null) {
        try {
          await _syncToken();
        } catch (e) {
          debugPrint('FCM [goouts_app] auth listener error: $e');
        }
      }
    });
  }

  RemoteMessage? consumeInitialMessage() {
    final msg = _initialOpenedMessage;
    _initialOpenedMessage = null;
    return msg;
  }

  Future<String?> getToken() => _messaging.getToken();

  // ── First-launch notification permission dialog ───────────────────────────
  /// Call this once after the home screen loads.
  /// Shows a branded rationale dialog, then the system permission prompt.
  /// Uses SharedPreferences to ensure it only ever runs once.
  Future<void> askPermissionWithRationale(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyAsked = prefs.getBool('notif_permission_asked') ?? false;
    if (alreadyAsked) return;

    // Check if already granted — skip dialog if so
    final current = await _messaging.getNotificationSettings();
    if (_isEnabled(current)) {
      await prefs.setBool('notif_permission_asked', true);
      await _syncToken(notificationsEnabled: true);
      return;
    }

    if (!context.mounted) return;

    // Show branded rationale dialog
    final allow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF0392CA).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_rounded,
                    color: Color(0xFF0392CA), size: 36),
              ),
              const SizedBox(height: 20),
              Text('Stay in the Loop!',
                  style: GoogleFonts.inter(
                      fontSize: 20, fontWeight: FontWeight.w800,
                      color: const Color(0xFF0D1B3E))),
              const SizedBox(height: 10),
              Text(
                'Allow GoOuts to send you notifications for:\n\n'
                '• Cashback earned & confirmed\n'
                '• KYC verification updates\n'
                '• Messages from our team\n'
                '• Exclusive partner offers',
                style: GoogleFonts.inter(
                    fontSize: 13, color: Colors.grey[600], height: 1.6),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0392CA),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text('Allow Notifications',
                      style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Not Now',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: Colors.grey[500])),
              ),
            ],
          ),
        ),
      ),
    );

    await prefs.setBool('notif_permission_asked', true);

    if (allow == true) {
      final settings = await _requestPermission();
      await _syncToken(notificationsEnabled: _isEnabled(settings));
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────
  void _onForeground(RemoteMessage msg) {
    debugPrint('FCM [goouts_app] foreground: ${msg.notification?.title}');
    _foregroundController.add(msg);
  }

  void _onOpened(RemoteMessage msg) {
    debugPrint('FCM [goouts_app] opened: ${msg.notification?.title}');
    _openedController.add(msg);
  }

  Future<NotificationSettings> _requestPermission() =>
      _messaging.requestPermission(
        alert: true, badge: true, sound: true,
        announcement: false, carPlay: false,
        criticalAlert: false, provisional: false,
      );

  Future<void> _syncToken({bool? notificationsEnabled}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;
      await _saveToken(
        token: token,
        notificationsEnabled: notificationsEnabled ?? await _notificationsEnabled(),
      );
    } catch (e) {
      debugPrint('FCM [goouts_app] _syncToken error: $e');
    }
  }

  Future<void> _saveToken({
    required String token,
    required bool   notificationsEnabled,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('users').doc(user.uid).set(
        {
          'fcmToken':           token,
          'fcmTokenUpdatedAt':  FieldValue.serverTimestamp(),
          'notificationsEnabled': notificationsEnabled,
        },
        SetOptions(merge: true),
      );

      debugPrint('FCM [goouts_app] token saved for user ${user.uid}');
    } catch (e) {
      debugPrint('FCM [goouts_app] _saveToken error: $e');
    }
  }

  Future<bool> _notificationsEnabled() async {
    final s = await _messaging.getNotificationSettings();
    return _isEnabled(s);
  }

  bool _isEnabled(NotificationSettings s) =>
      s.authorizationStatus == AuthorizationStatus.authorized ||
      s.authorizationStatus == AuthorizationStatus.provisional;

  Future<void> dispose() async {
    await _authSub?.cancel();
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();
    await _foregroundController.close();
    await _openedController.close();
  }
}
