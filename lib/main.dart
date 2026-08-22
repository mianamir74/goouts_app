import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'features/short_stay/stay_routes.dart';

import 'screens/splash_screen.dart';
import 'screens/slide1_screen.dart';
import 'screens/slide2_screen.dart';
import 'screens/slide2a_screen.dart';
import 'screens/slide3_screen.dart';
import 'screens/slide4_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/create_profile_screen.dart';
import 'screens/create_profile_expanded_screen.dart';
import 'screens/link_card_screen.dart';
import 'screens/link_card_details_screen.dart';
import 'screens/link_bank_screen.dart';
import 'screens/add_to_wallet_screen.dart';
import 'screens/registration_success_screen.dart';
import 'screens/home_screen.dart';
import 'screens/services_screen.dart';
import 'screens/nearby_screen.dart';
import 'screens/partner_details_screen.dart';
import 'screens/wallet_screen.dart';
import 'screens/add_funds_screen.dart';
import 'screens/transfer_screen.dart';
import 'screens/transfer_success_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/profile_security_screen.dart';
import 'screens/two_fa_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/notification_detail_screen.dart';
import 'screens/message_center_screen.dart';
import 'screens/faq_screen.dart';
import 'screens/support_tickets_screen.dart';
import 'screens/support_ticket_chat_screen.dart';
import 'screens/contact_support_screen.dart';
import 'screens/login_screen.dart';
import 'screens/special_offers_screen.dart';
import 'screens/partner_offer_screen.dart';
import 'screens/bonus_added_screen.dart';
import 'screens/activity_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/kyc_screen.dart';
import 'screens/payment_review_screen.dart';
import 'screens/biometric_lock_screen.dart';
import 'screens/food_delivery_screen.dart';
import 'screens/food_address_picker_screen.dart';
import 'screens/food_menu_screen.dart';
import 'screens/food_order_tracking_screen.dart';
import 'screens/food_delivery_chat_screen.dart';
import 'screens/food_order_history_screen.dart';
import 'screens/refer_friend_screen.dart';
import 'screens/family_plan_screen.dart';
import 'screens/goouts_plus_unlocked_screen.dart';
import 'screens/family_cashback_intro_screen.dart';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/partner_seed_service.dart';
import 'services/user_fcm_service.dart';
import 'services/delivery_address_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ── Crashlytics ─────────────────────────────────────────────────────────────
  // Pass all uncaught Flutter errors to Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  // Pass all uncaught async errors to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  // Disable Crashlytics in debug mode so we see errors in console instead
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);

  // Initialise push notifications
  await UserFcmService.instance.initialize();
  // Load persisted delivery address
  await DeliveryAddressService().init();
  // Auto-seeds merchants collection once — skips if already done
  PartnerSeedService().seedOnce().catchError((_) {});
  // ── THE FRESH-INSTALL GUARD MOVED OUT OF HERE ──────────────────────────
  //
  // 14 August 2026. It used to be awaited on this line, before runApp.
  //
  // Until runApp is called Flutter has painted nothing — iOS shows the static
  // launch image and nothing else. The guard was changed earlier the same day
  // to await the first authStateChanges event, which is allowed up to five
  // seconds, so a slow cold start meant up to five seconds of frozen picture
  // before the app appeared.
  //
  // This app already learned that lesson once: see the note in driver_app's
  // main.dart about awaiting FCM here, which produced "a guaranteed ~10s blank
  // screen then crash on every launch".
  //
  // It now runs inside SplashScreen.initState, during the 1200ms the splash
  // animation is already on screen. Same protection, no blank window.

  runApp(const GoOutsApp());
}

/// Route a FCM RemoteMessage to the correct screen.
void routeFromMessage(RemoteMessage msg) {
  final nav = navigatorKey.currentState;
  if (nav == null) return;
  final data   = msg.data;
  final screen = (data['screen'] ?? '').toString();
  switch (screen) {
    case 'support_ticket_chat':
      nav.pushNamed('/support-ticket-chat', arguments: {
        'ticketId':     data['ticketId']     ?? '',
        'subject':      data['subject']      ?? 'Support Ticket',
        'ticketNumber': data['ticketNumber'] ?? '',
        'userName':     'GoOuts Support',
      });
      break;
    case 'kyc':
      nav.pushNamed('/kyc');
      break;
    case 'profile':
      nav.pushNamed('/profile');
      break;
    case 'wallet':
      nav.pushNamed('/wallet');
      break;
    case 'messages':
      nav.pushNamed('/messages');
      break;
    case 'refer_friend':
      nav.pushNamed('/refer-friend');
      break;
    // ⚠ THE KEY IS SET IN stay_messages.js AS 'stay_message_thread' AND THE
    // ARGUMENT SHAPE IS StayRoutes' Map, not a bare string. Tapping the
    // notification lands in the conversation it is about; without this case
    // it fell through to /notifications, which is not where the message is.
    case 'stay_message_thread':
      nav.pushNamed(StayRoutes.messageHost, arguments: <String, dynamic>{
        'bookingId': (data['bookingId'] ?? '').toString(),
      });
      break;
    case 'notifications':
    default:
      nav.pushNamed('/notifications');
      break;
  }
}

class GoOutsApp extends StatefulWidget {
  const GoOutsApp({super.key});

  @override
  State<GoOutsApp> createState() => _GoOutsAppState();
}

class _GoOutsAppState extends State<GoOutsApp> {
  StreamSubscription<RemoteMessage>? _openedSub;

