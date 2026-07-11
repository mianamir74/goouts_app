import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';
import '../services/address_lookup_service.dart';
import '../services/referral_service.dart';

class CreateProfileExpandedScreen extends StatefulWidget {
  const CreateProfileExpandedScreen({super.key});

  @override
  State<CreateProfileExpandedScreen> createState() =>
      _CreateProfileExpandedScreenState();
}

class _CreateProfileExpandedScreenState
    extends State<CreateProfileExpandedScreen> {
  // ── Controllers ────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _dobController = TextEditingController();
  final _pinController = TextEditingController();
  final _postcodeController = TextEditingController();
  final _houseNoController = TextEditingController();
  final _streetNameController = TextEditingController();
  final _townController = TextEditingController();
  final _cityController = TextEditingController();

  // ── State ──────────────────────────────────────────────────────────────────
  bool _obscurePin = true;
  bool _obscureEmail = true;
  bool _emailValid = true;   // PROTOTYPE: always valid
  bool _termsAccepted = false;
  bool _isSubmitting = false;
  bool _isLookingUp = false;
  bool _isPostcodeVerified = false;
  bool _showManualEntryHint = false;
  String _selectedCountry = 'United Kingdom';
  String _selectedPrefix = 'Mr';

  static const List<String> _prefixOptions = [
    'Mr', 'Mrs', 'Miss', 'Ms', 'Dr', 'Prof', 'Sir', 'Rev', 'Other',
  ];
  final _userService      = UserService();
  final _addressService   = AddressLookupService();
  final _referralService  = ReferralService();
  final _inviteCodeController = TextEditingController();
  String? _referrerUid;
  bool   _checkingCode = false;
  bool   _codeValid    = false;

  String? _termsFromDb;
  String? _privacyFromDb;

  static const Color _primary = Color(0xFF0392CA);
  static const Color _dark = Color(0xFF0D1B3E);
  static const Color _green = Color(0xFF0A7A3E);

  // ── Country list ───────────────────────────────────────────────────────────
  final List<String> _countries = [
    'United Kingdom',
    'United States',
    'Ireland',
    'Canada',
    'Australia',
    'Germany',
    'France',
    'Spain',
    'Italy',
    'Netherlands',
    'Sweden',
    'Norway',
    'Denmark',
    'Switzerland',
    'UAE',
    'Singapore',
    'India',
    'Pakistan',
    'Nigeria',
    'South Africa',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadLegalContent();
  }

  Future<void> _loadLegalContent() async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('content_pages').doc('terms_conditions').get(),
        FirebaseFirestore.instance.collection('content_pages').doc('privacy_policy').get(),
      ]);
      final terms = results[0].data()?['content'] as String?;
      final privacy = results[1].data()?['content'] as String?;
      if (mounted) {
        setState(() {
          if (terms != null && terms.trim().isNotEmpty) _termsFromDb = terms;
          if (privacy != null && privacy.trim().isNotEmpty) _privacyFromDb = privacy;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _pinController.dispose();
    _postcodeController.dispose();
    _houseNoController.dispose();
    _streetNameController.dispose();
    _townController.dispose();
    _cityController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  // ── Email validation ───────────────────────────────────────────────────────
  static const _blockedDomains = {
    'mailinator.com', 'guerrillamail.com', 'tempmail.com', 'throwam.com',
    'trashmail.com', 'yopmail.com', 'sharklasers.com', 'guerrillamailblock.com',
    'grr.la', 'guerrillamail.info', 'spam4.me', 'dispostable.com',
    'maildrop.cc', 'mailnull.com', 'spamgourmet.com', 'trashmail.me',
    'fakeinbox.com', 'discard.email', 'spamherе.com', 'getairmail.com',
  };

  static bool _isValidEmail(String val) {
    final trimmed = val.trim().toLowerCase();
    // Must match standard email format
    if (!RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$')
        .hasMatch(trimmed)) return false;
    final parts = trimmed.split('@');
    if (parts.length != 2) return false;
    final domain = parts[1];
    // Block known disposable/fake domains
    if (_blockedDomains.contains(domain)) return false;
    // Domain must have at least one dot and a valid TLD (2+ chars)
    final domainParts = domain.split('.');
    if (domainParts.length < 2) return false;
    final tld = domainParts.last;
    if (tld.length < 2) return false;
    // Block domains with repeated characters (e.g. fsdfffsdf.com)
    final domainName = domainParts.first;
    if (domainName.length > 4) {
      // Check if >60% of characters are the same letter (gibberish signal)
      final charCounts = <String, int>{};
      for (final c in domainName.split('')) {
        charCounts[c] = (charCounts[c] ?? 0) + 1;
      }
      final maxCount = charCounts.values.reduce((a, b) => a > b ? a : b);
      if (maxCount / domainName.length > 0.6) return false;
    }
    // Local part must not be pure random gibberish (>70% same char)
    final local = parts[0];
    if (local.length > 6) {
      final charCounts = <String, int>{};
      for (final c in local.split('')) {
        charCounts[c] = (charCounts[c] ?? 0) + 1;
      }
      final maxCount = charCounts.values.reduce((a, b) => a > b ? a : b);
      if (maxCount / local.length > 0.7) return false;
    }
    return true;
  }

  void _onEmailChanged(String val) {
    final valid = _isValidEmail(val);
    if (valid != _emailValid) setState(() => _emailValid = valid);
  }

  // ── Date picker (calendar shortcut) ───────────────────────────────────────
  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 16, now.month, now.day),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _dobController.text =
          '${picked.day.toString().padLeft(2, '0')} / ${picked.month.toString().padLeft(2, '0')} / ${picked.year}';
      setState(() {});
    }
  }

  // ── DOB manual formatter — auto-inserts " / " after DD and MM ─────────────
  String _formatDobInput(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final buf = StringBuffer();
    for (int i = 0; i < digits.length && i < 8; i++) {
      if (i == 2 || i == 4) buf.write(' / ');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  // ── Postcode lookup ────────────────────────────────────────────────────────
  Future<void> _lookupPostcode() async {
    final postcode = _postcodeController.text.trim();
    if (postcode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a postcode first.')),
      );
      return;
    }
    setState(() => _isLookingUp = true);

    final result = await _addressService.validatePostcode(postcode);
    setState(() => _isLookingUp = false);

    if (!mounted) return;

    if (result == null) {
      setState(() {
        _isPostcodeVerified = false;
        _showManualEntryHint = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Postcode not found. Please check and try again, or enter your address manually.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Auto-fill town, city and country from Mapbox result
    final String inferredCity =
        AddressLookupService.inferCityFromPostcode(postcode) ?? result.city;
    final String country = AddressLookupService.isNorthernIrelandPostcode(postcode)
        ? 'Northern Ireland'
        : 'United Kingdom';

    setState(() {
      _postcodeController.text = result.postcode;
      _townController.text = result.city.toUpperCase();
      _cityController.text = inferredCity;
      _selectedCountry = _countries.contains(country) ? country : 'United Kingdom';
      _isPostcodeVerified = true;
      _showManualEntryHint = false;
    });
  }

  // ── Manual entry ──────────────────────────────────────────────────────────
  void _activateManualMode() {
    setState(() {
      _isPostcodeVerified = false;
      _showManualEntryHint = true;
      _houseNoController.clear();
      _streetNameController.clear();
      _townController.clear();
      _cityController.clear();
    });
  }

  // ── Validate invite code ──────────────────────────────────────────────────
  Future<void> _checkInviteCode() async {
    final code = _inviteCodeController.text.trim();
    if (code.isEmpty) {
      setState(() { _referrerUid = null; _codeValid = false; });
      return;
    }
    setState(() => _checkingCode = true);
    final uid = await _referralService.getReferrerUid(code);
    if (mounted) {
      setState(() {
        _referrerUid = uid;
        _codeValid   = uid != null;
        _checkingCode = false;
      });
    }
  }

  // ── Register account → save to Firestore ──────────────────────────────────
  Future<void> _registerAccount() async {
    setState(() => _isSubmitting = true);
    try {
      await _userService.createUser(
        prefix: _selectedPrefix,
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        dob: _dobController.text.trim(),
        pin: _pinController.text.trim(),
        postcode: _postcodeController.text.trim(),
        houseNo: _houseNoController.text.trim().toUpperCase(),
        streetName: _streetNameController.text.trim().toUpperCase(),
        town: _townController.text.trim().toUpperCase(),
        city: _cityController.text.trim(),
        country: _selectedCountry,
      );
      // If user entered a valid referral code, save referredByUid
      if (_referrerUid != null) {
        await _referralService.saveReferredBy(_referrerUid!);
      }

      // Mark this device as having signed up before
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_signed_up', true);

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/registration-success',
          (route) => false,
          arguments: {
            'prefix': _selectedPrefix,
            'name': _nameController.text.trim().split(' ').first,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed. Please try again.')),
        );
      }
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _primary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Profile Registration',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _primary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: _primary.withOpacity(0.12),
              child:
                  const Icon(Icons.person_rounded, color: _primary, size: 20),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // ── Step indicator ─────────────────────────────────────────
              _buildStepIndicator(),

              const SizedBox(height: 20),

              // ── Page title ─────────────────────────────────────────────
              Text(
                'Your Details',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Enter your details exactly as they appear on your official ID.',
                style: GoogleFonts.inter(
                    fontSize: 14, color: Colors.grey[600], height: 1.5),
              ),

              const SizedBox(height: 20),

              // ── Personal Profile card ──────────────────────────────────
              _sectionCard(
                title: 'Personal Information',
                icon: Icons.person_outline_rounded,
                children: [
                  // Prefix
                  _label('Title *'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedPrefix,
                    decoration: _fieldDec('').copyWith(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                    ),
                    style: _inputStyle(),
                    items: _prefixOptions
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(p, style: _inputStyle()),
                            ))
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _selectedPrefix = val ?? 'Mr'),
                  ),

                  const SizedBox(height: 14),

                  // Full name
                  _label('Legal Full Name *'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (val) {
                      final titled = val.replaceAllMapped(
                        RegExp(r'\b\w+'),
                        (m) => m[0]![0].toUpperCase() +
                            m[0]!.substring(1).toLowerCase(),
                      );
                      if (titled != val) {
                        _nameController.value = TextEditingValue(
                          text: titled,
                          selection: TextSelection.collapsed(
                              offset: titled.length),
                        );
                      }
                      setState(() {});
                    },
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Full name is required' : null,
                    style: _inputStyle(),
                    decoration: _fieldDec(
                        'As it appears on your passport or driving licence'),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFFF59E0B).withOpacity(0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.verified_user_outlined,
                            size: 14, color: Color(0xFFB45309)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Used to verify your identity — mismatches with your ID may delay your account approval.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF92400E),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Email
                  _label('Email Address *'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    obscureText: _obscureEmail,
                    onChanged: _onEmailChanged,
                    validator: (v) => !_emailValid ? 'Enter a valid email' : null,
                    style: _inputStyle(),
                    decoration: _fieldDec('e.g. julian@example.com').copyWith(
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Green tick when valid
                          if (_emailValid)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(Icons.check_circle_rounded,
                                  color: _green, size: 18),
                            ),
                          IconButton(
                            icon: Icon(
                              _obscureEmail
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: Colors.grey,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _obscureEmail = !_obscureEmail),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Date of Birth
                  _label('Date of Birth *'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _dobController,
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Date of birth is required' : null,
                    style: _inputStyle(),
                    onChanged: (val) {
                      final formatted = _formatDobInput(val);
                      if (formatted != val) {
                        _dobController.value = TextEditingValue(
                          text: formatted,
                          selection: TextSelection.collapsed(
                              offset: formatted.length),
                        );
                      }
                    },
                    decoration: _fieldDec('DD / MM / YYYY').copyWith(
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today_rounded,
                            color: Colors.grey, size: 18),
                        tooltip: 'Pick from calendar',
                        onPressed: _pickDob,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Type manually or tap 📅 to pick from calendar.',
                    style:
                        GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
                  ),

                  const SizedBox(height: 14),

                  // PIN
                  _label('Create 4-digit PIN *'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _pinController,
                    obscureText: _obscurePin,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    onChanged: (_) => setState(() {}),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) =>
                        v == null || v.length < 4 ? 'PIN must be 4 digits' : null,
                    style: _inputStyle().copyWith(letterSpacing: 8),
                    decoration: _fieldDec('').copyWith(
                      counterText: '',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePin
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: Colors.grey,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePin = !_obscurePin),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This PIN will be used to authorise all transactions.',
                    style:
                        GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Address Details card ───────────────────────────────────
              _sectionCard(
                title: 'Address Details',
                icon: Icons.location_on_outlined,
                children: [
                  // ── 1. Postcode + Look Up ──────────────────────────────
                  _label('Postcode *'),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _postcodeController,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 ]')),
                          ],
                          style: _inputStyle(),
                          decoration: _fieldDec('e.g. SW1A 1AA').copyWith(
                            suffixIcon: _isPostcodeVerified
                                ? const Icon(Icons.check_circle_rounded,
                                    color: _green, size: 20)
                                : null,
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Postcode is required'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isLookingUp ? null : _lookupPostcode,
                          icon: _isLookingUp
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : Icon(_isPostcodeVerified
                                  ? Icons.verified_rounded
                                  : Icons.search_rounded,
                                  size: 18),
                          label: Text(
                            _isPostcodeVerified ? 'Verified' : 'Look Up',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _isPostcodeVerified ? _green : _primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Status banners
                  if (_isPostcodeVerified) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _green.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _green.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_outline_rounded,
                              size: 16, color: _green),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Postcode confirmed — fill in your house number and street below.',
                              style: TextStyle(
                                color: _green,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (_showManualEntryHint) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 14, color: _primary),
                        const SizedBox(width: 6),
                        Text(
                          'Enter your address manually below ↓',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: _primary,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 14),

                  // ── 2. House / Business No or Name ────────────────────
                  _label('House / Business No or Name *'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _houseNoController,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 \-/]')),
                    ],
                    onChanged: (_) => setState(() {}),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'House / business number or name is required'
                        : null,
                    style: _inputStyle(),
                    decoration: _fieldDec('e.g. 12 or Flat 3A').copyWith(
                      suffixIcon: _houseNoController.text.trim().isNotEmpty
                          ? const Icon(Icons.check_circle_rounded,
                              color: _green, size: 20)
                          : null,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── 3. Street / Road Name ─────────────────────────────
                  _label('Street / Road Name *'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _streetNameController,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 \-]')),
                    ],
                    onChanged: (_) => setState(() {}),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Street / road name is required'
                        : null,
                    style: _inputStyle(),
                    decoration: _fieldDec('e.g. HIGH STREET').copyWith(
                      suffixIcon: _streetNameController.text.trim().isNotEmpty
                          ? const Icon(Icons.check_circle_rounded,
                              color: _green, size: 20)
                          : null,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── 4. Town (auto-filled from Mapbox) ─────────────────
                  _label('Town *'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _townController,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) => setState(() {}),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Town is required'
                        : null,
                    style: _inputStyle(),
                    decoration: _fieldDec('e.g. WEMBLEY').copyWith(
                      helperText: _isPostcodeVerified &&
                              _townController.text.trim().isNotEmpty
                          ? 'Auto-filled from postcode'
                          : null,
                      helperStyle: GoogleFonts.inter(
                          fontSize: 11, color: _green),
                      suffixIcon: _townController.text.trim().isNotEmpty
                          ? const Icon(Icons.check_circle_rounded,
                              color: _green, size: 20)
                          : null,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── 5. City (auto-filled from postcode mapping) ────────
                  _label('City *'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _cityController,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() {}),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'City is required'
                        : null,
                    style: _inputStyle(),
                    decoration: _fieldDec('e.g. London').copyWith(
                      helperText: _isPostcodeVerified &&
                              _cityController.text.trim().isNotEmpty
                          ? 'Auto-filled from postcode'
                          : null,
                      helperStyle: GoogleFonts.inter(
                          fontSize: 11, color: _green),
                      suffixIcon: _cityController.text.trim().isNotEmpty
                          ? const Icon(Icons.check_circle_rounded,
                              color: _green, size: 20)
                          : null,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── 6. Country ────────────────────────────────────────
                  _label('Country *'),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F6FA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCountry,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: Colors.grey),
                        style: _inputStyle(),
                        items: _countries
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCountry = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Invite Code (optional) ─────────────────────────────────
              _label('Got an invite code?'),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _inviteCodeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'e.g. GOAX72KP',
                        hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey[400]),
                        prefixIcon: const Icon(Icons.card_giftcard_rounded,
                            color: Color(0xFF0392CA), size: 18),
                        suffixIcon: _inviteCodeController.text.isNotEmpty
                            ? (_checkingCode
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 16, height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0392CA)),
                                    ))
                                : Icon(
                                    _codeValid ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                    color: _codeValid ? Colors.green : Colors.red,
                                    size: 20,
                                  ))
                            : null,
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF0392CA)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                      style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 2),
                      onChanged: (_) => setState(() { _codeValid = false; _referrerUid = null; }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _checkingCode ? null : _checkInviteCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0392CA),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text('Apply', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              if (_codeValid)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Invite code applied.',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.green[700], fontWeight: FontWeight.w600)),
                ),
              if (!_codeValid && _inviteCodeController.text.isNotEmpty && !_checkingCode)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Code not found. Check it and try again.',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.red[700])),
                ),

              const SizedBox(height: 16),

              // ── Terms & Conditions ─────────────────────────────────────
              GestureDetector(
                onTap: () => setState(() => _termsAccepted = !_termsAccepted),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _termsAccepted
                          ? _primary.withOpacity(0.4)
                          : Colors.grey[200]!,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Custom tick box
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _termsAccepted ? _primary : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _termsAccepted ? _primary : Colors.grey[400]!,
                            width: 1.5,
                          ),
                        ),
                        child: _termsAccepted
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 15)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.grey[700],
                                height: 1.6),
                            children: [
                              const TextSpan(text: 'I agree to the GoOuts '),
                              TextSpan(
                                text: 'Terms & Conditions',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _primary,
                                    decoration: TextDecoration.underline),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => _showLegalSheet(
                                        title: 'Terms & Conditions',
                                        content: _termsFromDb ?? _termsContent,
                                      ),
                              ),
                              const TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _primary,
                                    decoration: TextDecoration.underline),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => _showLegalSheet(
                                        title: 'Privacy Policy',
                                        content: _privacyFromDb ?? _privacyContent,
                                      ),
                              ),
                              const TextSpan(
                                  text:
                                      '. I confirm I am at least 16 years of age.'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Security note ──────────────────────────────────────────
              Row(
                children: [
                  const Icon(Icons.lock_outline_rounded,
                      size: 13, color: _primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Your details are encrypted and stored securely. Payment services provided by Stripe Payments Europe Ltd (FCA ref: 900461).',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: Colors.grey[500], height: 1.5),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Register button ────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _registerAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    disabledBackgroundColor: _primary.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : Text(
                    'Register Account',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Legal bottom sheet
  // ─────────────────────────────────────────────────────────────────────────
  void _showLegalSheet({required String title, required String content}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Title row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _dark),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.grey, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    content,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.7),
                  ),
                ),
              ),
              // Accept button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => _termsAccepted = true);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text(
                      'I Accept',
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
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

  static const String _termsContent = '''
GOOUTS LIMITED — TERMS & CONDITIONS OF SERVICE
Last Updated: May 2026 | Version 3.1
Registered in England & Wales

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

IMPORTANT — PLEASE READ CAREFULLY

By registering for a GoOuts account and ticking the acceptance box, you are entering into a legally binding agreement with GoOuts Technologies Limited ("GoOuts", "we", "us", "our"). These Terms govern your use of the GoOuts mobile application, wallet, cashback services, escrow facility, and advance facility. If you do not agree to these Terms in their entirety, you must not register or use our services.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PART 1 — DEFINITIONS

In these Terms, the following expressions shall have the meanings set out below:

"Account" means your registered GoOuts user account.

"Advance Facility" means the facility by which GoOuts may, at its sole discretion, release up to twenty-five percent (25%) of your Escrow Cashback Balance to your Wallet before the Escrow Release Date.

"Authorised Payment Method" means the debit card, credit card, or linked bank account you register with GoOuts and which you authorise us to charge in accordance with Clauses 8 and 9.

"Cashback" means the monetary reward, expressed as a percentage of a qualifying transaction amount, credited to your Wallet or Escrow Cashback Balance upon a verified purchase at a participating GoOuts Partner.

"Escrow Cashback Balance" means Cashback earnings that are held by GoOuts in a suspended state pending expiry of the applicable Return Window, as described in Part 4 of these Terms.

"Escrow Release Date" means the date falling fourteen (14) calendar days after the date of the qualifying transaction, on which Escrow Cashback is automatically transferred to your Wallet, provided no Return has been made.

"Partner" means a business that has entered into a commercial agreement with GoOuts to offer Cashback rewards to GoOuts account holders.

"Return" means the cancellation, reversal, refund, or return of a qualifying purchase for which Cashback or an Advance was issued.

"Return Window" means the period of fourteen (14) calendar days following a qualifying purchase during which a Return may be made.

"Wallet" means the GoOuts digital wallet associated with your Account, used to store, spend, and receive funds and Cashback.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PART 2 — ELIGIBILITY & REGISTRATION

2.1 You must be at least sixteen (16) years of age to register for a GoOuts account. Certain financial features may require you to be eighteen (18) or over, as stated within the app.

2.2 You must be a resident of the United Kingdom or such other jurisdiction as GoOuts may from time to time specify.

2.3 You must provide accurate, complete, and up-to-date information during registration. Providing false information constitutes a material breach of these Terms and may result in immediate account suspension, recovery of any Cashback paid, and referral to relevant authorities.

2.4 Each individual may hold only one GoOuts account. Creating duplicate accounts to gain additional Cashback is fraudulent and will result in permanent closure of all associated accounts.

2.5 GoOuts reserves the right to decline any registration application without giving reasons.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PART 3 — THE GOOUTS WALLET

3.1 The GoOuts Wallet allows you to hold funds, receive Cashback, and make payments at participating Partners.

3.2 Your GoOuts Wallet is powered by Stripe. Funds you add are held in a Stripe account in your name. GoOuts does not hold your money. Stripe Payments Europe Ltd (FCA ref: 900461) is the authorised payment institution. Payment providers may be updated from time to time; any change will be notified to you in advance.

3.3 You are responsible for maintaining the security of your four-digit PIN and login credentials. GoOuts will never request your PIN via email, telephone, SMS, or any channel other than the app's secure payment confirmation screen.

3.4 Monthly spending limits apply based on your verification tier:
  • Tier 1 (Registered): £500 per month
  • Tier 2 (Bank Linked): £1,000 per month
  • Tier 3 (KYC Verified): £2,000 per month

3.5 GoOuts reserves the right to freeze your Wallet if we reasonably suspect fraudulent activity, pending investigation.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PART 4 — ESCROW CASHBACK SCHEME

4.1 ESCROW CASHBACK — GENERAL

Where a qualifying purchase is made at a GoOuts Partner whose goods or services are subject to a statutory or contractual return right (including, without limitation, retail goods, fashion, electronics, or any product or service with a minimum fourteen-day return window) ("Return-Window Transaction"), the Cashback earned on that transaction shall not be credited directly to your Wallet.

4.2 ESCROW HOLDING PERIOD

4.2.1 Cashback earned on a Return-Window Transaction shall be held in your Escrow Cashback Balance for a period of fourteen (14) calendar days from the date of the qualifying transaction ("Escrow Period").

4.2.2 During the Escrow Period, you may view your Escrow Cashback Balance within the GoOuts app. Escrow funds are clearly identified and displayed separately from your available Wallet balance.

4.2.3 Escrow Cashback does not accrue interest during the Escrow Period and confers no property right until it is released to your Wallet on the Escrow Release Date.

4.3 AUTOMATIC RELEASE

4.3.1 On the Escrow Release Date (i.e., the fifteenth (15th) calendar day following the qualifying transaction), provided no Return has been notified to GoOuts in respect of that transaction, the Escrow Cashback shall be automatically transferred to your Wallet.

4.3.2 Release processing may take up to two (2) business hours from midnight on the Escrow Release Date. GoOuts will send you an in-app notification upon successful release.

4.4 ESCROW CASHBACK ON RETURNS

4.4.1 If you make a Return of a Return-Window Transaction during the Escrow Period:

  (a) The Escrow Cashback associated with that transaction shall be immediately cancelled and shall not be released to your Wallet.

  (b) If no Advance (as described in Part 5) has been drawn against that Escrow Cashback, you will owe nothing, and the matter is closed.

  (c) If an Advance has been drawn against that Escrow Cashback, the provisions of Clause 5.4 (Advance Clawback on Return) shall apply.

4.4.2 GoOuts may verify a Return by requesting confirmation from the relevant Partner. You agree to cooperate with any reasonable verification request.

4.4.3 Fraudulent Returns — including returns made for the purpose of retaining Cashback or an Advance — constitute fraud and may result in account closure, civil recovery proceedings, and reporting to law enforcement authorities.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PART 5 — CASHBACK ADVANCE FACILITY

5.1 AVAILABILITY OF ADVANCE

5.1.1 Subject to Clause 5.1.2, you may request a Cashback Advance of up to twenty-five percent (25%) of your total Escrow Cashback Balance at any time during the Escrow Period.

5.1.2 The Advance Facility is available at GoOuts' sole discretion. GoOuts may withdraw, suspend, or limit the Advance Facility at any time, including where:
  (a) you have a history of Returns;
  (b) your account is under investigation;
  (c) your linked Authorised Payment Method has failed or been removed; or
  (d) GoOuts determines, in its reasonable judgement, that your usage pattern presents an elevated risk.

5.1.3 The Advance Facility is not a regulated credit product. It constitutes a conditional, interest-free early release of a portion of your anticipated Cashback reward. No credit check is conducted and no interest, fees, or charges apply to the Advance itself.

5.2 INTEREST-FREE ADVANCE

5.2.1 GoOuts will not charge interest on any Advance.

5.2.2 There are no arrangement fees, processing fees, or administrative charges associated with taking an Advance.

5.2.3 The Advance amount shall be deducted from your Escrow Cashback Balance upon the Escrow Release Date (i.e., the Advance is recouped by GoOuts from the Cashback released on day 15).

Example: Your Escrow Cashback Balance is £40.00. You request a 25% Advance of £10.00. On the Escrow Release Date, £30.00 (£40.00 minus £10.00) is credited to your Wallet.

5.3 ADVANCE PAYMENT METHOD

5.3.1 The Advance will be credited directly to your GoOuts Wallet immediately upon approval.

5.3.2 You acknowledge that acceptance of an Advance constitutes your agreement to the clawback provisions set out in Clause 5.4.

5.4 ADVANCE CLAWBACK ON RETURN

5.4.1 DIRECT DEBIT AUTHORISATION — YOU MUST READ THIS CLAUSE CAREFULLY

By accepting these Terms and registering your Authorised Payment Method with GoOuts, you expressly and irrevocably authorise GoOuts to debit your Authorised Payment Method for the amount of any outstanding Advance in the circumstances described in this Clause 5.4.

5.4.2 If you make a Return of a Return-Window Transaction in respect of which an Advance has been paid:

  (a) The associated Escrow Cashback is cancelled in accordance with Clause 4.4.1.

  (b) The Advance amount that was paid to you (or such part of it as remains outstanding) becomes immediately due and repayable to GoOuts.

  (c) GoOuts will first attempt to deduct the outstanding Advance from any available Wallet balance.

  (d) If your Wallet balance is insufficient to cover the outstanding Advance in full, GoOuts will charge the shortfall amount to your Authorised Payment Method within five (5) business days of the Return being confirmed.

  (e) You will receive written notification (via in-app message and registered email) no less than forty-eight (48) hours before any charge is made to your Authorised Payment Method, except where GoOuts reasonably suspects fraud, in which case the charge may be made without prior notice.

5.4.3 Negative Escrow Balance: Where a Return causes the net position of your Escrow Cashback to fall below zero (i.e., the Advance paid exceeds the Cashback that would otherwise have been due), the resulting negative amount represents a debt owed by you to GoOuts, recoverable under Clause 5.4.2.

5.4.4 If your Authorised Payment Method fails or is declined, GoOuts reserves the right to:
  (a) suspend your Wallet and Advance Facility pending repayment;
  (b) offset the outstanding amount against future Cashback earnings;
  (c) refer the outstanding amount to a debt collection agency; and/or
  (d) pursue recovery through legal proceedings.

5.5 DISPUTES REGARDING ADVANCE CLAWBACK

If you believe a clawback has been applied in error, you must notify GoOuts in writing at disputes@goouts.co.uk within fourteen (14) calendar days of receiving the clawback notification. GoOuts will investigate and respond within ten (10) business days.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PART 6 — CASHBACK & REWARDS (GENERAL)

6.1 Cashback rates are set by individual Partners and are subject to change without notice. GoOuts will use reasonable endeavours to update the app promptly when rates change.

6.2 Cashback is earned only on verified transactions. A transaction is verified when both GPS proximity and QR code authentication checks are successfully completed within the GoOuts app at the time of payment.

6.3 Cashback will not be awarded on transactions that are subsequently identified as fraudulent, disputed, or in breach of a Partner's terms.

6.4 GoOuts reserves the right to reverse Cashback that has been incorrectly credited due to system error, Partner error, or fraudulent activity.

6.5 Cashback held in your Wallet has no expiry date, provided your account remains active. Accounts that have been inactive for twenty-four (24) consecutive months may be subject to account closure procedures, following thirty (30) days' written notice.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PART 7 — PAYMENT VERIFICATION & FRAUD PREVENTION

7.1 All in-store payments via the GoOuts app require dual verification: (a) GPS location confirmation that you are physically present at the Partner premises; and (b) scanning of the Partner's unique GoOuts QR code.

7.2 Attempting to circumvent, spoof, or manipulate either verification mechanism constitutes fraud and will result in immediate account suspension and potential prosecution.

7.3 GoOuts employs automated fraud detection systems. Unusual transaction patterns — including repeated Returns, GPS spoofing, and duplicate transactions — will trigger a security review.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PART 8 — AUTHORISED PAYMENT METHOD & DIRECT DEBIT MANDATE

8.1 By registering a payment method with GoOuts (debit card, credit card, or linked bank account), you authorise GoOuts to charge that payment method for:
  (a) wallet top-ups you initiate;
  (b) recovery of outstanding Advances as described in Clause 5.4; and
  (c) any other amounts legitimately owed to GoOuts under these Terms.

8.2 You must ensure your Authorised Payment Method remains valid and has sufficient funds. You agree to update your payment details promptly if they change.

8.3 GoOuts will store your payment details securely using PCI-DSS compliant infrastructure. We will never store your full card number.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PART 9 — KYC & IDENTITY VERIFICATION

9.1 GoOuts is required under the Money Laundering, Terrorist Financing and Transfer of Funds (Information on the Payer) Regulations 2017 to verify the identity of its users.

9.2 You agree to provide any documentation reasonably requested by GoOuts to complete identity verification, including but not limited to: government-issued photo ID, proof of address, and a biometric selfie.

9.3 Failure to complete identity verification within the requested timeframe may result in account restrictions, including suspension of the Wallet, Cashback, and Advance Facility.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PART 10 — ACCOUNT SUSPENSION & TERMINATION

10.1 GoOuts may suspend or terminate your account, with or without notice, if:
  (a) you breach any provision of these Terms;
  (b) we reasonably suspect fraud, money laundering, or misuse;
  (c) you provide false or misleading information;
  (d) a Return pattern suggests systematic abuse of the Advance Facility; or
  (e) we are required to do so by law or regulatory authority.

10.2 Upon termination, any Wallet balance (excluding Escrow Cashback subject to ongoing investigation) will be returned to you via your Authorised Payment Method within ten (10) business days, subject to any outstanding debts owed to GoOuts being deducted first.

10.3 You may close your account at any time by contacting support@goouts.co.uk, provided there are no outstanding Advances or negative balances.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PART 11 — LIMITATION OF LIABILITY

11.1 GoOuts shall not be liable for any indirect, consequential, special, or punitive loss arising from your use of the app or services.

11.2 Our total aggregate liability to you for any direct loss shall not exceed the total Cashback credited to your account in the twelve (12) months preceding the claim.

11.3 Nothing in these Terms excludes liability for death or personal injury caused by GoOuts' negligence, fraud, or fraudulent misrepresentation.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PART 12 — CHANGES TO TERMS

12.1 GoOuts reserves the right to amend these Terms at any time. Where changes are material — in particular changes to the Escrow, Advance Facility, or clawback provisions — we will provide no less than thirty (30) days' notice via in-app notification and registered email.

12.2 Your continued use of the GoOuts app after the notice period constitutes acceptance of the revised Terms.

12.3 If you do not accept the revised Terms, you must close your account before the revised Terms take effect.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PART 13 — GOVERNING LAW & DISPUTES

13.1 These Terms are governed by and construed in accordance with the laws of England and Wales.

13.2 Any dispute arising out of or in connection with these Terms shall be subject to the exclusive jurisdiction of the courts of England and Wales.

13.3 Before commencing legal proceedings, you agree to attempt to resolve any dispute with GoOuts through our internal complaints procedure by writing to complaints@goouts.co.uk.

13.4 If you are not satisfied with our response, you may refer your complaint to the Financial Ombudsman Service (where applicable) or seek independent legal advice.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CONTACT

GoOuts Technologies Limited
support@goouts.co.uk
disputes@goouts.co.uk
complaints@goouts.co.uk

Registered in England & Wales
GoOuts Technologies Limited operates as a Technical Service Provider under Schedule 1, Part 2(j) of the UK Payment Services Regulations 2017.
Payment services provided by Stripe Payments Europe Ltd (FCA ref: 900461).

These Terms were last reviewed and approved by GoOuts Legal, June 2026.
''';

  static const String _privacyContent = '''
1. Information We Collect
We collect information you provide during registration (name, email, date of birth, address), transaction data, and device information to operate and improve our services.

2. How We Use Your Data
Your data is used to:
• Operate your GoOuts account
• Process transactions and cashback
• Comply with legal and regulatory obligations (KYC/AML)
• Send important account notifications
• Personalise your experience

3. Data Sharing
We do not sell your personal data. We may share data with:
• Regulated identity verification partners (e.g. Sumsub)
• Payment processors (e.g. Stripe)
• Regulatory authorities when required by law

4. Data Security
All data is encrypted in transit and at rest. We use industry-standard security measures to protect your information.

5. Data Retention
We retain your data for as long as your account is active and for up to 7 years after closure as required by financial regulations.

6. Your Rights
You have the right to access, correct, or delete your personal data. To exercise these rights, contact privacy@goouts.co.uk.

7. Cookies
Our app uses analytics cookies to improve performance. You can manage cookie preferences in your device settings.

8. Contact
For privacy queries: privacy@goouts.co.uk

GoOuts is registered with the Information Commissioner's Office (ICO).
Last updated: May 2025
''';

  // ─────────────────────────────────────────────────────────────────────────
  // Shared widgets
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStepIndicator() => Row(
        children: [
          _stepDot(1, done: true),
          _stepLine(),
          _stepDot(2, active: true),
        ],
      );

  Widget _stepDot(int step, {bool active = false, bool done = false}) => Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: done
                  ? _green
                  : active
                      ? _primary
                      : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: done
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 16)
                  : Text(
                      '$step',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: active ? Colors.white : Colors.grey[500],
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            step == 1 ? 'Profile Photo' : 'Your Details',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: active || done ? FontWeight.w700 : FontWeight.w400,
              color: active || done ? _dark : Colors.grey[400],
            ),
          ),
        ],
      );

  Widget _stepLine() => Expanded(
        child: Container(
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          color: _green,
        ),
      );

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _dark,
        ),
      );

  TextStyle _inputStyle() => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _dark,
      );

  InputDecoration _fieldDec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 14, color: Colors.grey[400]),
        filled: true,
        fillColor: const Color(0xFFF0F6FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: _primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      );
}
