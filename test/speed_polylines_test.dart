import 'package:build_up/core/utils/route_simplify.dart';
import 'package:build_up/features/step_tracking/presentation/widgets/speed_polylines.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

List<RoutePoint> _points(List<double> speeds) => [
  for (var i = 0; i < speeds.length; i++)
    RoutePoint(lat: 24.86 + i * 0.0001, lng: 67.0, speed: speeds[i]),
];

void main() {
  test('needs at least two points', () {
    expect(buildSpeedPolylines([], strokeWidth: 6), isEmpty);
    expect(buildSpeedPolylines(_points([1.5]), strokeWidth: 6), isEmpty);
  });

  test('draws a steady walk as one line', () {
    final route = _points(List.filled(500, 1.5));

    final lines = buildSpeedPolylines(route, strokeWidth: 6);

    expect(lines, hasLength(1));
    expect(lines.single.color, Colors.green);
    expect(lines.single.points, hasLength(500));
    expect(lines.single.strokeWidth, 6);
  });

  test('starts a new line where the colour changes, sharing the joint', () {
    // A segment takes the colour of the speed at its end point.
    final route = _points([0.5, 0.5, 0.5, 3.5, 3.5, 1.5]);

    final lines = buildSpeedPolylines(route, strokeWidth: 4);

    expect(lines.map((l) => l.color), [Colors.blue, Colors.red, Colors.green]);
    LatLng at(int i) => LatLng(route[i].lat, route[i].lng);
    expect(lines[0].points, [at(0), at(1), at(2)]);
    expect(lines[1].points, [at(2), at(3), at(4)]);
    expect(lines[2].points, [at(4), at(5)]);
  });
}
