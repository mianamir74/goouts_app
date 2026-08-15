import 'dart:async';   // TimeoutException, for the top-up timeout below
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';   // FieldValue.increment
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/user_service.dart';
import '../services/transaction_service.dart';
import '../widgets/goouts_sheet.dart';

class AddFundsScreen extends StatefulWidget {
  const AddFundsScreen({super.key});

  @override
  State<AddFundsScreen> createState() => _AddFundsScreenState();
}

class _AddFundsScreenState extends State<AddFundsScreen> {
  int _selectedAmount = 25;
  bool _isCustom = false;
  int _selectedMethod = 0;
  bool _isLoading = false;

  static const Color _primary = Color(0xFF0392CA);
  static const Color _dark = Color(0xFF0D1B3E);
  static const Color _teal = Color(0xFF0A6E8A);
  static const Color _green = Color(0xFF0A7A3E);

  // Current tier — Starter by default (no backend yet)
  static const String _tierName = 'Starter';
  static const int _tierMax = 500;

  final List<int> _quickAmounts = [25, 50, 100, 250];

  // Detect device wallet — Apple Pay on iOS, Google Pay on Android
  bool get _isIOS => Platform.isIOS;
  String get _walletLabel => _isIOS ? 'Apple Pay' : 'Google Pay';
  IconData get _walletIcon =>
      _isIOS ? Icons.apple_rounded : Icons.g_mobiledata_rounded;

  // Methods — Bank Deposit first (recommended), then device wallet, then card
  List<Map<String, dynamic>> get _methods => [
        {
          'title': 'Bank Transfer',
          'subtitle': 'Instant via Faster Payments',
          'icon': Icons.account_balance_rounded,
          'badge': 'Recommended',
          'badgeColor': _green,
          'fee': null, // free
          'bonus': true,
        },
        {
          'title': _walletLabel,
          'subtitle': _isIOS ? 'Pay with Face ID or Touch ID' : 'Pay with fingerprint or PIN',
          'icon': _walletIcon,
          'badge': 'No 2% Bonus',
          'badgeColor': const Color(0xFF8A8A9A),
          'fee': '1.4% + 20p fee',
          'bonus': false,
        },
        {
          'title': 'Debit or Credit Card',
          'subtitle': 'Visa, Mastercard accepted',
          'icon': Icons.credit_card_rounded,
          'badge': 'No 2% Bonus',
          'badgeColor': const Color(0xFF8A8A9A),
          'fee': '1.4% + 20p fee',
          'bonus': false,
        },
      ];

