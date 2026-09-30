import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/business_partner_service.dart';
import '../widgets/goouts_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  "Become a Partner" — inside goouts_app Profile.
//
//  Added 11 September 2026, per design/PARTNER_ECOSYSTEM_ARCHITECTURE.md §2
//  and §7 step 3. A signed-in consumer upgrades the SAME account to run a
//  restaurant, a shop/pub/cafe, or host a property — never a second login,
//  never a separate signup. This screen only ever writes a 'pending'
//  application; approval is a real admin review, not something this screen
//  can fake or skip. See business_partner_service.dart for the write path
//  and firestore.rules' /businesses block for why a client cannot self-
//  approve even by editing the request directly.
//
//  Flag, don't fake: nothing here claims instant approval or instant access.
//  If the user already has a pending or verified application, that status is
//  shown immediately on load instead of the form.
// ─────────────────────────────────────────────────────────────────────────────
class BecomeAPartnerScreen extends StatefulWidget {
  const BecomeAPartnerScreen({super.key});

  @override
  State<BecomeAPartnerScreen> createState() => _BecomeAPartnerScreenState();
}

class _BecomeAPartnerScreenState extends State<BecomeAPartnerScreen> {
  static const Color _primary = Color(0xFF0392CA);
  static const Color _dark = Color(0xFF0D1B3E);
  static const Color _green = Color(0xFF0A7A3E);
  static const Color _amber = Color(0xFFF59E0B);

  final BusinessPartnerService _service = BusinessPartnerService();

  bool _checkingStatus = true;
  Map<String, dynamic>? _existingApplication;
  bool _submitting = false;
  bool _justSubmitted = false;

  // Business type multi-select. Values match the design doc's `lines`.
  final Set<String> _selectedLines = <String>{};

  final TextEditingController _legalNameCtrl = TextEditingController();
  final TextEditingController _tradingNameCtrl = TextEditingController();
  final TextEditingController _address1Ctrl = TextEditingController();
  final TextEditingController _address2Ctrl = TextEditingController();
  final TextEditingController _cityCtrl = TextEditingController();
  final TextEditingController _postcodeCtrl = TextEditingController();
  final TextEditingController _countryCtrl =
      TextEditingController(text: 'United Kingdom');

  @override
  void initState() {
    super.initState();
    _loadExistingApplication();
  }

