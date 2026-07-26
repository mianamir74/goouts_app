import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/goouts_sheet.dart';

const Color _primary          = Color(0xFF0392CA);
const Color _surfaceColor     = Color(0xFFF9F9FC);
const Color _onSurface        = Color(0xFF191C1E);
const Color _onSurfaceVariant = Color(0xFF42474E);
const Color _successGreen     = Color(0xFF0A7A3E);
const Color _successContainer = Color(0xFFE8F5E9);

class NotificationDetailScreen extends StatelessWidget {
  const NotificationDetailScreen({super.key});

  // ── Icon/colour helpers ───────────────────────────────────────────────────
  static IconData _iconFor(String type) {
    switch (type) {
      case 'kyc_approved':  return Icons.verified_outlined;
      case 'kyc_rejected':  return Icons.security_outlined;
      case 'ticket_reply':  return Icons.chat_outlined;
      case 'ticket_status': return Icons.support_agent_outlined;
      case 'cashback':      return Icons.account_balance_wallet_outlined;
      case 'transaction':   return Icons.receipt_long_outlined;
      case 'security':      return Icons.shield_outlined;
      default:              return Icons.notifications_none_outlined;
    }
  }

  static Color _iconBgFor(String type) {
    switch (type) {
      case 'kyc_approved':  return const Color(0xFFE8F5E9);
      case 'kyc_rejected':
      case 'security':      return const Color(0xFFFFEBEE);
      case 'ticket_reply':
      case 'cashback':      return const Color(0xFFE1F5FE);
      case 'ticket_status': return const Color(0xFFEDE7F6);
      case 'transaction':   return const Color(0xFFF5F5F5);
      default:              return const Color(0xFFF5F5F5);
    }
  }

  static Color _iconColorFor(String type) {
    switch (type) {
      case 'kyc_approved':  return _successGreen;
      case 'kyc_rejected':
      case 'security':      return const Color(0xFFC62828);
      case 'ticket_reply':
      case 'cashback':      return _primary;
      case 'ticket_status': return const Color(0xFF6A1B9A);
      default:              return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final args   = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    final type   = (args['type']  ?? '').toString();
    final title  = (args['title'] ?? 'Notification').toString();
    final body   = (args['body']  ?? '').toString();
    final data   = Map<String, dynamic>.from(args['data'] as Map? ?? {});

    // Extra fields for cashback/transaction
    final merchant      = (data['merchant']      ?? args['merchant']      ?? '').toString();
    final transactionId = (data['transactionId'] ?? args['transactionId'] ?? '').toString();
    final amount        = (data['amount']        ?? args['amount']        ?? '').toString();
    final category      = (data['category']      ?? args['category']      ?? '').toString();
    final status        = (data['status']        ?? args['status']        ?? 'Completed').toString();
    final dateLabel     = (data['dateLabel']     ?? args['dateLabel']     ?? '').toString();

    final icon      = _iconFor(type);
    final iconBg    = _iconBgFor(type);
    final iconColor = _iconColorFor(type);

    return Scaffold(
      backgroundColor: _surfaceColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text('Notification Detail',
          style: GoogleFonts.inter(fontSize: 20,
              fontWeight: FontWeight.bold, color: _onSurface)),
        actions: [
          if (transactionId.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy_outlined, color: _onSurface, size: 20),
              tooltip: 'Copy transaction ID',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: transactionId));
                GoOutsSheet.success(context,
                  title: 'Copied!',
                  message: 'Copied: $transactionId',
                );
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                // ── Icon header ─────────────────────────────────────────────
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                      color: iconBg, shape: BoxShape.circle),
                  child: Icon(icon, color: iconColor, size: 48),
                ),
                const SizedBox(height: 32),

