import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LinkCardScreen extends StatefulWidget {
  const LinkCardScreen({super.key});

  @override
  State<LinkCardScreen> createState() => _LinkCardScreenState();
}

class _LinkCardScreenState extends State<LinkCardScreen> {
  int _selectedOption = 0; // 0 = JIT Auto-Pay, 1 = Top-Up Wallet, 2 = Debit/Credit Card

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.black.withValues(alpha: 0.07),
            height: 1,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1A1A2E), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Link Payment Method',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1A2E),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Account created status card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0392CA), Color(0xFF0270A0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0392CA).withValues(alpha: 0.30),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.check_circle_rounded,
                                color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Account Created',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Registration Complete!',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Done',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Choose How to Pay',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pick how you want to pay and start earning cashback straight away.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF8A8A9A),
                        height: 1.45,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Option 1: JIT Auto-Pay (Recommended) ──
                    _PaymentOptionTile(
                      index: 0,
                      icon: Icons.account_balance_rounded,
                      title: 'Smart Pay',
                      subtitle: 'Link your bank and pay without topping up',
                      badge: 'Recommended',
                      badgeColor: const Color(0xFF0392CA),
                      isSelected: _selectedOption == 0,
                      onTap: () => setState(() => _selectedOption = 0),
                      highlight: true,
                      extraInfo: 'No top up ever needed. Funds are pulled from your bank at the exact moment you pay.',
                    ),

                    const SizedBox(height: 14),

                    // ── Option 2: Top-Up Wallet (+2% Bonus) ──
                    _PaymentOptionTile(
                      index: 1,
                      icon: Icons.wallet_rounded,
                      title: 'Top-Up Wallet',
                      subtitle: 'Load funds · earn instant bonus',
                      badge: '+2% Bonus',
                      badgeColor: const Color(0xFF00A651),
                      isSelected: _selectedOption == 1,
                      onTap: () => setState(() => _selectedOption = 1),
                      highlight: false,
                      extraInfo: 'We pass on our payment savings directly to you. Get 2% extra on every top up.',
                    ),

                    const SizedBox(height: 14),

                    // ── Option 3: Debit / Credit Card ──
                    _PaymentOptionTile(
                      index: 2,
                      icon: Icons.credit_card_rounded,
                      title: 'Debit or Credit Card',
                      subtitle: 'Pay directly with your existing card',
                      badge: 'Instant',
                      badgeColor: const Color(0xFF8A8A9A),
                      isSelected: _selectedOption == 2,
                      onTap: () => setState(() => _selectedOption = 2),
                      highlight: false,
                      extraInfo: 'Link your debit or credit card to fund your GoOuts Virtual Card directly.',
                    ),

                    const SizedBox(height: 20),

                    // Spending Tier info box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F8FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF0392CA).withValues(alpha: 0.18),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.shield_rounded,
                                  size: 16, color: Color(0xFF0392CA)),
                              const SizedBox(width: 8),
                              Text(
                                'Your Spending Limits',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1A1A2E),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _tierRow('🔵', 'Starter', 'Registered', '£500 / month', true),
                          const SizedBox(height: 8),
                          _tierRow('🟡', 'Member', 'Bank Linked', '£1,000 / month', false),
                          const SizedBox(height: 8),
                          _tierRow('🟢', 'Verified', 'KYC Complete', '£2,000 / month', false),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom section
            Container(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              color: Colors.white,
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      // Was three copies of pushNamed(...).then(...) that used
                      // `context` inside the callback without checking the
                      // widget was still mounted — popping a disposed screen
                      // throws. Collapsed into one awaited call with a
                      // context.mounted guard.
                      onPressed: () async {
                        final String route = _selectedOption == 0
                            ? '/link-bank'
                            : _selectedOption == 1
                                ? '/add-to-wallet'
                                : '/link-card-details';

                        final Object? result =
                            await Navigator.pushNamed(context, route);

                        if (!context.mounted) return;
                        if (result == true) Navigator.pop(context, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0392CA),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Continue',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tierRow(String emoji, String tier, String requirement,
      String limit, bool isActive) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$tier  ',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isActive
                        ? const Color(0xFF0392CA)
                        : const Color(0xFF8A8A9A),
                  ),
                ),
                TextSpan(
                  text: requirement,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF8A8A9A),
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF0392CA).withValues(alpha: 0.10)
                : const Color(0xFFF0F0F8),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            limit,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isActive
                  ? const Color(0xFF0392CA)
                  : const Color(0xFFAAAAAA),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Payment Option Tile ───────────────────────────────────────────────────────

class _PaymentOptionTile extends StatelessWidget {
  final int index;
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final bool isSelected;
  final bool highlight;
  final String extraInfo;
  final VoidCallback onTap;

  const _PaymentOptionTile({
    required this.index,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.isSelected,
    required this.highlight,
    required this.extraInfo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0392CA)
                : highlight
                    ? const Color(0xFF0392CA).withValues(alpha: 0.25)
                    : const Color(0xFFE8E8F0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF0392CA).withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF0392CA).withValues(alpha: 0.10)
                        : const Color(0xFFF0F0F8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon,
                      color: isSelected
                          ? const Color(0xFF0392CA)
                          : const Color(0xFF8A8A9A),
                      size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              badge,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF8A8A9A),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF0392CA)
                          : const Color(0xFFD0D0E0),
                      width: 2,
                    ),
                    color: isSelected
                        ? const Color(0xFF0392CA)
                        : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 13, color: Colors.white)
                      : null,
                ),
              ],
            ),
            // Extra info shown when selected
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: isSelected
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0392CA).withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                size: 14, color: Color(0xFF0392CA)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                extraInfo,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFF0392CA),
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