  @override
  void dispose() {
    _legalNameCtrl.dispose();
    _tradingNameCtrl.dispose();
    _address1Ctrl.dispose();
    _address2Ctrl.dispose();
    _cityCtrl.dispose();
    _postcodeCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingApplication() async {
    // ⚠ Must never leave the user on an infinite spinner. This query needs a
    // Firestore composite index (see the note on getExistingApplication), and
    // a missing index — or any other read failure — used to throw here with
    // nothing to catch it, so _checkingStatus never flipped to false and the
    // screen stayed on the loading spinner forever. Any error is now treated
    // the same as "no existing application found": log it for debugging and
    // quietly fall through to showing the form, matching the try/catch +
    // debugPrint pattern used for async loads elsewhere in this app (see
    // checkout_screen.dart's _load()).
    Map<String, dynamic>? existing;
    try {
      existing = await _service.getExistingApplication();
    } catch (e) {
      debugPrint('BecomeAPartnerScreen _loadExistingApplication error: $e');
    }
    if (!mounted) return;
    setState(() {
      _existingApplication = existing;
      _checkingStatus = false;
    });
  }

  void _toggleLine(String line) {
    setState(() {
      if (_selectedLines.contains(line)) {
        _selectedLines.remove(line);
      } else {
        _selectedLines.add(line);
      }
    });
  }

  Future<void> _submit() async {
    final legalName = _legalNameCtrl.text.trim();
    final address1 = _address1Ctrl.text.trim();
    final city = _cityCtrl.text.trim();
    final postcode = _postcodeCtrl.text.trim();

    if (_selectedLines.isEmpty) {
      GoOutsSheet.warning(context,
        title: 'Choose a Business Type',
        message: 'Select at least one option above to continue.',
      );
      return;
    }
    if (legalName.isEmpty) {
      GoOutsSheet.warning(context,
        title: 'Legal Name Required',
        message: 'Enter your business\'s legal name to continue.',
      );
      return;
    }
    if (address1.isEmpty || city.isEmpty || postcode.isEmpty) {
      GoOutsSheet.warning(context,
        title: 'Address Required',
        message: 'Enter your business address to continue.',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _service.submitApplication(
        legalName: legalName,
        tradingName: _tradingNameCtrl.text.trim().isEmpty
            ? null
            : _tradingNameCtrl.text.trim(),
        lines: _selectedLines.toList(),
        address: <String, dynamic>{
          'address1': address1,
          'address2': _address2Ctrl.text.trim(),
          'city': city,
          'postcode': postcode,
          'country': _countryCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _justSubmitted = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      GoOutsSheet.error(context,
        title: 'Could Not Submit',
        message:
            'Something went wrong sending your application. Please check your connection and try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: _primary, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Become a Partner',
            style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w700, color: _primary)),
        centerTitle: false,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool desktop = kIsWeb && constraints.maxWidth >= 900;
          final Widget content = SafeArea(
        child: _checkingStatus
            ? const Center(child: CircularProgressIndicator(color: _primary))
            : (_justSubmitted || _existingApplication != null)
                ? _buildStatusState(
                    status: _justSubmitted
                        ? 'pending'
                        : (_existingApplication?['status'] as String? ??
                            'pending'),
                  )
                : _buildForm(),
          );
          if (!desktop) return content;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: content,
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Status state — shown instead of the form once an application exists.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStatusState({required String status}) {
    final bool verified = status == 'verified';
    final Color color = verified ? _green : _amber;
    final IconData icon =
        verified ? Icons.verified_rounded : Icons.hourglass_top_rounded;
    final String title =
        verified ? 'You\'re a GoOuts Partner' : 'Application Submitted';
    final String message = verified
        ? 'Your business has been verified. Your GoOuts Partner tools are being set up — we\'ll be in touch with next steps.'
        : 'We\'ll review it and be in touch. This is a real review by our team, so it isn\'t instant — most applications are looked at within a few business days.';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 38),
          ),
          const SizedBox(height: 20),
          Text(title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 19, fontWeight: FontWeight.w800, color: _dark)),
          const SizedBox(height: 10),
          Text(message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 14, color: Colors.grey[600], height: 1.5)),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
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
            child: Row(
              children: [
                Icon(Icons.storefront_rounded, color: _primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (_existingApplication?['legalName'] as String?)
                                ?.isNotEmpty ==
                                true
                            ? _existingApplication!['legalName'] as String
                            : _legalNameCtrl.text,
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _dark),
                      ),
                      const SizedBox(height: 2),
                      Text('Status: ${verified ? 'Verified' : 'Pending review'}',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: const BorderSide(color: _primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Back to Profile',
                  style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Form state
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What are you setting up?',
              style: GoogleFonts.inter(
                  fontSize: 17, fontWeight: FontWeight.w800, color: _dark)),
          const SizedBox(height: 4),
          Text('Pick one or more — you can run several at once.',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 14),
          _typeTile(
            line: 'food',
            icon: Icons.restaurant_rounded,
            title: 'Restaurant or takeaway',
            subtitle: 'Sell food for delivery on GoOuts.',
          ),
          const SizedBox(height: 10),
          _typeTile(
            line: 'instore',
            icon: Icons.storefront_rounded,
            title: 'Shop, pub, cafe',
            subtitle: 'Offer in-store cashback to GoOuts members.',
          ),
          const SizedBox(height: 10),
          _typeTile(
            line: 'stay',
            icon: Icons.night_shelter_rounded,
            title: 'Property to host',
            subtitle: 'List a place for short stays.',
          ),
          const SizedBox(height: 28),
          Text('Business details',
              style: GoogleFonts.inter(
                  fontSize: 17, fontWeight: FontWeight.w800, color: _dark)),
          const SizedBox(height: 14),
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _field('Legal Business Name', _legalNameCtrl,
                    TextInputType.text),
                const SizedBox(height: 14),
                _field('Trading Name (optional)', _tradingNameCtrl,
                    TextInputType.text),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('Business address',
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w700, color: _dark)),
          const SizedBox(height: 10),
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _field('Address Line 1', _address1Ctrl,
                    TextInputType.streetAddress),
                const SizedBox(height: 12),
                _field('Address Line 2 (optional)', _address2Ctrl,
                    TextInputType.streetAddress),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _field('City', _cityCtrl, TextInputType.text)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _field(
                            'Postcode', _postcodeCtrl, TextInputType.text)),
                  ],
                ),
                const SizedBox(height: 12),
                _field('Country', _countryCtrl, TextInputType.text),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4FB),
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
                    'Our team reviews every application before a business goes live — this isn\'t instant approval.',
                    style: GoogleFonts.inter(
                        fontSize: 12.5, color: Colors.grey[700], height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Text('Submit Application',
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeTile({
    required String line,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final bool selected = _selectedLines.contains(line);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggleLine(line),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE8F4FB) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected ? _primary : Colors.grey.shade200,
                width: selected ? 1.5 : 1),
            boxShadow: selected
                ? []
                : [
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
                      ? _primary
                      : const Color(0xFFF0F6FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon,
                    color: selected ? Colors.white : _primary, size: 22),
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
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? _primary : Colors.grey[300],
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
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
        child: child,
      );

  Widget _field(
          String label, TextEditingController ctrl, TextInputType type) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600])),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            keyboardType: type,
            style: GoogleFonts.inter(fontSize: 14, color: _dark),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF0F6FA),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _primary, width: 1.5)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            ),
          ),
        ],
      );
}
