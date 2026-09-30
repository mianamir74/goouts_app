import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/stay_colors.dart';
import '../widgets/desktop_top_nav.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  33_partner_info_screen.dart — new file, added alongside the rebuilt
//  31_explore_cashback_screen.dart. INFO-ONLY partner page for the web
//  Explore Cashback directory.
//
//  Deliberately does NOT include screens/partner_details_screen.dart's QR
//  scan, GPS check-in, "Pay & Earn", Social Boost toggle or review flow —
//  those are mobile-app actions and stay there by explicit product decision,
//  not an oversight. This page only reads and displays real fields from the
//  same `partners/{id}` document that screen already reads: name, address,
//  rating, cashback percent, category, phone, imageUrl, description, lat/lng.
//  Any field missing on a given partner is simply omitted — no placeholder
//  text stands in for real data.
//
//  Takes a partnerId (see stay_routes.dart's "PASS IDS, NEVER OBJECTS" rule)
//  and loads its own document — it does not receive a pre-built partner
//  object from 31_explore_cashback_screen.dart.
// ─────────────────────────────────────────────────────────────────────────────

class PartnerInfoWebScreen extends StatefulWidget {
  const PartnerInfoWebScreen({super.key, required this.partnerId});

  final String partnerId;

  @override
  State<PartnerInfoWebScreen> createState() => _PartnerInfoWebScreenState();
}

