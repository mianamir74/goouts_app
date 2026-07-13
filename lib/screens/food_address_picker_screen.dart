import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/address_lookup_service.dart';
import '../services/delivery_address_service.dart';

/// Delivery address picker for GoOuts Food.
///
/// Flow:
///   1. GPS — tap "Use my location" → geolocator → Mapbox reverse geocode (1 call)
///   2. Search — type any part of address → free suggest calls → tap suggestion
///      → ONE retrieve call (session token bundles all suggest calls for free)
///   3. Current address shown if already saved
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

  // ── Controllers & services ────────────────────────────────────────────────
  final _searchCtrl  = TextEditingController();
  final _service     = AddressLookupService();
  final _addrService = DeliveryAddressService();

  // ── Session token for Mapbox billing ──────────────────────────────────────
  // All suggest() calls sharing this token are FREE.
  // Only the matching retrieve() call is billed (one session = one charge).
  String _sessionToken = AddressLookupService.generateSessionToken();

  // ── State ─────────────────────────────────────────────────────────────────
  bool _gpsLoading     = false;
  bool _retrieving     = false;
  String? _error;
  List<MapboxSuggestResult> _suggestions = [];
  MapboxAddressResult? _confirmedAddress;
  Timer? _debounce;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── GPS flow ──────────────────────────────────────────────────────────────

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
        _error = 'Could not get your location. Please search your address below.';
      });
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  // ── Address search (session token: suggest = free, retrieve = 1 paid call) ─

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await _service.suggest(query, _sessionToken);
      if (mounted) setState(() => _suggestions = results);
    });
  }

  Future<void> _selectSuggestion(MapboxSuggestResult suggestion) async {
    _debounce?.cancel();
    setState(() {
      _retrieving  = true;
      _suggestions = [];
    });

    // retrieve() is the ONE paid call — all the suggest() calls above were free
    final result = await _service.retrieve(suggestion.mapboxId, _sessionToken);

    // Always start a fresh session token after retrieve (next search = new session)
    _sessionToken = AddressLookupService.generateSessionToken();

    if (!mounted) return;
    if (result == null) {
      setState(() {
        _retrieving = false;
        _error = 'Could not get address details. Please try again.';
      });
      return;
    }

    setState(() {
      _retrieving      = false;
      _confirmedAddress = result;
      _error            = null;
    });
    _searchCtrl.clear();
  }

  void _resetSearch() {
    setState(() {
      _confirmedAddress = null;
      _suggestions      = [];
      _error            = null;
    });
    _searchCtrl.clear();
    // New session for next search
    _sessionToken = AddressLookupService.generateSessionToken();
  }

  // ── Confirm and save address ──────────────────────────────────────────────

  Future<void> _confirmAddress() async {
    final addr = _confirmedAddress;
    if (addr == null) return;

    final houseNo = addr.houseNumber ?? '';
    final street  = addr.street ?? '';
    final line1   = houseNo.isNotEmpty
        ? '\$houseNo \$street'.trim()
        : addr.fullAddress.split(',').first.trim();

    final delivery = DeliveryAddress(
      label: line1,
      line1: line1,
      line2: addr.town ?? addr.city,
      postcode: addr.postcode,
      latitude: addr.latitude,
      longitude: addr.longitude,
    );

    await _addrService.setAddress(delivery);
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
          // ── GPS button ────────────────────────────────────────────────────
          _GpsButton(loading: _gpsLoading, onTap: _useGPS),

          const SizedBox(height: 16),

          // ── Divider ───────────────────────────────────────────────────────
          Row(children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('or search your address',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
            ),
            const Expanded(child: Divider()),
          ]),

          const SizedBox(height: 16),

          // ── Address search field ──────────────────────────────────────────
          Container(
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
                _confirmedAddress != null
                    ? Icons.check_circle_rounded
                    : Icons.search_rounded,
                color: _confirmedAddress != null
                    ? _green
                    : Colors.grey[400],
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  keyboardType: TextInputType.streetAddress,
                  textCapitalization: TextCapitalization.words,
                  style: GoogleFonts.inter(fontSize: 14, color: _dark),
                  decoration: InputDecoration(
                    hintText: 'e.g. 12 East Hill or SW1A 1AA',
                    hintStyle: GoogleFonts.inter(
                        fontSize: 14, color: Colors.grey[400]),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
              if (_retrieving)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: _primary, strokeWidth: 2),
                  ),
                )
              else if (_searchCtrl.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: Colors.grey, size: 18),
                  onPressed: _resetSearch,
                ),
            ]),
          ),

          // ── Suggestions list ──────────────────────────────────────────────
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ],
              ),
              child: Column(
                children: List.generate(_suggestions.length, (i) {
                  final s = _suggestions[i];
                  return InkWell(
                    onTap: () => _selectSuggestion(s),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(children: [
                        const Icon(Icons.location_on_outlined,
                            color: _primary, size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.name,
                                style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _dark),
                              ),
                              Text(
                                s.placeFormatted,
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: Colors.grey, size: 16),
                      ]),
                    ),
                  );
                }),
              ),
            ),
          ],

          // ── Error ─────────────────────────────────────────────────────────
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

          // ── Confirmed address card ─────────────────────────────────────────
          if (_confirmedAddress != null) ...[
            const SizedBox(height: 16),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: _green, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _confirmedAddress!.fullAddress
                                  .split(',')
                                  .take(2)
                                  .join(','),
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _dark),
                            ),
                            if (_confirmedAddress!.postcode.isNotEmpty)
                              Text(
                                _confirmedAddress!.postcode,
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: Colors.grey[500]),
                              ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _resetSearch,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(40, 32),
                        ),
                        child: Text(
                          'Change',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _primary),
                        ),
                      ),
                    ],
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

          // ── Current saved address ─────────────────────────────────────────
          if (_addrService.hasAddress && _confirmedAddress == null &&
              _suggestions.isEmpty) ...[
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
          if (_confirmedAddress == null && _suggestions.isEmpty) ...[
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
                    'Start typing your house number, street, or postcode to search your address.',
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
