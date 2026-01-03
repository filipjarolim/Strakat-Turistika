import 'package:flutter/material.dart';
import 'dart:math';
import '../models/visit_data.dart';
import '../config/app_colors.dart';

class RouteThumbnail extends StatelessWidget {
  final VisitData visit;
  final double height;
  final double borderRadius;
  final bool showGradient;

  const RouteThumbnail({
    Key? key,
    required this.visit,
    this.height = 120,
    this.borderRadius = 0,
    this.showGradient = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 1. Try to show Hero Image (First Photo)
    if (visit.photos != null && visit.photos!.isNotEmpty) {
      final String? url = visit.photos!.first['url'] as String?;
      if (url != null && url.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadius)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: 'visit_photo_${visit.id}',
                child: Image.network(
                  url,
                  height: height,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildMapPreview(context),
                ),
              ),
              if (showGradient)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.0),
                        Colors.black.withOpacity(0.4),
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                ),
            ],
          ),
        );
      }
    }

    // 2. Show Map Preview (Polyline)
    return _buildMapPreview(context);
  }

  Widget _buildMapPreview(BuildContext context) {
    final trackPoints = _getTrackPoints();
    
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F7), // Soft grey background for map
        // Add a subtle grid pattern or texture? Keeping it clean.
        borderRadius: BorderRadius.only(
             topLeft: Radius.circular(borderRadius),
             topRight: Radius.circular(borderRadius),
        ),
      ),
      child: trackPoints.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadius)),
              child: CustomPaint(
                painter: RoutePainter(
                  points: trackPoints,
                  color: AppColors.primary,
                ),
                child: Container(),
              ),
            )
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Icon(Icons.map_outlined, size: 32, color: Colors.grey[400]),
                   const SizedBox(height: 4),
                   Text(
                     'Bez náhledu trasy',
                     style: TextStyle(color: Colors.grey[500], fontSize: 10),
                   ),
                ],
              ),
            ),
    );
  }

  List<Point<double>> _getTrackPoints() {
    if (visit.route == null || visit.route!['trackPoints'] == null) return [];
    
    final List<dynamic> rawPoints = visit.route!['trackPoints'];
    if (rawPoints.isEmpty) return [];

    return rawPoints.map((p) {
      // Assuming structure {latitude: x, longitude: y}
      final double lat = (p['latitude'] as num).toDouble();
      final double lon = (p['longitude'] as num).toDouble();
      return Point(lat, lon);
    }).toList();
  }
}

class RoutePainter extends CustomPainter {
  final List<Point<double>> points;
  final Color color;

  RoutePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 1. Calculate Bounds
    double minLat = points.first.x;
    double maxLat = points.first.x;
    double minLon = points.first.y;
    double maxLon = points.first.y;

    for (var p in points) {
      minLat = min(minLat, p.x);
      maxLat = max(maxLat, p.x);
      minLon = min(minLon, p.y);
      maxLon = max(maxLon, p.y);
    }
    
    // Add padding to bounds
    final latSpan = maxLat - minLat;
    final lonSpan = maxLon - minLon;
    
    // Avoid division by zero
    if (latSpan == 0 || lonSpan == 0) return;

    final path = Path();
    bool first = true;
    
    // Apply padding (15% for better spacing)
    final padding = 0.3;
    final usefulWidth = size.width * (1.0 - padding);
    final usefulHeight = size.height * (1.0 - padding);
    final offsetX = size.width * (padding / 2);
    final offsetY = size.height * (padding / 2);

    Offset? startPoint;
    Offset? endPoint;

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      // Normalize
      // Note: Latitude Y goes up, Screen Y goes down.
      // Longitude X goes right, Screen X goes right.
      
      final normalizedX = (p.y - minLon) / lonSpan;
      final normalizedY = 1.0 - (p.x - minLat) / latSpan; // Invert Y
      
      final screenX = offsetX + (normalizedX * usefulWidth);
      final screenY = offsetY + (normalizedY * usefulHeight);
      final pointOffset = Offset(screenX, screenY);

      if (first) {
        path.moveTo(screenX, screenY);
        startPoint = pointOffset;
        first = false;
      } else {
        path.lineTo(screenX, screenY);
      }
      
      if (i == points.length - 1) {
        endPoint = pointOffset;
      }
    }
    
    // Draw the Line
    canvas.drawPath(path, paint);
    
    // Draw Start/End Markers
    if (startPoint != null) {
      // Start (Green Dot)
      canvas.drawCircle(startPoint, 5, Paint()..color = Colors.white);
      canvas.drawCircle(startPoint, 3, Paint()..color = Colors.green);
    }
    
    if (endPoint != null) {
      // End (Red Checkered/Flag - simplified to Red Dot)
      canvas.drawCircle(endPoint, 5, Paint()..color = Colors.white);
      canvas.drawCircle(endPoint, 3, Paint()..color = Colors.red);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
