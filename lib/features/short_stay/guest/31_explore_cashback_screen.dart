import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/goouts_services.dart';
import '../stay_routes.dart';
import '../theme/stay_colors.dart';
import '../widgets/desktop_top_nav.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Explore Cashback — real partner directory, modelled on Airbnb's own
//  Services page: a category icon strip at top, then one section per category
//  underneath, each a row of real partner cards. Replaces the 14 September
//  2026 stub (see git history for that placeholder).
//
//  DATA: same Firestore shape as screens/explore_screen.dart —
//  partner_config/global for the category list (skipping any category with
//  status 'hold'), partners where isActive == true for the venues themselves.
//  The only hardcoded array below is the SAME fallback
//  screens/explore_screen.dart already falls back to when the config doc is
//  empty, sourced from data/goouts_services.dart's gooutsPartnerCategories —
//  the one list of what GoOuts offers, not a second copy of it. No sample
//  partner data anywhere in this file.
//
//  Each partner card pushes StayRoutes.partnerInfo with only the partner's
//  id (see stay_routes.dart's "PASS IDS, NEVER OBJECTS" rule) —
//  33_partner_info_screen.dart loads the real document itself. That
//  destination page is INFO-ONLY: no QR/redeem/check-in UI. Those stay in
//  the mobile app, by explicit product decision, not an oversight.
// ─────────────────────────────────────────────────────────────────────────────

class ExploreCashbackScreen extends StatefulWidget {
  const ExploreCashbackScreen({super.key});

  @override
  State<ExploreCashbackScreen> createState() => _ExploreCashbackScreenState();
}

class _CategoryMeta {
  const _CategoryMeta({
    required this.category,
    required this.label,
    required this.icon,
    required this.color,
  });
  final String category;
  final String label;
  final IconData icon;
  final Color color;
}

class _ExploreCashbackScreenState extends State<ExploreCashbackScreen> {
  static const Color _defaultColor = GoOutsColors.primaryBlue;
  static const IconData _defaultIcon = Icons.storefront_rounded;

  bool _loading = true;
  String? _error;
  int _totalPartners = 0;

  List<_CategoryMeta> _sections = <_CategoryMeta>[];
  final Map<String, List<Map<String, dynamic>>> _partnersByCategory =
      <String, List<Map<String, dynamic>>>{};
  final Map<String, GlobalKey> _sectionKeys = <String, GlobalKey>{};