  @override
  void initState() {
    super.initState();
    // Background tap — app was running in background
    _openedSub = UserFcmService.instance.openedMessages.listen(routeFromMessage);

    // Terminated tap — app was killed; handle after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initial = UserFcmService.instance.consumeInitialMessage();
      if (initial != null) routeFromMessage(initial);
    });
  }

  @override
  void dispose() {
    _openedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'GoOuts',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),

      // Short Stay, added 4 August 2026. Until this line existed the whole
      // feature — 41 files, about 11,000 lines — was unreachable from the app.
      //
      // It is one line rather than 29 entries in `routes` below because
      // StayRoutes.onGenerateRoute owns its own names, parses its own
      // arguments, and returns null for anything that is not a /stay route, so
      // the map below still handles everything else. Adding a Short Stay screen
      // means touching stay_routes.dart only, never this file.
      // HOST SIDE REMOVED 6 August 2026. The 25 host screens were chained here
      // on 4 August, but a host and a guest are different people using
      // different apps — the host side now lives in the separate GoOuts Host
      // app (goouts/goouts_host, bundle com.goouts.host). Shipping those
      // screens inside the consumer app meant every guest carried 10,000 lines
      // of property-management UI they can never reach.
      //
      // The chain still works the same way: StayRoutes returns NULL for any
      // name it does not own, so `routes` below handles everything else. A
      // resolver that returned a "not found" page instead of null would
      // swallow every route after it.
      onGenerateRoute: (settings) => StayRoutes.onGenerateRoute(settings),

      routes: {
        '/splash': (context) => const SplashScreen(),
        '/slide1': (context) => const Slide1Screen(),
        '/slide2': (context) => const Slide2Screen(),
        '/slide2a': (context) => const Slide2aScreen(),
        '/slide3': (context) => const Slide3Screen(),
        '/slide4': (context) => const Slide4Screen(),
        '/signup': (context) => const SignupScreen(),
        '/otp': (context) => const OtpScreen(),
        '/create-profile': (context) => const CreateProfileScreen(),
        '/create-profile-expanded': (context) => const CreateProfileExpandedScreen(),
        '/link-card': (context) => const LinkCardScreen(),
        '/link-card-details': (context) => const LinkCardDetailsScreen(),
        '/link-bank': (context) => const LinkBankScreen(),
        '/add-to-wallet': (context) => const AddToWalletScreen(),
        '/registration-success': (context) => const RegistrationSuccessScreen(),
        '/home': (context) => const HomeScreen(),
        '/services': (context) => const ServicesScreen(),
        '/nearby': (context) => const NearbyScreen(),
        '/partner-details': (context) => const PartnerDetailsScreen(),
        '/wallet': (context) => const WalletScreen(),
        '/add-funds': (context) => const AddFundsScreen(),
        '/transfer': (context) => const TransferScreen(),
        '/transfer-success': (context) => const TransferSuccessScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/profile-security': (context) => const ProfileSecurityScreen(),
        '/2fa-setup': (context) => const TwoFaScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/notification-detail': (context) => const NotificationDetailScreen(),
        '/messages': (context) => const MessageCenterScreen(),
        '/faq': (context) => const FaqScreen(),
        '/support-tickets': (context) => const SupportTicketsScreen(),
        '/contact-support': (context) => const ContactSupportScreen(),
        '/support-ticket-chat': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>?;
          return SupportTicketChatScreen(
            ticketId:     args?['ticketId']     as String? ?? '',
            subject:      args?['subject']      as String? ?? '',
            ticketNumber: args?['ticketNumber'] as String? ?? '',
            userName:     args?['userName']     as String? ?? '',
          );
        },
        '/login': (context) => const LoginScreen(),
        '/special-offers': (context) => const SpecialOffersScreen(),
        '/partner-offer': (context) => const PartnerOfferScreen(),
        '/bonus-added': (context) => const BonusAddedScreen(),
        '/family-plan': (context) => const FamilyPlanScreen(),
        '/goouts-plus-unlocked': (context) => const GoOutsPlusUnlockedScreen(),
        '/family-cashback-intro': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map?;
          final fromOnboarding = args?['fromOnboarding'] as bool? ?? false;
          return FamilyCashbackIntroScreen(fromOnboarding: fromOnboarding);
        },
        '/activity': (context) => const ActivityScreen(),
        '/explore': (context) => const ExploreScreen(),
        '/kyc': (context) => const KycScreen(),
        '/payment-review': (context) => const PaymentReviewScreen(),
        '/biometric-lock': (context) => const BiometricLockScreen(nextRoute: '/home'),
        '/food-delivery': (context) => const FoodDeliveryScreen(),
        '/food-address-picker': (context) => const FoodAddressPickerScreen(),
        '/food-menu': (context) => const FoodMenuScreen(),
        // Task #73 — cart/checkout screen (placeholder until built)
        '/food-cart': (context) => Scaffold(
          appBar: AppBar(title: const Text('Your Cart')),
          body: const Center(child: Text('Cart coming soon — Task #73')),
        ),
        // Task #74 — live order tracking + Add to Order
        '/food-order-tracking': (context) => const FoodOrderTrackingScreen(),
        '/food-delivery-chat': (context) => const FoodDeliveryChatScreen(),
        '/food-order-history': (context) => const FoodOrderHistoryScreen(),
        '/refer-friend': (context) => const ReferFriendScreen(),
      },
    );
  }
}