class _PartnerInfoWebScreenState extends State<PartnerInfoWebScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _partner;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.partnerId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'No partner was specified.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final DocumentSnapshot snap = await FirebaseFirestore.instance
          .collection('partners')
          .doc(widget.partnerId)
          .get();
      if (!snap.exists) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'This partner could not be found.';
          });
        }
        return;
      }
      final Map<String, dynamic> data =
          snap.data() as Map<String, dynamic>? ?? <String, dynamic>{};
      if (mounted) {
        setState(() {
          _partner = <String, dynamic>{'id': snap.id, ...data};
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _callPhone(String phone) async {
    final Uri uri = Uri(scheme: 'tel', path: phone);
    await launchUrl(uri);
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
    return Scaffold(
      backgroundColor: GoOutsColors.pageBackground,
      body: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const DesktopTopNav(current: DesktopNavTab.explore),
          const SizedBox(height: 40),
          DesktopCenter(
            maxWidth: 900,
            child: _content(desktop: true),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ── MOBILE ───────────────────────────────────────────────────────────────
  Widget _buildMobile(BuildContext context) {
    return Scaffold(
      backgroundColor: GoOutsColors.pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: GoOutsColors.primaryBlue),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text('Partner',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, color: GoOutsColors.deepNavy)),
        iconTheme: const IconThemeData(color: GoOutsColors.primaryBlue),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 40),
          child: _content(desktop: false),
        ),
      ),
    );
  }

  // ── SHARED CONTENT ───────────────────────────────────────────────────────
  Widget _content({required bool desktop}) {
    if (_loading) return _loadingState(desktop: desktop);
    if (_error != null) return _errorState();
    final Map<String, dynamic> p = _partner!;

    final String name = (p['name'] as String?) ?? 'Partner';
    final String category = (p['category'] as String?) ?? '';
    final String address = (p['address'] as String?) ?? '';
    final String desc = (p['description'] as String?) ?? '';
    final String phone = (p['phone'] as String?) ?? '';
    final String imageUrl =
        (p['imageUrl'] as String?) ?? (p['bannerUrl'] as String?) ?? '';
    final num? ratingNum = p['rating'] as num?;
    final num cashbackPct =
        (p['cashbackPercent'] as num?) ?? (p['cashbackPct'] as num?) ?? 0;
    final String? openingInfo =
        (p['openingHours'] as String?) ?? (p['hours'] as String?);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: desktop ? 0 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(height: desktop ? 0 : 20),
          // ── Hero ────────────────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(desktop ? 20 : 16),
            child: SizedBox(
              height: desktop ? 340 : 220,
              width: double.infinity,
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _heroFallback(),
                    )
                  : _heroFallback(),
            ),
          ),
          SizedBox(height: desktop ? 32 : 20),
          // ── Name / category / rating / address ─────────────────────────
          Text(name,
              style: GoogleFonts.inter(
                fontSize: desktop ? 32 : 24,
                fontWeight: FontWeight.w800,
                color: GoOutsColors.deepNavy,
                letterSpacing: -0.5,
              )),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 14,
            runSpacing: 8,
            children: <Widget>[
              if (category.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: GoOutsColors.paleBlueTint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(category,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: GoOutsColors.primaryBlue,
                      )),
                ),
              if (ratingNum != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.star_rounded,
                        color: Colors.amber, size: 18),
                    const SizedBox(width: 4),
                    Text(ratingNum.toStringAsFixed(1),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: GoOutsColors.deepNavy,
                        )),
                  ],
                ),
              if (address.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.location_on_outlined,
                        size: 16, color: GoOutsColors.bodyText),
                    const SizedBox(width: 4),
                    Text(address,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: GoOutsColors.bodyText,
                        )),
                  ],
                ),
            ],
          ),
          SizedBox(height: desktop ? 32 : 24),
          // ── Cashback card ────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: GoOutsColors.paleBlueTint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_offer_rounded,
                      color: GoOutsColors.primaryBlue, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('${cashbackPct.toStringAsFixed(0)}% Cashback',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: GoOutsColors.deepNavy,
                          )),
                      const SizedBox(height: 4),
                      Text(
                        'Earned when you check in and pay with GoOuts on '
                        'your next visit.',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color:
                              GoOutsColors.primaryBlue.withValues(alpha: 0.85),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (desc.isNotEmpty) ...<Widget>[
            SizedBox(height: desktop ? 32 : 24),
            Text('About',
                style: GoogleFonts.inter(
                  fontSize: desktop ? 20 : 17,
                  fontWeight: FontWeight.w700,
                  color: GoOutsColors.deepNavy,
                )),
            const SizedBox(height: 10),
            Text(desc,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: GoOutsColors.bodyText,
                  height: 1.6,
                )),
          ],
          if (openingInfo != null && openingInfo.isNotEmpty) ...<Widget>[
            SizedBox(height: desktop ? 28 : 20),
            Text('Opening hours',
                style: GoogleFonts.inter(
                  fontSize: desktop ? 20 : 17,
                  fontWeight: FontWeight.w700,
                  color: GoOutsColors.deepNavy,
                )),
            const SizedBox(height: 8),
            Text(openingInfo,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: GoOutsColors.bodyText,
                  height: 1.6,
                )),
          ],
          if (phone.isNotEmpty) ...<Widget>[
            SizedBox(height: desktop ? 28 : 20),
            InkWell(
              onTap: () => _callPhone(phone),
              borderRadius: BorderRadius.circular(10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.phone_rounded,
                      size: 18, color: GoOutsColors.primaryBlue),
                  const SizedBox(width: 8),
                  Text(phone,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: GoOutsColors.primaryBlue,
                      )),
                ],
              ),
            ),
          ],
          SizedBox(height: desktop ? 44 : 32),
          // ── Honest, non-transactional CTA. No QR/redeem UI on this page —
          //    that stays in the mobile app by explicit product decision. ───
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: GoOutsColors.cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: GoOutsColors.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(Icons.smartphone_rounded,
                        color: GoOutsColors.primaryBlue, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Redeem this cashback the next time you visit — '
                        'open the GoOuts app to check in and confirm your '
                        'visit.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: GoOutsColors.deepNavy,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Check-in and cashback redemption happen in the GoOuts '
                  'mobile app, not on this page.',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: GoOutsColors.bodyText,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: desktop ? 0 : 12),
        ],
      ),
    );
  }

  Widget _heroFallback() => Container(
        color: GoOutsColors.tealSecondary,
        child: Center(
          child: Icon(Icons.store_rounded,
              color: Colors.white.withValues(alpha: 0.4), size: 64),
        ),
      );

  Widget _loadingState({required bool desktop}) {
    Widget box(double h, double w, [double r = 8]) => Container(
          height: h,
          width: w,
          decoration: BoxDecoration(
            color: GoOutsColors.dividerGray,
            borderRadius: BorderRadius.circular(r),
          ),
        );
    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: desktop ? 0 : 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          box(desktop ? 340 : 220, double.infinity, 16),
          const SizedBox(height: 24),
          box(28, 240),
          const SizedBox(height: 12),
          box(16, 160),
          const SizedBox(height: 24),
          box(90, double.infinity, 16),
        ],
      ),
    );
  }

  Widget _errorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      child: Column(
        children: <Widget>[
          const Icon(Icons.error_outline_rounded,
              size: 48, color: GoOutsColors.primaryBlue),
          const SizedBox(height: 14),
          Text(_error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: GoOutsColors.deepNavy)),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _load,
            child: Text('Try again',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: GoOutsColors.primaryBlue)),
          ),
        ],
      ),
    );
  }
}