  // Category → icon/colour, straight from the one list of what GoOuts offers.
  static final Map<String, GoOutsService> _catMeta = <String, GoOutsService>{
    for (final GoOutsService s in gooutsPartnerCategories) s.category!: s,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<dynamic> results = await Future.wait(<Future<dynamic>>[
        FirebaseFirestore.instance
            .collection('partner_config')
            .doc('global')
            .get(),
        FirebaseFirestore.instance
            .collection('partners')
            .where('isActive', isEqualTo: true)
            .get(),
      ]);
      final DocumentSnapshot configSnap = results[0] as DocumentSnapshot;
      final QuerySnapshot partnersSnap = results[1] as QuerySnapshot;

      // ── Category order, same source as explore_screen.dart ───────────────
      final List<String> orderedCats = <String>[];
      final dynamic rawCats = configSnap.data() != null
          ? (configSnap.data() as Map<String, dynamic>)['categories']
          : null;
      if (rawCats != null) {
        for (final dynamic c in rawCats as List<dynamic>) {
          final String name = (c is Map ? c['name'] : c).toString();
          final String status =
              c is Map ? (c['status'] ?? 'active').toString() : 'active';
          if (status == 'hold') continue;
          orderedCats.add(name);
        }
      }
      if (orderedCats.isEmpty) {
        orderedCats.addAll(
          gooutsPartnerCategories.map((GoOutsService s) => s.category!),
        );
      }

      // ── Real partners, grouped by their real category field ──────────────
      final Map<String, List<Map<String, dynamic>>> grouped =
          <String, List<Map<String, dynamic>>>{};
      for (final QueryDocumentSnapshot doc in partnersSnap.docs) {
        final Map<String, dynamic> data = <String, dynamic>{
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
        final Map<String, dynamic> card = _partnerToCard(data);
        final String cat = (card['category'] as String).isNotEmpty
            ? card['category'] as String
            : 'Other';
        grouped.putIfAbsent(cat, () => <Map<String, dynamic>>[]).add(card);
      }

      // ── Sections: config order first, then any real category Firestore
      //    holds that the config list did not mention. Only categories with
      //    at least one real partner become a section — nothing is shown
      //    with zero content behind it. ─────────────────────────────────────
      final List<_CategoryMeta> sections = <_CategoryMeta>[];
      final Set<String> seen = <String>{};
      for (final String cat in orderedCats) {
        if (!grouped.containsKey(cat) || seen.contains(cat)) continue;
        seen.add(cat);
        sections.add(_metaFor(cat));
      }
      for (final String cat in grouped.keys) {
        if (seen.contains(cat)) continue;
        seen.add(cat);
        sections.add(_metaFor(cat));
      }

      if (mounted) {
        setState(() {
          _sections = sections;
          _partnersByCategory
            ..clear()
            ..addAll(grouped);
          _sectionKeys
            ..clear()
            ..addEntries(
                sections.map((m) => MapEntry(m.category, GlobalKey())));
          _totalPartners = partnersSnap.docs.length;
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

  _CategoryMeta _metaFor(String category) {
    final GoOutsService? known = _catMeta[category];
    return _CategoryMeta(
      category: category,
      label: known?.label ?? category,
      icon: known?.icon ?? _defaultIcon,
      color: known?.color ?? _defaultColor,
    );
  }

  Map<String, dynamic> _partnerToCard(Map<String, dynamic> doc) {
    final String cat = doc['category']?.toString() ?? '';
    final num pct =
        (doc['cashbackPercent'] as num?) ?? (doc['cashbackPct'] as num?) ?? 0;
    return <String, dynamic>{
      'id': doc['id'],
      'name': (doc['name'] ?? '').toString(),
      'category': cat,
      'imageUrl': (doc['imageUrl'] ?? doc['bannerUrl'] ?? '').toString(),
      'rating': (doc['rating'] as num?)?.toStringAsFixed(1) ?? '0.0',
      'cashback': '${pct.toStringAsFixed(0)}%',
      'address': (doc['address'] ?? '').toString(),
    };
  }

  void _scrollToSection(String category) {
    final GlobalKey? key = _sectionKeys[category];
    final BuildContext? ctx = key?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      alignment: 0.05,
    );
  }

  void _openPartner(String partnerId) {
    if (partnerId.isEmpty) return;
    Navigator.pushNamed(
      context,
      StayRoutes.partnerInfo,
      arguments: <String, dynamic>{'partnerId': partnerId},
    );
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
            maxWidth: 1400,
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
        title: Text('Explore Cashback',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, color: GoOutsColors.deepNavy)),
        iconTheme: const IconThemeData(color: GoOutsColors.primaryBlue),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          child: _content(desktop: false),
        ),
      ),
    );
  }

