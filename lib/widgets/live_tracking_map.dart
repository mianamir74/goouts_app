import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  LiveTrackingMap
//  Shows a Google Map with:
//    - Animated driver pin (updates every ~4 s from RTDB)
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

class _LiveTrackingMapState extends State<LiveTrackingMap> {
  GoogleMapController? _mapController;

  StreamSubscription? _rtdbSub;
  LatLng? _driverLatLng;
  double  _driverBearing = 0;
  bool    _driverOnline  = false;

  final Set<Marker>   _markers   = {};
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _buildStaticMarkers();
    _subscribeDriver();
  }

  @override
  void dispose() {
    _rtdbSub?.cancel();
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

      final newPos = LatLng(lat, lng);
      setState(() {
        _driverLatLng  = newPos;
        _driverBearing = bearing;
        _driverOnline  = true;

        _markers.removeWhere((m) => m.markerId.value == 'driver');
        _markers.add(Marker(
          markerId: const MarkerId('driver'),
          position: newPos,
          rotation: bearing,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Your driver'),
          flat: true,
          anchor: const Offset(0.5, 0.5),
        ));
      });

      // Smoothly pan map to keep driver visible
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(newPos),
      );
    });
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
