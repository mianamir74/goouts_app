import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _receiverController = TextEditingController();
  final _amountController = TextEditingController();
  double _amount = 0;

  static const Color _primary = Color(0xFF0392CA);
  static const Color _dark = Color(0xFF0D1B3E);
  static const Color _teal = Color(0xFF0A6E8A);
  static const Color _green = Color(0xFF0A7A3E);

  @override
  void dispose() {
    _receiverController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _primary, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'One-Click Share',
          style: GoogleFonts.inter(
              fontSize: 18, fontWeight: FontWeight.w700, color: _primary),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded,
                color: Colors.grey, size: 22),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Illustration card ─────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0392CA), Color(0xFF0A6E8A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Sender avatar
                          Column(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.person_rounded,
                                    color: Colors.white, size: 28),
                              ),
                              const SizedBox(height: 8),
                              Text('You',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                            ],
                          ),
                          // Arrow + amount
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _amount > 0
                                        ? '£${_amount.toStringAsFixed(2)}'
                                        : '£0.00',
                                    style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: List.generate(
                                    3,
                                    (i) => Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: Icon(Icons.arrow_forward_rounded,
                                          color: Colors.white
                                              .withOpacity(0.4 + i * 0.2),
                                          size: 18),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Receiver avatar
                          Column(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.person_rounded,
                                    color: Colors.white, size: 28),
                              ),
                              const SizedBox(height: 8),
                              Text('Friend',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt_rounded,
                                color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'Instant · Secure · Free',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Available Balance card ────────────────────
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
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F3FB),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: _primary,
                            size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Available Balance',
                              style: GoogleFonts.inter(
                                  fontSize: 14, color: Colors.grey[500]),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '£247.60',
                              style: GoogleFonts.inter(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: _dark),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Ready',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _green),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Single unified input card ─────────────────
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Column(
                    children: [

                      // ── To field ──────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'To',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[400],
                                  letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0F3FB),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                      Icons.person_search_rounded,
                                      color: _primary,
                                      size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _receiverController,
                                    decoration: InputDecoration(
                                      hintText:
                                          'Mobile number or GoOuts card number',
                                      hintStyle: GoogleFonts.inter(
                                          fontSize: 15,
                                          color: Colors.grey[400]),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: const EdgeInsets.fromLTRB(10, 18, 0, 18),
                                      isDense: true,
                                    ),
                                    style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: _dark),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                          ],
                        ),
                      ),

                      Divider(height: 1, color: Colors.grey[100]),

                      // ── Amount field ──────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Amount',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[400],
                                  letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0F3FB),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '£',
                                      style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: _primary),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _amountController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    onChanged: (v) => setState(
                                        () => _amount = double.tryParse(v) ?? 0),
                                    decoration: InputDecoration(
                                      hintText: '0.00',
                                      hintStyle: GoogleFonts.inter(
                                          fontSize: 15,
                                          color: Colors.grey[400]),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: const EdgeInsets.fromLTRB(10, 18, 0, 18),
                                      isDense: true,
                                    ),
                                    style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: _dark),
                                  ),
                                ),
                                if (_amount > 0)
                                  GestureDetector(
                                    onTap: () {
                                      _amountController.clear();
                                      setState(() => _amount = 0);
                                    },
                                    child: Icon(Icons.cancel_rounded,
                                        color: Colors.grey[300], size: 20),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Info box ──────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F3FB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.notifications_active_rounded,
                            color: _primary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Instant notification sent',
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _dark),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your friend will get a push notification and SMS the moment the share goes through.',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                  height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom CTA ────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: const Color(0xFFF2F4F7),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: ElevatedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, '/transfer-success'),
                icon: const Icon(Icons.bolt_rounded,
                    color: Colors.white, size: 22),
                label: Text(
                  'Share Instantly',
                  style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

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
                _navItem(Icons.explore_rounded, 'Explore', '/explore'),
                _navItemActive(),
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
                style:
                    GoogleFonts.inter(fontSize: 11, color: Colors.grey[400])),
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
            const Icon(Icons.account_balance_wallet_rounded,
                color: _primary, size: 22),
            const SizedBox(width: 6),
            Text(
              'Wallet',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _primary),
            ),
          ],
        ),
      );
}
