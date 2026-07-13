import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/message_service.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  static const Color _primary = Color(0xFF0392CA);
  static const Color _dark = Color(0xFF0D1B3E);
  static const Color _green = Color(0xFF0A7A3E);
  static const Color _bg = Color(0xFFF2F4F7);

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _loading = true;

  final PageController _catPageController = PageController();
  int _catPage = 0;

  // ── Category icon / colour lookup (covers all known names + any new ones fall back) ──
  static const _catColors = <String, Color>{
    'Cafes':       Color(0xFF5C3D1E),
    'Restaurants': Color(0xFF3B1F0A),
    'Pubs':        Color(0xFF1A3A1A),
    'Clubs':       Color(0xFF1A0533),
    'Bars':        Color(0xFF0A3A4A),
    'Fast Food':   Color(0xFF0A2A4A),
    'Music':       Color(0xFF0D3B2E),
    'Comedy':      Color(0xFF2C1A08),
    'Retail':      Color(0xFF0A2A2A),
    'Gyms':        Color(0xFF1A2A1A),
  };
  static const _catIcons = <String, IconData>{
    'Cafes':       Icons.coffee_rounded,
    'Restaurants': Icons.restaurant_rounded,
    'Pubs':        Icons.sports_bar_rounded,
    'Clubs':       Icons.nightlife_rounded,
    'Bars':        Icons.local_bar_rounded,
    'Fast Food':   Icons.fastfood_rounded,
    'Music':       Icons.music_note_rounded,
    'Comedy':      Icons.theater_comedy_rounded,
    'Retail':      Icons.shopping_bag_rounded,
    'Gyms':        Icons.fitness_center_rounded,
  };
  static const Color _defaultCatColor = Color(0xFF0392CA);
  static const IconData _defaultCatIcon = Icons.storefront_rounded;

  // ── Live data from Firestore ────────────────────────────
  List<Map<String, dynamic>> _categories   = [];
  List<Map<String, dynamic>> _nearYou      = [];
  List<Map<String, dynamic>> _topCashback  = [];
  List<Map<String, dynamic>> _allPartners  = []; // full list for search

  // ── initState + Firestore loader ──────────────────────
  @override
  void initState() {
    super.initState();
    _loadFromFirestore();
  }

  Future<void> _loadFromFirestore() async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('partner_config').doc('global').get(),
        FirebaseFirestore.instance
            .collection('partners')
            .where('isActive', isEqualTo: true)
            .get(),
      ]);
      final configSnap   = results[0] as DocumentSnapshot;
      final partnersSnap = results[1] as QuerySnapshot;

      // Categories from Firestore (active only)
      List<Map<String, dynamic>> cats = [];
      final rawCats = configSnap.data() != null
          ? (configSnap.data() as Map<String, dynamic>)['categories']
          : null;
      if (rawCats != null) {
        for (final c in rawCats as List) {
          final name   = (c is Map ? c['name'] : c).toString();
          final status = c is Map ? (c['status'] ?? 'active').toString() : 'active';
          if (status == 'hold') continue;
          cats.add({
            'icon':  _catIcons[name]  ?? _defaultCatIcon,
            'label': name,
            'route': name,
            'color': _catColors[name] ?? _defaultCatColor,
          });
        }
      }
      // Fallback if Firestore empty
      if (cats.isEmpty) {
        cats = [
          {'icon': Icons.coffee_rounded,         'label': 'Cafes',       'route': 'Cafes',       'color': const Color(0xFF5C3D1E)},
          {'icon': Icons.restaurant_rounded,     'label': 'Restaurants', 'route': 'Restaurants', 'color': const Color(0xFF3B1F0A)},
          {'icon': Icons.sports_bar_rounded,     'label': 'Pubs',        'route': 'Pubs',        'color': const Color(0xFF1A3A1A)},
          {'icon': Icons.nightlife_rounded,      'label': 'Clubs',       'route': 'Clubs',       'color': const Color(0xFF1A0533)},
          {'icon': Icons.fastfood_rounded,       'label': 'Fast Food',   'route': 'Fast Food',   'color': const Color(0xFF0A2A4A)},
          {'icon': Icons.music_note_rounded,     'label': 'Music',       'route': 'Music',       'color': const Color(0xFF0D3B2E)},
          {'icon': Icons.theater_comedy_rounded, 'label': 'Comedy',      'route': 'Comedy',      'color': const Color(0xFF2C1A08)},
          {'icon': Icons.local_bar_rounded,      'label': 'Bars',        'route': 'Bars',        'color': const Color(0xFF0A3A4A)},
        ];
      }

      // Partners from Firestore
      final allCards = partnersSnap.docs
          .map((d) => _partnerToCard({'id': d.id, ...d.data() as Map<String, dynamic>}))
          .toList();

      final nearYou = List<Map<String, dynamic>>.from(allCards)
        ..sort((a, b) => (b['_createdMs'] as int).compareTo(a['_createdMs'] as int));
      final topCashback = List<Map<String, dynamic>>.from(allCards)
        ..sort((a, b) => (b['_cashbackNum'] as double).compareTo(a['_cashbackNum'] as double));

      if (mounted) {
        setState(() {
          _categories  = cats;
          _allPartners = allCards;
          _nearYou     = nearYou.take(6).toList();
          _topCashback = topCashback.take(5).toList();
          _loading     = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _partnerToCard(Map<String, dynamic> doc) {
    final cat = doc['category']?.toString() ?? '';
    final pct = (doc['cashbackPercent'] as num?) ?? 0;
    final ts  = doc['createdAt'];
    return {
      ...doc,
      'imageUrl':    doc['imageUrl'] ?? doc['bannerUrl'] ?? '',
      'cashback':    '${pct.toStringAsFixed(0)}%',
      'cashback_pct':'${pct.toStringAsFixed(0)}%',
      'rating':      (doc['rating'] as num?)?.toStringAsFixed(1) ?? '0.0',
      'distance':    'Nearby',
      'color':       _catColors[cat] ?? _defaultCatColor,
      'icon':        _catIcons[cat]  ?? _defaultCatIcon,
      'type':        cat,
      'desc':        doc['description'] ?? '',
      'phone':       doc['phone'] ?? '',
      'visits':      doc['visits'] ?? '',
      'reviews':     '',
      'foodTags':    doc['foodTags'] ?? [],
      '_createdMs':  ts != null ? (ts as Timestamp).millisecondsSinceEpoch : 0,
      '_cashbackNum': pct.toDouble(),
    };
  }

  // ─────────────────────────────────────────────────────
  // (hardcoded data removed — all loaded from Firestore)
  // ─────────────────────────────────────────────────────


  bool _venueMatchesQuery(Map<String, dynamic> v, String q) {
    final fields = [
      v['name']        as String? ?? '',
      v['category']    as String? ?? '',
      v['type']        as String? ?? '',
      v['desc']        as String? ?? '',
      v['address']     as String? ?? '',
      v['description'] as String? ?? '',
    ];
    if (fields.any((f) => f.toLowerCase().contains(q))) return true;
    // Also search food tags list
    final tags = v['foodTags'];
    if (tags is List) {
      return tags.any((t) => t.toString().toLowerCase().contains(q));
    }
    return false;
  }

  // When searching: search ALL partners, not just the visible 6/5 subsets
  List<Map<String, dynamic>> get _filteredNearYou {
    if (_searchQuery.isEmpty) return _nearYou;
    final q = _searchQuery.toLowerCase();
    final source = _allPartners.isNotEmpty ? _allPartners : _nearYou;
    return source.where((v) => _venueMatchesQuery(v, q)).toList();
  }

  List<Map<String, dynamic>> get _filteredTopCashback {
    if (_searchQuery.isEmpty) return _topCashback;
    return []; // hide top cashback section while searching — results shown in near you
  }

  @override
  void dispose() {
    _searchController.dispose();
    _catPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildSearchBar()),
            SliverToBoxAdapter(child: const SizedBox(height: 20)),
            SliverToBoxAdapter(child: _buildCategories()),
            SliverToBoxAdapter(child: const SizedBox(height: 24)),
            SliverToBoxAdapter(child: _buildNearYou()),
            SliverToBoxAdapter(child: const SizedBox(height: 24)),
            SliverToBoxAdapter(child: _buildTopCashback()),
            SliverToBoxAdapter(child: const SizedBox(height: 24)),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Header ───────────────────────────────────────────────
  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Explore',
                    style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _dark)),
                Text('Discover GoOuts partners near you',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[500])),
              ],
            ),
            const Spacer(),
            StreamBuilder<int>(
              stream: MessageService().unreadNotificationsStream(),
              builder: (context, snap) {
                final count = snap.data ?? 0;
                return GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/notifications'),
                  child: Stack(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 6)
                          ],
                        ),
                        child: const Icon(Icons.notifications_outlined,
                            color: Colors.black87, size: 22),
                      ),
                      if (count > 0)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                                color: Colors.red, shape: BoxShape.circle),
                            child: Center(
                              child: Text(
                                count > 9 ? '9+' : '$count',
                                style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      );

  // ── Search bar ───────────────────────────────────────────
  Widget _buildSearchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3))
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search cafes, restaurants, pubs...',
              hintStyle:
                  GoogleFonts.inter(fontSize: 14, color: Colors.grey[400]),
              prefixIcon:
                  const Icon(Icons.search_rounded, color: _primary, size: 22),
              suffixIcon: _searchQuery.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: const Icon(Icons.cancel_rounded,
                          color: Colors.grey, size: 20),
                    )
                  : Icon(Icons.tune_rounded, color: Colors.grey[400], size: 20),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
            ),
            style: GoogleFonts.inter(fontSize: 14, color: _dark),
          ),
        ),
      );

  // ── Categories scrolling row + dots ─────────────────────
  Widget _buildCategories() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Split into pages of 4 items each
    const itemsPerPage = 4;
    final pages = <List<Map<String, dynamic>>>[];
    for (int i = 0; i < _categories.length; i += itemsPerPage) {
      final end = (i + itemsPerPage).clamp(0, _categories.length);
      pages.add(_categories.sublist(i, end));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Categories',
              style: GoogleFonts.inter(
                  fontSize: 18, fontWeight: FontWeight.w700, color: _dark)),
        ),
        const SizedBox(height: 14),

        // ── Horizontal page of icons ──────────────────────
        SizedBox(
          height: 108,
          child: PageView.builder(
            controller: _catPageController,
            itemCount: pages.length,
            onPageChanged: (p) => setState(() => _catPage = p),
            itemBuilder: (context, pageIndex) {
              final pageItems = pages[pageIndex];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(itemsPerPage, (i) {
                    if (i >= pageItems.length) {
                      return const SizedBox(width: 72); // empty slot
                    }
                    final c = pageItems[i];
                    return GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/nearby',
                          arguments: {'category': c['route'] as String}),
                      child: SizedBox(
                        width: 72,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.07),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2))
                                ],
                              ),
                              child: Icon(c['icon'] as IconData,
                                  color: _primary, size: 26),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 32,
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Text(
                                  c['label'] as String,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _dark),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              );
            },
          ),
        ),

        // ── Page dots ─────────────────────────────────────
        if (pages.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(pages.length, (i) {
              final active = i == _catPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? _primary : Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  // ── Near You ─────────────────────────────────────────────
  Widget _buildNearYou() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.near_me_rounded, color: _primary, size: 18),
                const SizedBox(width: 6),
                Text('Near You',
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _dark)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/nearby'),
                  child: Text('Show All',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _primary)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_filteredNearYou.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded, size: 40, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text('No results for "$_searchQuery"',
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[400])),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filteredNearYou.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final v = _filteredNearYou[index];
                  return _nearYouCard(v);
                },
              ),
            ),
        ],
      );

  Widget _nearYouCard(Map<String, dynamic> v) => GestureDetector(
        onTap: () =>
            Navigator.pushNamed(context, '/partner-details', arguments: v),
        child: Container(
          width: 160,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3))
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photo
                SizedBox(
                  height: 110,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: v['color'] as Color),
                      CachedNetworkImage(
                        imageUrl: v['imageUrl'] as String,
                        fit: BoxFit.cover,
                        memCacheWidth: 320,
                        fadeInDuration: const Duration(milliseconds: 200),
                        placeholder: (_, __) =>
                            Container(color: v['color'] as Color),
                        errorWidget: (_, __, ___) =>
                            Container(color: v['color'] as Color),
                      ),
                      // Cashback badge
                      Positioned(
                        top: 8,
                        left: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: const BoxDecoration(
                            color: Color(0xFF0A7A3E),
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
                // Info
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v['name'] as String,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _dark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              color: Colors.amber, size: 12),
                          const SizedBox(width: 3),
                          Text(v['rating'] as String,
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700])),
                          const SizedBox(width: 6),
                          const Icon(Icons.near_me_rounded,
                              size: 11, color: Colors.grey),
                          const SizedBox(width: 3),
                          Text(v['distance'] as String,
                              style: GoogleFonts.inter(
                                  fontSize: 11, color: Colors.grey[500])),
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

  // ── Top Cashback ─────────────────────────────────────────
  Widget _buildTopCashback() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_offer_rounded,
                    color: _green, size: 18),
                const SizedBox(width: 6),
                Text('Top Cashback This Week',
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _dark)),
              ],
            ),
            const SizedBox(height: 14),
            ..._filteredTopCashback.map((v) => _cashbackRow(v)),
          ],
        ),
      );

  Widget _cashbackRow(Map<String, dynamic> v) => GestureDetector(
        onTap: () =>
            Navigator.pushNamed(context, '/partner-details', arguments: v),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(
            children: [
              // Venue photo
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: v['color'] as Color),
                      CachedNetworkImage(
                        imageUrl: v['imageUrl'] as String,
                        fit: BoxFit.cover,
                        memCacheWidth: 128,
                        fadeInDuration: const Duration(milliseconds: 200),
                        placeholder: (_, __) =>
                            Container(color: v['color'] as Color),
                        errorWidget: (_, __, ___) =>
                            Container(color: v['color'] as Color),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v['name'] as String,
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _dark),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(v['category'] as String,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: Colors.grey[500])),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 13),
                        const SizedBox(width: 3),
                        Text(v['rating'] as String,
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700])),
                      ],
                    ),
                  ],
                ),
              ),
              // Cashback badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${v['cashback']}\nCashback',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _green,
                      height: 1.3),
                ),
              ),
            ],
          ),
        ),
      );

  // ── Bottom nav ───────────────────────────────────────────
  Widget _buildBottomNav() => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, -2))
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(Icons.home_rounded, 'Home', '/home'),
                _navItemActive(),
                _navItem(Icons.account_balance_wallet_rounded, 'Wallet', '/wallet'),
                _navItem(Icons.receipt_long_rounded, 'Activity', '/activity'),
                _navItem(Icons.person_rounded, 'Profile', '/profile'),
              ],
            ),
          ),
        ),
      );

  Widget _navItem(IconData icon, String label, String route) =>
      GestureDetector(
        onTap: () => Navigator.pushNamed(context, route),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.grey[400], size: 24),
            const SizedBox(height: 3),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 11, color: Colors.grey[400])),
          ],
        ),
      );

  Widget _navItemActive() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F3FB),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.explore_rounded, color: _primary, size: 22),
            const SizedBox(width: 6),
            Text('Explore',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _primary)),
          ],
        ),
      );
}
