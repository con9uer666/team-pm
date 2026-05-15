import 'dart:async';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

class GeoPosition {
  const GeoPosition({required this.lat, required this.lng, required this.accuracy});
  final double lat;
  final double lng;
  final double accuracy;
}

class GeolocationException implements Exception {
  const GeolocationException(this.message);
  final String message;

  @override
  String toString() => message;
}

class GeolocatorService {
  const GeolocatorService();

  Future<GeoPosition> current() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const GeolocationException('位置信息不可用，请检查 GPS 或网络');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const GeolocationException('位置权限被拒绝，请在设置中允许本应用定位');
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return GeoPosition(
        lat: pos.latitude,
        lng: pos.longitude,
        accuracy: pos.accuracy,
      );
    } on LocationServiceDisabledException {
      throw const GeolocationException('位置信息不可用，请检查 GPS 或网络');
    } on TimeoutException {
      throw const GeolocationException('定位超时，请重试');
    } catch (e) {
      throw GeolocationException('定位失败: ${e.toString()}');
    }
  }
}

/// Great-circle distance in meters between two coordinates.
double haversine(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  double toRad(double v) => v * math.pi / 180.0;
  final dLat = toRad(lat2 - lat1);
  final dLng = toRad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(toRad(lat1)) * math.cos(toRad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(a.toDouble()));
}
