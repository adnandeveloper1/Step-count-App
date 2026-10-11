import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme/theme_extensions.dart';

/// Dashboard ring showing today's steps against the goal.
///
/// The ring and the count animate from the previous value to the new one.
/// Past the goal the ring keeps going: each extra lap is drawn on top of the
/// full first lap in the same colour, with a shadow under its leading end
/// so the overlap stands out.
class StepGauge extends StatelessWidget {
  final int steps;
  final int goal;
  final double size;
  final Duration duration;

  const StepGauge({
    super.key,
    required this.steps,
    required this.goal,
    required this.size,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final strokeWidth = size * (0.05 / 0.6);
    final discSize = size * (0.525 / 0.6);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: steps.toDouble()),
      duration: reduceMotion ? Duration.zero : duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedSteps, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: size,
              child: CustomPaint(
                painter: StepGaugePainter(
                  progress: goal > 0 ? animatedSteps / goal : 0.0,
                  strokeWidth: strokeWidth,
                  color: context.primaryColor,
                  trackColor: context.primaryColor.withValues(alpha: 0.1),
                ),
              ),
            ),
            ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  height: discSize,
                  width: discSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.cardColor,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        key: const Key('dashboard_step_count'),
                        '${animatedSteps.round()}',
                        style: GoogleFonts.sora(
                          fontSize: size * (0.105 / 0.6),
                          fontWeight: FontWeight.w900,
                          color: context.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      Text(
                        '/ $goal STEPS',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: size * (0.03 / 0.6),
                          fontWeight: FontWeight.w600,
                          color: context.textSecondary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Paints the track, the first lap, and (past the goal) the current extra lap.
class StepGaugePainter extends CustomPainter {
  /// Steps divided by goal; values above 1 mean the goal was passed.
  final double progress;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  const StepGaugePainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
  });

  /// Fraction of a full turn to draw for the base lap and the overflow lap.
  ///
  /// Up to the goal only the base lap moves. Past it the base lap stays full
  /// and the overflow lap shows progress through the current extra lap; an
  /// exact multiple of the goal (e.g. 2x) shows a full overflow lap, not zero.
  static ({double base, double overflow}) sweeps(double progress) {
    if (progress.isNaN || progress <= 0) return (base: 0, overflow: 0);
    if (progress <= 1) return (base: progress, overflow: 0);
    final extra = progress - 1;
    final lap = extra % 1;
    return (base: 1, overflow: lap == 0 ? 1 : lap);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      // Stroke centred on the box edge, like CircularProgressIndicator's
      // default strokeAlignCenter, so the ring keeps its old size.
      radius: size.shortestSide / 2,
    );
    const start = -math.pi / 2;
    Paint stroke(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, 2 * math.pi, false, stroke(trackColor));

    final s = sweeps(progress);
    if (s.base > 0) {
      canvas.drawArc(rect, start, 2 * math.pi * s.base, false, stroke(color));
    }
    if (s.overflow > 0) {
      final sweep = 2 * math.pi * s.overflow;
      // Same colour as the first lap, so a shadow under the leading cap is
      // what shows the new lap sitting on top. It is nudged a little ahead
      // of the cap (along the direction of travel) so it falls on the lap
      // below instead of being hidden under the new lap itself.
      final end = start + sweep;
      final radius = rect.width / 2;
      final capCenter =
          rect.center + Offset(math.cos(end), math.sin(end)) * radius;
      final ahead = Offset(-math.sin(end), math.cos(end)) * strokeWidth * 0.2;
      canvas.drawCircle(
        capCenter + ahead,
        strokeWidth / 2,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.6)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, strokeWidth * 0.25),
      );
      canvas.drawArc(rect, start, sweep, false, stroke(color));
    }
  }

  @override
  bool shouldRepaint(StepGaugePainter old) =>
      old.progress != progress ||
      old.strokeWidth != strokeWidth ||
      old.color != color ||
      old.trackColor != trackColor;
}
