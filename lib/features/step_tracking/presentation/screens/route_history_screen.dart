import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../app/theme/theme_extensions.dart';
import '../../../../core/utils/route_simplify.dart';
import '../widgets/glass_step_card.dart';
import '../widgets/speed_polylines.dart';

class RouteHistoryScreen extends StatelessWidget {
  const RouteHistoryScreen({super.key});

  /// Reads a route document's points, saved before or after thinning.
  List<RoutePoint> _readPoints(Map<String, dynamic> data) {
    final raw = data['points'] as List<dynamic>? ?? [];
    return raw.map((p) => RoutePoint.fromMap(p as Map)).toList();
  }

  double _calculateDistance(List<RoutePoint> points) {
    double total = 0.0;
    final distanceCalc = const Distance();
    for (int index = 0; index < points.length - 1; index++) {
      total += distanceCalc(
        LatLng(points[index].lat, points[index].lng),
        LatLng(points[index + 1].lat, points[index + 1].lng),
      );
    }
    return total;
  }

  void _showRouteDetails(
    BuildContext context,
    List<RoutePoint> points,
    double distance,
    String dateStr,
  ) {
    if (points.isEmpty) return;

    List<LatLng> routePoints = points.map((p) => LatLng(p.lat, p.lng)).toList();
    final lines = buildSpeedPolylines(points, strokeWidth: 4);

    final distanceText = distance > 1000
        ? '${(distance / 1000).toStringAsFixed(2)} km'
        : '${distance.toStringAsFixed(0)} m';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogContext.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: dialogContext.textSecondary.withValues(alpha: 0.2),
          ),
        ),
        title: Text(
          dateStr,
          style: TextStyle(
            color: dialogContext.textPrimary,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 250,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: dialogContext.primaryColor.withValues(alpha: 0.3),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCameraFit: CameraFit.bounds(
                        bounds: LatLngBounds.fromPoints(routePoints),
                        padding: const EdgeInsets.all(20.0),
                      ),
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.build_up',
                      ),
                      PolylineLayer(polylines: lines),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: routePoints.first,
                            width: 20,
                            height: 20,
                            child: const Icon(
                              Icons.circle,
                              color: Colors.green,
                              size: 20,
                            ),
                          ),
                          Marker(
                            point: routePoints.last,
                            width: 30,
                            height: 30,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 30,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.straighten,
                    color: dialogContext.primaryColor,
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        distanceText,
                        style: TextStyle(
                          color: dialogContext.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Total Distance',
                        style: TextStyle(
                          color: dialogContext.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: dialogContext.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close', style: TextStyle(color: Colors.black)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Workout History',
          style: TextStyle(color: context.textPrimary),
        ),
        iconTheme: IconThemeData(color: context.textPrimary),
      ),
      body: user == null
          ? Center(
              child: Text(
                'User not found',
                style: TextStyle(color: context.textPrimary),
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('routes')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: context.primaryColor,
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No routes recorded.',
                      style: TextStyle(color: context.textPrimary),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;
                double maxDistance = 0;
                String longestDocId = '';

                for (var doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final points = _readPoints(data);
                  final distance = _calculateDistance(points);
                  if (distance > maxDistance) {
                    maxDistance = distance;
                    longestDocId = doc.id;
                  }
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final points = _readPoints(data);
                    final distance = _calculateDistance(points);
                    final isLongest = doc.id == longestDocId && distance > 0;
                    final timestamp = data['timestamp'] as Timestamp?;

                    String dateStr = 'Unknown Date';
                    if (timestamp != null) {
                      final date = timestamp.toDate();
                      dateStr =
                          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                    }

                    final distanceText = distance > 1000
                        ? '${(distance / 1000).toStringAsFixed(2)} km'
                        : '${distance.toStringAsFixed(0)} m';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: GestureDetector(
                        onTap: () => _showRouteDetails(
                          context,
                          points,
                          distance,
                          dateStr,
                        ),
                        child: GlassCard(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dateStr,
                                    style: TextStyle(
                                      color: context.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.straighten,
                                        color: context.primaryColor,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        distanceText,
                                        style: TextStyle(
                                          color: context.textPrimary,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (isLongest)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.orange),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.emoji_events,
                                        color: Colors.orange,
                                        size: 16,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Longest',
                                        style: TextStyle(
                                          color: Colors.orange,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
