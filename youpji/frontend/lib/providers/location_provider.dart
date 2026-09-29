import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/location_model.dart';
import '../services/location_service.dart';

class LocationState {
  final GuizhouCity currentCity;
  final double currentLongitude;
  final double currentLatitude;
  final bool isLocating;
  final String? statusMessage;

  const LocationState({
    required this.currentCity,
    required this.currentLongitude,
    required this.currentLatitude,
    this.isLocating = false,
    this.statusMessage,
  });

  LocationState copyWith({
    GuizhouCity? currentCity,
    double? currentLongitude,
    double? currentLatitude,
    bool? isLocating,
    String? statusMessage,
  }) {
    return LocationState(
      currentCity: currentCity ?? this.currentCity,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      isLocating: isLocating ?? this.isLocating,
      statusMessage: statusMessage,
    );
  }
}

class LocationNotifier extends StateNotifier<LocationState> {
  final LocationService _service;

  LocationNotifier(this._service)
      : super(
          const LocationState(
            currentCity: GuizhouCities.guiyang,
            currentLongitude: 106.630153,
            currentLatitude: 26.647661,
          ),
        ) {
    _initCity();
  }

  Future<void> _initCity() async {
    final city = await _service.getSavedCity();
    state = state.copyWith(
      currentCity: city,
      currentLongitude: city.longitude,
      currentLatitude: city.latitude,
    );
  }

  /// 切换当前城市
  Future<void> setCity(GuizhouCity city) async {
    await _service.saveCity(city);
    state = state.copyWith(
      currentCity: city,
      currentLongitude: city.longitude,
      currentLatitude: city.latitude,
      statusMessage: '已切换至 ${city.name}',
    );
  }

  /// 模拟/获取当前精准定位 (GPS)
  Future<void> refreshLocation() async {
    state = state.copyWith(isLocating: true, statusMessage: '正在定位中...');
    await Future.delayed(const Duration(milliseconds: 600));

    // 默认以当前城市中心定位
    final city = state.currentCity;
    state = state.copyWith(
      isLocating: false,
      currentLongitude: city.longitude,
      currentLatitude: city.latitude,
      statusMessage: '定位成功：${city.name}',
    );
  }

  /// 计算当前位置到目标经纬度的公里数
  double distanceTo(double targetLat, double targetLon) {
    return LocationService.calculateHaversineKm(
      state.currentLatitude,
      state.currentLongitude,
      targetLat,
      targetLon,
    );
  }
}

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final locationProvider = StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  final service = ref.watch(locationServiceProvider);
  return LocationNotifier(service);
});
