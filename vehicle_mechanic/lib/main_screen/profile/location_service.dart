import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  static Future<Map<String, dynamic>> getCurrentLocation() async {
    // 1️⃣ Check GPS
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception("Location services are disabled");
    }

    // 2️⃣ Permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception("Location permission denied");
    }

    // 3️⃣ Get position
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );

    // 4️⃣ Reverse geocode
    final placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    final p = placemarks.first;

    // 5️⃣ BUILD FULL ADDRESS (ROBUST)
    final parts = <String>[
      if (p.subThoroughfare != null && p.subThoroughfare!.isNotEmpty)
        p.subThoroughfare!,
      if (p.thoroughfare != null && p.thoroughfare!.isNotEmpty) p.thoroughfare!,
      if (p.subLocality != null && p.subLocality!.isNotEmpty) p.subLocality!,
      if (p.locality != null && p.locality!.isNotEmpty) p.locality!,
      if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty)
        p.administrativeArea!,
      if (p.postalCode != null && p.postalCode!.isNotEmpty) p.postalCode!,
      if (p.country != null && p.country!.isNotEmpty) p.country!,
    ];

    final fullAddress = parts.join(", ");

    return {
      "latitude": position.latitude,
      "longitude": position.longitude,
      "address": fullAddress,
    };
  }
}