  // ── SHARED CONTENT ───────────────────────────────────────────────────────
  Widget _content({required bool desktop}) {
    if (_loading) return _skeletons(desktop: desktop);
    if (_error != null) return _buildLoadFailed();
    if (_sections.isEmpty) return _buildEmpty();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Explore Cashback',
            style: GoogleFonts.inter(
              fontSize: desktop ? 36 : 26,
              fontWeight: FontWeight.w800,
              color: GoOutsColors.deepNavy,
              letterSpacing: -0.5,
            )),
        const SizedBox(height: 12),
        Text(
          _totalPartners > 0
              ? '$_totalPartners GoOuts partners across ${_sections.length} '
                  'categories — tap one to see real cashback and open its '
                  'page for details.'
              : 'Real cashback partners, grouped by category.',
          style: GoogleFonts.inter(
            fontSize: desktop ? 16 : 14,
            color: GoOutsColors.bodyText,
            height: 1.5,
          ),
        ),
        SizedBox(height: desktop ? 36 : 24),
        _categoryStrip(desktop: desktop),
        SizedBox(height: desktop ? 44 : 28),
        for (final _CategoryMeta meta in _sections) ...<Widget>[
          _categorySection(meta, desktop: desktop),
          SizedBox(height: desktop ? 40 : 28),
        ],
      ],
    );
  }

  // ── Category strip ──────────────────────────────────────────────────────
  Widget _categoryStrip({required bool desktop}) {
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _sections.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final _CategoryMeta meta = _sections[index];
          return GestureDetector(
            onTap: () => _scrollToSection(meta.category),
            child: SizedBox(
              width: 78,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          meta.color.withValues(alpha: 0.16),
                          meta.color.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: meta.color.withValues(alpha: 0.18),
                          width: 1),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                            color: meta.color.withValues(alpha: 0.18),
                            blurRadius: 8,
                            offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Icon(meta.icon, color: meta.color, size: 27),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    meta.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: GoOutsColors.deepNavy,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── One category section ────────────────────────────────────────────────
  Widget _categorySection(_CategoryMeta meta, {required bool desktop}) {
    final List<Map<String, dynamic>> partners =
        _partnersByCategory[meta.category] ?? const <Map<String, dynamic>>[];
    return Column(
      key: _sectionKeys[meta.category],
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: meta.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(meta.icon, color: meta.color, size: 18),
            ),
            const SizedBox(width: 10),
            Text(meta.label,
                style: GoogleFonts.inter(
                  fontSize: desktop ? 20 : 17,
                  fontWeight: FontWeight.w700,
                  color: GoOutsColors.deepNavy,
                )),
            const SizedBox(width: 8),
            Text('${partners.length}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: GoOutsColors.bodyText,
                )),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: desktop ? 240 : 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: partners.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) =>
                _partnerCard(partners[i], meta.color, desktop: desktop),
          ),
        ),
      ],
    );
  }

  Widget _partnerCard(Map<String, dynamic> v, Color accent,
      {required bool desktop}) {
    final double width = desktop ? 240 : 200;
    final double photoHeight = desktop ? 150 : 130;
    return GestureDetector(
      onTap: () => _openPartner((v['id'] as String?) ?? ''),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: GoOutsColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: <BoxShadow>[
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                height: photoHeight,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Container(color: accent),
                    if ((v['imageUrl'] as String).isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: v['imageUrl'] as String,
                        fit: BoxFit.cover,
                        memCacheWidth: 480,
                        fadeInDuration: const Duration(milliseconds: 200),
                        placeholder: (_, __) => Container(color: accent),
                        errorWidget: (_, __, ___) => Container(color: accent),
                      ),
                    Positioned(
                      top: 8,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: const BoxDecoration(
                          color: GoOutsColors.success,
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: Text(
                          '${v['cashback']} Cashback',
                          style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      (v['name'] as String).isNotEmpty
                          ? v['name'] as String
                          : 'Partner',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: GoOutsColors.deepNavy),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: <Widget>[
                        const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 12),
                        const SizedBox(width: 3),
                        Text(v['rating'] as String,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: GoOutsColors.bodyText)),
                        if ((v['address'] as String).isNotEmpty) ...<Widget>[
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              v['address'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  color: GoOutsColors.bodyText
                                      .withValues(alpha: 0.8)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── States ───────────────────────────────────────────────────────────────
  Widget _skeletons({required bool desktop}) {
    Widget box(double h, double w, [double r = 8]) => Container(
          height: h,
          width: w,
          decoration: BoxDecoration(
            color: GoOutsColors.dividerGray,
            borderRadius: BorderRadius.circular(r),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        box(desktop ? 36 : 26, 260),
        const SizedBox(height: 12),
        box(16, 320),
        SizedBox(height: desktop ? 36 : 24),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, __) => box(108, 78, 16),
          ),
        ),
        SizedBox(height: desktop ? 44 : 28),
        box(20, 180),
        const SizedBox(height: 16),
        SizedBox(
          height: desktop ? 240 : 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, __) =>
                box(desktop ? 240 : 210, desktop ? 240 : 200, 16),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadFailed() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: <Widget>[
          const Icon(Icons.cloud_off_rounded,
              size: 48, color: GoOutsColors.primaryBlue),
          const SizedBox(height: 14),
          Text('We could not load partners',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: GoOutsColors.deepNavy)),
          const SizedBox(height: 6),
          Text('Something went wrong fetching the partner list.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13, color: GoOutsColors.bodyText)),
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

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: <Widget>[
          const Icon(Icons.local_offer_outlined,
              size: 48, color: GoOutsColors.primaryBlue),
          const SizedBox(height: 14),
          Text('No cashback partners yet',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: GoOutsColors.deepNavy)),
          const SizedBox(height: 6),
          Text('Check back soon as we add partners in your area.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13, color: GoOutsColors.bodyText)),
        ],
      ),
    );
  }
}
