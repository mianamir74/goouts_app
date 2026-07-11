import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/delivery_address_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  GoOuts Food Delivery — Restaurant Listing & Discovery Screen
//  Task 71 | Cuisines sourced from Deliveroo + UberEats UK live data
// ─────────────────────────────────────────────────────────────────────────────

class FoodDeliveryScreen extends StatefulWidget {
  const FoodDeliveryScreen({super.key});

  @override
  State<FoodDeliveryScreen> createState() => _FoodDeliveryScreenState();
}

class _FoodDeliveryScreenState extends State<FoodDeliveryScreen>
    with SingleTickerProviderStateMixin {
  // ── Brand colours ──────────────────────────────────────────────────────────
  static const Color _primary  = Color(0xFFEA580C); // orange
  static const Color _navy     = Color(0xFF0D1B3E);
  static const Color _purple   = Color(0xFF7C3AED);
  static const Color _bg       = Color(0xFFF2F4F7);

  // ── Cuisine categories (Deliveroo + UberEats UK, with emoji icons) ──────────
  // Stored in Firestore `foodCuisines` collection in production.
  // Hardcoded here as fallback so screen works before Firestore is seeded.
  static const _cuisineList = [
    _Cuisine('🍽️', 'All'),
    _Cuisine('🍕', 'Pizza'),
    _Cuisine('🍛', 'Indian'),
    _Cuisine('🥡', 'Chinese'),
    _Cuisine('🍔', 'Burgers'),
    _Cuisine('🍣', 'Sushi'),
    _Cuisine('🌮', 'Mexican'),
    _Cuisine('🥙', 'Kebab'),
    _Cuisine('🍜', 'Thai'),
    _Cuisine('🍝', 'Italian'),
    _Cuisine('🍱', 'Japanese'),
    _Cuisine('🥗', 'Healthy'),
    _Cuisine('🫕', 'Lebanese'),
    _Cuisine('🍗', 'Chicken'),
    _Cuisine('🥐', 'Breakfast'),
    _Cuisine('🍟', 'American'),
    _Cuisine('🐟', 'Fish & Chips'),
    _Cuisine('🫙', 'Greek'),
    _Cuisine('🌯', 'Pakistani'),
    _Cuisine('🥘', 'Caribbean'),
    _Cuisine('🍲', 'Nigerian'),
    _Cuisine('🥩', 'Korean BBQ'),
    _Cuisine('🍩', 'Desserts'),
    _Cuisine('🛒', 'Groceries'),
  ];

  // ── Dietary filters (separate row, shown when Filters expanded) ─────────────
  // Matches `dietaryTags` field saved by admin panel
  static const _dietaryList = [
    'Halal', 'Vegetarian', 'Vegan', 'Gluten Free',
    'Kosher', 'Nut Free', 'Dairy Free',
  ];

  // ── Sort options ────────────────────────────────────────────────────────────
  static const _sortOptions = ['Popular', 'Fastest', 'Top Rated', 'Lowest Fee'];

  // ── State ───────────────────────────────────────────────────────────────────
  final _searchCtrl   = TextEditingController();
  final _addrService  = DeliveryAddressService(); // singleton — safe as field
  String _searchQuery      = '';
  String _selectedCuisine  = 'All';
  String _sortBy           = 'Popular';
  bool   _socialBoostOnly  = false;
  bool   _filtersExpanded  = false;
  final Set<String> _selectedDietary = {};

  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildSearchAndFilter()),
          SliverToBoxAdapter(child: _buildCuisineRow()),
          if (_filtersExpanded) SliverToBoxAdapter(child: _buildDietaryRow()),
          SliverToBoxAdapter(child: _buildAddressBanner()),
          SliverToBoxAdapter(child: _buildPromoBanner()),
          SliverToBoxAdapter(child: _buildSectionHeader('Restaurants near you')),
          _buildRestaurantList(),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  // ── App bar ─────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      // Address bar replaces static title
      title: ListenableBuilder(
        listenable: _addrService,
        builder: (context, _) {
          final addr = _addrService.current;
          return GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/food-address-picker'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  addr != null
                      ? Icons.location_on_rounded
                      : Icons.location_searching_rounded,
                  color: _primary,
                  size: 18,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        addr != null ? 'Delivering to' : 'Set delivery address',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500),
                      ),
                      if (addr != null)
                        Text(
                          addr.shortDisplay,
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _navy),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey[500], size: 18),
              ],
            ),
          );
        },
      ),
      centerTitle: false,
      actions: [
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.shopping_bag_outlined, color: Colors.black87),
              onPressed: () => Navigator.pushNamed(context, '/food-cart'),
            ),
            // Cart badge — wire to CartService later
            Positioned(
              right: 8, top: 8,
              child: Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                    color: _primary, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Search + filter row ─────────────────────────────────────────────────────
  Widget _buildSearchAndFilter() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Row(
          children: [
            // Search bar
            Expanded(
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(Icons.search_rounded, color: Colors.grey[400], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) =>
                            setState(() => _searchQuery = v.toLowerCase()),
                        decoration: InputDecoration(
                          hintText: 'Restaurants, dishes...',
                          hintStyle: GoogleFonts.inter(
                              fontSize: 13, color: Colors.grey[400]),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: Colors.grey[400], size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Filter toggle button
            GestureDetector(
              onTap: () => setState(() => _filtersExpanded = !_filtersExpanded),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: _filtersExpanded ? _primary : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Icon(Icons.tune_rounded,
                    color: _filtersExpanded ? Colors.white : Colors.grey[700],
                    size: 20),
              ),
            ),
            const SizedBox(width: 10),
            // Sort button
            GestureDetector(
              onTap: _showSortSheet,
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sort_rounded, size: 16, color: Colors.grey[700]),
                    const SizedBox(width: 4),
                    Text(_sortBy,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: Colors.grey[700])),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        size: 14, color: Colors.grey[500]),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  // ── Cuisine horizontal chips ────────────────────────────────────────────────
  Widget _buildCuisineRow() => SizedBox(
        height: 60,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          itemCount: _cuisineList.length,
          itemBuilder: (context, i) {
            final c = _cuisineList[i];
            final selected = c.label == _selectedCuisine;
            return GestureDetector(
              onTap: () => setState(() => _selectedCuisine = c.label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? _primary : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: selected ? _primary : Colors.grey.shade300),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                              color: _primary.withOpacity(0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2))
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(c.emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 5),
                    Text(c.label,
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.normal,
                            color: selected ? Colors.white : Colors.grey[700])),
                  ],
                ),
              ),
            );
          },
        ),
      );

  // ── Dietary filter chips (expanded) ─────────────────────────────────────────
  Widget _buildDietaryRow() => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 50,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          children: [
            // Social Boost toggle
            _dietaryChip(
              label: '⚡ Social Boost',
              selected: _socialBoostOnly,
              color: _purple,
              onTap: () => setState(() => _socialBoostOnly = !_socialBoostOnly),
            ),
            ..._dietaryList.map((d) => _dietaryChip(
                  label: d,
                  selected: _selectedDietary.contains(d),
                  color: const Color(0xFF10B981),
                  onTap: () => setState(() => _selectedDietary.contains(d)
                      ? _selectedDietary.remove(d)
                      : _selectedDietary.add(d)),
                )),
          ],
        ),
      );

  Widget _dietaryChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.12) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: selected ? color : Colors.grey.shade300),
          ),
          child: Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: selected ? color : Colors.grey[700],
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.normal)),
        ),
      );

  // ── Address prompt banner (shown only when no address set) ─────────────────
  Widget _buildAddressBanner() {
    return ListenableBuilder(
      listenable: _addrService,
      builder: (context, _) {
        final addr = _addrService.current;
        if (addr != null) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/food-address-picker'),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: Row(children: [
              const Icon(Icons.location_on_rounded,
                  color: Color(0xFFEA580C), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Set your delivery address to see restaurants near you',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF9A3412),
                      fontWeight: FontWeight.w500),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFFEA580C), size: 18),
            ]),
          ),
        );
      },
    );
  }

  // ── Promo banner ────────────────────────────────────────────────────────────
  Widget _buildPromoBanner() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: GestureDetector(
          onTap: () {}, // future: open Social Boost info sheet
          child: Container(
            height: 90,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF0392CA)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -12, top: -12,
                  child: Icon(Icons.campaign_rounded,
                      size: 100,
                      color: Colors.white.withOpacity(0.08)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                            child: Text('📸',
                                style: TextStyle(fontSize: 22))),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Text('Social Boost',
                                    style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text('FREE DELIVERY',
                                      style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                                'Post about your order on Instagram → next delivery free.',
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.85))),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: Colors.white60),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  // ── Section header ──────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Row(
          children: [
            Text(title,
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _navy)),
            const Spacer(),
            // Active filter count badge
            if (_selectedDietary.isNotEmpty || _socialBoostOnly)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: _primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(
                    '${_selectedDietary.length + (_socialBoostOnly ? 1 : 0)} filter${(_selectedDietary.length + (_socialBoostOnly ? 1 : 0)) > 1 ? 's' : ''} active',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: _primary,
                        fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      );

  // ── Restaurant list (Firestore stream + placeholder fallback) ───────────────
  Widget _buildRestaurantList() => StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('restaurants')
            .where('isOnline', isEqualTo: true)
            .where('isApproved', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          final restaurants =
              snapshot.hasData && snapshot.data!.docs.isNotEmpty
                  ? snapshot.data!.docs
                      .map((d) => _RestaurantItem.fromDoc(d))
                      .toList()
                  : _placeholders;

          // ── Apply filters ──────────────────────────────────────────────────
          var filtered = restaurants.where((r) {
            // Search
            if (_searchQuery.isNotEmpty &&
                !r.name.toLowerCase().contains(_searchQuery) &&
                !r.cuisineType.toLowerCase().contains(_searchQuery)) {
              return false;
            }
            // Cuisine
            if (_selectedCuisine != 'All' &&
                !r.cuisineType
                    .toLowerCase()
                    .contains(_selectedCuisine.toLowerCase())) {
              return false;
            }
            // Social Boost
            if (_socialBoostOnly && !r.socialBoostEnabled) return false;
            // Dietary tags — normalise both sides (strip hyphens, lowercase)
            for (final d in _selectedDietary) {
              final norm = d.toLowerCase().replaceAll('-', ' ');
              if (!r.tags.any((t) => t.toLowerCase().replaceAll('-', ' ') == norm)) {
                return false;
              }
            }
            return true;
          }).toList();

          // ── Sort ───────────────────────────────────────────────────────────
          switch (_sortBy) {
            case 'Top Rated':
              filtered.sort((a, b) => b.rating.compareTo(a.rating));
              break;
            case 'Fastest':
              filtered.sort((a, b) =>
                  a.deliveryMins.compareTo(b.deliveryMins));
              break;
            case 'Lowest Fee':
              filtered.sort(
                  (a, b) => a.deliveryFee.compareTo(b.deliveryFee));
              break;
            default:
              break; // Popular = Firestore order
          }

          if (filtered.isEmpty) {
            return SliverToBoxAdapter(child: _emptyState());
          }

          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _restaurantCard(filtered[i]),
              childCount: filtered.length,
            ),
          );
        },
      );

  Widget _emptyState() => Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            const Text('😕', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
            Text('No restaurants found',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600])),
            const SizedBox(height: 6),
            Text('Try a different cuisine or remove some filters.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 13, color: Colors.grey[400])),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => setState(() {
                _selectedCuisine = 'All';
                _socialBoostOnly = false;
                _selectedDietary.clear();
              }),
              child: Text('Clear all filters',
                  style: GoogleFonts.inter(color: _primary)),
            ),
          ],
        ),
      );

  // ── Restaurant card ─────────────────────────────────────────────────────────
  Widget _restaurantCard(_RestaurantItem r) => GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/food-menu', arguments: {
          'restaurantId': r.id,
          'restaurantName': r.name,
          'cuisineType': r.cuisineType,
          'deliveryFee': r.deliveryFee,
          'deliveryMins': r.deliveryMins,
          'socialBoostEnabled': r.socialBoostEnabled,
        }),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Cover image ────────────────────────────────────────────────
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  children: [
                    r.coverImageUrl != null
                        ? Image.network(r.coverImageUrl!,
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _coverPlaceholder(r))
                        : _coverPlaceholder(r),
                    // Gradient overlay at bottom
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.4),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Top-left badges
                    Positioned(
                      top: 10, left: 10,
                      child: Wrap(
                        spacing: 5,
                        children: [
                          if (r.isBusy) _badge('Busy', Colors.orange),
                          if (r.socialBoostEnabled)
                            _badge('⚡ Social Boost', _purple),
                          if (r.tags.contains('halal'))
                            _badge('Halal', const Color(0xFF10B981)),
                        ],
                      ),
                    ),
                    // Delivery fee — bottom right
                    Positioned(
                      bottom: 8, right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: r.deliveryFee == 0
                              ? const Color(0xFF10B981)
                              : Colors.black.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          r.deliveryFee == 0
                              ? '🚚 Free delivery'
                              : '£${r.deliveryFee.toStringAsFixed(2)} delivery',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ── Info row ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.name,
                              style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _navy)),
                          const SizedBox(height: 2),
                          Text(r.cuisineType,
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.grey[500])),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _infoChip(
                                  Icons.access_time_rounded,
                                  '${r.deliveryMins} min'),
                              const SizedBox(width: 10),
                              _infoChip(
                                  Icons.shopping_bag_outlined,
                                  'Min £${r.minOrder.toStringAsFixed(0)}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Rating
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 16,
                                color: Color(0xFFF59E0B)),
                            const SizedBox(width: 3),
                            Text(r.rating.toStringAsFixed(1),
                                style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: _navy)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text('(${r.reviewCount})',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey[400])),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _infoChip(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey[500]),
          const SizedBox(width: 3),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12, color: Colors.grey[600])),
        ],
      );

  Widget _coverPlaceholder(_RestaurantItem r) => Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _primary.withOpacity(0.08),
              _primary.withOpacity(0.14),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🍽️', style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 6),
            Text(r.name,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: _primary.withOpacity(0.6),
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.w700)),
      );

  // ── Sort bottom sheet ───────────────────────────────────────────────────────
  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text('Sort by',
                style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ..._sortOptions.map((opt) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    opt == 'Popular'
                        ? Icons.local_fire_department_rounded
                        : opt == 'Fastest'
                            ? Icons.flash_on_rounded
                            : opt == 'Top Rated'
                                ? Icons.star_rounded
                                : Icons.money_off_rounded,
                    color:
                        _sortBy == opt ? _primary : Colors.grey[500],
                    size: 22,
                  ),
                  title: Text(opt,
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: _sortBy == opt
                              ? FontWeight.w700
                              : FontWeight.normal,
                          color: _sortBy == opt ? _primary : Colors.black87)),
                  trailing: _sortBy == opt
                      ? Icon(Icons.check_circle_rounded,
                          color: _primary, size: 20)
                      : null,
                  onTap: () {
                    setState(() => _sortBy = opt);
                    Navigator.pop(ctx);
                  },
                )),
          ],
        ),
      ),
    );
  }

  // ── Placeholder data ─────────────────────────────────────────────────────────
  static final _placeholders = [
    _RestaurantItem(
        id: 'p1', name: 'Spice Garden', cuisineType: 'Indian · Curry · Biryani',
        rating: 4.8, reviewCount: 312, deliveryMins: 25, deliveryFee: 1.99,
        minOrder: 12, isBusy: false, socialBoostEnabled: true,
        tags: ['halal'], coverImageUrl: null),
    _RestaurantItem(
        id: 'p2', name: 'Pizza Palace', cuisineType: 'Pizza · Italian · Pasta',
        rating: 4.6, reviewCount: 198, deliveryMins: 30, deliveryFee: 2.49,
        minOrder: 10, isBusy: true, socialBoostEnabled: false,
        tags: ['vegetarian'], coverImageUrl: null),
    _RestaurantItem(
        id: 'p3', name: 'Dragon Wok', cuisineType: 'Chinese · Noodles · Dim Sum',
        rating: 4.5, reviewCount: 267, deliveryMins: 20, deliveryFee: 0,
        minOrder: 15, isBusy: false, socialBoostEnabled: true,
        tags: ['halal'], coverImageUrl: null),
    _RestaurantItem(
        id: 'p4', name: 'Burger Bros', cuisineType: 'Burgers · American · Fries',
        rating: 4.7, reviewCount: 445, deliveryMins: 15, deliveryFee: 1.49,
        minOrder: 8, isBusy: false, socialBoostEnabled: true,
        tags: [], coverImageUrl: null),
    _RestaurantItem(
        id: 'p5', name: 'Sushi Zen', cuisineType: 'Sushi · Japanese · Ramen',
        rating: 4.9, reviewCount: 156, deliveryMins: 35, deliveryFee: 2.99,
        minOrder: 20, isBusy: false, socialBoostEnabled: false,
        tags: [], coverImageUrl: null),
    _RestaurantItem(
        id: 'p6', name: 'Thai Orchid', cuisineType: 'Thai · Noodles · Curry',
        rating: 4.7, reviewCount: 203, deliveryMins: 28, deliveryFee: 1.99,
        minOrder: 12, isBusy: false, socialBoostEnabled: true,
        tags: ['vegetarian', 'halal'], coverImageUrl: null),
    _RestaurantItem(
        id: 'p7', name: 'The Greek Kitchen', cuisineType: 'Greek · Mediterranean',
        rating: 4.6, reviewCount: 87, deliveryMins: 32, deliveryFee: 2.49,
        minOrder: 15, isBusy: false, socialBoostEnabled: false,
        tags: [], coverImageUrl: null),
    _RestaurantItem(
        id: 'p8', name: 'Lagos Kitchen', cuisineType: 'Nigerian · African',
        rating: 4.8, reviewCount: 124, deliveryMins: 40, deliveryFee: 2.99,
        minOrder: 18, isBusy: false, socialBoostEnabled: true,
        tags: ['halal'], coverImageUrl: null),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
//  Data models
// ─────────────────────────────────────────────────────────────────────────────

class _Cuisine {
  final String emoji;
  final String label;
  const _Cuisine(this.emoji, this.label);
}

class _RestaurantItem {
  final String id;
  final String name;
  final String cuisineType;
  final double rating;
  final int reviewCount;
  final int deliveryMins;
  final double deliveryFee;
  final double minOrder;
  final bool isBusy;
  final bool socialBoostEnabled;
  final List<String> tags; // halal, vegetarian, vegan, gluten-free
  final String? coverImageUrl;

  const _RestaurantItem({
    required this.id,
    required this.name,
    required this.cuisineType,
    required this.rating,
    required this.reviewCount,
    required this.deliveryMins,
    required this.deliveryFee,
    required this.minOrder,
    required this.isBusy,
    required this.socialBoostEnabled,
    required this.tags,
    this.coverImageUrl,
  });

  factory _RestaurantItem.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _RestaurantItem(
      id: doc.id,
      name: d['name'] ?? '',
      cuisineType: (d['cuisineTypes'] as List?)?.join(' · ') ?? '',
      rating: (d['averageRating'] ?? 4.5).toDouble(),
      reviewCount: d['reviewCount'] ?? 0,
      deliveryMins: d['estimatedDeliveryMins'] ?? 30,
      deliveryFee: (d['deliveryFee'] ?? 2.99).toDouble(),
      minOrder: (d['minimumOrderAmount'] ?? 10.0).toDouble(),
      isBusy: d['isBusy'] ?? false,
      socialBoostEnabled: d['socialBoostEnabled'] ?? false,
      // Read `dietaryTags` (new field); fall back to `tags` for legacy docs
      tags: List<String>.from(d['dietaryTags'] ?? d['tags'] ?? []),
      coverImageUrl: d['coverImageUrl'],
    );
  }
}
