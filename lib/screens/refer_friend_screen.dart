import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/referral_service.dart';
import '../widgets/goouts_sheet.dart';

class ReferFriendScreen extends StatefulWidget {
  const ReferFriendScreen({super.key});

  @override
  State<ReferFriendScreen> createState() => _ReferFriendScreenState();
}

class _ReferFriendScreenState extends State<ReferFriendScreen> {
  static const Color _primary   = Color(0xFF0392CA);
  static const Color _dark      = Color(0xFF0D1B3E);
  static const Color _green     = Color(0xFF10B981);
  static const Color _bgLight   = Color(0xFFF6FAFF);

  final _referralService = ReferralService();

  String?               _inviteCode;
  Map<String, dynamic>? _stats;
  bool                  _loading = true;
  bool                  _copied  = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final code  = await _referralService.getMyInviteCode();
    final stats = await _referralService.getReferralStats();
    if (mounted) {
      setState(() {
        _inviteCode = code;
        _stats      = stats;
        _loading    = false;
      });
    }
  }

  void _copyCode() {
    if (_inviteCode == null) return;
    Clipboard.setData(ClipboardData(text: _inviteCode!));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _shareCode() async {
    if (_inviteCode == null) return;
    final message = Uri.encodeComponent(
      '🎉 Hey! Join GoOuts with my invite code *$_inviteCode* and earn real cashback every time you shop or eat out! 💳\n\nDownload the app: https://goouts.co.uk',
    );
    final url = Uri.parse('https://wa.me/?text=$message');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      // Fallback: copy to clipboard
      await Clipboard.setData(ClipboardData(
        text:
            '🎉 Hey! Join GoOuts with my invite code $_inviteCode and earn real cashback every time you shop or eat out! Download the app: https://goouts.co.uk',
      ));
      if (mounted) {
        GoOutsSheet.success(context,
          title: 'Copied!',
          message: 'Copied to clipboard — WhatsApp not found',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Refer a Friend',
            style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w700, color: _dark)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0392CA)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Hero banner ──────────────────────────────────────────
                  _buildHeroBanner(),
                  const SizedBox(height: 20),

                  // ── Invite code card ─────────────────────────────────────
                  _buildCodeCard(),
                  const SizedBox(height: 16),

                  // ── How it works ─────────────────────────────────────────
                  _buildHowItWorks(),
                  const SizedBox(height: 16),

                  // ── Stats ────────────────────────────────────────────────
                  _buildStats(),
                  const SizedBox(height: 16),

                  // ── Referral list ────────────────────────────────────────
                  _buildReferralList(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  // ── Hero banner ───────────────────────────────────────────────────────────
  Widget _buildHeroBanner() => Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0392CA), Color(0xFF0270A0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text('No limits • Invite as many as you like',
                  style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
            const SizedBox(height: 16),
            Text('Give a friend £2.\nGet £2 yourself.',
                style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.2)),
            const SizedBox(height: 10),
            Text(
              'Every time a friend signs up with your code and places their first order, £2 lands in your wallet automatically. You will be notified the moment it arrives.',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.85),
                  height: 1.6),
            ),
          ],
        ),
      );

  // ── Invite code card ──────────────────────────────────────────────────────
  Widget _buildCodeCard() => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your Invite Code',
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600])),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F8FF),
                border: Border.all(color: _primary.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _inviteCode ?? 'Loading...',
                      style: GoogleFonts.inter(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: _dark,
                          letterSpacing: 3),
                    ),
                  ),
                  GestureDetector(
                    onTap: _copyCode,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _copied ? _green : _primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _copied ? Icons.check_rounded : Icons.copy_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _copied ? 'Copied' : 'Copy',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _shareCode,
                icon: const Icon(Icons.share_rounded, size: 17),
                label: Text('Share with Friends',
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _dark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      );

  // ── How it works ──────────────────────────────────────────────────────────
  Widget _buildHowItWorks() => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How it works',
                style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w700, color: _dark)),
            const SizedBox(height: 16),
            _step(
              number: '1',
              color: _primary,
              title: 'Share your code',
              desc: 'Send your invite code to as many friends as you like. There is no limit.',
            ),
            _stepConnector(),
            _step(
              number: '2',
              color: const Color(0xFFF59E0B),
              title: 'They sign up and order',
              desc: 'Your friend creates their GoOuts account using your invite code and places their first order.',
            ),
            _stepConnector(),
            _step(
              number: '3',
              color: _green,
              title: '£2 lands in your wallet',
              desc: 'You get notified instantly. £2 in Cashback Points is automatically credited to your GoOuts wallet. Every single time.',
            ),
          ],
        ),
      );

  Widget _step({
    required String number,
    required Color color,
    required String title,
    required String desc,
  }) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(number,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: color)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _dark)),
                const SizedBox(height: 3),
                Text(desc,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                        height: 1.55)),
              ],
            ),
          ),
        ],
      );

  Widget _stepConnector() => Padding(
        padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
        child: Container(
          width: 2,
          height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.grey.withOpacity(0.2), Colors.grey.withOpacity(0.05)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      );

  // ── Stats ─────────────────────────────────────────────────────────────────
  Widget _buildStats() {
    final count    = _stats?['count']    as int?    ?? 0;
    final rewarded = _stats?['rewarded'] as int?    ?? 0;
    final earned   = _stats?['earned']   as double? ?? 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Referrals',
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700, color: _dark)),
          const SizedBox(height: 16),
          Row(
            children: [
              _statPill(label: 'Total Invited', value: '$count', color: _primary),
              const SizedBox(width: 10),
              _statPill(label: 'Converted', value: '$rewarded', color: _green),
              const SizedBox(width: 10),
              _statPill(
                  label: 'Earned',
                  value: '£${earned.toStringAsFixed(2)}',
                  color: const Color(0xFFF59E0B)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statPill({
    required String label,
    required String value,
    required Color color,
  }) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: color)),
              const SizedBox(height: 3),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color.withOpacity(0.7)),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  // ── Referral list ─────────────────────────────────────────────────────────
  Widget _buildReferralList() {
    final referrals = (_stats?['referrals'] as List<dynamic>?) ?? [];
    if (referrals.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.people_outline_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('No referrals yet',
                style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w700, color: _dark)),
            const SizedBox(height: 6),
            Text('Share your code and start earning £2 for every friend who joins.',
                style: GoogleFonts.inter(
                    fontSize: 13, color: Colors.grey[500], height: 1.5),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Friends you invited',
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700, color: _dark)),
          const SizedBox(height: 12),
          ...referrals.asMap().entries.map((entry) {
            final i    = entry.key;
            final r    = entry.value as Map<String, dynamic>;
            final name = r['name'] as String? ?? 'GoOuts User';
            final done = r['rewarded'] as bool? ?? false;
            return Column(
              children: [
                if (i > 0) Divider(height: 1, color: Colors.grey[100]),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: _primary.withOpacity(0.1),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'G',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _primary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _dark)),
                            Text(
                              done ? 'First order placed' : 'Signed up, waiting for first order',
                              style: GoogleFonts.inter(
                                  fontSize: 11, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: done
                              ? _green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          done ? '+£2.00' : 'Pending',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: done ? _green : Colors.orange[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
