import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/utils/route_simplify.dart';

const _bandColors = [Colors.blue, Colors.green, Colors.orange, Colors.red];

Color speedColor(double speed) => _bandColors[speedBand(speed)];

/// Draws [points] coloured by speed. Each segment takes the colour of the
/// speed at its end; consecutive segments of one colour share a single
/// polyline, so long routes stay smooth and cheap to draw.
List<Polyline> buildSpeedPolylines(
  List<RoutePoint> points, {
  required double strokeWidth,
}) {
  final lines = <Polyline>[];
  if (points.length < 2) return lines;

  LatLng at(int i) => LatLng(points[i].lat, points[i].lng);

  var run = [at(0), at(1)];
  var runColor = speedColor(points[1].speed);
  for (var i = 2; i < points.length; i++) {
    final color = speedColor(points[i].speed);
    if (color != runColor) {
      lines.add(
        Polyline(points: run, color: runColor, strokeWidth: strokeWidth),
      );
      run = [at(i - 1)];
      runColor = color;
    }
    run.add(at(i));
  }
  lines.add(Polyline(points: run, color: runColor, strokeWidth: strokeWidth));
  return lines;
}
