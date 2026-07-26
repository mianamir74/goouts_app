import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TransferSuccessScreen extends StatelessWidget {
  const TransferSuccessScreen({super.key});

  static const Color _primary = Color(0xFF0392CA);
  static const Color _dark = Color(0xFF0D1B3E);
  static const Color _teal = Color(0xFF0A6E8A);

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final amount = args?['amount'] as String? ?? '£150.00';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded,
              color: Colors.black87, size: 24),
          onPressed: () =>
              Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false),
        ),
        title: Text(
          'Transfer Status',
          style: GoogleFonts.inter(
              fontSize: 18, fontWeight: FontWeight.w700, color: _primary),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),

            // Success circle with glow
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(
                    color: _teal,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 36),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Title
            Text(
              '$amount Sent Successfully',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _dark),
            ),
            const SizedBox(height: 8),
            Text(
              'Your transfer is complete and processed.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13, color: Colors.grey[500]),
            ),

            const SizedBox(height: 24),

            // Details card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
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
                children: [
                  _detailRow(
                    'RECEIVER',
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: _primary.withValues(alpha: 0.15),
                          child: const Icon(Icons.person_rounded,
                              color: _primary, size: 14),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Sarah Jenkins',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _dark),
                        ),
                      ],
                    ),
                  ),
                  _divider(),
                  _detailRow(
                    'CARD NUMBER',
                    Text(
                      '**** 5678',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _dark),
                    ),
                  ),
                  _divider(),
                  _detailRow(
                    'DATE',
                    Text(
                      'Today, 2:45 PM',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _dark),
                    ),
                  ),
                  _divider(),
                  _detailRow(
                    'TRANSACTION ID',
                    Text(
                      'TXN-82741092',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _primary),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Info box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFD6EEF8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: _primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sarah will receive a notification and SMS instantly.',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey[700],
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Back to Home button
            ElevatedButton(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context, '/home', (_) => false),
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text(
                'Back to Home',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
            ),

            const SizedBox(height: 12),

            // Share Receipt outlined button
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.share_outlined,
                  color: Colors.grey, size: 18),
              label: Text(
                'Share Receipt',
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700]),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
                side: BorderSide(color: Colors.grey[300]!),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, Widget valueWidget) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[400],
                  letterSpacing: 0.6),
            ),
            const Spacer(),
            valueWidget,
          ],
        ),
      );

  Widget _divider() =>
      Divider(height: 1, color: Colors.grey[100]);
}
