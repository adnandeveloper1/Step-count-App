import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class GpsTrackingState {
  final Position? currentPosition;
  final List<Position> recordedPositions;
  final bool isTracking;
  final String? errorMessage;
  final DateTime? startTime;

  const GpsTrackingState({
    this.currentPosition,
    this.recordedPositions = const [],
    this.isTracking = false,
    this.errorMessage,
    this.startTime,
  });

  GpsTrackingState copyWith({
    Position? currentPosition,
    List<Position>? recordedPositions,
    bool? isTracking,
    String? errorMessage,
    DateTime? startTime,
  }) {
    return GpsTrackingState(
      currentPosition: currentPosition ?? this.currentPosition,
      recordedPositions: recordedPositions ?? this.recordedPositions,
      isTracking: isTracking ?? this.isTracking,
      errorMessage: errorMessage,
      startTime: startTime ?? this.startTime,
    );
  }
}

class GpsTrackingNotifier extends StateNotifier<GpsTrackingState> {
  final Ref ref;
  StreamSubscription<Position>? _positionSubscription;

  GpsTrackingNotifier(this.ref) : super(const GpsTrackingState());

  Future<void> checkPermissionAndStart() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      state = state.copyWith(errorMessage: "Location services are turned off. Please enable GPS.");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        state = state.copyWith(errorMessage: "Location permission denied.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      state = state.copyWith(errorMessage: "Location permission permanently denied. Enable it in Settings.");
      return;
    }

    _listenToPosition();
  }

  void _listenToPosition() {
    if (_positionSubscription != null) return;

    LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2,
        forceLocationManager: true,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "Build Up is tracking your route.",
          notificationTitle: "Active Workout",
          enableWakeLock: true,
        ),
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2,
      );
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      if (state.isTracking) {
        state = state.copyWith(
          currentPosition: position,
          recordedPositions: [...state.recordedPositions, position],
        );
      } else {
        state = state.copyWith(currentPosition: position);
      }
    });
  }

  void startTracking() {
    state = state.copyWith(
      isTracking: true,
      recordedPositions: [],
      startTime: DateTime.now(),
    );
  }

  Future<void> stopTracking() async {
    state = state.copyWith(isTracking: false);
    await _saveRouteToHistory();
  }

  Future<void> _saveRouteToHistory() async {
    if (state.recordedPositions.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final routeData = state.recordedPositions.map((p) => {
      'lat': p.latitude,
      'lng': p.longitude,
      'speed': p.speed,
    }).toList();

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('routes')
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'points': routeData,
        'pointCount': state.recordedPositions.length,
      });
    } catch (e) {
      debugPrint('Failed to save route');
    }
  }

  void disposeSubscription() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }
}

final gpsTrackingProvider = StateNotifierProvider<GpsTrackingNotifier, GpsTrackingState>((ref) {
  return GpsTrackingNotifier(ref);
});