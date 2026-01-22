import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Requests location permission (using geolocator helpers) then returns position.
  static Future<Position?> getCurrentPosition() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      return null;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      return pos;
    } catch (_) {
      return null;
    }
  }
}
