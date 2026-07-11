import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/address_lookup_service.dart';
import '../services/delivery_address_service.dart';

/// Delivery address picker for GoOuts Food.
///
/// Flow:
///   1. GPS — tap "Use my location" → geolocator → Mapbox reverse geocode
///   2. Postcode search — enter postcode → Mapbox validates →
///      user types house number + street → confirm
///   3. Current address shown if already saved
///
/// Returns via [Navigator.pop] after saving to [DeliveryAddressService].
class FoodAddressPickerScreen extends StatefulWidget {
  const FoodAddressPickerScreen({super.key});

  @override
  State<FoodAddressPickerScreen> createState() =>
      _FoodAddressPickerScreenState();
}

class _FoodAddressPickerScreenState extends State<FoodAddressPickerScreen> {
  static const Color _primary = Color(0xFF0392CA);
  static const Color _dark    = Color(0xFF0D1B3E);
  static const Color _green   = Color(0xFF10B981);

  final _postcodeCtrl  = TextEditingController();
  final _houseNoCtrl   = TextEditingController();
  final _streetCtrl    = TextEditingController();
  final _service       = AddressLookupService();
  final _addrService   = DeliveryAddressService();

  bool _gpsLoading      = false;
  bool _searchLoading   = false;
  bool _postcodeVerified = false;
  String? _error;
  MapboxAddressResult? _mapboxResult;

  @override
  void dispose() {
    _postcodeCtrl.dispose();
    _houseNoCtrl.dispose();
    _streetCtrl.dispose();
    super.dispose();
  }

  // ── GPS flow ─────────────────────────────────────────────────────────────

