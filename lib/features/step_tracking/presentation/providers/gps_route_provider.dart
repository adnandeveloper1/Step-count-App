import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class GpsRouteState {
  final List<LatLng> routePoints;
  final bool isTracking;
  final double distanceMeters;
  final double currentSpeed;

  const GpsRouteState({
    required this.routePoints,
    required this.isTracking,
    required this.distanceMeters,
    required this.currentSpeed,
  });

  GpsRouteState copyWith({
    List<LatLng>? routePoints,
    bool? isTracking,
    double? distanceMeters,
    double? currentSpeed,
  }) {
    return GpsRouteState(
      routePoints: routePoints ?? this.routePoints,
      isTracking: isTracking ?? this.isTracking,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      currentSpeed: currentSpeed ?? this.currentSpeed,
    );
  }
}

final gpsRouteProvider =
NotifierProvider<GpsRouteNotifier, GpsRouteState>(GpsRouteNotifier.new);

class GpsRouteNotifier extends Notifier<GpsRouteState> {
  StreamSubscription<Position>? _positionStream;

  @override
  GpsRouteState build() {
    return const GpsRouteState(
      routePoints: [],
      isTracking: false,
      distanceMeters: 0.0,
      currentSpeed: 0.0,
    );
  }

  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    return permission != LocationPermission.deniedForever;
  }

  void startTracking() async {
    final hasPermission = await _checkLocationPermission();
    if (!hasPermission) return;

    state = state.copyWith(isTracking: true);

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      final newPoint = LatLng(position.latitude, position.longitude);
      double addedDistance = 0.0;

      if (state.routePoints.isNotEmpty) {
        final lastPoint = state.routePoints.last;
        addedDistance = Geolocator.distanceBetween(
          lastPoint.latitude,
          lastPoint.longitude,
          newPoint.latitude,
          newPoint.longitude,
        );
      }

      state = state.copyWith(
        routePoints: [...state.routePoints, newPoint],
        distanceMeters: state.distanceMeters + addedDistance,
        currentSpeed: position.speed,
      );
    });
  }

  void stopTracking() {
    _positionStream?.cancel();
    state = state.copyWith(isTracking: false);
  }

  void resetRoute() {
    _positionStream?.cancel();
    state = const GpsRouteState(
      routePoints: [],
      isTracking: false,
      distanceMeters: 0.0,
      currentSpeed: 0.0,
    );
  }
}