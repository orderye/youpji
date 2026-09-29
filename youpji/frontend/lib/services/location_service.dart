import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/location_model.dart';

class LocationService {
  static const String _prefCityKey = 'active_guizhou_city';

  /// 计算地球两点间大圆距离（Haversine 公式，单位：千米）
  static double calculateHaversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// 预估公路自驾距离（对齐 DESIGN.md §6 route 模块的 1.25x 蜿蜒系数）
  static double estimateDrivingDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final straight = calculateHaversineKm(lat1, lon1, lat2, lon2);
    if (straight < 0.1) return 0.0;
    return straight * 1.25;
  }

  /// 预估自驾耗时（小时）：平均时速按高速与省道结合 65 km/h 计算
  static double estimateDrivingHours(double distanceKm) {
    if (distanceKm <= 0) return 0.0;
    return distanceKm / 65.0;
  }

  /// 格式化距离文案：米或千米
  static String formatDistance(double? distanceMeters) {
    if (distanceMeters == null || distanceMeters.isNaN || distanceMeters < 0) {
      return '未知距离';
    }
    if (distanceMeters < 1000) {
      return '${distanceMeters.toInt()}m';
    }
    final km = distanceMeters / 1000.0;
    return '${km.toStringAsFixed(1)}km';
  }

  /// 格式化耗时文案
  static String formatDrivingTime(double hours) {
    if (hours <= 0.1) return '约 5 分钟';
    final totalMinutes = (hours * 60).round();
    if (totalMinutes < 60) {
      return '约 $totalMinutes 分钟';
    }
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (m == 0) {
      return '约 $h 小时';
    }
    return '约 $h 小时 $m 分钟';
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);

  /// 读取用户选定的当前城市，默认贵阳市
  Future<GuizhouCity> getSavedCity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cityName = prefs.getString(_prefCityKey);
      if (cityName != null) {
        return GuizhouCities.findByName(cityName);
      }
    } catch (_) {}
    return GuizhouCities.guiyang;
  }

  /// 保存用户选定的当前城市
  Future<void> saveCity(GuizhouCity city) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefCityKey, city.name);
    } catch (_) {}
  }
}
