import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../stay_routes.dart';
import '../theme/stay_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ADDED 9 September 2026, building the professional desktop web layout.
//  REBUILT 14 September 2026 to a reversed layout (logo far right, links
//  centred, account controls far left), on the belief this mirrored
//  www.goouts.co.uk's marketing nav.
//
//  REVERTED 22 September 2026, per Mian, after the live /shortstay pages
//  were flagged as visually broken — logo appearing on the far right read
//  as a bug, not a deliberate match to the marketing site. The landing
//  page (goouts_website/public/index.html) is a separate, unrelated file
//  and keeps whatever layout it already has; this fix only concerns the
//  Short Stay / Food Delivery / Explore Cashback pages built from this
//  Flutter app. Standard layout restored:
//
//    GoOuts (→ home)   Short Stay · Food Delivery ·   [ Join as Host | profile+menu ]
//                       Explore Cashback · About Us
//
//  Colours are the SAME GoOutsColors this file already used — 0392CA is the
//  same blue as the marketing site's --blue, so no new hex values needed,
//  only the layout change above.
//
//  ⚠ ONLY FOR DESKTOP WEB. Callers gate this behind their own
//  `kIsWeb && width >= 900` check, exactly like every screen that uses it —
//  this widget does not check that itself, so it must not be built on mobile.
//
//  01_short_stay_home_screen.dart and food_delivery_screen.dart still do NOT
//  use this widget directly (each has its own inline `_desktopTopNav` for
//  reasons explained in their own files) — both need the identical
//  logo-left reorder applied separately; see those files.
// ─────────────────────────────────────────────────────────────────────────────

enum DesktopNavTab { stay, food, explore, about, none }

/// Where "Join as Host" sends a visitor. This is the real, deployed Host
/// dashboard app (goouts-host-dashboard.web.app) — not a marketing page —
/// so a click here lands on an actual sign-up/sign-in screen, same as every
/// other cross-app link already in this codebase (index.html's "Sign in"
/// links straight into /shortstay/#/login the same way).
const String kHostDashboardUrl = 'https://goouts-host-dashboard.web.app';

class DesktopTopNav extends StatelessWidget {
  const DesktopTopNav({
    super.key,
    required this.current,
    this.maxWidth = 1400,
  });

  final DesktopNavTab current;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: GoOutsColors.outlineVariant, width: 1),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Row(
              children: <Widget>[
                // ── FAR LEFT: logo, hyperlinked home ────────────────────────
                const GoOutsBrandLogo(),
                // ── CENTRE (of the remaining space): the four tabs ────────
                Expanded(
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _NavIconTab(
                          icon: Icons.villa_rounded,
                          label: 'Short Stay',
                          active: current == DesktopNavTab.stay,
                          onTap: () => Navigator.of(context)
                              .pushNamedAndRemoveUntil(
                                  StayRoutes.home, (r) => false),
                        ),
                        const SizedBox(width: 4),
                        _NavIconTab(
                          icon: Icons.restaurant_rounded,
                          label: 'Food Delivery',
                          active: current == DesktopNavTab.food,
                          onTap: () =>
                              Navigator.of(context).pushNamed('/food-delivery'),
                        ),
                        const SizedBox(width: 4),
                        _NavIconTab(
                          icon: Icons.local_offer_rounded,
                          label: 'Explore Cashback',
                          active: current == DesktopNavTab.explore,
                          onTap: () => Navigator.of(context)
                              .pushNamed(StayRoutes.exploreCashback),
                        ),
                        const SizedBox(width: 4),
                        _NavIconTab(
                          icon: Icons.info_outline_rounded,
                          label: 'About Us',
                          active: current == DesktopNavTab.about,
                          onTap: () => Navigator.of(context)
                              .pushNamed(StayRoutes.aboutUs),
                        ),
                      ],
                    ),
                  ),
                ),
                // ── FAR RIGHT: Join as Host, then profile+menu ─────────────
                JoinAsHostButton(),
                const SizedBox(width: 14),
                AccountMenuButton(user: user),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Go" in deep navy, "Outs" in brand blue — the same two-tone treatment as
