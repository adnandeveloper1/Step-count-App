import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/app_colors.dart';
import '../onboarding_content.dart';
import '../onboarding_provider.dart';

/// Ends onboarding; the app root then shows the auth screen.
void finishOnboarding(WidgetRef ref) {
  ref.read(onboardingSeenProvider.notifier).complete();
}

bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

class PillButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final text = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        if (icon != null) ...[const SizedBox(width: 8), Icon(icon, size: 20)],
      ],
    );
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryEmerald,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: text,
      ),
    );
  }
}

class MonoLabel extends StatelessWidget {
  final String text;
  final Color color;

  const MonoLabel(this.text, {super.key, this.color = AppColors.textSecondary});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 1.4,
      ),
    );
  }
}

/// A drawn preview of the feature on page [index] of [onboardingPages].
class FeatureIllustration extends StatelessWidget {
  final OnboardingFeature feature;

  const FeatureIllustration({super.key, required this.feature});

  @override
  Widget build(BuildContext context) {
    return switch (feature) {
      OnboardingFeature.steps => const _StepRingPreview(),
      OnboardingFeature.gps => const _RoutePreview(),
      OnboardingFeature.coins => const _CoinsPreview(),
      OnboardingFeature.race => const _LeaderboardPreview(),
      OnboardingFeature.insights => const _ChartPreview(),
    };
  }
}

/// A route being drawn across a simple street map, with live distance and
/// time underneath, like the GPS tracking screen.
class _RoutePreview extends StatelessWidget {
  const _RoutePreview();

  @override
  Widget build(BuildContext context) {
    return _CountUp(
      builder: (t) => SizedBox(
        width: 260,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 160,
                width: double.infinity,
                child: CustomPaint(painter: _RoutePainter(progress: t)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _RouteStat(
                  value: (2.4 * t).toStringAsFixed(1),
                  unit: 'km',
                  label: 'Distance',
                ),
                _RouteStat(
                  value:
                      '${(18 * t).floor()}:${((32 * t).floor()).toString().padLeft(2, '0')}',
                  unit: 'min',
                  label: 'Duration',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteStat extends StatelessWidget {
  final String value;
  final String unit;
  final String label;

  const _RouteStat({
    required this.value,
    required this.unit,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: value),
                  TextSpan(
                    text: ' $unit',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              style: GoogleFonts.sora(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            MonoLabel(label),
          ],
        ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  final double progress;

  _RoutePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white10);

    // Streets.
    final street = Paint()
      ..color = Colors.white12
      ..strokeWidth = 6;
    for (final x in [0.22, 0.55, 0.83]) {
      canvas.drawLine(
        Offset(size.width * x, 0),
        Offset(size.width * x, size.height),
        street,
      );
    }
    for (final y in [0.3, 0.72]) {
      canvas.drawLine(
        Offset(0, size.height * y),
        Offset(size.width, size.height * y),
        street,
      );
    }

    final route = Path()
      ..moveTo(size.width * 0.1, size.height * 0.72)
      ..lineTo(size.width * 0.22, size.height * 0.72)
      ..lineTo(size.width * 0.22, size.height * 0.3)
      ..quadraticBezierTo(
        size.width * 0.4,
        size.height * 0.12,
        size.width * 0.55,
        size.height * 0.3,
      )
      ..lineTo(size.width * 0.55, size.height * 0.72)
      ..lineTo(size.width * 0.83, size.height * 0.72)
      ..lineTo(size.width * 0.83, size.height * 0.18);

    final metric = route.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * progress);
    canvas.drawPath(
      drawn,
      Paint()
        ..color = AppColors.primaryEmerald
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final start = metric.getTangentForOffset(0)!.position;
    canvas.drawCircle(start, 6, Paint()..color = Colors.white);
    final end = metric.getTangentForOffset(metric.length * progress)!.position;
    canvas.drawCircle(
      end,
      12,
      Paint()..color = AppColors.primaryEmerald.withValues(alpha: 0.25),
    );
    canvas.drawCircle(end, 6, Paint()..color = AppColors.primaryEmerald);
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.progress != progress;
}

class _StepRingPreview extends StatelessWidget {
  const _StepRingPreview();

  @override
  Widget build(BuildContext context) {
    return _CountUp(
      builder: (t) => SizedBox(
        width: 200,
        height: 200,
        child: CustomPaint(
          painter: _RingPainter(progress: 0.72 * t),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (7240 * t).round().toString(),
                  style: GoogleFonts.sora(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const MonoLabel('of 10,000 steps'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;

  _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 10;
    final base = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;
    final arc = Paint()
      ..color = AppColors.primaryEmerald
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 14;
    canvas.drawCircle(center, radius, base);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

class _CoinsPreview extends StatelessWidget {
  const _CoinsPreview();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CountUp(
          builder: (t) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.toll_rounded,
                color: AppColors.primaryEmerald,
                size: 44,
              ),
              const SizedBox(width: 10),
              Text(
                '+${(72 * t).round()}',
                style: GoogleFonts.sora(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const MonoLabel('coins earned today'),
        const SizedBox(height: 24),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            _BadgeChip(
              icon: Icons.local_fire_department_rounded,
              label: '7 day',
            ),
            SizedBox(width: 10),
            _BadgeChip(icon: Icons.military_tech_rounded, label: '10K'),
            SizedBox(width: 10),
            _BadgeChip(icon: Icons.palette_rounded, label: 'Ocean'),
          ],
        ),
      ],
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _BadgeChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.glassCardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassCardBorder),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primaryEmerald, size: 26),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardPreview extends StatelessWidget {
  const _LeaderboardPreview();

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('1', 'Sara', '58,210', false),
      ('2', 'You', '54,980', true),
      ('3', 'Ali', '49,305', false),
    ];
    return SizedBox(
      width: 260,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (rank, name, steps, isYou) in rows)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isYou
                    ? AppColors.primaryEmerald.withValues(alpha: 0.14)
                    : AppColors.glassCardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isYou
                      ? AppColors.primaryEmerald
                      : AppColors.glassCardBorder,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    rank,
                    style: GoogleFonts.jetBrainsMono(
                      fontWeight: FontWeight.w700,
                      color: isYou
                          ? AppColors.primaryEmerald
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      name,
                      style: GoogleFonts.sora(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    steps,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          const MonoLabel('weekly step race'),
        ],
      ),
    );
  }
}

class _ChartPreview extends StatelessWidget {
  const _ChartPreview();

  @override
  Widget build(BuildContext context) {
    const values = [0.45, 0.7, 0.55, 0.9, 0.62, 1.0, 0.8];
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return _CountUp(
      builder: (t) => SizedBox(
        width: 260,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 150,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < values.length; i++)
                    Container(
                      width: 24,
                      height: 150 * values[i] * t,
                      decoration: BoxDecoration(
                        color: i == 5
                            ? AppColors.primaryEmerald
                            : Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final d in days)
                  SizedBox(
                    width: 24,
                    child: Center(
                      child: Text(
                        d,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Animates 0 → 1 once when shown; jumps straight to 1 with reduced motion.
class _CountUp extends StatelessWidget {
  final Widget Function(double t) builder;

  const _CountUp({required this.builder});

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return builder(1);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (_, t, _) => builder(t),
    );
  }
}
