import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/theme_extensions.dart';

/// Avatar for users who own the Pro Avatar Frame: a solid polished-gold ring
/// with a gold gem at the top. Static, so it costs nothing after first paint.
///
/// The gap between the ring and the avatar is transparent, so the frame sits
/// on any surface (scaffold, card, list row) without a mismatched fill.
class ProAvatar extends StatelessWidget {
  final String emojiAvatar;
  final double radius;
  final bool isPro;

  const ProAvatar({
    super.key,
    required this.emojiAvatar,
    this.radius = 40.0,
    this.isPro = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isPro) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.withValues(alpha: 0.2),
        child: Text(emojiAvatar, style: TextStyle(fontSize: radius)),
      );
    }

    final size = radius * 2;
    final inner = ProFramePainter.avatarRadius(size);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        foregroundPainter: const ProFramePainter(),
        child: Center(
          child: Container(
            width: inner * 2,
            height: inner * 2,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.cardColor,
            ),
            child: Text(
              emojiAvatar,
              style: TextStyle(fontSize: inner, height: 1.15),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the Pro frame: a gold ring shaded like polished metal and a gem
/// at 12 o'clock that overhangs the top edge.
class ProFramePainter extends CustomPainter {
  const ProFramePainter();

  static const _gold = Color(0xFFC9A227);
  static const _goldLight = Color(0xFFFFF6D0);
  static const _goldMid = Color(0xFFE9C866);
  static const _goldDeep = Color(0xFF7A5A12);
  static const _goldDark = Color(0xFFA87C14);

  /// Ring, gap and gem sizes for a frame [size] wide. Each scales with the
  /// frame but keeps a floor so the 44px dashboard avatar stays crisp.
  static ({double stroke, double gap, double gem}) geometry(double size) => (
    stroke: math.max(3.0, size * 0.055),
    gap: math.max(2.0, size * 0.035),
    gem: math.max(8.0, size * 0.14),
  );

  /// Radius left for the avatar inside the ring and gap.
  static double avatarRadius(double size) {
    final g = geometry(size);
    return size / 2 - g.stroke - g.gap;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final g = geometry(size.width);
    final center = size.center(Offset.zero);
    final ringRadius = size.width / 2 - g.stroke / 2;
    final ringRect = Rect.fromCircle(center: center, radius: ringRadius);

    canvas.drawCircle(
      center,
      ringRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = g.stroke
        ..shader = const SweepGradient(
          colors: [
            _goldDark,
            _goldLight,
            _gold,
            _goldMid,
            _goldDeep,
            _gold,
            _goldDark,
          ],
          stops: [0, 0.15, 0.35, 0.55, 0.7, 0.85, 1],
          transform: GradientRotation(-math.pi / 2),
        ).createShader(ringRect),
    );

    _paintGem(canvas, Offset(center.dx, g.gem * 0.15), g.gem);
  }

  void _paintGem(Canvas canvas, Offset gemCenter, double gem) {
    final half = gem / 2;
    final square = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: gem, height: gem),
      Radius.circular(gem * 0.15),
    );

    canvas.save();
    canvas.translate(gemCenter.dx, gemCenter.dy);
    canvas.rotate(math.pi / 4);
    canvas.drawShadow(
      Path()..addRRect(square),
      Colors.black.withValues(alpha: 0.4),
      1.5,
      false,
    );
    canvas.drawRRect(
      square,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_goldLight, _goldMid, _goldDark],
          stops: [0, 0.45, 1],
        ).createShader(Rect.fromLTWH(-half, -half, gem, gem)),
    );
    canvas.drawRRect(
      square,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _goldDeep,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ProFramePainter oldDelegate) => false;
}
