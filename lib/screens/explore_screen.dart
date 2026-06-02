import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

  // ── Categories ──────────────────────────────────────────
  final List<Map<String, dynamic>> _categories = [
    {'icon': Icons.coffee_rounded,         'label': 'Cafes',       'route': 'Cafes',       'color': Color(0xFF5C3D1E)},
    {'icon': Icons.restaurant_rounded,     'label': 'Restaurants', 'route': 'Restaurants', 'color': Color(0xFF3B1F0A)},
    {'icon': Icons.sports_bar_rounded,     'label': 'Pubs',        'route': 'Pubs',        'color': Color(0xFF1A3A1A)},
    {'icon': Icons.nightlife_rounded,      'label': 'Clubs',       'route': 'Clubs',       'color': Color(0xFF1A0533)},
    {'icon': Icons.fastfood_rounded,       'label': 'Fast Food',   'route': 'Fast Food',   'color': Color(0xFF0A2A4A)},
    {'icon': Icons.music_note_rounded,     'label': 'Music',       'route': 'Music',       'color': Color(0xFF0D3B2E)},
    {'icon': Icons.theater_comedy_rounded, 'label': 'Comedy',      'route': 'Comedy',      'color': Color(0xFF2C1A08)},
    {'icon': Icons.local_bar_rounded,      'label': 'Bars',        'route': 'Clubs',       'color': Color(0xFF0A3A4A)},
  ];

  // ── Near You (mixed, curated) ────────────────────────────
  final List<Map<String, dynamic>> _nearYou = [
    {
      'name': 'Monmouth Coffee Co.',
      'category': 'Café',
      'cashback': '12%',
      'rating': '4.9',
      'distance': '0.3 mi',
      'color': Color(0xFF5C3D1E),
      'icon': Icons.coffee_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=400&q=75',
      'address': '2 Park St, Borough Market, SE1 9AB',
      'visits': '18.4k+ visits',
      'phone': '020 7232 3010',
      'cashback_pct': '12%',
      'type': 'Café',
      'reviews': '3.1k',
      'desc': 'One of London\'s most celebrated independent coffee roasters, beloved for its single-origin brews served in a rustic Borough Market setting.',
    },
    {
      'name': 'Dishoom Covent Garden',
      'category': 'Indian Restaurant',
      'cashback': '10%',
      'rating': '4.8',
      'distance': '0.7 mi',
      'color': Color(0xFF3B1F0A),
      'icon': Icons.restaurant_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=400&q=75',
      'address': '12 Upper St Martin\'s Lane, WC2H 9FB',
      'visits': '32.5k+ visits',
      'phone': '020 7420 9320',
      'cashback_pct': '10%',
      'type': 'Restaurant',
      'reviews': '8.4k',
      'desc': 'Inspired by the iconic Irani cafés of Bombay, Dishoom serves extraordinary food all day long.',
    },
    {
      'name': 'The Churchill Arms',
      'category': 'Historic Pub',
      'cashback': '15%',
      'rating': '4.8',
      'distance': '1.1 mi',
      'color': Color(0xFF1A3A1A),
      'icon': Icons.sports_bar_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1525268323446-0505b6fe7778?w=400&q=75',
      'address': '119 Kensington Church St, W8 7LN',
      'visits': '24.6k+ visits',
      'phone': '020 7727 4242',
      'cashback_pct': '15%',
      'type': 'Pub',
      'reviews': '2.6k',
      'desc': 'A legendary Kensington pub draped in hanging flower baskets and festive lights.',
    },
    {
      'name': 'Fabric',
      'category': 'Nightclub',
      'cashback': '8%',
      'rating': '4.7',
      'distance': '1.4 mi',
      'color': Color(0xFF1A0533),
      'icon': Icons.nightlife_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1566737236500-c8ac43014a67?w=400&q=75',
      'address': '77a Charterhouse St, Farringdon, EC1M 6HJ',
      'visits': '42.1k+ visits',
      'phone': '020 7336 8898',
      'cashback_pct': '8%',
      'type': 'Nightclub',
      'reviews': '5.2k',
      'desc': 'One of the world\'s most respected nightclubs, a cornerstone of London\'s electronic music scene.',
    },
    {
      'name': 'Sketch',
      'category': 'Restaurant & Bar',
      'cashback': '12%',
      'rating': '4.7',
      'distance': '1.8 mi',
      'color': Color(0xFF1C1C2E),
      'icon': Icons.wine_bar_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=400&q=75',
      'address': '9 Conduit St, Mayfair, W1S 2XG',
      'visits': '14.8k+ visits',
      'phone': '020 7659 4500',
      'cashback_pct': '12%',
      'type': 'Restaurant & Bar',
      'reviews': '4.9k',
      'desc': 'A spectacular collection of restaurants and bars housed in an 18th-century Mayfair townhouse.',
    },
    {
      'name': 'Poppies Fish & Chips',
      'category': 'Fast Food',
      'cashback': '10%',
      'rating': '4.6',
      'distance': '0.9 mi',
      'color': Color(0xFF0A2A4A),
      'icon': Icons.fastfood_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1585325701956-60dd9c8553bc?w=400&q=75',
      'address': '6-8 Hanbury St, Spitalfields, E1 6QR',
      'visits': '11.2k+ visits',
      'phone': '020 7247 0892',
      'cashback_pct': '10%',
      'type': 'Fast Food',
      'reviews': '2.1k',
      'desc': 'London\'s most celebrated fish and chips restaurant. Fresh fish, hand-cut chips, classic British seaside food done right.',
    },
    {
      'name': 'Bleecker Burger',
      'category': 'Fast Food',
      'cashback': '8%',
      'rating': '4.7',
      'distance': '1.2 mi',
      'color': Color(0xFF0A2A4A),
      'icon': Icons.fastfood_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&q=75',
      'address': '3 Bloomberg Arcade, EC4N 8AR',
      'visits': '9.8k+ visits',
      'phone': '020 3146 4500',
      'cashback_pct': '8%',
      'type': 'Fast Food',
      'reviews': '1.8k',
      'desc': 'Award-winning burgers made from dry-aged beef, served in a no-fuss setting in the heart of the City.',
    },
  ];

  // ── Top Cashback ─────────────────────────────────────────
  final List<Map<String, dynamic>> _topCashback = [
    {
      'name': 'Attendant Coffee',
      'cashback': '15%',
      'category': 'Café',
      'color': Color(0xFF4A2C17),
      'imageUrl': 'https://images.unsplash.com/photo-1442512595331-e89e73853f31?w=400&q=75',
      'address': '74 Great Titchfield St, Fitzrovia, W1W 7QP',
      'visits': '7.3k+ visits',
      'phone': '020 7580 6089',
      'cashback_pct': '15%',
      'type': 'Café',
      'rating': '4.8',
      'reviews': '1.9k',
      'desc': 'A unique café housed in a restored Victorian underground public toilet.',
    },
    {
      'name': 'The Churchill Arms',
      'cashback': '15%',
      'category': 'Historic Pub',
      'color': Color(0xFF1A3A1A),
      'imageUrl': 'https://images.unsplash.com/photo-1525268323446-0505b6fe7778?w=400&q=75',
      'address': '119 Kensington Church St, W8 7LN',
      'visits': '24.6k+ visits',
      'phone': '020 7727 4242',
      'cashback_pct': '15%',
      'type': 'Pub',
      'rating': '4.8',
      'reviews': '2.6k',
      'desc': 'A legendary Kensington pub draped in hanging flower baskets and festive lights.',
    },
    {
      'name': 'Monmouth Coffee Co.',
      'cashback': '12%',
      'category': 'Café',
      'color': Color(0xFF5C3D1E),
      'imageUrl': 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=400&q=75',
      'address': '2 Park St, Borough Market, SE1 9AB',
      'visits': '18.4k+ visits',
      'phone': '020 7232 3010',
      'cashback_pct': '12%',
      'type': 'Café',
      'rating': '4.9',
      'reviews': '3.1k',
      'desc': 'One of London\'s most celebrated independent coffee roasters.',
    },
    {
      'name': 'Sketch',
      'cashback': '12%',
      'category': 'Restaurant & Bar',
      'color': Color(0xFF1C1C2E),
      'imageUrl': 'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=400&q=75',
      'address': '9 Conduit St, Mayfair, W1S 2XG',
      'visits': '14.8k+ visits',
      'phone': '020 7659 4500',
      'cashback_pct': '12%',
      'type': 'Restaurant & Bar',
      'rating': '4.7',
      'reviews': '4.9k',
      'desc': 'A spectacular collection of restaurants and bars in a Mayfair townhouse.',
    },
  ];

  bool _venueMatchesQuery(Map<String, dynamic> v, String q) {
    final fields = [
      v['name']     as String? ?? '',
      v['category'] as String? ?? '',
      v['type']     as String? ?? '',
      v['desc']     as String? ?? '',
      v['address']  as String? ?? '',
    ];
    return fields.any((f) => f.toLowerCase().contains(q));
  }

  List<Map<String, dynamic>> get _filteredNearYou {
    if (_searchQuery.isEmpty) return _nearYou;
    final q = _searchQuery.toLowerCase();
    return _nearYou.where((v) => _venueMatchesQuery(v, q)).toList();
  }

  List<Map<String, dynamic>> get _filteredTopCashback {
    if (_searchQuery.isEmpty) return _topCashback;
    final q = _searchQuery.toLowerCase();
    return _topCashback.where((v) => _venueMatchesQuery(v, q)).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/messages'),
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
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                      child: Center(
                        child: Text('3',
                            style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
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

  // ── Categories grid ──────────────────────────────────────
  Widget _buildCategories() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Categories',
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _dark)),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 16,
                childAspectRatio: 0.82,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final c = _categories[index];
                return GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/nearby',
                      arguments: {'category': c['route'] as String}),
                  child: Column(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
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
                        height: 30,
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
                );
              },
            ),
          ],
        ),
      );

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