                Text(title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: _onSurface, height: 1.2)),
                const SizedBox(height: 12),

                Text(body,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 16,
                      color: _onSurfaceVariant, height: 1.5)),

                const SizedBox(height: 40),

                // ── Detail card (shown for cashback / transaction) ──────────
                if (merchant.isNotEmpty || transactionId.isNotEmpty)
                  _buildDetailCard(
                    merchant: merchant,
                    transactionId: transactionId,
                    amount: amount,
                    category: category,
                    status: status,
                    dateLabel: dateLabel,
                  ),

                const SizedBox(height: 60),

                // ── Action buttons ──────────────────────────────────────────
                ..._buildActions(context, type, data),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  // ── Detail card ────────────────────────────────────────────────────────────
  Widget _buildDetailCard({
    required String merchant,
    required String transactionId,
    required String amount,
    required String category,
    required String status,
    required String dateLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 20, offset: const Offset(0, 10)),
        ],
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          // Merchant row
          if (merchant.isNotEmpty) ...[
            _detailRow(
              label: 'MERCHANT',
              child: Text(merchant,
                style: GoogleFonts.inter(fontWeight: FontWeight.bold,
                    color: _onSurface, fontSize: 16)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: _successContainer,
                    borderRadius: BorderRadius.circular(20)),
                child: Row(children: [
                  const Icon(Icons.check_circle,
                      color: _successGreen, size: 14),
                  const SizedBox(width: 4),
                  Text(status.isNotEmpty ? status : 'Completed',
                    style: GoogleFonts.inter(color: _successGreen,
                        fontWeight: FontWeight.bold, fontSize: 12)),
                ]),
              ),
            ),
            const Divider(height: 48),
          ],

          // Date + Transaction ID
          if (transactionId.isNotEmpty) ...[
            _detailRow(
              label: 'DATE',
              child: Text(dateLabel.isNotEmpty ? dateLabel : 'Today',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600,
                    color: _onSurface, fontSize: 15)),
              trailing: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('TRANSACTION ID',
                    style: GoogleFonts.inter(fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _onSurfaceVariant.withValues(alpha: 0.6),
                        letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text(transactionId,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600,
                        color: _onSurface, fontSize: 14)),
                ],
              ),
            ),
            const Divider(height: 48),
          ],

          // Category
          if (category.isNotEmpty)
            _detailRow(
              label: 'CATEGORY',
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: const Color(0xFFE0F2F1),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.local_cafe,
                      color: Color(0xFF00796B), size: 18),
                ),
                const SizedBox(width: 12),
                Text(category,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600,
                      color: _onSurface, fontSize: 15)),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _detailRow({required String label, required Widget child, Widget? trailing}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold,
              color: _onSurfaceVariant.withValues(alpha: 0.6), letterSpacing: 0.5)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            child,
            if (trailing != null) trailing,
          ],
        ),
      ],
    );
  }

  // ── Action buttons per type ────────────────────────────────────────────────
  List<Widget> _buildActions(BuildContext context, String type, Map<String, dynamic> data) {
    switch (type) {
      case 'cashback':
      case 'transaction':
        return [
          _primaryBtn('View Wallet',
            () => Navigator.pushNamed(context, '/wallet')),
          const SizedBox(height: 16),
          _outlineBtn(Icons.share_outlined, 'Share Transaction', () {}),
        ];
      case 'kyc_rejected':
        return [
          _primaryBtn('Complete Verification',
            () => Navigator.pushNamed(context, '/kyc')),
        ];
      case 'kyc_approved':
        return [
          _primaryBtn('View Profile',
            () => Navigator.pushNamed(context, '/profile')),
        ];
      case 'security':
        return [
          _primaryBtn('Secure My Account',
            () => Navigator.pushNamed(context, '/profile-security')),
        ];
      default:
        return [
          _primaryBtn('Done', () => Navigator.pop(context)),
        ];
    }
  }

  Widget _primaryBtn(String label, VoidCallback onTap) => SizedBox(
    width: double.infinity, height: 60,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary, foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(label, style: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.bold)),
    ),
  );

  Widget _outlineBtn(IconData icon, String label, VoidCallback onTap) => SizedBox(
    width: double.infinity, height: 60,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: _onSurface.withValues(alpha: 0.1)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: _primary, size: 20),
        const SizedBox(width: 12),
        Text(label, style: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.bold, color: _primary)),
      ]),
    ),
  );

  // ── Bottom nav (Stitch style) ─────────────────────────────────────────────
  Widget _buildBottomNav(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Colors.grey[200]!)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _navItem(context, Icons.home_outlined,                   'Home',     '/home',     false),
        _navItem(context, Icons.explore_outlined,                'Explore',  '/explore',  false),
        _navItem(context, Icons.account_balance_wallet_outlined, 'Wallet',   '/wallet',   false),
        _navItem(context, Icons.receipt_long_outlined,           'Activity', '/activity', true),
        _navItem(context, Icons.person_outline,                  'Profile',  '/profile',  false),
      ],
    ),
  );

  Widget _navItem(BuildContext ctx, IconData icon, String label,
      String route, bool isActive) {
    if (isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFFE1F5FE),
            borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          Icon(icon, color: _primary, size: 20),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.inter(
              color: _primary, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
      );
    }
    return GestureDetector(
      onTap: () => Navigator.pushNamed(ctx, route),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: _onSurfaceVariant, size: 24),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(
            color: _onSurfaceVariant, fontSize: 11)),
      ]),
    );
  }
}
