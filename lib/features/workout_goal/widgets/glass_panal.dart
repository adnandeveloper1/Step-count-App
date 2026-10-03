import 'dart:ui';
import 'package:flutter/material.dart';
import '../workout_goal_screen.dart';

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final Color? color;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 32,
    this.blur = 20,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? CustomColors.surface.withValues(alpha: .65),
            borderRadius: BorderRadius.circular(radius),
            border: const Border(
              top: BorderSide(color: Colors.white10),
              left: BorderSide(color: Colors.white10),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}