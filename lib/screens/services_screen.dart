import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  int _currentIndex = 1;

  static const Color _primary = Color(0xFF0392CA);
  static const Color _dark = Color(0xFF0D1B3E);
  static const Color _bg = Color(0xFFF2F4F7);

  final List<Map<String, dynamic>> _allServices = [
    {'icon': Icons.delivery_dining_rounded, 'label': 'Food Delivery', 'isNew': true, 'route': '/food-delivery'},
    {'icon': Icons.coffee_rounded, 'label': 'Cafes', 'isNew': false, 'route': '/nearby'},
    {'icon': Icons.restaurant_rounded, 'label': 'Restaurants', 'isNew': false, 'route': '/nearby'},
    {'icon': Icons.nightlife_rounded, 'label': 'Clubs', 'isNew': false, 'route': '/nearby'},
    {'icon': Icons.sports_bar_rounded, 'label': 'Pubs', 'isNew': false, 'route': '/nearby'},
    {'icon': Icons.fastfood_rounded, 'label': 'Fast Food', 'isNew': false, 'route': '/nearby'},
    {'icon': Icons.music_note_rounded, 'label': 'Music', 'isNew': false, 'route': '/nearby'},
    {'icon': Icons.theater_comedy_rounded, 'label': 'Comedy', 'isNew': false, 'route': '/nearby'},
    {'icon': Icons.local_bar_rounded, 'label': 'Bars', 'isNew': false, 'route': '/nearby'},
  ];

  final List<Map<String, dynamic>> _offers = [
    {
      'name': 'Artisan Brews',
      'description': 'Premium coffee and handcrafted pastries.',
      'badge': '20% OFF',
      'cashback': '15% Cashback',
      'color': const Color(0xFF5C8FA8),
      'image': 'assets/images/special offers/working_table.webp',
    },
    {
      'name': 'The Golden Spoon',
      'description': 'Fine dining experience in the heart of London.',
      'badge': '10% OFF',
      'cashback': 'Free Dessert',
      'color': const Color(0xFF8B6F47),
      'image': 'assets/images/special offers/wine_noodle.webp',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        title: Text(
          'Services',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _primary,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_outline_rounded,
                  color: Colors.black87, size: 20),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 14),
            _buildSearchBar(),
            const SizedBox(height: 20),
            _buildFoodDeliveryBanner(context),
            const SizedBox(height: 20),
            _buildSpecialOffers(context),
            const SizedBox(height: 20),
            _buildAllServices(),
            const SizedBox(height: 20),
            _buildCashbackBanner(),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildFoodDeliveryBanner(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/food-delivery'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEA580C), Color(0xFFF59E0B)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -10,
                  top: -10,
                  child: Icon(Icons.delivery_dining_rounded,
                      size: 110, color: Colors.white.withOpacity(0.12)),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('NEW', style: GoogleFonts.inter(
                                fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                          ),
                          const SizedBox(height: 8),
                          Text('GoOuts Food\nDelivery',
                              style: GoogleFonts.inter(
                                  fontSize: 22, fontWeight: FontWeight.w800,
                                  color: Colors.white, height: 1.2)),
                          const SizedBox(height: 8),
                          Text('Order from local restaurants.\nFree delivery with Social Boost.',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.9),
                                  height: 1.5)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.delivery_dining_rounded,
                          color: Color(0xFFEA580C), size: 36),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildSearchBar() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(Icons.search_rounded, color: Colors.grey[400], size: 20),
              const SizedBox(width: 10),
              Text(
                'Search services, cafes, or clubs...',
                style: GoogleFonts.inter(
                    fontSize: 14, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      );

  Widget _buildSpecialOffers(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Special Offers',
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _dark),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/special-offers'),
                  child: Text(
                    'See All',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 240,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _offers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final o = _offers[index];
                  return _offerCard(o, context);
                },
              ),
            ),
          ],
        ),
      );

  Widget _offerCard(Map<String, dynamic> o, BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/partner-details',
        arguments: {
          'name': o['name'],
          'category': 'Cafes',
          'cashback': o['cashback'],
        },
      ),
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image header
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
              child: Stack(
                children: [
                  Image.asset(
                    o['image'] as String,
                    height: 120,
                    width: 220,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => Container(
                      height: 120,
                      width: 220,
                      color: o['color'] as Color,
                      child: Icon(Icons.store_rounded,
                          color: Colors.white.withOpacity(0.5), size: 40),
                    ),
                  ),
                  // Discount badge
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D6E3A),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        o['badge'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info area
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    o['name'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    o['description'] as String,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        o['cashback'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _primary,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.local_offer_rounded,
                          color: _primary, size: 18),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllServices() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'All Services',
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _dark),
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 14,
                childAspectRatio: 0.85,
              ),
              itemCount: _allServices.length,
              itemBuilder: (context, index) {
                final s = _allServices[index];
                final isNew = s['isNew'] as bool;
                final route = s['route'] as String;
                return GestureDetector(
                  onTap: () => Navigator.pushNamed(context, route,
                      arguments: {'category': s['label']}),
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: isNew
                                  ? const Color(0xFFFEF3C7)
                                  : const Color(0xFFE8F4FB),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(s['icon'] as IconData,
                                color: isNew ? const Color(0xFFEA580C) : _primary,
                                size: 26),
                          ),
                          if (isNew)
                            Positioned(
                              top: -6,
                              right: -6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEA580C),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('NEW',
                                    style: GoogleFonts.inter(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        s['label'] as String,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isNew ? const Color(0xFFEA580C) : Colors.grey[700],
                            fontWeight: isNew ? FontWeight.w700 : FontWeight.normal),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      );

  Widget _buildCashbackBanner() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0A6E8A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              // Background watermark icon
              Positioned(
                right: -10,
                top: -10,
                child: Icon(
                  Icons.local_offer_rounded,
                  size: 110,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unlock Cashback\nRewards',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Load £100 and more to your wallet and unlock extra cashback.',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.85),
                        height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/add-funds'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0A6E8A),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 10),
                      elevation: 0,
                    ),
                    child: Text(
                      'Load Now',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0A6E8A)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

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
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) {
            setState(() => _currentIndex = i);
            const routes = [
              '/home',
              '/nearby',
              '/wallet',
              '/activity',
              '/profile'
            ];
            if (i != 1) Navigator.pushNamed(context, routes[i]);
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: _primary,
          unselectedItemColor: Colors.grey[400],
          selectedLabelStyle:
              GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.explore_rounded), label: 'Explore'),
            BottomNavigationBarItem(
                icon: Icon(Icons.account_balance_wallet_rounded),
                label: 'Wallet'),
            BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long_rounded), label: 'Activity'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      );
}
