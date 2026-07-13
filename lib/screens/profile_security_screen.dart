import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/user_service.dart';
import '../services/biometric_service.dart';
import '../utils/pin_hasher.dart';
import '../widgets/goouts_sheet.dart';

class ProfileSecurityScreen extends StatefulWidget {
  const ProfileSecurityScreen({super.key});

  @override
  State<ProfileSecurityScreen> createState() => _ProfileSecurityScreenState();
}

class _ProfileSecurityScreenState extends State<ProfileSecurityScreen> {
  static const Color _primary = Color(0xFF0392CA);
  static const Color _dark = Color(0xFF0D1B3E);

  String _fullName = '';
  String _email = '';
  String _phone = '';
  String? _photoUrl;

  bool _biometricEnabled = false;
  bool _biometricSupported = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadBiometric();
  }

  Future<void> _loadBiometric() async {
    final supported = await BiometricService.instance.isSupported();
    final enabled = await BiometricService.instance.isEnabled();
    if (mounted) {
      setState(() {
        _biometricSupported = supported;
        _biometricEnabled = enabled;
      });
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (!_biometricSupported) {
      GoOutsSheet.info(context,
        title: 'Not Available',
        message: 'Biometrics not available on this device.',
      );
      return;
    }
    if (value) {
      // Ask user to confirm with biometrics before enabling
      final ok = await BiometricService.instance.authenticate(
        reason: 'Confirm your identity to enable biometric login',
      );
      if (!ok) return;
    }
    await BiometricService.instance.setEnabled(value);
    if (mounted) setState(() => _biometricEnabled = value);
    if (mounted) {
      GoOutsSheet.success(context,
        title: 'Biometrics Enabled',
        message: 'value ? \'Biometric login enabled.\' : \'Biometric login disabled.',
      );
    }
  }

  Future<void> _loadProfile() async {
    final data = await UserService().getCurrentUser();
    if (data != null && mounted) {
      setState(() {
        _fullName = data['fullName'] ?? '';
        _email = data['email'] ?? '';
        _phone = data['phone'] ??
            FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
        _photoUrl = data['photoUrl'] as String?;
      });
    }
  }

  void _showChangePinSheet(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? errorMsg;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F4FB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.lock_reset_rounded,
                          color: _primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text('Change PIN',
                        style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: _dark)),
                  ],
                ),
                const SizedBox(height: 20),
                _pinField('Current PIN', currentCtrl),
                const SizedBox(height: 14),
                _pinField('New PIN', newCtrl),
                const SizedBox(height: 14),
                _pinField('Confirm New PIN', confirmCtrl),
                if (errorMsg != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Colors.red, size: 14),
                      const SizedBox(width: 6),
                      Text(errorMsg!,
                          style: GoogleFonts.inter(
                              fontSize: 13, color: Colors.red)),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (currentCtrl.text.length < 4) {
                              setSheet(() => errorMsg = 'Enter your current 4-digit PIN.');
                              return;
                            }
                            if (newCtrl.text.length < 4) {
                              setSheet(() => errorMsg = 'New PIN must be 4 digits.');
                              return;
                            }
                            if (newCtrl.text != confirmCtrl.text) {
                              setSheet(() => errorMsg = 'PINs do not match.');
                              return;
                            }
                            // Check current PIN against Firestore
                            setSheet(() => isSaving = true);
                            final userData = await UserService().getCurrentUser();
                            final storedHash = userData?['pin'] as String? ?? '';
                            final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                            if (storedHash.isNotEmpty &&
                                !PinHasher.verify(currentCtrl.text, storedHash, uid)) {
                              setSheet(() {
                                isSaving = false;
                                errorMsg = 'Current PIN is incorrect.';
                              });
                              return;
                            }
                            // Hash new PIN and save to Firestore
                            final newHash = PinHasher.hash(newCtrl.text, uid);
                            await UserService().updateUser({'pin': newHash});
                            if (context.mounted) {
                              Navigator.pop(context);
                              GoOutsSheet.success(context,
                                title: 'PIN Updated',
                                message: 'PIN updated successfully.',
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : Text('Update PIN',
                            style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pinField(String label, TextEditingController ctrl) => Column(
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
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 10,
                color: _dark),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: const Color(0xFFF0F6FA),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _primary, width: 1.5)),
              hintText: '_ _ _ _',
              hintStyle: GoogleFonts.inter(
                  fontSize: 18, letterSpacing: 10, color: Colors.grey[300]),
            ),
          ),
        ],
      );

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
        title: Text(
          'Account Security',
          style: GoogleFonts.inter(
              fontSize: 18, fontWeight: FontWeight.w700, color: _primary),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
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
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.grey[300]!, width: 2),
                        ),
                        child: ClipOval(
                          child: _photoUrl != null
                              ? Image.network(
                                  _photoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: const Color(0xFFE8F4FB),
                                    child: const Icon(Icons.person_rounded,
                                        color: _primary, size: 40),
                                  ),
                                )
                              : Container(
                                  color: const Color(0xFFE8F4FB),
                                  child: const Icon(Icons.person_rounded,
                                      color: _primary, size: 40),
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                              color: _primary, shape: BoxShape.circle),
                          child: const Icon(Icons.edit_rounded,
                              color: Colors.white, size: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(_fullName.isNotEmpty ? _fullName : 'GoOuts Member',
                      style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _dark)),
                  const SizedBox(height: 4),
                  Text('GoOuts Member',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: Colors.grey[500])),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Personal Information
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded,
                          color: _primary, size: 20),
                      const SizedBox(width: 8),
                      Text('Personal Information',
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _dark)),
                      const Spacer(),
                      Text('Edit',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _primary)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _infoField('Full Name',
                      _fullName.isNotEmpty ? _fullName : '—'),
                  const SizedBox(height: 12),
                  _infoField('Email Address',
                      _email.isNotEmpty ? _email : '—'),
                  const SizedBox(height: 12),
                  _infoField('Phone Number',
                      _phone.isNotEmpty ? _phone : '—'),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Security settings
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.settings_outlined,
                          color: _primary, size: 20),
                      const SizedBox(width: 8),
                      Text('Security Settings',
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _dark)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _menuRow(
                    icon: Icons.lock_outline_rounded,
                    title: 'Change PIN',
                    subtitle: 'Last changed 3 months ago',
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: Colors.grey, size: 20),
                    onTap: () => _showChangePinSheet(context),
                  ),
                  Divider(height: 1, color: Colors.grey[100]),
                  _menuRow(
                    icon: Icons.security_rounded,
                    title: '2-Step Verification',
                    subtitle: 'Secure your account with 2FA',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('SMS (Active)',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _primary)),
                        const Icon(Icons.chevron_right_rounded,
                            color: _primary, size: 18),
                      ],
                    ),
                    onTap: () =>
                        Navigator.pushNamed(context, '/2fa-setup'),
                  ),
                  Divider(height: 1, color: Colors.grey[100]),
                  _menuRow(
                    icon: Icons.fingerprint_rounded,
                    title: 'Biometric Login',
                    subtitle: _biometricSupported
                        ? 'Use Face ID or fingerprint'
                        : 'Not available on this device',
                    trailing: Switch(
                      value: _biometricEnabled,
                      onChanged: _biometricSupported ? _toggleBiometric : null,
                      activeColor: _primary,
                    ),
                    onTap: () => _toggleBiometric(!_biometricEnabled),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _infoField(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11, color: Colors.grey[400])),
          const SizedBox(height: 3),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w500, color: _dark)),
        ],
      );

  Widget _menuRow({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget trailing,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: Colors.grey[500], size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _dark)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: GoogleFonts.inter(
                              fontSize: 12, color: Colors.grey[500])),
                    ],
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      );

  Widget _sectionCard({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
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
        child: child,
      );
}
