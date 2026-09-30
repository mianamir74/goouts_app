import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/stay_booking.dart';
import '../services/stay_booking_service.dart';
import '../stay_routes.dart';
import '../theme/stay_colors.dart';
import '../widgets/desktop_top_nav.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ADDED 14 September 2026, requested directly against a screenshot of
//  Airbnb's own web profile page ("short stay profile page of airbnb and we
//  need to make better then this"). Deliberately NOT the consumer app's
//  '/profile' route — that screen opens into the original phone wallet
//  section (20+ screens, never reviewed for web — see the removal note in
//  01_short_stay_home_screen.dart's desktop nav from 9 September). This is a
//  new, web-native, Short-Stay-scoped profile page instead.
//
//  BETTER THAN AIRBNB'S, deliberately: Airbnb's own profile page is just an
//  empty "About me" card with a "Complete your profile" nag and a "Past
//  trips" link that goes nowhere useful without one. This page adds a real
//  Cashback Wallet summary — Airbnb has no equivalent, and cashback is the
//  actual point of this product — plus a real Trips list, not a promise of
//  one.
//
//  ALL DATA REAL: users/{uid} (fullName/email/phone/walletBalance/
//  cashbackBalance/createdAt — same fields wallet_screen.dart and
//  user_service.dart already write/read) and StayBookingService().myBookings
//  (same stream 14_my_bookings_screen.dart uses). No "Connections"/social
//  section — GoOuts has no such feature, so none is invented here. No inline
//  "Edit profile" write-flow either — editing name/email/phone touches
//  verification (phone re-auth, email change) that already exists as tested
//  flows in the app; this page links out to them rather than half-rebuilding
//  that on web.
// ─────────────────────────────────────────────────────────────────────────────

enum _ProfileSection { about, trips, wallet, settings }

String _statusLabel(String wire) {
  final String spaced = wire.replaceAll('_', ' ');
  return spaced.isEmpty
      ? spaced
      : spaced[0].toUpperCase() + spaced.substring(1);
}

class ProfileWebScreen extends StatefulWidget {
  const ProfileWebScreen({super.key});

  @override
  State<ProfileWebScreen> createState() => _ProfileWebScreenState();
}

class _ProfileWebScreenState extends State<ProfileWebScreen> {
  _ProfileSection _section = _ProfileSection.about;

  bool _loading = true;
  Map<String, dynamic>? _userDoc;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
          .instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (mounted) {
        setState(() {
          _userDoc = doc.data();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool desktop = kIsWeb && constraints.maxWidth >= 900;
        return desktop ? _buildDesktop(context) : _buildMobile(context);
      },
    );
  }

