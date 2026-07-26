import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../services/user_service.dart';
import '../services/transaction_service.dart';
import '../services/message_service.dart';
import 'transfer_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  static const Color _primary = Color(0xFF0392CA);
  static const Color _dark = Color(0xFF0D1B3E);
  static const Color _green = Color(0xFF0A7A3E);
  static const Color _teal = Color(0xFF0A6E8A);

  // Tier — Starter by default
  static const String _tierName = 'Starter';

  double _balance = 0.0;
  double _cashbackBalance = 0.0;
  bool _loadingData = true;
  bool _cardAddedToWallet = false;
  List<Map<String, dynamic>> _transactions = [];

  // Static demo transactions shown when Firestore has no data yet
  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  double _monthCashback = 0.0;
  int _monthPartners = 0;
  double _monthTopUp = 0.0;

  Future<void> _loadAllData() async {
    try {
    final userData = await UserService().getCurrentUser();
    final firestoreTransactions = await TransactionService().getTransactions();

    if (!mounted) return;

    // Calculate this-month stats from real transactions
    final now = DateTime.now();
    final txList = firestoreTransactions;

    double monthCashback = 0.0;
    int monthPartners = 0;
    double monthTopUp = 0.0;

    for (final t in txList) {
      final month = t['month'] as String? ?? '';
      final isThisMonth = month.contains('${_monthName(now.month)}') && month.contains('${now.year}');
      if (!isThisMonth) continue;
      final type = t['type'] as String? ?? t['category'] as String? ?? '';
      final amount = (t['amountValue'] as num?)?.toDouble() ?? 0.0;
      if (type == 'Cashback') monthCashback += amount;
      if (type == 'Spending') monthPartners++;
      if (type == 'Top-Up') monthTopUp += amount;
    }

    setState(() {
      final raw = userData?['walletBalance'];
      _balance = raw is num ? raw.toDouble() : 0.0;

      final cb = userData?['cashbackBalance'];
      _cashbackBalance = cb is num ? cb.toDouble() : 0.0;

      _transactions = txList;
      _monthCashback = monthCashback;
      _monthPartners = monthPartners;
      _monthTopUp = monthTopUp;
      _cardAddedToWallet = userData?['cardAddedToWallet'] as bool? ?? false;
      _loadingData = false;
    });
    } catch (_) {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  String _monthName(int month) {
    const names = ['January','February','March','April','May','June',
      'July','August','September','October','November','December'];
    return names[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primary,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildBalanceCard(context),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: _loadingData
                    ? _buildShimmer()
                    : SingleChildScrollView(
                        padding: const EdgeInsets.only(top: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCashbackCard(),
                            const SizedBox(height: 20),
                            _buildSpendingSummary(),
                            const SizedBox(height: 20),
                            _buildRecentTransactions(context),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Shimmer loading placeholder ─────────────────────────
  Widget _buildShimmer() => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              // Cashback card placeholder
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 20),
              // Summary row placeholder
              Row(
                children: List.generate(3, (i) => Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: i < 2 ? 10 : 0),
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                )),
              ),
              const SizedBox(height: 20),
              // Transaction rows
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: List.generate(4, (i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(12))),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(height: 12, width: double.infinity,
                                color: Colors.grey[300]),
                            const SizedBox(height: 6),
                            Container(height: 10, width: 120,
                                color: Colors.grey[300]),
                          ],
                        )),
                        Container(height: 14, width: 60, color: Colors.grey[300]),
                      ],
                    ),
                  )),
                ),
              ),
            ],
          ),
        ),
      );

  // ── Header ──────────────────────────────────────────────
  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text(
              'My Wallet',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            // Tier badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _tierName,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
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
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.notifications_outlined,
                            color: Colors.white, size: 20),
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

  // ── Wallet Balance Card ──────────────────────────────────
  Widget _buildBalanceCard(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0392CA), Color(0xFF0A6E8A), Color(0xFF0D1B3E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D1B3E).withValues(alpha: 0.30),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Wallet Balance',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _tierName,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '£${_balance.toStringAsFixed(2)}',
              style: GoogleFonts.inter(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              '£${(500 - _balance).toStringAsFixed(2)} monthly limit remaining',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.65)),
            ),
            const SizedBox(height: 6),
            // Limit progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_balance / 500).clamp(0.0, 1.0),
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.pushNamed(context, '/add-funds');
                      if (result != null && result is Map) {
                        final total = (result['total'] as num).toDouble();
                        final bonus = (result['bonus'] as num).toDouble();
                        final hasBonus = result['hasBonus'] as bool;
                        final newBalance = _balance + total;
                        final txTitle = hasBonus
                            ? 'Wallet Top-Up (+£${bonus.toStringAsFixed(2)} bonus)'
                            : 'Wallet Top-Up';

                        // Save balance to Firestore
                        await UserService().updateUser({'walletBalance': newBalance});

                        // Save transaction to Firestore
                        await TransactionService().addTransaction(
                          title: txTitle,
                          amount: total,
                          amountFormatted: '+£${total.toStringAsFixed(2)}',
                          type: 'Top-Up',
                          iconKey: 'topup',
                          positive: true,
                          status: 'Completed',
                        );

                        setState(() {
                          _balance = newBalance;
                          _transactions.insert(0, {
                            'title': txTitle,
                            'date': 'Just now',
                            'amount': '+£${total.toStringAsFixed(2)}',
                            'category': 'Top-Up',
                            'icon': Icons.add_circle_outline_rounded,
                            'positive': true,
                            'cashback': false,
                          });
                        });
                      }
                    },
                    icon: const Icon(Icons.add_circle_outline_rounded,
                        color: _primary, size: 18),
                    label: Text(
                      'Add Funds',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _primary),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => TransferScreen(availableBalance: _balance),
                        )),
                    icon: Icon(Icons.share_rounded,
                        color: Colors.white.withValues(alpha: 0.9), size: 18),
                    label: Text(
                      'Share',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.4), width: 1),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_cardAddedToWallet) {
                    // Already added — show info popup
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 56, height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0A7A3E).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_circle_rounded,
                                  color: Color(0xFF0A7A3E), size: 32),
                            ),
                            const SizedBox(height: 16),
                            Text('Already Added',
                                style: GoogleFonts.inter(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0D1B3E))),
                            const SizedBox(height: 8),
                            Text(
                              'Your GoOuts Virtual Card is already added to your phone Wallet.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                  height: 1.5),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primary,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text('Got it',
                                    style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    Navigator.pushNamed(context, '/add-to-wallet',
                        arguments: 'fromWallet');
                  }
                },
                icon: Icon(
                  Platform.isIOS
                      ? Icons.apple_rounded
                      : Icons.account_balance_wallet_outlined,
                  color: Colors.white,
                  size: 18,
                ),
                label: Text(
                  Platform.isIOS
                      ? 'Add to Apple Wallet'
                      : 'Add to Google Wallet',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.4), width: 1),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      );

  // ── Cashback Balance Card ────────────────────────────────
  Widget _buildCashbackCard() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _green.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
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
                color: _green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_wallet_rounded,
                  color: _green, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cashback Balance',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '£${_cashbackBalance.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: _green),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _monthCashback > 0 ? '+£${_monthCashback.toStringAsFixed(2)} this month' : 'No cashback yet',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _green,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Use it anywhere',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      );

  // ── Spending Summary ────────────────────────────────────
  Widget _buildSpendingSummary() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'This Month',
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _dark),
                ),
                const Spacer(),
                Text(
                  'May 2026',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _summaryCard(
                    icon: Icons.savings_rounded,
                    iconColor: _green,
                    label: 'Cashback Earned',
                    value: '£${_monthCashback.toStringAsFixed(2)}',
                    valueColor: _green,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _summaryCard(
                    icon: Icons.store_rounded,
                    iconColor: _primary,
                    label: 'Partners Visited',
                    value: '$_monthPartners',
                    valueColor: _primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _summaryCard(
                    icon: Icons.add_circle_outline_rounded,
                    iconColor: _teal,
                    label: 'Total Top-Up',
                    value: '£${_monthTopUp.toStringAsFixed(0)}',
                    valueColor: _teal,
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _summaryCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
  }) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: valueColor),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.grey[500],
                  height: 1.3),
              maxLines: 2,
            ),
          ],
        ),
      );

  // ── Recent Transactions ─────────────────────────────────
  Widget _buildRecentTransactions(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Recent Activity',
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _dark),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () =>
                      Navigator.pushNamed(context, '/activity'),
                  child: Text(
                    'See All',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_transactions.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_rounded,
                        size: 40, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text(
                      'No transactions yet',
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Visit a GoOuts partner to earn your first cashback.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[400],
                          height: 1.5),
                    ),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Column(
                  children: _transactions.asMap().entries.map((entry) {
                    final i = entry.key;
                    final t = entry.value;
                    final isLast = i == _transactions.length - 1;
                    return Column(
                      children: [
                        _transactionRow(t),
                        if (!isLast)
                          Divider(
                              height: 1,
                              color: Colors.grey[100],
                              indent: 68,
                              endIndent: 16),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      );

  Widget _transactionRow(Map<String, dynamic> t) {
    final isCashback = t['cashback'] as bool? ?? false;
    final earnedCashback = t['earnedCashback'] as String?;
    final isPositive = t['positive'] as bool;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isCashback
                  ? _green.withValues(alpha: 0.1)
                  : const Color(0xFFE0F3FB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(t['icon'] as IconData,
                color: isCashback ? _green : _primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t['title'] as String,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _dark)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(t['date'] as String,
                        style: GoogleFonts.inter(
                            fontSize: 11, color: Colors.grey[500])),
                    if (earnedCashback != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$earnedCashback cashback',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _green,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                t['amount'] as String,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isPositive ? _green : _dark,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(t['category'] as String,
                    style: GoogleFonts.inter(
                        fontSize: 10, color: Colors.grey[500])),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Bottom Nav ──────────────────────────────────────────
  Widget _buildBottomNav() => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
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
                _navItem(Icons.home_rounded, 'Home', '/home'),
                _navItem(Icons.explore_rounded, 'Explore', '/explore'),
                _navItemActive(),
                _navItem(Icons.receipt_long_rounded, 'Activity',
                    '/activity'),
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
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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