  void _openCustomAmount() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Enter Your Amount',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F3FB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 15, color: _primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your $_tierName tier allows up to £$_tierMax per month. Link your bank to unlock higher limits.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _primary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text(
                        '£',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: _dark,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        autofocus: true,
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: _dark,
                        ),
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 22,
                            color: Colors.grey[400],
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Maximum: £$_tierMax',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    final val = int.tryParse(controller.text) ?? 0;
                    if (val <= 0) return;
                    final capped = val > _tierMax ? _tierMax : val;
                    setState(() {
                      _selectedAmount = capped;
                      _isCustom = true;
                    });
                    Navigator.pop(context);
                    if (val > _tierMax) {
                      GoOutsSheet.info(context,
                        title: 'Amount Adjusted',
                        message: 'Capped at £$_tierMax — your $_tierName tier limit.',
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Confirm Amount',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// How long to wait on any single Firestore call before giving up.
  ///
  /// This is the fix for the frozen sheet. A Firestore write future does NOT
  /// complete until the server acknowledges it. On a dropped or flaky
  /// connection it neither completes nor throws — it simply hangs forever. So
  /// `_isLoading` stayed true, the Confirm button stayed disabled, the spinner
  /// stayed up, and nothing ever reached Crashlytics because nothing crashed.
  static const Duration _netTimeout = Duration(seconds: 20);

  Future<void> _confirmTopUp(
      double totalAmount, double bonusAmount, bool hasBonus) async {
    setState(() => _isLoading = true);

    // Declared out here so `finally` can always clear the loading state,
    // whatever happens in between.
    bool succeeded = false;
    double newBalance = 0.0;
    String? errorTitle;
    String? errorMessage;

    try {
      final userData =
          await UserService().getCurrentUser().timeout(_netTimeout);
      final double currentBalance =
          (userData?['walletBalance'] as num?)?.toDouble() ?? 0.0;
      newBalance = currentBalance + totalAmount;

      // FieldValue.increment, NOT `currentBalance + totalAmount` written back.
      //
      // The old code read the balance, added to it, and wrote the result. If
      // cashback landed in the gap between the read and the write, the write
      // overwrote it and that cashback was gone with no trace. increment is
      // applied by the server against whatever the balance is at that moment.
      //
      // newBalance above is now only used to show a figure on the success
      // sheet. It is an estimate, not the source of truth.
      await UserService()
          .updateUser({'walletBalance': FieldValue.increment(totalAmount)})
          .timeout(_netTimeout);

      final String label =
          hasBonus ? 'Wallet Top-Up (+2% bonus)' : 'Wallet Top-Up';
      await TransactionService().addTransaction(
        title: label,
        amount: totalAmount,
        amountFormatted: '+£${totalAmount.toStringAsFixed(2)}',
        type: 'Top-Up',
        iconKey: 'topup',
        positive: true,
        status: 'Completed',
      ).timeout(_netTimeout);

      succeeded = true;
    } on TimeoutException {
      // A timeout does NOT mean the top-up failed. Firestore may still deliver
      // the write once the connection recovers, so telling the user "Payment
      // Failed" here would be a lie that could make them top up twice.
      errorTitle = 'Taking Longer Than Expected';
      errorMessage = 'We could not confirm your top-up. Check your wallet '
          'balance before trying again — it may already have gone through.';
    } catch (_) {
      errorTitle = 'Payment Failed';
      errorMessage = 'Something went wrong. Please try again.';
    } finally {
      // ALWAYS clears the button, on every path.
      //
      // The old code called setState in both the try and the catch with no
      // mounted guard. If the State was disposed mid-await, the setState in
      // the try threw, the catch caught it, and the setState in the catch
      // threw again — that second one uncaught.
      if (mounted) setState(() => _isLoading = false);
    }

    if (!mounted) return;

    if (succeeded) {
      await _showSuccessSheet(totalAmount, bonusAmount, hasBonus, newBalance);
    } else {
      GoOutsSheet.error(context,
        title: errorTitle ?? 'Payment Failed',
        message: errorMessage ?? 'Something went wrong. Please try again.',
      );
    }
  }

  Future<void> _showSuccessSheet(
      double totalAmount, double bonusAmount, bool hasBonus, double newBalance) async {
    await showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Green checkmark circle
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF0A7A3E).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF0A7A3E), size: 44),
            ),
            const SizedBox(height: 16),
            Text(
              'Wallet Topped Up!',
              style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0D1B3E)),
            ),
            const SizedBox(height: 6),
            Text(
              'Your funds have been added successfully.',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // Summary box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _summaryRow('Amount Added', '£${_selectedAmount.toStringAsFixed(2)}'),
                  if (hasBonus) ...[
                    const SizedBox(height: 8),
                    _summaryRow('2% Bonus', '+£${bonusAmount.toStringAsFixed(2)}',
                        valueColor: const Color(0xFF0A7A3E)),
                  ],
                  const Divider(height: 20, color: Color(0xFFDDE1E9)),
                  _summaryRow(
                    'Total Added',
                    '+£${totalAmount.toStringAsFixed(2)}',
                    bold: true,
                    valueColor: const Color(0xFF0A7A3E),
                  ),
                  const SizedBox(height: 8),
                  _summaryRow(
                    'New Wallet Balance',
                    '£${newBalance.toStringAsFixed(2)}',
                    bold: true,
                  ),
                ],
              ),
            ),
            if (hasBonus) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A7A3E).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFF0A7A3E), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '2% Bank Transfer bonus applied — keep using Bank Transfer to maximise your wallet!',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF0A7A3E),
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // close sheet
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      Navigator.pop(context, {
                        'total': totalAmount,
                        'base': _selectedAmount.toDouble(),
                        'bonus': bonusAmount,
                        'hasBonus': hasBonus,
                        'newBalance': newBalance,
                      });
                    }
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0392CA),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'Back to Wallet',
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value,
      {bool bold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400)),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                color: valueColor ?? const Color(0xFF0D1B3E))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final methods = _methods;
    final selectedBonus = methods[_selectedMethod]['bonus'] as bool;
    final double bonusAmount = selectedBonus ? _selectedAmount * 0.02 : 0.0;
    final double totalAmount = _selectedAmount + bonusAmount;

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
          'Add Funds',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _primary,
          ),
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Amount display card ────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AMOUNT TO ADD',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[500],
                            letterSpacing: 1.0),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('£',
                              style: GoogleFonts.inter(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: _dark)),
                          const SizedBox(width: 4),
                          Text(
                            '$_selectedAmount.00',
                            style: GoogleFonts.inter(
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                color: _dark),
                          ),
                          if (_isCustom) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('Custom',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _primary,
                                  )),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '$_tierName tier · up to £$_tierMax / month',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: Colors.grey[500]),
                          ),
                          if (selectedBonus) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '+2% bonus applies',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _green,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (selectedBonus) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _green.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _green.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('You add',
                                      style: GoogleFonts.inter(
                                          fontSize: 13, color: Colors.grey[600])),
                                  Text('£${_selectedAmount.toStringAsFixed(2)}',
                                      style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _dark)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('2% Bank Transfer Bonus',
                                      style: GoogleFonts.inter(
                                          fontSize: 13, color: _green)),
                                  Text('+£${bonusAmount.toStringAsFixed(2)}',
                                      style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _green)),
                                ],
                              ),
                              const Divider(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Total added to wallet',
                                      style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: _dark)),
                                  Text('£${totalAmount.toStringAsFixed(2)}',
                                      style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: _green)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── Quick amount pills ─────────────────────────────
                Row(
                  children: _quickAmounts.map((amount) {
                    final selected = _selectedAmount == amount && !_isCustom;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedAmount = amount;
                          _isCustom = false;
                        }),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: selected
                                ? _teal
                                : const Color(0xFFD6EEF8),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              '£$amount',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: selected ? Colors.white : _primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 10),

                // ── Other amount ───────────────────────────────────
                GestureDetector(
                  onTap: _openCustomAmount,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: _isCustom ? _teal : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isCustom
                            ? _teal
                            : _primary.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_rounded,
                            size: 15,
                            color: _isCustom ? Colors.white : _primary),
                        const SizedBox(width: 7),
                        Text(
                          _isCustom
                              ? 'Custom: £$_selectedAmount  (tap to change)'
                              : 'Other Amount  (max £$_tierMax)',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _isCustom ? Colors.white : _primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Payment Method header ──────────────────────────
                Text(
                  'How would you like to pay?',
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _dark),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bank Transfer keeps your 2% top-up bonus intact — no processing fees.',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: Colors.grey[500], height: 1.4),
                ),
                const SizedBox(height: 14),

                // ── Payment method tiles ───────────────────────────
                ...methods.asMap().entries.map((entry) {
                  final i = entry.key;
                  final m = entry.value;
                  final selected = _selectedMethod == i;
                  final badge = m['badge'] as String?;
                  final badgeColor = m['badgeColor'] as Color? ?? _primary;
                  final fee = m['fee'] as String?;
                  final hasBonus = m['bonus'] as bool;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedMethod = i),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected ? _primary : Colors.grey[200]!,
                          width: selected ? 1.5 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: selected
                                  ? _primary.withValues(alpha: 0.1)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(m['icon'] as IconData,
                                color: selected ? _primary : Colors.grey[500],
                                size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      m['title'] as String,
                                      style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: _dark),
                                    ),
                                    if (badge != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: badgeColor.withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(6),
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
                                    if (hasBonus) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _green.withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '+2% Bonus',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: _green,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  m['subtitle'] as String,
                                  style: GoogleFonts.inter(
                                      fontSize: 12, color: Colors.grey[500]),
                                ),
                                if (fee != null) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    fee,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.orange[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Icon(
                            selected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: selected ? _primary : Colors.grey[300],
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 14),

                // ── Tier upgrade nudge ─────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6EEF8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.trending_up_rounded,
                            color: _primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Want a higher limit?',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _dark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Link your bank for £1,000 per month or complete verification for £2,000 per month.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey[600],
                                height: 1.4,
                              ),
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

          // ── Bottom button ──────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: const Color(0xFFF2F4F7),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!selectedBonus)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 13, color: Colors.orange),
                          const SizedBox(width: 5),
                          Text(
                            'Processing fee applies. Switch to Bank Transfer for your 2% bonus.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () => _confirmTopUp(totalAmount, bonusAmount, selectedBonus),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Icon(Icons.add_circle_outline_rounded,
                              color: Colors.white, size: 20),
                      label: Text(
                        _isLoading
                            ? 'Processing...'
                            : selectedBonus
                                ? 'Add £${totalAmount.toStringAsFixed(2)} to Wallet'
                                : 'Add £$_selectedAmount to Wallet',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isLoading ? _teal.withValues(alpha: 0.6) : _teal,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
