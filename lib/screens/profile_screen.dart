import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/user_service.dart';
import '../services/support_ticket_service.dart';
import '../services/message_service.dart';
import '../utils/pin_hasher.dart';
import '../widgets/goouts_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _primary = Color(0xFF0392CA);
  static const Color _dark = Color(0xFF0D1B3E);
  static const Color _green = Color(0xFF0A7A3E);
  bool _kycSubmitted = false;
  bool _kycPending = false;
  File? _profileImage;
  String? _photoUrl;
  bool _uploadingPhoto = false;
  double _walletBalance = 0.0;
  int    _reviewPoints  = 0;
  int    _visitCount    = 0;
  bool _firstCashbackEarned = false;
  String _memberSince = '';

  Future<void> _pickProfileImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('Profile Photo', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _photoOption(Icons.camera_alt_rounded, 'Take Photo', ImageSource.camera),
                _photoOption(Icons.photo_library_rounded, 'Choose from Gallery', ImageSource.gallery),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;
    // Same reason as elsewhere: the picker is a separate system UI and this
    // screen can be unloaded behind it on a low memory device.
    if (!mounted) return;
    final file = File(picked.path);
    setState(() { _profileImage = file; _uploadingPhoto = true; });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('users/${user.uid}/profile_photo.jpg');
        await ref.putFile(file);
        final url = await ref.getDownloadURL();
        await UserService().updateUser({'photoUrl': url});
        if (mounted) setState(() => _photoUrl = url);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
        GoOutsSheet.error(context,
          title: 'Upload Failed',
          message: 'Could not save your photo. Please check your connection and try again.',
        );
      }
      return;
    }
    if (mounted) setState(() => _uploadingPhoto = false);
  }

  Widget _photoOption(IconData icon, String label, ImageSource source) =>
    GestureDetector(
      onTap: () => Navigator.pop(context, source),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFE1F5FE),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: _primary, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );

  // Editable personal info
  String _fullName = '';
  String _email = '';
  String _phone = '';

  // Address
  String _address1 = '';
  String _address2 = '';
  String _city = '';
  String _postcode = '';
  String _country = '';
  bool _hasAddress = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final data = await UserService().getCurrentUser();
    if (data != null && mounted) {
      final kycStatus = data['kycStatus'] as String? ?? '';
      final raw = data['walletBalance'];
      setState(() {
        _fullName = data['fullName'] ?? '';
        _email = data['email'] ?? '';
        _phone = data['phone'] ?? FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
        _kycSubmitted = kycStatus == 'verified';
        _kycPending = kycStatus == 'pending';
        _walletBalance = raw is num ? raw.toDouble() : 0.0;
        _reviewPoints  = (data['reviewPoints'] as num?)?.toInt() ?? 0;
        _firstCashbackEarned = data['firstCashbackEarned'] as bool? ?? false;
        _photoUrl = data['photoUrl'] as String?;
        final ts = data['createdAt'];
        if (ts is Timestamp) {
          final dt = ts.toDate();
          _memberSince = 'Member since ${_monthName(dt.month)} ${dt.year}';
        } else {
          _memberSince = 'GoOuts Member';
        }
        _address1 = data['address1'] as String? ?? '';
        _address2 = data['address2'] as String? ?? '';
        _city = data['city'] as String? ?? '';
        _postcode = data['postcode'] as String? ?? '';
        _country = data['country'] as String? ?? '';
        _hasAddress = _address1.isNotEmpty || _city.isNotEmpty;
      });
    }
    // Count transactions as visits
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('transactions')
            .count()
            .get();
        if (mounted) setState(() => _visitCount = snap.count ?? 0);
      }
    } catch (_) {}
  }

  String _monthName(int month) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[(month - 1).clamp(0, 11)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildProfileCard(),
                    const SizedBox(height: 12),
                    _buildKycBanner(context),
                    const SizedBox(height: 12),
                    _buildPersonalInfoCard(context),
                    const SizedBox(height: 12),
                    _buildSecurityCard(context),
                    const SizedBox(height: 12),
                    _buildAddressesCard(context),
                    const SizedBox(height: 12),
                    _buildPreferencesCard(context),
                    const SizedBox(height: 12),
                    _buildSignOut(context),
                    const SizedBox(height: 24),
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

  // ─────────────────────────────────────────────────────────────────────────
  // Header
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text('GoOuts',
                style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _primary)),
            const Spacer(),
            StreamBuilder<int>(
              stream: MessageService().unreadNotificationsStream(),
              builder: (context, snap) {
                final count = snap.data ?? 0;
                return GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/notifications'),
                  child: Stack(
                    children: [
                      const Icon(Icons.notifications_outlined, color: _primary, size: 26),
                      if (count > 0)
                        Positioned(
                          top: 0, right: 0,
                          child: Container(
                            width: 14, height: 14,
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            child: Center(
                              child: Text(count > 9 ? '9+' : '$count',
                                style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white)),
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

  // ─────────────────────────────────────────────────────────────────────────
  // Profile card
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildProfileCard() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
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
            GestureDetector(
              onTap: _pickProfileImage,
              child: Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.grey[300]!,
                          width: 2,
                          strokeAlign: BorderSide.strokeAlignOutside),
                    ),
                    child: ClipOval(
                      child: _uploadingPhoto
                          ? Container(
                              color: const Color(0xFFE8F4FB),
                              child: const Padding(
                                padding: EdgeInsets.all(22),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: _primary),
                              ))
                          // FIX: photoUrl is stored as an EMPTY STRING (see
                          // user_service.dart: 'photoUrl': existingPhotoUrl ?? '')
                          // when the user has no photo, so the old
                          // `_photoUrl != null` test was always true. That
                          // called Image.network('') — which always fails — and
                          // made the _profileImage branch below unreachable, so
                          // a freshly picked photo never previewed. Check for a
                          // non-empty string, and show the locally picked file
                          // first so the new photo appears immediately.
                          : _profileImage != null
                              ? Image.file(_profileImage!, fit: BoxFit.cover)
                              : (_photoUrl != null && _photoUrl!.isNotEmpty)
                                  ? Image.network(_photoUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                          color: const Color(0xFFE8F4FB),
                                          child: const Icon(
                                              Icons.person_rounded,
                                              color: _primary,
                                              size: 40)))
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
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                          color: _primary, shape: BoxShape.circle),
                      child: const Icon(Icons.edit_rounded,
                          color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_fullName,
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _dark)),
                if (_kycSubmitted) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified_rounded, color: _green, size: 18),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(_memberSince.isNotEmpty ? _memberSince : 'GoOuts Member',
                style:
                    GoogleFonts.inter(fontSize: 13, color: Colors.grey[500])),
            const SizedBox(height: 14),
            // Member stats row
            SizedBox(
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _statItem('£${_walletBalance.toStringAsFixed(0)}', 'Balance'),
                  _divider(),
                  _statItem('$_reviewPoints pts', 'Points'),
                  _divider(),
                  _statItem('$_visitCount', 'Visits'),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _statItem(String value, String label) => Column(
        children: [
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w800, color: _dark)),
          const SizedBox(height: 2),
          Text(label,
              style:
                  GoogleFonts.inter(fontSize: 11, color: Colors.grey[500])),
        ],
      );

  Widget _divider() => Container(
      width: 1, height: 28, color: Colors.grey[200]);

  // ─────────────────────────────────────────────────────────────────────────
  // KYC banner
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildKycBanner(BuildContext context) {
    final bool done = _kycSubmitted || _kycPending;
    final Color bannerColor = _kycSubmitted
        ? const Color(0xFFEDF7F1)
        : _kycPending
            ? const Color(0xFFE8F4FB)
            : const Color(0xFFFFF8E7);
    final Color borderColor = _kycSubmitted
        ? _green.withValues(alpha: 0.4)
        : _kycPending
            ? _primary.withValues(alpha: 0.4)
            : const Color(0xFFF59E0B).withValues(alpha: 0.5);
    final Color iconColor = _kycSubmitted
        ? _green
        : _kycPending
            ? _primary
            : const Color(0xFFF59E0B);
    final IconData iconData = _kycSubmitted
        ? Icons.verified_user_rounded
        : _kycPending
            ? Icons.hourglass_top_rounded
            : Icons.shield_outlined;
    final String title = _kycSubmitted
        ? 'Identity Verified'
        : _kycPending
            ? 'Under Review'
            : 'Verify Your Identity';
    final String subtitle = _kycSubmitted
        ? 'Your identity has been verified successfully.'
        : _kycPending
            ? 'Your documents are under review. We\'ll notify you within 1–2 business days.'
            : 'Required to unlock higher limits & cashback.';

    return GestureDetector(
      onTap: () async {
        await Navigator.pushNamed(context, '/kyc');
        if (mounted) _loadProfile();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bannerColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: iconColor, size: 22),
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
                          color: iconColor)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: done ? Colors.grey[400]! : const Color(0xFFF59E0B),
                size: 20),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Personal Information
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPersonalInfoCard(BuildContext context) => _sectionCard(
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
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _requirePin(context,
                        onSuccess: () => _showEditPersonalInfo(context)),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      child: Text('Edit',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _primary)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _infoField('Full Name', _fullName),
            const SizedBox(height: 12),
            _infoField('Email Address', _email),
            const SizedBox(height: 12),
            _infoField('Phone Number', _phone),
          ],
        ),
      );

  Widget _infoField(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  GoogleFonts.inter(fontSize: 11, color: Colors.grey[400])),
          const SizedBox(height: 3),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _dark)),
        ],
      );

  // ─────────────────────────────────────────────────────────────────────────
  // Security (Password + 2FA + KYC)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSecurityCard(BuildContext context) => _sectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined, color: _primary, size: 20),
                const SizedBox(width: 8),
                Text('Security',
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _dark)),
              ],
            ),
            const SizedBox(height: 14),
            _menuRow(
              icon: Icons.pin_outlined,
              title: 'Change PIN',
              subtitle: 'Update your 4-digit security PIN',
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: Colors.grey, size: 20),
              onTap: () => Navigator.pushNamed(context, '/profile-security'),
            ),
            Divider(height: 1, color: Colors.grey[100]),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
              child: Row(
                children: [
                  const Icon(Icons.security_rounded,
                      color: Color(0xFF0A7A3E), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('2-Step Verification',
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0D1B3E))),
                        const SizedBox(height: 2),
                        Text('SMS OTP is active on every login',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey[500])),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A7A3E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF0A7A3E), size: 12),
                        const SizedBox(width: 4),
                        Text('Active',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0A7A3E))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey[100]),
            _menuRow(
              icon: Icons.badge_outlined,
              title: 'Identity Verification',
              subtitle: _kycSubmitted
                  ? 'Submitted — under review'
                  : 'Not verified — tap to verify',
              trailing: _kycSubmitted
                  ? _pill('Submitted', _green)
                  : _pill('Verify', const Color(0xFFF59E0B)),
              onTap: _kycSubmitted
                  ? () {}
                  : () async {
                      await Navigator.pushNamed(context, '/kyc');
                      if (mounted) setState(() => _kycSubmitted = true);
                    },
            ),
          ],
        ),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // Saved Addresses
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAddressesCard(BuildContext context) {
    // Build the display string from Firestore fields
    final parts = <String>[
      if (_address1.isNotEmpty) _address1,
      if (_address2.isNotEmpty) _address2,
      if (_city.isNotEmpty && _postcode.isNotEmpty) '$_city, $_postcode'
      else if (_city.isNotEmpty) _city
      else if (_postcode.isNotEmpty) _postcode,
      if (_country.isNotEmpty) _country,
    ];
    final addressDisplay = parts.join('\n');

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  color: _primary, size: 20),
              const SizedBox(width: 8),
              Text('Saved Addresses',
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _dark)),
              const Spacer(),
              if (!_hasAddress)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _requirePin(context,
                        onSuccess: () => _showEditAddressSheet(context)),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      child: Text('+ Add',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _primary)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (!_hasAddress)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Icon(Icons.location_off_outlined,
                        size: 36, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text('No address saved',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: Colors.grey[400])),
                  ],
                ),
              ),
            )
          else
            _addressRow(
              context: context,
              icon: Icons.home_outlined,
              title: 'Home',
              address: addressDisplay,
            ),
        ],
      ),
    );
  }

  Widget _addressRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String address,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 2),
                  Text(address,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _requirePin(context,
                    onSuccess: () => _showEditAddressSheet(context)),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.edit_outlined,
                      color: _primary, size: 18),
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _requirePin(context,
                    onSuccess: () => _confirmDeleteAddress(context)),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.delete_outline_rounded,
                      color: Colors.red[300], size: 18),
                ),
              ),
            ),
          ],
        ),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // Preferences
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPreferencesCard(BuildContext context) => _sectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune_rounded, color: _primary, size: 20),
                const SizedBox(width: 8),
                Text('Preferences',
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _dark)),
              ],
            ),
            const SizedBox(height: 14),
            _menuRow(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: null,
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: Colors.grey, size: 20),
              onTap: () => Navigator.pushNamed(context, '/notifications'),
            ),
            Divider(height: 1, color: Colors.grey[100]),
            StreamBuilder<int>(
              stream: MessageService().unreadCountStream(),
              builder: (context, snap) {
                final unread = snap.data ?? 0;
                return _menuRow(
                  icon: Icons.message_outlined,
                  title: 'Messages',
                  subtitle: null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (unread > 0)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unread > 9 ? '9+' : '$unread',
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                      const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                    ],
                  ),
                  onTap: () => Navigator.pushNamed(context, '/messages'),
                );
              },
            ),
            // Family Plan — only visible after first cashback earned (Touch 2)
            if (_firstCashbackEarned) ...[
              Divider(height: 1, color: Colors.grey[100]),
              _menuRow(
                icon: Icons.people_alt_rounded,
                title: 'Family Plan',
                subtitle: 'Invite family. Earn together.',
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFBF00).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'GoOuts Plus',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFBF8C00),
                    ),
                  ),
                ),
                onTap: () => Navigator.pushNamed(context, '/family-plan'),
              ),
            ],
            Divider(height: 1, color: Colors.grey[100]),
            _menuRow(
              icon: Icons.card_giftcard_rounded,
              title: 'Refer a Friend',
              subtitle: 'Give £2, get £2 for every friend who joins',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('£2 Reward',
                    style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
              ),
              onTap: () => Navigator.pushNamed(context, '/refer-friend'),
            ),
            Divider(height: 1, color: Colors.grey[100]),
            _menuRow(
              icon: Icons.help_outline_rounded,
              title: 'FAQ',
              subtitle: null,
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: Colors.grey, size: 20),
              onTap: () => Navigator.pushNamed(context, '/faq'),
            ),
            Divider(height: 1, color: Colors.grey[100]),
            StreamBuilder<int>(
              stream: SupportTicketService().unreadCountStream(),
              builder: (context, snap) {
                final unread = snap.data ?? 0;
                return _menuRow(
                  icon: Icons.headset_mic_outlined,
                  title: 'Contact Support',
                  subtitle: null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (unread > 0)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unread > 9 ? '9+' : '$unread',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white),
                          ),
                        ),
                      const Icon(Icons.chevron_right_rounded,
                          color: Colors.grey, size: 20),
                    ],
                  ),
                  onTap: () => Navigator.pushNamed(
                      context,
                      unread > 0 ? '/support-tickets' : '/contact-support'),
                );
              },
            ),
          ],
        ),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // Sign out
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSignOut(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
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
        child: ListTile(
          leading:
              const Icon(Icons.logout_rounded, color: Colors.red, size: 22),
          title: Text('Sign Out',
              style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.red)),
          onTap: () => _confirmSignOut(context),
        ),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // PIN gate — shown before any edit action
  // ─────────────────────────────────────────────────────────────────────────
  void _requirePin(BuildContext context, {required VoidCallback onSuccess}) {
    final pinCtrl = TextEditingController();
    bool hasError = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F4FB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.lock_rounded,
                      color: _primary, size: 26),
                ),
                const SizedBox(height: 14),
                Text('Enter Your PIN',
                    style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _dark)),
                const SizedBox(height: 6),
                Text('Please enter your 4-digit PIN to continue.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 13, color: Colors.grey[600])),
                const SizedBox(height: 24),
                // PIN field
                TextField(
                  controller: pinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  autofocus: true,
                  style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 12,
                      color: _dark),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: hasError
                        ? Colors.red.withValues(alpha: 0.05)
                        : const Color(0xFFF0F6FA),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: hasError ? Colors.red : _primary,
                            width: 1.5)),
                    hintText: '_ _ _ _',
                    hintStyle: GoogleFonts.inter(
                        fontSize: 20,
                        letterSpacing: 10,
                        color: Colors.grey[300]),
                  ),
                  onChanged: (v) async {
                    if (hasError) setSheet(() => hasError = false);
                    if (v.length == 4) {
                      final userData = await UserService().getCurrentUser();
                      final storedHash = userData?['pin'] as String? ?? '';
                      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                      final valid = PinHasher.verify(v, storedHash, uid);
                      if (valid) {
                        if (context.mounted) Navigator.pop(context);
                        onSuccess();
                      } else {
                        setSheet(() => hasError = true);
                        pinCtrl.clear();
                      }
                    }
                  },
                ),
                // Error message
                AnimatedOpacity(
                  opacity: hasError ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Colors.red, size: 14),
                        const SizedBox(width: 5),
                        Text('Incorrect PIN. Please try again.',
                            style: GoogleFonts.inter(
                                fontSize: 13, color: Colors.red)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel',
                      style: GoogleFonts.inter(
                          fontSize: 14, color: Colors.grey[500])),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Edit personal info bottom sheet
  // ─────────────────────────────────────────────────────────────────────────
  void _showEditPersonalInfo(BuildContext context) {
    final nameCtrl = TextEditingController(text: _fullName);
    final emailCtrl = TextEditingController(text: _email);
    final phoneCtrl = TextEditingController(text: _phone);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Edit Personal Info',
                  style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _dark)),
              const SizedBox(height: 20),
              _editField('Full Name', nameCtrl, TextInputType.name),
              const SizedBox(height: 14),
              _editField('Email Address', emailCtrl,
                  TextInputType.emailAddress),
              const SizedBox(height: 14),
              _editField('Phone Number', phoneCtrl, TextInputType.phone),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    final newName = nameCtrl.text.trim();
                    final newEmail = emailCtrl.text.trim();
                    final newPhone = phoneCtrl.text.trim();
                    Navigator.pop(context);
                    setState(() {
                      _fullName = newName;
                      _email = newEmail;
                      _phone = newPhone;
                    });
                    await UserService().updateUser({
                      'fullName': newName,
                      'email': newEmail,
                      'phone': newPhone,
                    });
                    // Guard the context actually being used, not this State's
                    // `mounted` — `context` here is the parameter passed into
                    // _showEditPersonalInfo and the sheet it belonged to has
                    // already been popped above.
                    if (context.mounted) {
                      GoOutsSheet.success(context,
                        title: 'Profile Updated',
                        message: 'Profile updated successfully.',
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text('Save Changes',
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editField(String label, TextEditingController ctrl,
          TextInputType type) =>
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
                  borderSide:
                      const BorderSide(color: _primary, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 13),
            ),
          ),
        ],
      );

  // ─────────────────────────────────────────────────────────────────────────
  // Edit Address Sheet
  // ─────────────────────────────────────────────────────────────────────────
  void _showEditAddressSheet(BuildContext context) {
    final a1Ctrl = TextEditingController(text: _address1);
    final a2Ctrl = TextEditingController(text: _address2);
    final cityCtrl = TextEditingController(text: _city);
    final pcCtrl = TextEditingController(text: _postcode);
    final countryCtrl = TextEditingController(text: _country);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
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
                      child: const Icon(Icons.home_outlined,
                          color: _primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text('Edit Home Address',
                        style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: _dark)),
                  ],
                ),
                const SizedBox(height: 20),
                _editField('Address Line 1', a1Ctrl, TextInputType.streetAddress),
                const SizedBox(height: 12),
                _editField('Address Line 2 (optional)', a2Ctrl, TextInputType.streetAddress),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _editField('City', cityCtrl, TextInputType.text)),
                    const SizedBox(width: 12),
                    Expanded(child: _editField('Postcode', pcCtrl, TextInputType.text)),
                  ],
                ),
                const SizedBox(height: 12),
                _editField('Country', countryCtrl, TextInputType.text),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final a1 = a1Ctrl.text.trim();
                            if (a1.isEmpty) {
                              GoOutsSheet.warning(context,
                                title: 'Address Required',
                                message: 'Address line 1 is required.',
                              );
                              return;
                            }
                            setSheet(() => isSaving = true);
                            final updates = {
                              'address1': a1,
                              'address2': a2Ctrl.text.trim(),
                              'city': cityCtrl.text.trim(),
                              'postcode': pcCtrl.text.trim(),
                              'country': countryCtrl.text.trim(),
                            };
                            await UserService().updateUser(updates);
                            if (!context.mounted) return;
                            setState(() {
                              _address1 = updates['address1']!;
                              _address2 = updates['address2']!;
                              _city = updates['city']!;
                              _postcode = updates['postcode']!;
                              _country = updates['country']!;
                              _hasAddress = _address1.isNotEmpty || _city.isNotEmpty;
                            });
                            Navigator.pop(ctx);
                            GoOutsSheet.success(context,
                              title: 'Address Updated',
                              message: 'Address updated successfully.',
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : Text('Save Address',
                            style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Delete address — clears from Firestore
  // ─────────────────────────────────────────────────────────────────────────
  void _confirmDeleteAddress(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove Address',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _dark)),
        content: Text('Remove your saved home address?',
            style: GoogleFonts.inter(color: Colors.grey[600])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: GoogleFonts.inter(color: Colors.grey))),
          TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await UserService().updateUser({
                  'address1': '',
                  'address2': '',
                  'city': '',
                  'postcode': '',
                  'country': '',
                });
                if (!mounted) return;
                setState(() {
                  _address1 = '';
                  _address2 = '';
                  _city = '';
                  _postcode = '';
                  _country = '';
                  _hasAddress = false;
                });
                // Guard the dialog context separately — it was popped above.
                if (!context.mounted) return;
                GoOutsSheet.info(context,
                  title: 'Address Removed',
                  message: 'Address removed.',
                );
              },
              child: Text('Remove',
                  style: GoogleFonts.inter(
                      color: Colors.red, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────
  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign Out',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, color: _dark)),
        content: Text('Are you sure you want to sign out?',
            style: GoogleFonts.inter(color: Colors.grey[600])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: GoogleFonts.inter(color: Colors.grey))),
          TextButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/login', (_) => false);
                }
              },
              child: Text('Sign Out',
                  style: GoogleFonts.inter(
                      color: Colors.red, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _pill(String label, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color)),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // Shared
  // ─────────────────────────────────────────────────────────────────────────
  Widget _sectionCard({required Widget child}) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
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

  Widget _menuRow({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget trailing,
    required VoidCallback onTap,
  }) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          splashColor: _primary.withValues(alpha: 0.08),
          highlightColor: _primary.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: Row(
              children: [
                Icon(icon, color: Colors.grey[500], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // title is a required non-nullable String, so the old
                      // `if (title != null)` guard was always true.
                      Text(title,
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
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
        ),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // Bottom navigation bar
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -2))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(context, Icons.home_rounded, 'Home', '/home'),
              _navItem(context, Icons.storefront_rounded, 'Explore', '/nearby'),
              _navItem(context, Icons.account_balance_wallet_rounded, 'Wallet', '/wallet'),
              _navItem(context, Icons.person_rounded, 'Profile', '/profile', active: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, IconData icon, String label, String route, {bool active = false}) {
    return GestureDetector(
      onTap: active ? null : () => Navigator.pushReplacementNamed(context, route),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: active ? _primary : Colors.grey[400], size: 24),
          const SizedBox(height: 3),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? _primary : Colors.grey[400])),
        ],
      ),
    );
  }
}

