import 'package:build_up/app/theme/theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The app's coin: a disc with a raised rim and a "B" monogram, tinted with
/// the active theme's primary colour.
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 20});

  final double size;

  /// Below this size the monogram is too small to read, so only the disc
  /// and rim are drawn.
  static const _minMonogramSize = 16.0;

  static Color _shade(Color color, double lightness) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness(lightness.clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.primaryColor;
    final baseLightness = HSLColor.fromColor(base).lightness;
    final light = _shade(base, baseLightness + 0.18);
    final dark = _shade(base, baseLightness - 0.2);
    final ink = _shade(base, baseLightness - 0.35);

    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [light, base, dark],
          ),
          boxShadow: [
            BoxShadow(
              color: dark.withValues(alpha: 0.35),
              blurRadius: size * 0.15,
              offset: Offset(0, size * 0.06),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: base,
              border: Border.all(
                color: light.withValues(alpha: 0.8),
                width: size * 0.05,
              ),
            ),
            child: size < _minMonogramSize
                ? null
                : Center(
                    child: Text(
                      'B',
                      style: GoogleFonts.sora(
                        fontSize: size * 0.42,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        color: ink,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
