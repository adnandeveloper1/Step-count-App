import 'dart:convert';
import 'dart:math';

import 'package:build_up/core/utils/route_simplify.dart';
import 'package:flutter_test/flutter_test.dart';

// About 1 m of latitude, in degrees.
const _metre = 1 / 111320;

/// [count] points heading north, [stepMetres] apart, at [speed].
List<RoutePoint> _line(int count, {double stepMetres = 2, double speed = 1.5}) {
  return [
    for (var i = 0; i < count; i++)
      RoutePoint(lat: 24.86 + i * stepMetres * _metre, lng: 67.0, speed: speed),
  ];
}

void main() {
  group('simplifyRoute', () {
    test('keeps routes too short to thin as they are', () {
      expect(simplifyRoute([]), isEmpty);
      expect(simplifyRoute(_line(1)), _line(1));
      expect(simplifyRoute(_line(2)), _line(2));
    });

    test('drops the middle of a straight line', () {
      final route = _line(1000);

      expect(simplifyRoute(route), [route.first, route.last]);
    });

    test('keeps the corner of a turn', () {
      final north = _line(100);
      final corner = north.last;
      final east = [
        for (var i = 1; i < 100; i++)
          RoutePoint(
            lat: corner.lat,
            lng: corner.lng + i * 2 * _metre / cos(corner.lat * pi / 180),
            speed: 1.5,
          ),
      ];

      expect(simplifyRoute([...north, ...east]), [
        north.first,
        corner,
        east.last,
      ]);
    });

    /// A straight line with point 50 pushed [metres] east.
    List<RoutePoint> offsetMiddle(double metres) {
      final route = _line(101);
      final middle = route[50];
      route[50] = RoutePoint(
        lat: middle.lat,
        lng: middle.lng + metres * _metre,
        speed: 1.5,
      );
      return route;
    }

    test('drops wobble inside the tolerance', () {
      final route = offsetMiddle(1);

      expect(simplifyRoute(route, toleranceMetres: 3), [
        route.first,
        route.last,
      ]);
    });

    test('keeps a detour beyond the tolerance', () {
      final route = offsetMiddle(10);

      final thinned = simplifyRoute(route, toleranceMetres: 3);

      // The spike's neighbours stay too, since they sit far off the lines
      // to its tip.
      expect(thinned, containsAllInOrder([route.first, route[50], route.last]));
      expect(thinned.length, lessThan(route.length));
    });

    test('keeps the point where the speed band changes', () {
      final route = [
        ..._line(50, speed: 0.5),
        ..._line(50, speed: 3.5).map(
          (p) => RoutePoint(lat: p.lat + 100 * _metre, lng: p.lng, speed: 3.5),
        ),
      ];

      final thinned = simplifyRoute(route);

      expect(thinned.map((p) => speedBand(p.speed)).toSet(), {0, 3});
      expect(thinned, contains(route[50]));
    });

    test('caps a long zig-zag walk and keeps its ends', () {
      // 40 km of 2 m steps, each 5 m off the line, so tolerance alone keeps
      // nearly every point.
      final route = [
        for (var i = 0; i < 20000; i++)
          RoutePoint(
            lat: 24.86 + i * 2 * _metre,
            lng: 67.0 + (i.isEven ? 0 : 5 * _metre),
            speed: 1.5,
          ),
      ];

      final thinned = simplifyRoute(route);

      expect(thinned.length, lessThanOrEqualTo(maxStoredRoutePoints));
      expect(thinned.first, route.first);
      expect(thinned.last, route.last);
    });

    test('a capped walk fits well inside one Firestore document', () {
      final random = Random(7);
      final route = [
        for (var i = 0; i < 50000; i++)
          RoutePoint(
            lat: 24.86 + i * 2 * _metre + random.nextDouble() * 20 * _metre,
            lng: 67.0 + random.nextDouble() * 20 * _metre,
            speed: random.nextDouble() * 4,
          ),
      ];

      final stored = simplifyRoute(route).map((p) => p.toMap()).toList();

      expect(jsonEncode(stored).length, lessThan(500 * 1024));
    });
  });

  group('RoutePoint.fromMap', () {
    test('reads routes saved before thinning, with whole numbers', () {
      expect(
        RoutePoint.fromMap({'lat': 24, 'lng': 67.5, 'speed': 2}),
        const RoutePoint(lat: 24, lng: 67.5, speed: 2),
      );
    });

    test('treats a missing speed as standing still', () {
      expect(
        RoutePoint.fromMap({'lat': 24.1, 'lng': 67.5}),
        const RoutePoint(lat: 24.1, lng: 67.5, speed: 0),
      );
    });

    test('round-trips through toMap', () {
      const point = RoutePoint(lat: 24.1, lng: 67.5, speed: 1.2);

      expect(RoutePoint.fromMap(point.toMap()), point);
    });
  });

  test('speedBand matches the map colours', () {
    expect(speedBand(0), 0);
    expect(speedBand(1.0), 0);
    expect(speedBand(1.5), 1);
    expect(speedBand(2.5), 2);
    expect(speedBand(3.1), 3);
  });
}
