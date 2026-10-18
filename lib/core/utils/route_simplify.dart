import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Most points one saved route keeps. Each point is a few dozen bytes, so
/// this stays far below Firestore's 1 MB document limit.
const maxStoredRoutePoints = 2000;

/// One GPS fix as stored in a route document.
@immutable
class RoutePoint {
  final double lat;
  final double lng;

  /// Metres per second.
  final double speed;

  const RoutePoint({required this.lat, required this.lng, required this.speed});

  factory RoutePoint.fromPosition(Position p) =>
      RoutePoint(lat: p.latitude, lng: p.longitude, speed: p.speed);

  /// Reads old and new route documents alike: Firestore may hand back whole
  /// numbers as ints, and a missing speed counts as standing still.
  factory RoutePoint.fromMap(Map<dynamic, dynamic> map) => RoutePoint(
    lat: (map['lat'] as num).toDouble(),
    lng: (map['lng'] as num).toDouble(),
    speed: (map['speed'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toMap() => {'lat': lat, 'lng': lng, 'speed': speed};

  @override
  bool operator ==(Object other) =>
      other is RoutePoint &&
      other.lat == lat &&
      other.lng == lng &&
      other.speed == speed;

  @override
  int get hashCode => Object.hash(lat, lng, speed);

  @override
  String toString() => 'RoutePoint($lat, $lng, $speed m/s)';
}

/// The map's speed colours: 0 up to 1 m/s, 1 up to 2, 2 up to 3, 3 above.
int speedBand(double speed) {
  if (speed > 3.0) return 3;
  if (speed > 2.0) return 2;
  if (speed > 1.0) return 1;
  return 0;
}

/// Thins [points] while keeping the route's shape and colours.
///
/// Drops points within [toleranceMetres] of the line between their kept
/// neighbours (Douglas-Peucker). Points where the speed colour changes are
/// always kept, so the map colours stay where they were. If the route still
/// has more than [maxPoints], the tolerance doubles until it fits.
List<RoutePoint> simplifyRoute(
  List<RoutePoint> points, {
  double toleranceMetres = 2,
  int maxPoints = maxStoredRoutePoints,
}) {
  if (points.length <= 2) return List.of(points);

  var tolerance = toleranceMetres;
  var result = _simplifyByBand(points, tolerance);
  // Each pass at least doubles the tolerance; 40 passes reach thousands of
  // kilometres, so the fallback only guards against odd input.
  for (var pass = 0; result.length > maxPoints && pass < 40; pass++) {
    tolerance *= 2;
    result = _simplifyByBand(points, tolerance);
  }
  if (result.length > maxPoints) result = _evenlySpaced(result, maxPoints);
  return result;
}

/// Simplifies each run of same-colour points on its own and joins them.
List<RoutePoint> _simplifyByBand(List<RoutePoint> points, double tolerance) {
  final result = <RoutePoint>[];
  var start = 0;
  for (var i = 1; i <= points.length; i++) {
    final runEnds =
        i == points.length ||
        speedBand(points[i].speed) != speedBand(points[i - 1].speed);
    if (!runEnds) continue;
    result.addAll(_douglasPeucker(points.sublist(start, i), tolerance));
    start = i;
  }
  return result;
}

List<RoutePoint> _douglasPeucker(List<RoutePoint> points, double tolerance) {
  if (points.length <= 2) return points;

  // Flat x/y in metres around the first point; fine over a walk's distances.
  final originLat = points.first.lat;
  final lngScale = 111320 * cos(originLat * pi / 180);
  final xs = [for (final p in points) (p.lng - points.first.lng) * lngScale];
  final ys = [for (final p in points) (p.lat - originLat) * 110540];

  final keep = List.filled(points.length, false);
  keep[0] = true;
  keep[points.length - 1] = true;

  // A stack instead of recursion, so long walks can't overflow it.
  final stack = <(int, int)>[(0, points.length - 1)];
  while (stack.isNotEmpty) {
    final (first, last) = stack.removeLast();
    var farthest = -1;
    var farthestDistance = tolerance;
    for (var i = first + 1; i < last; i++) {
      final d = _distanceToSegment(
        xs[i],
        ys[i],
        xs[first],
        ys[first],
        xs[last],
        ys[last],
      );
      if (d > farthestDistance) {
        farthest = i;
        farthestDistance = d;
      }
    }
    if (farthest == -1) continue;
    keep[farthest] = true;
    stack
      ..add((first, farthest))
      ..add((farthest, last));
  }

  return [
    for (var i = 0; i < points.length; i++)
      if (keep[i]) points[i],
  ];
}

double _distanceToSegment(
  double px,
  double py,
  double ax,
  double ay,
  double bx,
  double by,
) {
  final dx = bx - ax;
  final dy = by - ay;
  final lengthSquared = dx * dx + dy * dy;
  if (lengthSquared == 0) return sqrt(pow(px - ax, 2) + pow(py - ay, 2));
  final t = (((px - ax) * dx + (py - ay) * dy) / lengthSquared).clamp(0.0, 1.0);
  return sqrt(pow(px - (ax + t * dx), 2) + pow(py - (ay + t * dy), 2));
}

/// [count] points spread evenly along [points], first and last included.
List<RoutePoint> _evenlySpaced(List<RoutePoint> points, int count) {
  final step = (points.length - 1) / (count - 1);
  return [for (var i = 0; i < count; i++) points[(i * step).round()]];
}
