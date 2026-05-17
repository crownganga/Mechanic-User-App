import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MechanicLocationService {
  final supabase = Supabase.instance.client;
  Timer? _timer;

  void startTracking(String mechanicId) {
    _timer = Timer.periodic(const Duration(seconds: 10), (_) async {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await supabase
          .from('mechanics')
          .update({
            'latitude': position.latitude,
            'longitude': position.longitude,
          })
          .eq('id', mechanicId);
    });
  }

  void stopTracking() {
    _timer?.cancel();
  }
}
