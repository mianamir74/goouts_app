import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/stay_colors.dart';
import '../widgets/desktop_top_nav.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ADDED 14 September 2026 — "About Us" tab on the new shared desktop nav
//  (see desktop_top_nav.dart).
//
//  REWRITTEN the same day, requested directly: "same we have on home page of
//  www.goouts.co.uk" — the marketing site already has a real, live About Us
//  section (index.html, id="about-us"), so this page now carries THE SAME
//  copy word for word (the mission paragraphs and the four value cards —
//  Honest and Transparent / Built for Communities / Fair for Everyone / No
//  Gimmicks), rather than the separately-drafted mission copy this file
//  shipped with initially. One About Us, not two slightly different ones.
// ─────────────────────────────────────────────────────────────────────────────

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  // Word for word from index.html's #about-us section — see this file's
  // header comment.
  static const List<String> _missionParagraphs = <String>[
    'We started GoOuts because we saw something that felt wrong. Local '
        'restaurants were handing over a large share of every sale to the '
        'big delivery platforms and getting very little in return. '
        'Customers were ordering every week and earning absolutely nothing '
        'back for their loyalty.',
    'GoOuts is built on a simple idea. When you spend money at a local '
        'venue, you should get something back right away. Real Cashback '
        'Points in your wallet the moment you pay. Not a voucher that '
        'expires. Not a punch card sitting forgotten in your pocket. '
        'Actual points you can spend on your next order or share with '
        'someone you care about.',
    'For local businesses, we offer something genuinely different. Fairer '
        'commission, a shorter exit notice, and Social Boost tools that '
        'actually help them grow rather than just send them a bill at the '
        'end of every month.',
    'We are a small team with a big belief. Local businesses and the '
        'communities around them deserve better. GoOuts is how we are '
        'making that happen.',
  ];

  static const List<_Pillar> _values = <_Pillar>[
    _Pillar(
      icon: Icons.check_circle_rounded,
      title: 'Honest and Transparent',
      body: 'No hidden fees, no confusing terms. What you see is what you '
          'get, every time.',
      accent: Color(0xFF0392CA),
    ),
    _Pillar(
      icon: Icons.groups_rounded,
      title: 'Built for Communities',
      body: 'Every pound spent through GoOuts supports a local business in '
          'your neighbourhood.',
      accent: Color(0xFFF59E0B),
    ),
    _Pillar(
      icon: Icons.balance_rounded,
      title: 'Fair for Everyone',
      body: 'Consumers earn real rewards. Businesses keep more of what they '
          'make. That is how it should work.',
      accent: Color(0xFF10B981),
    ),
    _Pillar(
      icon: Icons.verified_rounded,
      title: 'No Gimmicks',
      body: 'No points that expire after 90 days. No apps you forget to '
          'scan. Real cashback, real simple.',
      accent: Color(0xFF6C63FF),
    ),
  ];

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
          const DesktopTopNav(current: DesktopNavTab.about),
          const SizedBox(height: 56),
          DesktopCenter(
            maxWidth: 900,
            child: _content(context, desktop: true),
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
        title: Text('About Us',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, color: GoOutsColors.deepNavy)),
        iconTheme: const IconThemeData(color: GoOutsColors.primaryBlue),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          child: _content(context, desktop: false),
        ),
      ),
    );
  }

  // ── SHARED CONTENT ───────────────────────────────────────────────────────
  Widget _content(BuildContext context, {required bool desktop}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('About Us',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: GoOutsColors.primaryBlue,
              letterSpacing: 0.4,
            )),
        const SizedBox(height: 10),
        RichText(
          text: TextSpan(
            style: GoogleFonts.inter(
              fontSize: desktop ? 34 : 24,
              fontWeight: FontWeight.w800,
              color: GoOutsColors.deepNavy,
              letterSpacing: -0.5,
              height: 1.2,
            ),
            children: const <TextSpan>[
              TextSpan(text: 'We built GoOuts because '),
              TextSpan(
                text: 'people deserve more.',
                style: TextStyle(color: GoOutsColors.primaryBlue),
              ),
            ],
          ),
        ),
        SizedBox(height: desktop ? 32 : 22),
        for (final String p in _missionParagraphs) ...<Widget>[
          Text(p,
              style: GoogleFonts.inter(
                fontSize: desktop ? 16 : 14.5,
                height: 1.75,
                color: GoOutsColors.bodyText,
              )),
          const SizedBox(height: 18),
        ],
        SizedBox(height: desktop ? 12 : 6),
        Wrap(
          spacing: 14,
          runSpacing: 12,
          children: <Widget>[
            InkWell(
              onTap: () => Navigator.of(context).pushNamed('/signup'),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
                decoration: BoxDecoration(
                  color: GoOutsColors.primaryBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Get Started',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
            InkWell(
              onTap: () async {
                final Uri uri = Uri.parse(kHostDashboardUrl);
                await launchUrl(uri, webOnlyWindowName: '_blank');
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
                decoration: BoxDecoration(
                  border: Border.all(color: GoOutsColors.outlineVariant),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('List Your Venue',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: GoOutsColors.deepNavy)),
              ),
            ),
          ],
        ),
        SizedBox(height: desktop ? 56 : 36),
        Container(
          padding: const EdgeInsets.only(top: 32),
          decoration: const BoxDecoration(
            border: Border(
                top: BorderSide(color: GoOutsColors.outlineVariant, width: 1)),
          ),
          child: desktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (int i = 0; i < _values.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(width: 24),
                      Expanded(child: _valueTile(_values[i])),
                    ],
                  ],
                )
              : Wrap(
                  spacing: 20,
                  runSpacing: 24,
                  children: <Widget>[
                    for (final _Pillar v in _values)
                      SizedBox(
                        width: (MediaQuery.of(context).size.width - 60) / 2,
                        child: _valueTile(v),
                      ),
                  ],
                ),
        ),
        SizedBox(height: desktop ? 40 : 28),
        Text('GoOuts Technologies Limited is a UK-registered company. '
            'Full registration and VAT details are published in the site '
            'footer.',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: GoOutsColors.bodyText,
              fontStyle: FontStyle.italic,
            )),
      ],
    );
  }

  /// Same vertical icon/title/body layout as index.html's `.about-val` — one
  /// of the 4 value cards, not the horizontal feature-tile style this file
  /// used before the rewrite.
  static Widget _valueTile(_Pillar v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: v.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(v.icon, color: v.accent, size: 20),
        ),
        const SizedBox(height: 12),
        Text(v.title,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: GoOutsColors.deepNavy,
            )),
        const SizedBox(height: 6),
        Text(v.body,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.65,
              color: GoOutsColors.bodyText,
            )),
      ],
    );
  }
}

class _Pillar {
  const _Pillar({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
  });
  final IconData icon;
  final String title;
  final String body;
  final Color accent;
}
