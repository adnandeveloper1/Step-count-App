import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Material(
            color: Colors.transparent,
            child: child,
          ),
        ),
      ),
    );
  }
}
