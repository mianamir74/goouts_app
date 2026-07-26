import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SpecialOffersScreen extends StatelessWidget {
  const SpecialOffersScreen({super.key});

  static const Color _primary = Color(0xFF0392CA);
  static const Color _dark = Color(0xFF191C1E);
  static const Color _grey = Color(0xFF42474E);
  static const Color _rewardBg = Color(0xFFD3E4FF);
  static const Color _rewardText = Color(0xFF001C38);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _primary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          'GoOuts',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _primary,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_outlined, color: _primary),
                onPressed: () => Navigator.pushNamed(context, '/messages'),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Special Offers',
              style: GoogleFonts.inter(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Exclusive rewards for our gold members.',
              style: GoogleFonts.inter(fontSize: 14, color: _grey),
            ),
            const SizedBox(height: 28),

            // Card 1 — Dishoom Covent Garden
            _buildOfferCard(
              context: context,
              imagePath: 'assets/images/special offers/working_table.webp',
              tag: '20% Off First Visit',
              tagColor: const Color(0xFF3B1F0A),
              title: 'Dishoom Covent Garden',
              location: 'Covent Garden • Indian Restaurant',
              reward: '10% Cashback',
              buttonText: 'Claim Offer',
              rating: '4.8',
              distance: '0.8 miles away',
              onTap: () => Navigator.pushNamed(context, '/partner-offer',
                  arguments: {
                    'name': 'Dishoom Covent Garden',
                    'address': '12 Upper St Martin\'s Lane, WC2H 9FB',
                    'rating': '4.8',
                    'imagePath': 'assets/images/special offers/working_table.webp',
                    'tag': '20% Off First Visit',
                    'promoCode': 'DISHOOM20',
                    'offerTitle': 'First Visit Reward',
                    'cashback': '10% Cashback',
                    'category': '££ • Indian',
                  }),
            ),

            const SizedBox(height: 24),

            // Card 2 — Aqua Shard
            _buildOfferCard(
              context: context,
              imagePath: 'assets/images/special offers/wine_noodle.webp',
              tag: 'Happy Hour 30% Off',
              tagColor: const Color(0xFF0A2A4A),
              title: 'Aqua Shard',
              location: 'The Shard, London Bridge • European',
              reward: '12% Cashback',
              buttonText: 'Book Table',
              rating: '4.7',
              distance: '1.2 miles away',
              onTap: () => Navigator.pushNamed(context, '/partner-offer',
                  arguments: {
                    'name': 'Aqua Shard',
                    'address': 'Level 31, The Shard, 31 St Thomas St, SE1 9RY',
                    'rating': '4.7',
                    'imagePath': 'assets/images/special offers/wine_noodle.webp',
                    'tag': 'Happy Hour 30% Off',
                    'promoCode': 'SHARD30',
                    'offerTitle': 'Happy Hour Reward',
                    'cashback': '12% Cashback',
                    'category': '£££ • Modern European',
                  }),
            ),

            const SizedBox(height: 24),

            // Card 3 — Fabric
            _buildOfferCard(
              context: context,
              imagePath: 'assets/images/special offers/astral_launge.webp',
              tag: 'VIP Entry Deal',
              tagColor: const Color(0xFF1A0533),
              title: 'Fabric',
              location: 'Farringdon • Nightclub',
              reward: '8% Cashback',
              buttonText: 'Reserve Now',
              rating: '4.7',
              distance: '1.8 miles away',
              onTap: () => Navigator.pushNamed(context, '/partner-offer',
                  arguments: {
                    'name': 'Fabric',
                    'address': '77a Charterhouse St, Farringdon, EC1M 6HJ',
                    'rating': '4.7',
                    'imagePath': 'assets/images/special offers/astral_launge.webp',
                    'tag': 'VIP Entry Deal',
                    'promoCode': 'FABRICVIP',
                    'offerTitle': 'VIP Entry Reward',
                    'cashback': '8% Cashback',
                    'category': '££ • Nightclub',
                  }),
            ),

            const SizedBox(height: 24),

            // Card 4 — Monmouth Coffee
            _buildOfferCard(
              context: context,
              imagePath: 'assets/images/special offers/working_table.webp',
              tag: 'Free Coffee',
              tagColor: const Color(0xFF5C3D1E),
              title: 'Monmouth Coffee Co.',
              location: 'Borough Market, SE1 • Specialty Café',
              reward: '12% Cashback',
              buttonText: 'Claim Offer',
              hasAvatars: true,
              onTap: () => Navigator.pushNamed(context, '/partner-offer',
                  arguments: {
                    'name': 'Monmouth Coffee Co.',
                    'address': '2 Park St, Borough Market, SE1 9AB',
                    'rating': '4.9',
                    'imagePath': 'assets/images/special offers/working_table.webp',
                    'tag': 'Free Coffee',
                    'promoCode': 'MONMOUTH1',
                    'offerTitle': 'Free Coffee Reward',
                    'cashback': '12% Cashback',
                    'category': '£ • Café',
                  }),
            ),

            const SizedBox(height: 24),

            // Card 5 — Ronnie Scott's
            _buildOfferCard(
              context: context,
              imagePath: 'assets/images/special offers/astral_launge.webp',
              tag: '2-for-1 Cocktails',
              tagColor: const Color(0xFF1A0A00),
              title: 'Ronnie Scott\'s Jazz Club',
              location: 'Soho • Jazz Club',
              reward: '10% Cashback',
              buttonText: 'Reserve Now',
              rating: '4.9',
              distance: '0.5 miles away',
              onTap: () => Navigator.pushNamed(context, '/partner-offer',
                  arguments: {
                    'name': 'Ronnie Scott\'s',
                    'address': '47 Frith St, Soho, W1D 4HT',
                    'rating': '4.9',
                    'imagePath': 'assets/images/special offers/astral_launge.webp',
                    'tag': '2-for-1 Cocktails',
                    'promoCode': 'RONNIE2FOR1',
                    'offerTitle': 'Cocktail Night Reward',
                    'cashback': '10% Cashback',
                    'category': '££ • Jazz Club',
                  }),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildOfferCard({
    required BuildContext context,
    required String imagePath,
    required String tag,
    required Color tagColor,
    required String title,
    required String location,
    required String reward,
    required String buttonText,
    String? rating,
    String? distance,
    bool hasAvatars = false,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Stack(
            children: [
              Image.asset(
                imagePath,
                height: 190,
                width: double.infinity,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorBuilder: (ctx, err, st) => Container(
                  height: 190,
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(Icons.store_rounded,
                        color: Colors.white54, size: 48),
                  ),
                ),
              ),
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: tagColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tag,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: _dark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 14, color: _grey),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  location,
                                  style: GoogleFonts.inter(
                                      fontSize: 13, color: _grey),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _rewardBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'REWARD',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _rewardText.withValues(alpha: 0.6),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            reward,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _rewardText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (hasAvatars)
                      Row(
                        children: [
                          _buildAvatar('JD', Colors.grey[400]!),
                          Transform.translate(
                            offset: const Offset(-8, 0),
                            child: _buildAvatar('ML', _primary),
                          ),
                          Transform.translate(
                            offset: const Offset(-16, 0),
                            child: _buildAvatar('+12', Colors.orange[700]!),
                          ),
                        ],
                      )
                    else if (rating != null)
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text(rating,
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: _dark)),
                          const SizedBox(width: 6),
                          Text('• $distance',
                              style: GoogleFonts.inter(
                                  color: _grey, fontSize: 13)),
                        ],
                      ),
                    ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        buttonText,
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String text, Color color) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.local_offer_rounded, 'Offers', _primary, true),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/notifications'),
            child: _navItem(Icons.history_rounded, 'Activity',
                Colors.grey[400]!, false),
          ),
          GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: _primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.qr_code_scanner_rounded,
                  color: Colors.white, size: 24),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/profile'),
            child: _navItem(
                Icons.person_outline_rounded, 'Profile', Colors.grey[400]!, false),
          ),
        ],
      ),
    );
  }

  Widget _navItem(
      IconData icon, String label, Color color, bool isActive) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            color: color,
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