/// the ".logo span" rule on www.goouts.co.uk (`.logo span { color:var(--blue) }`).
/// Public (not file-private) so 01_short_stay_home_screen.dart and
/// food_delivery_screen.dart's own inline nav bars can reuse the exact same
/// widget rather than each keeping a slightly different copy.
class GoOutsBrandLogo extends StatelessWidget {
  const GoOutsBrandLogo();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context)
          .pushNamedAndRemoveUntil(StayRoutes.home, (r) => false),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: RichText(
          text: TextSpan(
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
            children: const <TextSpan>[
              TextSpan(
                  text: 'Go', style: TextStyle(color: GoOutsColors.deepNavy)),
              TextSpan(
                  text: 'Outs',
                  style: TextStyle(color: GoOutsColors.primaryBlue)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ghost-button styled exactly like www.goouts.co.uk's `.btn-ghost`: bordered,
/// transparent, blue border+text on hover. Opens the real Host dashboard app
/// in a new tab — the same "Join as Host" destination a host would actually
/// need, not a dead link. Public for the same reason as GoOutsBrandLogo above.
class JoinAsHostButton extends StatefulWidget {
  @override
  State<JoinAsHostButton> createState() => _JoinAsHostButtonState();
}

class _JoinAsHostButtonState extends State<JoinAsHostButton> {
  bool _hovering = false;

  Future<void> _open() async {
    final uri = Uri.parse(kHostDashboardUrl);
    await launchUrl(uri, webOnlyWindowName: '_blank');
  }

  @override
  Widget build(BuildContext context) {
    final Color color =
        _hovering ? GoOutsColors.primaryBlue : GoOutsColors.deepNavy;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: InkWell(
        onTap: _open,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
          decoration: BoxDecoration(
            border: Border.all(
              color: _hovering
                  ? GoOutsColors.primaryBlue
                  : GoOutsColors.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('Join as Host',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              )),
        ),
      ),
    );
  }
}

/// The "profile icon and menu icon" pair. Visually two icons side by side in
/// one bordered pill, functionally one tap target that opens a single
/// account menu — the same thing Airbnb's own avatar+hamburger pair does,
/// just laid out the way it was asked for here. Public for the same reason
/// as GoOutsBrandLogo above.
class AccountMenuButton extends StatefulWidget {
  const AccountMenuButton({required this.user});
  final User? user;

  @override
  State<AccountMenuButton> createState() => _AccountMenuButtonState();
}

class _AccountMenuButtonState extends State<AccountMenuButton> {
  final GlobalKey _key = GlobalKey();
  bool _hovering = false;

  void _openMenu(BuildContext context) {
    final RenderBox button =
        _key.currentContext!.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final Offset topLeft = button.localToGlobal(Offset.zero, ancestor: overlay);
    final RelativeRect position = RelativeRect.fromLTRB(
      topLeft.dx,
      topLeft.dy + button.size.height + 6,
      overlay.size.width - topLeft.dx - button.size.width,
      0,
    );

    final User? user = widget.user;
    showMenu<String>(
      context: context,
      position: position,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: <PopupMenuEntry<String>>[
        if (user != null) ...<PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            enabled: false,
            child: Text(
              user.email ?? user.phoneNumber ?? 'Signed in',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: GoOutsColors.bodyText,
              ),
            ),
          ),
          const PopupMenuDivider(),
        ],
        _menuItem('trips', Icons.luggage_outlined, 'My Trips'),
        _menuItem('notifications', Icons.notifications_none_rounded,
            'Notifications'),
        _menuItem('profile', Icons.person_outline_rounded, 'Account & Profile'),
        const PopupMenuDivider(),
        _menuItem('help', Icons.help_outline_rounded, 'Help Centre'),
        _menuItem('contact', Icons.support_agent_rounded, 'Contact Support'),
        const PopupMenuDivider(),
        if (user == null) ...<PopupMenuEntry<String>>[
          _menuItem('signup', Icons.person_add_alt_rounded, 'Sign up'),
          _menuItem('login', Icons.login_rounded, 'Sign in'),
        ] else
          _menuItem('logout', Icons.logout_rounded, 'Sign out'),
      ],
    ).then((value) {
      if (value == null || !context.mounted) return;
      switch (value) {
        case 'trips':
          Navigator.of(context).pushNamed(StayRoutes.myBookings);
        case 'notifications':
          Navigator.of(context).pushNamed('/notifications');
        case 'profile':
          Navigator.of(context).pushNamed(StayRoutes.profile);
        case 'help':
          Navigator.of(context).pushNamed('/faq');
        case 'contact':
          Navigator.of(context).pushNamed('/contact-support');
        case 'signup':
          Navigator.of(context).pushNamed('/signup');
        case 'login':
          Navigator.of(context).pushNamed('/login');
        case 'logout':
          FirebaseAuth.instance.signOut();
      }
    });
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: <Widget>[
          Icon(icon, size: 19, color: GoOutsColors.deepNavy),
          const SizedBox(width: 12),
          Text(label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: GoOutsColors.deepNavy,
              )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: InkWell(
        key: _key,
        onTap: () => _openMenu(context),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: _hovering
                  ? GoOutsColors.primaryBlue
                  : GoOutsColors.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.person_outline_rounded,
                  size: 19, color: GoOutsColors.deepNavy),
              const SizedBox(width: 8),
              Icon(Icons.menu_rounded, size: 19, color: GoOutsColors.deepNavy),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon-then-label nav item, one row, hover-aware. Used by DesktopTopNav's
/// four centre tabs.
class _NavIconTab extends StatefulWidget {
  const _NavIconTab({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  State<_NavIconTab> createState() => _NavIconTabState();
}

class _NavIconTabState extends State<_NavIconTab> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final Color color = widget.active
        ? GoOutsColors.primaryBlue
        : _hovering
            ? GoOutsColors.primaryBlue
            : GoOutsColors.deepNavy;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(widget.icon, size: 19, color: color),
              const SizedBox(width: 7),
              Text(widget.label,
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    fontWeight:
                        widget.active ? FontWeight.w700 : FontWeight.w600,
                    color: color,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

/// Centres a child inside [maxWidth] with matching side gutters. Shared by
/// every "inside" desktop page.
///
/// ⚠ THE SizedBox(width: double.infinity) IS NOT DECORATIVE. See
/// 01_short_stay_home_screen.dart's build() for the full story: ConstrainedBox
/// only sets a WIDTH CEILING, it does not force its child to actually use it.
class DesktopCenter extends StatelessWidget {
  const DesktopCenter({
    super.key,
    required this.child,
    this.maxWidth = 1400,
    this.horizontalPadding = 48,
  });

  final Widget child;
  final double maxWidth;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: child,
          ),
        ),
      ),
    );
  }
}
