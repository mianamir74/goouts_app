import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const Color _primary = Color(0xFF0392CA);
  static const Color _dark = Color(0xFF0D1B3E);

  final List<Map<String, dynamic>> _today = [
    {
      'title': 'Cashback Earned',
      'body': 'You\'ve received £12.50 cashback from your last purchase at Artisan Brews.',
      'time': '2m ago',
      'icon': Icons.account_balance_wallet_rounded,
      'iconBg': Color(0xFFD6EEF8),
      'iconColor': Color(0xFF0392CA),
      'unread': true,
    },
    {
      'title': 'Security Alert',
      'body': 'New login detected from a Chrome browser on a Linux device in Berlin.',
      'time': '1h ago',
      'icon': Icons.shield_rounded,
      'iconBg': Color(0xFFFFEBEE),
      'iconColor': Color(0xFFE53935),
      'unread': true,
    },
    {
      'title': 'New Feature Available',
      'body': 'Try our new AI-powered spending insights today and save more effectively!',
      'time': '4h ago',
      'icon': Icons.rocket_launch_rounded,
      'iconBg': Color(0xFFD6EEF8),
      'iconColor': Color(0xFF0392CA),
      'unread': false,
    },
  ];

  final List<Map<String, dynamic>> _yesterday = [
    {
      'title': 'Bill Payment\nSuccessful',
      'body': 'Your electricity bill for August has been paid automatically.',
      'time': 'Yesterday, 4:12 PM',
      'icon': Icons.receipt_long_rounded,
      'iconBg': Color(0xFFF0F0F0),
      'iconColor': Colors.grey,
      'unread': false,
    },
    {
      'title': 'Referral Accepted',
      'body': 'Sarah J. joined GoOuts using your code. You\'ve earned a £5 bonus!',
      'time': 'Yesterday, 10:05 AM',
      'icon': Icons.person_add_rounded,
      'iconBg': Color(0xFFF0F0F0),
      'iconColor': Colors.grey,
      'unread': false,
    },
  ];

  int get _unreadCount =>
      [..._today, ..._yesterday].where((n) => n['unread'] == true).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TODAY
                    Row(
                      children: [
                        _sectionLabel('TODAY'),
                        const Spacer(),
                        if (_unreadCount > 0)
                          GestureDetector(
                            onTap: () => setState(() {
                              for (var n in _today) n['unread'] = false;
                              for (var n in _yesterday) n['unread'] = false;
                            }),
                            child: Text(
                              'Mark all as read',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _primary),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._today.map((n) => _notifCard(n, context)),

                    const SizedBox(height: 16),

                    // YESTERDAY
                    _sectionLabel('YESTERDAY'),
                    const SizedBox(height: 8),
                    ..._yesterday.map((n) => _notifCard(n, context)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          children: [
            // App bar row
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 6)
                      ],
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.black87, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Notifications',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _dark,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/messages'),
                  child: Stack(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 6)
                          ],
                        ),
                        child: const Icon(Icons.notifications_rounded,
                            color: Colors.black87, size: 22),
                      ),
                      if (_unreadCount > 0)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle),
                          child: Center(
                            child: Text('$_unreadCount',
                                style: GoogleFonts.inter(
                                    fontSize: 10,
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
          ],
        ),
      );

  Widget _sectionLabel(String label) => Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey[500],
          letterSpacing: 1.0,
        ),
      );

  Widget _notifCard(Map<String, dynamic> n, BuildContext context) =>
      GestureDetector(
        onTap: () =>
            Navigator.pushNamed(context, '/notification-detail', arguments: n),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: (n['unread'] as bool)
                ? const Color(0xFFE8F4FB)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: (n['unread'] as bool)
                ? Border.all(color: _primary.withOpacity(0.15))
                : null,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon circle
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: n['iconBg'] as Color,
                  shape: BoxShape.circle,
                ),
                child: Icon(n['icon'] as IconData,
                    color: n['iconColor'] as Color, size: 20),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            n['title'] as String,
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _dark),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            Text(
                              n['time'] as String,
                              style: GoogleFonts.inter(
                                  fontSize: 11, color: Colors.grey[400]),
                            ),
                            if (n['unread'] as bool) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                    color: _primary, shape: BoxShape.circle),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      n['body'] as String,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey[500],
                          height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

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
                _navItem(context, Icons.explore_rounded, 'Explore', '/explore'),
                _navItem(context, Icons.account_balance_wallet_rounded, 'Wallet', '/wallet'),
                _navItem(context, Icons.receipt_long_rounded, 'Activity', '/activity'),
                _navItem(context, Icons.person_rounded, 'Profile', '/profile'),
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

}
