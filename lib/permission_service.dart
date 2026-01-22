import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Requests location permission (when-in-use).
  /// Returns true if granted.
  static Future<bool> requestLocationPermission() async {
    final status = await Permission.location.status;
    if (status.isGranted) return true;

    final result = await Permission.location.request();
    if (result.isGranted) return true;

    if (result.isPermanentlyDenied) {
      // Opens app settings so the user can grant permission manually.
      await openAppSettings();
      return false;
    }

    return false;
  }
}
