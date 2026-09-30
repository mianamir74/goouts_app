import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/address_lookup_service.dart';
import '../services/delivery_address_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Inline "Where to deliver?" address search field.
//
//  ⚠ ADDED 10 September 2026, replacing the standalone /food-address-picker
//  page (removed the same day — this is now the ONLY way to set a delivery
//  address, everywhere it can be set from).
//
//  Uses the exact same AddressLookupService (Mapbox) the profile
//  registration postcode lookup uses — free-text suggest() calls as the
//  user types (bundled under one session token, free), ONE paid retrieve()
//  call when they tap a suggestion. Same billing pattern, just inline
//  instead of behind a full page.
// ─────────────────────────────────────────────────────────────────────────────
class DeliveryAddressField extends StatefulWidget {
  const DeliveryAddressField({
    super.key,
    this.autofocus = false,
    this.textColor = const Color(0xFF0D1B3E),
    this.hintColor,
    this.iconColor = Colors.black54,
    this.fontSize = 15,
    this.onSelected,
  });

  final bool autofocus;
  final Color textColor;
  final Color? hintColor;
  final Color iconColor;
  final double fontSize;

  /// Called after an address is successfully picked and saved.
  /// Callers showing this inside a bottom sheet/dialog use this to close it.
  final VoidCallback? onSelected;

  @override
  State<DeliveryAddressField> createState() => _DeliveryAddressFieldState();
}

class _DeliveryAddressFieldState extends State<DeliveryAddressField> {
  static const Color _primary = Color(0xFF0392CA);

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  final AddressLookupService _service = AddressLookupService();
  final DeliveryAddressService _addrService = DeliveryAddressService();

  String _sessionToken = AddressLookupService.generateSessionToken();
  Timer? _debounce;
  List<MapboxSuggestResult> _suggestions = <MapboxSuggestResult>[];
  bool _retrieving = false;
  bool _showNoToken = false;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _removeOverlay();
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      // Small delay so a tap on a suggestion (which briefly steals focus
      // via its own gesture) registers before the overlay is torn down.
      Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted && !_focusNode.hasFocus) _removeOverlay();
      });
    }
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() => _suggestions = <MapboxSuggestResult>[]);
      _updateOverlay();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (!AddressLookupService.hasToken) {
        if (mounted) setState(() => _showNoToken = true);
        _updateOverlay();
        return;
      }
      final results = await _service.suggest(query, _sessionToken);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _showNoToken = false;
      });
      _updateOverlay();
    });
  }

  Future<void> _selectSuggestion(MapboxSuggestResult s) async {
    setState(() {
      _retrieving = true;
      _suggestions = <MapboxSuggestResult>[];
    });
    _updateOverlay();

    final result = await _service.retrieve(s.mapboxId, _sessionToken);
    _sessionToken = AddressLookupService.generateSessionToken();
    if (!mounted) return;

    setState(() => _retrieving = false);

    if (result == null) {
      _removeOverlay();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not load that address — please try again.')),
      );
      return;
    }

    final String houseNo = result.houseNumber ?? '';
    final String street = result.street ?? '';
    final String line1 = houseNo.isNotEmpty
        ? '$houseNo $street'.trim()
        : result.fullAddress.split(',').first.trim();

    await _addrService.setAddress(DeliveryAddress(
      label: line1,
      line1: line1,
      line2: result.town ?? result.city,
      postcode: result.postcode,
      latitude: result.latitude,
      longitude: result.longitude,
    ));

    _controller.clear();
    _removeOverlay();
    _focusNode.unfocus();
    widget.onSelected?.call();
  }

  // ── Dropdown overlay ─────────────────────────────────────────────────────
  void _updateOverlay() {
    _removeOverlay();
    if (_suggestions.isEmpty && !_retrieving && !_showNoToken) return;

    final RenderBox? box =
        _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final double width = box.size.width;
    final double height = box.size.height;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, height + 6),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: _buildDropdownContent(),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildDropdownContent() {
    if (_retrieving) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    }
    if (_showNoToken) {
      // ⚠ Flag, don't fake — this only surfaces if the app was built
      // without --dart-define=MAPBOX_TOKEN=<token>. See
      // address_lookup_service.dart for why the token isn't hardcoded.
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Address search is temporarily unavailable.',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      itemCount: _suggestions.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
      itemBuilder: (context, i) {
        final s = _suggestions[i];
        return InkWell(
          onTap: () => _selectSuggestion(s),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 18, color: _primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(s.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0D1B3E))),
                      if (s.placeFormatted.isNotEmpty)
                        Text(s.placeFormatted,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Row(
        key: _fieldKey,
        children: [
          Icon(Icons.location_on_outlined, color: widget.iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: ListenableBuilder(
              listenable: _addrService,
              builder: (context, _) {
                final addr = _addrService.current;
                return TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: widget.autofocus,
                  onChanged: _onChanged,
                  style: GoogleFonts.inter(
                      fontSize: widget.fontSize, color: widget.textColor),
                  decoration: InputDecoration(
                    // ⚠ Current address (when set) is shown as the HINT, not
                    // pre-filled controller text — typing immediately starts
                    // a fresh search rather than needing to select-all and
                    // overwrite existing text first.
                    //
                    // ⚠ TEXT CHANGED 10 September 2026, requested directly
                    // — was 'Where to deliver?'.
                    hintText:
                        addr?.shortDisplay ?? 'Enter your address',
                    hintStyle: GoogleFonts.inter(
                        fontSize: widget.fontSize,
                        color: widget.hintColor ??
                            (addr != null
                                ? widget.textColor
                                : Colors.grey[500]),
                        fontWeight:
                            addr != null ? FontWeight.w600 : FontWeight.w400),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Modal entry point for compact "closed" address chips (mobile app bar,
//  mobile banner, desktop small chip) — opens a sheet with the same field,
//  autofocused, instead of the removed full-page picker.
// ─────────────────────────────────────────────────────────────────────────────
Future<void> showDeliveryAddressSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
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
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 18),
                Text('Where to deliver?',
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0D1B3E))),
                const SizedBox(height: 4),
                Text('Search by address or postcode.',
                    style:
                        GoogleFonts.inter(fontSize: 12, color: Colors.grey[500])),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F6FA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: DeliveryAddressField(
                    autofocus: true,
                    onSelected: () => Navigator.of(sheetContext).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
