import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';

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
import 'screens/contact_support_screen.dart';
import 'screens/login_screen.dart';
import 'screens/special_offers_screen.dart';
import 'screens/partner_offer_screen.dart';
import 'screens/bonus_added_screen.dart';
import 'screens/activity_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/kyc_screen.dart';
import 'screens/payment_review_screen.dart';
import 'screens/family_plan_screen.dart';
import 'screens/goouts_plus_unlocked_screen.dart';
import 'screens/family_cashback_intro_screen.dart';
import 'services/partner_seed_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Auto-seeds merchants collection once — skips if already done
  PartnerSeedService().seedOnce().catchError((_) {});
  runApp(const GoOutsApp());
}

class GoOutsApp extends StatelessWidget {
  const GoOutsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GoOuts',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
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
      },
    );
  }
}