  // ── DESKTOP ──────────────────────────────────────────────────────────────
  Widget _buildDesktop(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _signedOutScaffold(context, desktop: true);
    }
    return Scaffold(
      backgroundColor: GoOutsColors.pageBackground,
      body: Column(
        children: <Widget>[
          const DesktopTopNav(current: DesktopNavTab.none),
          Expanded(
            child: SingleChildScrollView(
              child: DesktopCenter(
                maxWidth: 1100,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: _loading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 80),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            SizedBox(width: 260, child: _sidebar()),
                            const SizedBox(width: 48),
                            Expanded(child: _sectionContent(context, user)),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebar() {
    Widget item(_ProfileSection s, IconData icon, String label) {
      final bool active = _section == s;
      return InkWell(
        onTap: () => setState(() => _section = s),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: active ? GoOutsColors.paleBlueTint : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon,
                  size: 20,
                  color: active
                      ? GoOutsColors.primaryBlue
                      : GoOutsColors.bodyText),
              const SizedBox(width: 12),
              Text(label,
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    color: active
                        ? GoOutsColors.primaryBlue
                        : GoOutsColors.deepNavy,
                  )),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Profile',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: GoOutsColors.deepNavy,
            )),
        const SizedBox(height: 20),
        item(_ProfileSection.about, Icons.person_outline_rounded, 'About me'),
        item(_ProfileSection.trips, Icons.luggage_outlined, 'My Trips'),
        item(_ProfileSection.wallet, Icons.account_balance_wallet_outlined,
            'Cashback Wallet'),
        item(_ProfileSection.settings, Icons.settings_outlined,
            'Account Settings'),
      ],
    );
  }

  Widget _sectionContent(BuildContext context, User user) {
    switch (_section) {
      case _ProfileSection.about:
        return _aboutMe(context, user);
      case _ProfileSection.trips:
        return _trips(context);
      case _ProfileSection.wallet:
        return _wallet(context);
      case _ProfileSection.settings:
        return _settings(context, user);
    }
  }

  // ── ABOUT ME ─────────────────────────────────────────────────────────────
  Widget _aboutMe(BuildContext context, User user) {
    final String fullName =
        (_userDoc?['fullName'] as String?)?.trim() ?? '';
    final String displayName =
        fullName.isNotEmpty ? fullName : (user.displayName ?? 'Guest');
    final String initial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'G';
    final Timestamp? createdTs = _userDoc?['createdAt'] as Timestamp?;
    final String memberSince = createdTs != null
        ? DateFormat('MMMM yyyy').format(createdTs.toDate())
        : '';

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: GoOutsColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GoOutsColors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: GoOutsColors.paleBlueTint,
              shape: BoxShape.circle,
            ),
            child: Text(initial,
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: GoOutsColors.primaryBlue,
                )),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(displayName,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: GoOutsColors.deepNavy,
                    )),
                const SizedBox(height: 4),
                Text(
                    memberSince.isNotEmpty
                        ? 'Guest · Member since $memberSince'
                        : 'Guest',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      color: GoOutsColors.bodyText,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── MY TRIPS ─────────────────────────────────────────────────────────────
  Widget _trips(BuildContext context) {
    return StreamBuilder<List<StayBooking>>(
      stream: StayBookingService.instance.myBookings(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final List<StayBooking> bookings = snap.data ?? const <StayBooking>[];
        if (bookings.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: GoOutsColors.cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: GoOutsColors.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('No trips yet',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: GoOutsColors.deepNavy,
                    )),
                const SizedBox(height: 8),
                Text('When you book a stay, it will show up here.',
                    style: GoogleFonts.inter(
                        fontSize: 13.5, color: GoOutsColors.bodyText)),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => Navigator.of(context)
                      .pushNamedAndRemoveUntil(StayRoutes.home, (r) => false),
                  child: Text('Find a stay →',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: GoOutsColors.primaryBlue,
                      )),
                ),
              ],
            ),
          );
        }
        final DateFormat df = DateFormat('d MMM yyyy');
        return Column(
          children: <Widget>[
            for (final StayBooking b in bookings)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: GoOutsColors.cardSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color:
                          GoOutsColors.outlineVariant.withValues(alpha: 0.4)),
                ),
                child: InkWell(
                  onTap: () => Navigator.of(context).pushNamed(
                      StayRoutes.trip,
                      arguments: <String, dynamic>{'bookingId': b.id}),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('${df.format(b.checkIn)} – ${df.format(b.checkOut)}',
                                style: GoogleFonts.inter(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: GoOutsColors.deepNavy,
                                )),
                            const SizedBox(height: 4),
                            Text(_statusLabel(b.status.wire),
                                style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    color: GoOutsColors.bodyText)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: GoOutsColors.bodyText),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ── CASHBACK WALLET ──────────────────────────────────────────────────────
  Widget _wallet(BuildContext context) {
    final num wallet = (_userDoc?['walletBalance'] as num?) ?? 0;
    final num cashback = (_userDoc?['cashbackBalance'] as num?) ?? 0;

    Widget statCard(String label, num amount, Color accent) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: GoOutsColors.cardSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: GoOutsColors.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: GoOutsColors.bodyText)),
              const SizedBox(height: 10),
              Text('£${amount.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  )),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            statCard('Cashback balance', cashback, GoOutsColors.primaryBlue),
            const SizedBox(width: 16),
            statCard('Wallet balance', wallet, GoOutsColors.deepNavy),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: GoOutsColors.paleBlueTint,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            'Add funds, transfer to a friend and redeem cashback at partners '
            'from the GoOuts app — this page is a live summary of your '
            'wallet, not a place to move money.',
            style: GoogleFonts.inter(
              fontSize: 13.5,
              height: 1.6,
              color: GoOutsColors.bodyText,
            ),
          ),
        ),
      ],
    );
  }

  // ── ACCOUNT SETTINGS ─────────────────────────────────────────────────────
  Widget _settings(BuildContext context, User user) {
    final String email =
        (_userDoc?['email'] as String?) ?? user.email ?? 'Not set';
    final String phone =
        (_userDoc?['phone'] as String?) ?? user.phoneNumber ?? 'Not set';

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: <Widget>[
              SizedBox(
                  width: 120,
                  child: Text(label,
                      style: GoogleFonts.inter(
                          fontSize: 13.5, color: GoOutsColors.bodyText))),
              Expanded(
                child: Text(value,
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: GoOutsColors.deepNavy,
                    )),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: GoOutsColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GoOutsColors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Account details',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: GoOutsColors.deepNavy,
              )),
          const Divider(height: 28, color: GoOutsColors.outlineVariant),
          row('Email', email),
          row('Phone', phone),
          const SizedBox(height: 8),
          Text(
            'To change these details or your security settings, use the '
            'GoOuts app.',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontStyle: FontStyle.italic,
              color: GoOutsColors.bodyText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _signedOutScaffold(BuildContext context, {required bool desktop}) {
    return Scaffold(
      backgroundColor: GoOutsColors.pageBackground,
      body: Column(
        children: <Widget>[
          if (desktop) const DesktopTopNav(current: DesktopNavTab.none),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text('Sign in to view your profile',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: GoOutsColors.deepNavy,
                        )),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () =>
                          Navigator.of(context).pushNamed('/login'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: GoOutsColors.primaryBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('Sign in',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── MOBILE ───────────────────────────────────────────────────────────────
  Widget _buildMobile(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return _signedOutScaffold(context, desktop: false);
    return Scaffold(
      backgroundColor: GoOutsColors.pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text('Profile',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, color: GoOutsColors.deepNavy)),
        iconTheme: const IconThemeData(color: GoOutsColors.primaryBlue),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _aboutMe(context, user),
                    const SizedBox(height: 24),
                    Text('My Trips',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: GoOutsColors.deepNavy)),
                    const SizedBox(height: 12),
                    _trips(context),
                    const SizedBox(height: 24),
                    Text('Cashback Wallet',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: GoOutsColors.deepNavy)),
                    const SizedBox(height: 12),
                    _wallet(context),
                    const SizedBox(height: 24),
                    _settings(context, user),
                  ],
                ),
              ),
            ),
    );
  }
}
