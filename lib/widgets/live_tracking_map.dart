import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  LiveTrackingMap
//  Shows a Google Map with:
//    - Driver marker that GLIDES between the ~4 s RTDB updates and turns to
//      face its direction of travel (added 7 October 2026 - see _glideTo)
//    - Restaurant pin (orange)
//    - Customer delivery pin (green)
//    - Dashed route polyline between them
//
//  Usage:
//    LiveTrackingMap(
//      orderId: 'abc123',
//      restaurantLocation: GeoPoint(51.51, -0.12),
//      deliveryLocation:   GeoPoint(51.52, -0.11),
//    )
// ─────────────────────────────────────────────────────────────────────────────

class LiveTrackingMap extends StatefulWidget {
  final String    orderId;
  final GeoPoint? restaurantLocation;
  final GeoPoint? deliveryLocation;
  final String?   restaurantName;
  final double    height;

  const LiveTrackingMap({
    super.key,
    required this.orderId,
    this.restaurantLocation,
    this.deliveryLocation,
    this.restaurantName,
    this.height = 260,
  });

  @override
  State<LiveTrackingMap> createState() => _LiveTrackingMapState();
}

class _LiveTrackingMapState extends State<LiveTrackingMap>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;

  StreamSubscription? _rtdbSub;
  LatLng? _driverLatLng;      // where the marker is DRAWN right now
  double  _driverBearing = 0; // degrees, which way the marker is DRAWN facing
  bool    _driverOnline  = false;

  // ── Glide animation, ADDED 7 October 2026 ───────────────────────────────
  //
  // The driver app writes a position every 4 seconds. Drawing each one as it
  // arrives makes the marker jump. Instead the marker is animated from where
  // it is drawn now to the new position over roughly one update interval, and
  // turned (shortest way round) to the new heading - the same thing the big
  // delivery apps do rather than sending positions more often, which would
  // cost the driver battery and data for the same visual result.
  static const _glideDuration = Duration(milliseconds: 3800);
  // Further than this in one update is a GPS correction or a reconnect, not
  // driving - snap instead of sliding across the map.
  static const _snapBeyondMetres = 600.0;

  late final AnimationController _glide;
  LatLng? _fromPos;
  LatLng? _toPos;
  double  _fromBearing = 0;
  double  _toBearing   = 0;
  BitmapDescriptor? _driverIcon;

  final Set<Marker>   _markers   = {};
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _glide = AnimationController(vsync: this, duration: _glideDuration)
      ..addListener(_onGlideTick);
    _buildStaticMarkers();
    _loadDriverIcon();
    _subscribeDriver();
  }

  @override
  void dispose() {
    _rtdbSub?.cancel();
    _glide.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Static restaurant + customer markers ────────────────────────────────
  void _buildStaticMarkers() {
    final restGeo = widget.restaurantLocation;
    final custGeo = widget.deliveryLocation;
    final pts     = <LatLng>[];

    if (restGeo != null) {
      final pos = LatLng(restGeo.latitude, restGeo.longitude);
      pts.add(pos);
      _markers.add(Marker(
        markerId: const MarkerId('restaurant'),
        position: pos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(title: widget.restaurantName ?? 'Restaurant'),
      ));
    }
    if (custGeo != null) {
      final pos = LatLng(custGeo.latitude, custGeo.longitude);
      pts.add(pos);
      _markers.add(Marker(
        markerId: const MarkerId('customer'),
        position: pos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Your location'),
      ));
    }

    if (pts.length == 2) {
      _polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: pts,
        color: const Color(0xFFEA580C),
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ));
    }
  }

  // ── Listen to driver location in RTDB ───────────────────────────────────
  void _subscribeDriver() {
    final ref = FirebaseDatabase.instance
        .ref('active_deliveries/${widget.orderId}/driver_location');

    _rtdbSub = ref.onValue.listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value;
      if (data == null) {
        setState(() => _driverOnline = false);
        return;
      }

      final map     = Map<String, dynamic>.from(data as Map);
      final lat     = (map['lat']     as num?)?.toDouble();
      final lng     = (map['lng']     as num?)?.toDouble();
      final bearing = (map['bearing'] as num?)?.toDouble() ?? 0;

      if (lat == null || lng == null) return;

      final speed   = (map['speed'] as num?)?.toDouble() ?? 0;
      final newPos  = LatLng(lat, lng);

      // A phone standing still reports a meaningless heading (often 0), which
      // would spin the marker to face north at every red light. Keep the last
      // real heading unless the driver is actually moving.
      final newBearing = speed > 1.0 ? bearing : _toBearing;

      _glideTo(newPos, newBearing);

      // Smoothly pan map to keep driver visible
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(newPos),
      );
    });
  }

  void _glideTo(LatLng target, double bearing) {
    final current = _driverLatLng;
    final firstFix = current == null;
    final tooFar = !firstFix &&
        _metresBetween(current, target) > _snapBeyondMetres;

    _toPos     = target;
    _toBearing = bearing;

    if (firstFix || tooFar) {
      _glide.stop();
      _fromPos     = target;
      _fromBearing = bearing;
      setState(() {
        _driverOnline = true;
        _drawDriver(target, bearing);
      });
      return;
    }

    // Start from wherever the marker is drawn NOW, so an update that lands
    // mid-glide continues smoothly instead of jumping back.
    _fromPos     = current;
    _fromBearing = _driverBearing;
    if (!_driverOnline) setState(() => _driverOnline = true);
    _glide.forward(from: 0);
  }

  void _onGlideTick() {
    final from = _fromPos;
    final to   = _toPos;
    if (!mounted || from == null || to == null) return;
    final t = _glide.value;
    final pos = LatLng(
      from.latitude  + (to.latitude  - from.latitude)  * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
    // Turn the short way round (350 -> 10 degrees is +20, not -340), and
    // finish the turn in the first third of the glide so the marker faces
    // where it is going rather than rotating all the way along.
    final delta = ((_toBearing - _fromBearing + 540) % 360) - 180;
    final turn  = (t * 3).clamp(0.0, 1.0);
    final bearing = (_fromBearing + delta * turn + 360) % 360;
    setState(() => _drawDriver(pos, bearing));
  }

  /// Replaces the driver marker. Call inside setState.
  void _drawDriver(LatLng pos, double bearing) {
    _driverLatLng  = pos;
    _driverBearing = bearing;
    _markers.removeWhere((m) => m.markerId.value == 'driver');
    _markers.add(Marker(
      markerId: const MarkerId('driver'),
      position: pos,
      rotation: bearing,
      icon: _driverIcon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      infoWindow: const InfoWindow(title: 'Your driver'),
      flat: true,
      anchor: const Offset(0.5, 0.5),
      zIndexInt: 2,
    ));
  }

  double _metresBetween(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final la1 = a.latitude * math.pi / 180;
    final la2 = b.latitude * math.pi / 180;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(la1) * math.cos(la2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * r * math.asin(math.min(1.0, math.sqrt(h)));
  }

  // A round GoOuts-blue marker with a white arrow pointing "up", so rotating
  // it by the driver's heading makes the arrow point the way they are going.
  // The stock teardrop pin has no front, so rotating it meant nothing.
  Future<void> _loadDriverIcon() async {
    try {
      final dpr = WidgetsBinding
          .instance.platformDispatcher.views.first.devicePixelRatio;
      final size = (46 * dpr).roundToDouble();
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      final centre = Offset(size / 2, size / 2);
      final radius = size / 2;
      c.drawCircle(centre, radius * 0.96,
          Paint()..color = const Color(0x33000000)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      c.drawCircle(centre, radius * 0.86, Paint()..color = Colors.white);
      c.drawCircle(centre, radius * 0.72,
          Paint()..color = const Color(0xFF0392CA));
      final arrow = Path()
        ..moveTo(centre.dx, centre.dy - radius * 0.46)
        ..lineTo(centre.dx + radius * 0.34, centre.dy + radius * 0.36)
        ..lineTo(centre.dx, centre.dy + radius * 0.16)
        ..lineTo(centre.dx - radius * 0.34, centre.dy + radius * 0.36)
        ..close();
      c.drawPath(arrow, Paint()..color = Colors.white);
      final img = await rec.endRecording().toImage(size.toInt(), size.toInt());
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      if (data == null || !mounted) return;
      final Uint8List bytes = data.buffer.asUint8List();
      // imagePixelRatio makes it draw at 46 logical px on every screen.
      final icon = BitmapDescriptor.bytes(bytes, imagePixelRatio: dpr);
      setState(() {
        _driverIcon = icon;
        final pos = _driverLatLng;
        if (pos != null) _drawDriver(pos, _driverBearing);
      });
    } catch (_) {
      // Falls back to the stock blue pin - the map still works.
    }
  }

  LatLng get _initialCenter {
    if (widget.restaurantLocation != null) {
      return LatLng(widget.restaurantLocation!.latitude,
                    widget.restaurantLocation!.longitude);
    }
    if (widget.deliveryLocation != null) {
      return LatLng(widget.deliveryLocation!.latitude,
                    widget.deliveryLocation!.longitude);
    }
    return const LatLng(51.5074, -0.1278); // London default
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _initialCenter,
                zoom: 14,
              ),
              markers: Set.from(_markers),
              polylines: Set.from(_polylines),
              myLocationEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
              // controller.setMapStyle() is deprecated — the style is now
              // passed declaratively via GoogleMap.style.
              style: _lightMapStyle,
              onMapCreated: (ctrl) {
                _mapController = ctrl;
              },
            ),

            // Driver status pill
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _driverOnline
                      ? const Color(0xFF10B981)
                      : Colors.grey[700],
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 6)
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _driverOnline ? Icons.delivery_dining : Icons.hourglass_empty,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _driverOnline ? 'Driver on the way' : 'Locating driver...',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),

            // Re-centre button
            Positioned(
              bottom: 12,
              right: 12,
              child: GestureDetector(
                onTap: () {
                  if (_driverLatLng != null) {
                    _mapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(_driverLatLng!, 15),
                    );
                  }
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: const Icon(Icons.my_location, size: 20, color: Color(0xFFEA580C)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Light map style (clean delivery look) ────────────────────────────────────
const _lightMapStyle = '''[
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#f8c471"}]},
  {"featureType":"landscape","elementType":"geometry","stylers":[{"color":"#f5f5f0"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#b3d9f2"}]}
]''';