  Future<void> _useGPS() async {
    setState(() { _gpsLoading = true; _error = null; });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() {
          _error = 'Location services are turned off. Enable them in Settings.';
          _gpsLoading = false;
        });
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        if (mounted) setState(() {
          _error = 'Location permission denied. Please enable it in Settings.';
          _gpsLoading = false;
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final result = await _service.reverseGeocode(pos.latitude, pos.longitude);

      final addr = DeliveryAddress(
        label: 'Current location',
        line1: result?.fullAddress.split(',').first.trim() ?? 'Your location',
        line2: result?.city ?? '',
        postcode: result?.postcode ?? '',
        latitude: pos.latitude,
        longitude: pos.longitude,
      );

      await _addrService.setAddress(addr);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() {
        _error = 'Could not get your location. Please search by postcode.';
      });
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  // ── Postcode lookup ───────────────────────────────────────────────────────

  Future<void> _lookupPostcode() async {
    final pc = _postcodeCtrl.text.trim();
    if (pc.isEmpty) return;

    setState(() {
      _searchLoading = true;
      _error = null;
      _postcodeVerified = false;
      _mapboxResult = null;
      _houseNoCtrl.clear();
      _streetCtrl.clear();
    });

    final result = await _service.validatePostcode(pc);
    if (!mounted) return;

    if (result == null) {
      setState(() {
        _error = 'Postcode "$pc" not found. Please check and try again.';
        _searchLoading = false;
      });
      return;
    }

    setState(() {
      _mapboxResult = result;
      _postcodeCtrl.text = result.postcode;
      _postcodeVerified = true;
      _searchLoading = false;
    });
  }

  // ── Confirm address ───────────────────────────────────────────────────────

  Future<void> _confirmAddress() async {
    final mb = _mapboxResult;
    if (mb == null) return;

    final houseNo = _houseNoCtrl.text.trim();
    final street  = _streetCtrl.text.trim();
    if (houseNo.isEmpty || street.isEmpty) {
      setState(() => _error = 'Please enter your house number and street name.');
      return;
    }

    final line1 = '$houseNo $street'.trim();
    final addr = DeliveryAddress(
      label: line1,
      line1: line1,
      line2: mb.city,
      postcode: mb.postcode,
      latitude: mb.latitude,
      longitude: mb.longitude,
    );

    await _addrService.setAddress(addr);
    if (mounted) Navigator.pop(context);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Deliver to',
          style: GoogleFonts.inter(
              fontSize: 18, fontWeight: FontWeight.w700, color: _dark),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── GPS button ──────────────────────────────────────────────────
          _GpsButton(loading: _gpsLoading, onTap: _useGPS),

          const SizedBox(height: 16),

          // ── Divider ─────────────────────────────────────────────────────
          Row(children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('or enter postcode',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
            ),
            const Expanded(child: Divider()),
          ]),

          const SizedBox(height: 16),

          // ── Postcode search ─────────────────────────────────────────────
          Row(children: [
            Expanded(
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Row(children: [
                  const SizedBox(width: 14),
                  Icon(
                    _postcodeVerified
                        ? Icons.check_circle_rounded
                        : Icons.search_rounded,
                    color: _postcodeVerified ? _green : Colors.grey[400],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _postcodeCtrl,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 ]')),
                        LengthLimitingTextInputFormatter(8),
                      ],
                      decoration: InputDecoration(
                        hintText: 'e.g. SW1A 1AA',
                        hintStyle: GoogleFonts.inter(
                            fontSize: 14, color: Colors.grey[400]),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => _lookupPostcode(),
                      onChanged: (_) {
                        if (_postcodeVerified) {
                          setState(() {
                            _postcodeVerified = false;
                            _mapboxResult = null;
                          });
                        }
                      },
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _searchLoading ? null : _lookupPostcode,
              child: Container(
                height: 50,
                width: 80,
                decoration: BoxDecoration(
                  color: _postcodeVerified ? _green : _primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: _searchLoading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(
                        _postcodeVerified ? 'OK ✓' : 'Find',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
              ),
            ),
          ]),

          // ── Error ────────────────────────────────────────────────────────
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded,
                    color: Color(0xFFDC2626), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!,
                      style: GoogleFonts.inter(
                          fontSize: 13, color: const Color(0xFFDC2626))),
                ),
              ]),
            ),
          ],

          // ── Address detail form (after postcode verified) ─────────────
          if (_postcodeVerified && _mapboxResult != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _green.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.check_circle_rounded,
                        color: _green, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Postcode confirmed: ${_mapboxResult!.postcode}',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _green),
                    ),
                  ]),
                  if (_mapboxResult!.city.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.only(left: 26),
                      child: Text(
                        _mapboxResult!.city,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: Colors.grey[500]),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  // House No
                  Text('House / Flat Number *',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _dark)),
                  const SizedBox(height: 6),
                  _inputField(
                    controller: _houseNoCtrl,
                    hint: 'e.g. 12 or Flat 3A',
                  ),
                  const SizedBox(height: 12),
                  // Street
                  Text('Street / Road Name *',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _dark)),
                  const SizedBox(height: 6),
                  _inputField(
                    controller: _streetCtrl,
                    hint: 'e.g. High Street',
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _confirmAddress,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(
                        'Use This Address',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Current address ───────────────────────────────────────────────
          if (_addrService.hasAddress && !_postcodeVerified) ...[
            const SizedBox(height: 24),
            Text(
              'CURRENT ADDRESS',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                  letterSpacing: 1.0),
            ),
            const SizedBox(height: 8),
            _CurrentAddressTile(
              address: _addrService.current!,
              primaryColor: _green,
            ),
          ],

          // ── Tip ───────────────────────────────────────────────────────────
          if (!_postcodeVerified) ...[
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF8FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded,
                    color: _primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'We use your postcode to show you restaurants that deliver to your area and give you accurate delivery times.',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF0369A1),
                        height: 1.5),
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
      style: GoogleFonts.inter(fontSize: 14, color: _dark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 14, color: Colors.grey[400]),
        filled: true,
        fillColor: const Color(0xFFF0F6FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      onChanged: (_) => setState(() {}),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _GpsButton extends StatelessWidget {
  const _GpsButton({required this.loading, required this.onTap});
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF0392CA).withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(children: [
          const SizedBox(width: 16),
          Container(
            width: 36, height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF8FF), shape: BoxShape.circle),
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                        color: Color(0xFF0392CA), strokeWidth: 2))
                : const Icon(Icons.my_location_rounded,
                    color: Color(0xFF0392CA), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Use my current location',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0D1B3E))),
                Text("We'll find restaurants near you automatically",
                    style: GoogleFonts.inter(
                        fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: Colors.grey, size: 20),
          const SizedBox(width: 12),
        ]),
      ),
    );
  }
}

class _CurrentAddressTile extends StatelessWidget {
  const _CurrentAddressTile(
      {required this.address, required this.primaryColor});
  final DeliveryAddress address;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(Icons.check_circle_rounded, color: primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(address.line1.isNotEmpty ? address.line1 : address.label,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0D1B3E))),
              if (address.line2.isNotEmpty || address.postcode.isNotEmpty)
                Text(
                    [address.line2, address.postcode]
                        .where((s) => s.isNotEmpty)
                        .join(', '),
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.grey[500])),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('Active',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: primaryColor)),
        ),
      ]),
    );
  }
}
