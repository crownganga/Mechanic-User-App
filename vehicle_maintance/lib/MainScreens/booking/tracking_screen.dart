import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vehicle_maintance/MainScreens/booking/booking_screen.dart';
import 'package:vehicle_maintance/MainScreens/booking/rating_screen.dart';

class TrackingScreen extends StatefulWidget {
  final String requestId;
  const TrackingScreen({super.key, required this.requestId});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final supabase = Supabase.instance.client;

  Set<Polyline> polylines = {};
  bool movedToPayment = false;

  GoogleMapController? _mapController;
  LatLng? _lastMechanicPos;
  bool _routeLoading = false;

  /// 🔑 GOOGLE API KEY
  //  static const String googleApiKey = "AIzaSyAsh88i9vbeOUIyOaQqYpT3a9p0_q3lBVs";

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const BookingScreen()),
        );
        return false; // ⛔ prevent app close
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F4DAB),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const BookingScreen()),
              );
            },
          ),
          title: const Text("Tracking", style: TextStyle(color: Colors.white)),
        ),

        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: supabase
              .from('service_requests')
              .stream(primaryKey: ['id'])
              .eq('id', widget.requestId),

          builder: (context, snap) {
            if (!snap.hasData || snap.data!.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            final req = snap.data!.first;
            final status = req['status'];

            /// ❌ NO MECHANIC
            if (status == 'rejected' || status == 'no_mechanic') {
              return _message("No mechanic available");
            }

            /// ⏳ WAITING
            if (status == 'pending') {
              return _message("Waiting for mechanic approval...");
            }

            return _trackingView(req, status);
          },
        ),
      ),
    );
  }

  /// ================= TRACKING VIEW =================
  Widget _trackingView(Map<String, dynamic> req, String status) {
    final LatLng userPos = LatLng(
      (req['latitude'] as num).toDouble(),
      (req['longitude'] as num).toDouble(),
    );

    return FutureBuilder<Map<String, dynamic>?>(
      future: supabase
          .from('mechanics')
          .select('name, phone')
          .eq('id', req['mechanic_id'])
          .maybeSingle(),

      builder: (context, mechSnap) {
        final mechanic = mechSnap.data;

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: supabase
              .from('mechanic_locations')
              .stream(primaryKey: ['mechanic_id'])
              .eq('mechanic_id', req['mechanic_id']),

          builder: (context, locSnap) {
            LatLng? mechPos;

            if (locSnap.hasData && locSnap.data!.isNotEmpty) {
              final loc = locSnap.data!.first;

              if (loc['latitude'] != null && loc['longitude'] != null) {
                mechPos = LatLng(
                  (loc['latitude'] as num).toDouble(),
                  (loc['longitude'] as num).toDouble(),
                );

                // 🔥 ONLY redraw route if mechanic moved
                if (_lastMechanicPos == null ||
                    _lastMechanicPos!.latitude != mechPos.latitude ||
                    _lastMechanicPos!.longitude != mechPos.longitude) {
                  _lastMechanicPos = mechPos;

                  // Clear old route first
                  //    polylines.clear();

                  // Draw new route
                  _drawRoute(mechPos, userPos);

                  // Move camera
                  _moveCamera(mechPos, userPos);
                }
              }
            }

            final markers = <Marker>{
              Marker(
                markerId: const MarkerId("user"),
                position: userPos,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed,
                ),
                infoWindow: const InfoWindow(title: "You"),
              ),
            };

            if (mechPos != null) {
              markers.add(
                Marker(
                  markerId: const MarkerId("mechanic"),
                  position: mechPos,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueBlue,
                  ),
                  infoWindow: const InfoWindow(title: "Mechanic"),
                ),
              );
            }

            final bool canPay = status == 'arrived' || status == 'accepted';

            return Stack(
              children: [
                /// 🗺 FULL SCREEN MAP
                GoogleMap(
                  key: ValueKey(polylines), // 🔥 VERY IMPORTANT
                  initialCameraPosition: CameraPosition(
                    target: userPos,
                    zoom: 14,
                  ),
                  markers: markers,
                  polylines: polylines,
                  myLocationEnabled: false,
                  zoomControlsEnabled: false,
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                ),

                /// 📍 Floating My Location Button
                Positioned(
                  bottom: 220,
                  right: 16,
                  child: FloatingActionButton(
                    backgroundColor: Colors.white,
                    mini: true,
                    onPressed: () {
                      if (mechPos != null) {
                        _moveCamera(mechPos, userPos);
                      }
                    },
                    child: const Icon(Icons.my_location, color: Colors.blue),
                  ),
                ),

                /// 📋 MODERN BOTTOM SHEET
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(25),
                        topRight: Radius.circular(25),
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 10),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// Drag Handle
                        Center(
                          child: Container(
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey[400],
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),

                        const SizedBox(height: 15),

                        /// Status Text
                        Text(
                          status == 'arrived'
                              ? "✅ Mechanic Arrived"
                              : "🚗 Mechanic On The Way",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 10),

                        /// Mechanic Info Card
                        if (mechanic != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Row(
                              children: [
                                const CircleAvatar(
                                  radius: 25,
                                  backgroundColor: Colors.blue,
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        mechanic['name'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(mechanic['phone']),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.call,
                                    color: Colors.green,
                                  ),
                                  onPressed: () async {
                                    final phoneNumber = mechanic['phone'];

                                    if (phoneNumber != null &&
                                        phoneNumber.toString().isNotEmpty) {
                                      final Uri phoneUri = Uri(
                                        scheme: 'tel',
                                        path: phoneNumber.toString(),
                                      );

                                      if (await canLaunchUrl(phoneUri)) {
                                        await launchUrl(phoneUri);
                                      } else {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text("Cannot open dialer"),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 20),

                        /// COMPLETE & PAY BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: canPay
                                ? () async {
                                    await supabase
                                        .from('service_requests')
                                        .update({'status': 'payment'})
                                        .eq('id', widget.requestId);

                                    if (!mounted) return;

                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => RatingScreen(
                                          requestId: widget.requestId,
                                          mechanicId: req['mechanic_id'],
                                        ),
                                      ),
                                    );
                                  }
                                : null,

                            style: ElevatedButton.styleFrom(
                              backgroundColor: canPay
                                  ? const Color(0xFF0F4DAB)
                                  : Colors.grey,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              "Complete & Pay",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _moveCamera(LatLng mech, LatLng user) {
    if (_mapController == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        mech.latitude < user.latitude ? mech.latitude : user.latitude,
        mech.longitude < user.longitude ? mech.longitude : user.longitude,
      ),
      northeast: LatLng(
        mech.latitude > user.latitude ? mech.latitude : user.latitude,
        mech.longitude > user.longitude ? mech.longitude : user.longitude,
      ),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  /// ================= ROUTE DRAW =================
  Future<void> _drawRoute(LatLng start, LatLng end) async {
    if (_routeLoading) return;
    _routeLoading = true;

    try {
      print("Start: $start");
      print("End: $end");

      final url =
          "https://router.project-osrm.org/route/v1/driving/"
          "${start.longitude},${start.latitude};"
          "${end.longitude},${end.latitude}"
          "?overview=full&geometries=polyline";

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        print("HTTP Error: ${response.statusCode}");
        _drawStraightLine(start, end);
        return;
      }

      final data = jsonDecode(response.body);

      if (data['code'] != 'Ok' ||
          data['routes'] == null ||
          data['routes'].isEmpty) {
        print("No valid route from OSRM. Drawing straight line.");
        _drawStraightLine(start, end);
        return;
      }

      final encodedPolyline = data['routes'][0]['geometry'];

      final List<LatLng> points = _decodePolyline(encodedPolyline);

      if (points.isEmpty) {
        print("Decoded polyline empty. Drawing straight line.");
        _drawStraightLine(start, end);
        return;
      }

      setState(() {
        polylines = {
          Polyline(
            polylineId: const PolylineId("route"),
            color: const Color(0xFF0F4DAB),
            width: 7,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
            points: points,
          ),
        };
      });
    } catch (e) {
      print("Route Exception: $e");
      _drawStraightLine(start, end);
    }

    _routeLoading = false;
  }

  /// ================= POLYLINE DECODER =================
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, lat = 0, lng = 0;

    while (index < encoded.length) {
      int shift = 0, result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  Widget _message(String text) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(fontSize: 18),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// ================= STRAIGHT LINE FALLBACK =================
  void _drawStraightLine(LatLng start, LatLng end) {
    setState(() {
      polylines = {
        Polyline(
          polylineId: const PolylineId("fallback"),
          color: Colors.red,
          width: 6,
          points: [start, end],
        ),
      };
    });
  }
}
