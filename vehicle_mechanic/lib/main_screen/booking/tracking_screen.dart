import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:vehicle_mechanic/main_screen/booking/booking.dart';

class TrackingScreen extends StatefulWidget {
  final String requestId;
  final bool isEmergency;

  const TrackingScreen({
    super.key,
    required this.requestId,
    this.isEmergency = true,
  });

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final supabase = Supabase.instance.client;

  Set<Polyline> polylines = {};

  GoogleMapController? mapController;

  LatLng? lastMechanicPos;

  bool routeLoading = false;

  /// 🔑 PUT YOUR GOOGLE MAP API KEY
  static const String googleApiKey = "AIzaSyD8HY3cIJZM7_J4uCb6g-JUwDLCh4lga-U";

  /// 🔒 PREVENT DOUBLE NAVIGATION
  bool paymentDialogShown = false;

  Future<void> _drawRoute(LatLng start, LatLng end) async {
    if (routeLoading) return;

    routeLoading = true;

    final url =
        "https://maps.googleapis.com/maps/api/directions/json"
        "?origin=${start.latitude},${start.longitude}"
        "&destination=${end.latitude},${end.longitude}"
        "&mode=driving"
        "&key=$googleApiKey";

    final res = await http.get(Uri.parse(url));

    final data = jsonDecode(res.body);

    if (data['routes'].isEmpty) {
      routeLoading = false;
      return;
    }

    final points = _decodePolyline(
      data['routes'][0]['overview_polyline']['points'],
    );

    setState(() {
      polylines = {
        Polyline(
          polylineId: const PolylineId("route"),
          color: Colors.green,
          width: 6,
          points: points,
        ),
      };
    });

    routeLoading = false;
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];

    int index = 0, lat = 0, lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int b;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F4DAB),
        centerTitle: true,
        title: const Text("Tracking", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase
            .from('service_requests')
            .stream(primaryKey: ['id'])
            .eq('id', widget.requestId),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.data!.isEmpty) {
            return _message("Request not found");
          }

          final req = snap.data!.first;
          final status = (req['status'] ?? '').toString().trim();

          debugPrint("MECHANIC STATUS 👉 $status");

          /// 💳 AUTO MOVE TO PAYMENT (CRITICAL FIX)
          if (status == 'payment' && !paymentDialogShown) {
            paymentDialogShown = true;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) {
                  return AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),

                    title: const Text(
                      "Payment Confirmed",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),

                    content: const Text("User payment completed successfully."),

                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);

                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BookingScreen(),
                            ),
                            (route) => false,
                          );
                        },
                        child: const Text(
                          "OK",
                          style: TextStyle(
                            color: Color(0xFF0F4DAB),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            });
          }

          return _trackingView(req, status);
        },
      ),
    );
  }

  /// 🚗 TRACKING VIEW
  Widget _trackingView(Map<String, dynamic> req, String status) {
    if (req['latitude'] == null || req['longitude'] == null) {
      return _message("User location not available");
    }

    final userPos = LatLng(
      double.parse(req['latitude'].toString()),
      double.parse(req['longitude'].toString()),
    );

    return FutureBuilder<Map<String, dynamic>?>(
      future: supabase
          .from('users_data')
          .select('name, phone')
          .eq('user_id', req['user_id'])
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
                  double.parse(loc['latitude'].toString()),
                  double.parse(loc['longitude'].toString()),
                );

                /// redraw only if moved
                if (lastMechanicPos == null ||
                    lastMechanicPos!.latitude != mechPos.latitude ||
                    lastMechanicPos!.longitude != mechPos.longitude) {
                  lastMechanicPos = mechPos;

                  _drawRoute(mechPos, userPos);
                }
              }
            }

            final markers = <Marker>{
              Marker(
                markerId: const MarkerId('user'),
                position: userPos,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueBlue,
                ),
                infoWindow: const InfoWindow(title: "User"),
              ),
            };

            if (mechPos != null) {
              markers.add(
                Marker(
                  markerId: const MarkerId('mechanic'),
                  position: mechPos,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueOrange,
                  ),
                  infoWindow: const InfoWindow(title: "Mechanic"),
                ),
              );
            }

            return Column(
              children: [
                /// 🗺 MAP
                Expanded(
                  flex: 3,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: userPos,
                      zoom: 15,
                    ),

                    markers: markers,

                    polylines: polylines,

                    zoomControlsEnabled: true,

                    myLocationEnabled: true,

                    myLocationButtonEnabled: true,

                    mapType: MapType.normal,

                    onMapCreated: (controller) {
                      mapController = controller;

                      Future.delayed(const Duration(milliseconds: 500), () {
                        controller.animateCamera(
                          CameraUpdate.newLatLng(userPos),
                        );
                      });
                    },
                  ),
                ),

                /// 📋 INFO PANEL
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status == 'arrived'
                              ? "✅ You reached the user"
                              : "🚗 Driving to user",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 8),

                        if (mechanic != null)
                          Container(
                            height: 80,
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(16),
                            ),

                            child: Row(
                              children: [
                                /// PROFILE ICON
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF0F4DAB),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),

                                const SizedBox(width: 12),

                                /// NAME + PHONE
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        mechanic['name'] ?? "User",
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),

                                      const SizedBox(height: 4),

                                      Text(
                                        mechanic['phone'] ?? "",
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                /// CALL BUTTON
                                SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: Material(
                                    color: Colors.green,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () async {
                                        final phone = mechanic['phone'];

                                        if (phone != null) {
                                          final Uri callUri = Uri(
                                            scheme: 'tel',
                                            path: phone,
                                          );

                                          if (await canLaunchUrl(callUri)) {
                                            await launchUrl(callUri);
                                          }
                                        }
                                      },
                                      child: const Icon(
                                        Icons.call,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        //        const Spacer(),
                        const SizedBox(height: 10),

                        Text(
                          status == 'payment'
                              ? "Payment completed"
                              : "Waiting for user payment...",
                          style: TextStyle(
                            color: status == 'payment'
                                ? Colors.green
                                : Colors.grey,
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

  Widget _message(String text) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(fontSize: 18),
        textAlign: TextAlign.center,
      ),
    );
  }
}
