import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

// 260 degree arc with a gap at the bottom, like a speedometer.
class GoalArcPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;

  GoalArcPainter({required this.progress, required this.strokeWidth});

  static const double _startAngle = 140 * math.pi / 180;
  static const double _totalSweep = 260 * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.width - strokeWidth) / 2 - 8,
    );

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = AppColors.primaryEmerald.withValues(alpha: 0.1);
    canvas.drawArc(rect, _startAngle, _totalSweep, false, trackPaint);

    if (progress <= 0) return;
    final sweep = _totalSweep * progress;

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = AppColors.primaryEmerald.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawArc(rect, _startAngle, sweep, false, glowPaint);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = AppColors.primaryEmerald;
    canvas.drawArc(rect, _startAngle, sweep, false, arcPaint);
  }

  @override
  bool shouldRepaint(GoalArcPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.strokeWidth != strokeWidth;
}
