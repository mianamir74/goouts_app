import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationDetailScreen extends StatelessWidget {
  const NotificationDetailScreen({super.key});

  static const Color _primary = Color(0xFF0392CA);
  static const Color _dark = Color(0xFF0D1B3E);
  static const Color _teal = Color(0xFF0A6E8A);

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final title = args?['title'] as String? ?? 'Cashback Earned';
    final body = args?['body'] as String? ??
        'You\'ve received \$12.50 cashback from your last purchase at Starbucks.';
    final iconData = args?['icon'] as IconData? ??
        Icons.account_balance_wallet_rounded;
    final iconBg =
        args?['iconBg'] as Color? ?? const Color(0xFFD6EEF8);
    final iconColor = args?['iconColor'] as Color? ?? _primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: Colors.black87, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notification Detail',
          style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _dark),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded,
                color: Colors.black87, size: 22),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Large icon circle
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconData, color: iconColor, size: 36),
                ),

                const SizedBox(height: 20),

                // Title
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                      height: 1.3),
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[500],
                      height: 1.5),
                ),

                const SizedBox(height: 28),

                // Details card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Merchant + Status row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('MERCHANT',
                                    style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[400],
                                        letterSpacing: 0.6)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Colors.green[700],
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.coffee_rounded,
                                          color: Colors.white, size: 18),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('Starbucks',
                                        style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: _dark)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('STATUS',
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[400],
                                      letterSpacing: 0.6)),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.green.withOpacity(0.1),
                                  borderRadius:
                                      BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle_rounded,
                                        color: Colors.green, size: 13),
                                    const SizedBox(width: 4),
                                    Text('Completed',
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      Divider(height: 24, color: Colors.grey[100]),

                      // Date + Transaction ID
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('DATE',
                                    style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[400],
                                        letterSpacing: 0.6)),
                                const SizedBox(height: 6),
                                Text('Today, 2:15 PM',
                                    style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: _dark)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('TRANSACTION ID',
                                    style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[400],
                                        letterSpacing: 0.6)),
                                const SizedBox(height: 6),
                                Text('TXN-90823412',
                                    style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: _dark)),
                              ],
                            ),
                          ),
                        ],
                      ),

                      Divider(height: 24, color: Colors.grey[100]),

                      // Category
                      Text('CATEGORY',
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[400],
                              letterSpacing: 0.6)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.coffee_rounded,
                              color: _primary, size: 18),
                          const SizedBox(width: 8),
                          Text('Food & Drink',
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _dark)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom buttons
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: const Color(0xFFF2F4F7),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/wallet'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _teal,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text('View Wallet',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.share_outlined,
                        color: _teal, size: 18),
                    label: Text('Share Transaction',
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _teal)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 54),
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildBottomNav(BuildContext context) => Container(
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
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(context, Icons.home_rounded, 'Home', '/home'),
                _navItem(context, Icons.explore_rounded, 'Explore',
                    '/nearby'),
                _navItem(context, Icons.account_balance_wallet_rounded,
                    'Wallet', '/wallet'),
                _navItemActive(),
                _navItem(context, Icons.person_rounded, 'Profile',
                    '/profile'),
              ],
            ),
          ),
        ),
      );

  Widget _navItem(BuildContext context, IconData icon, String label,
          String route) =>
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
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F3FB),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_rounded,
                color: _primary, size: 22),
            const SizedBox(width: 6),
            Text('Activity',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _primary)),
          ],
        ),
      );
}
