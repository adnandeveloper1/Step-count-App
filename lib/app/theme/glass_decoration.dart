import 'package:flutter/material.dart';

class GlassDecoration {
  static BoxDecoration get decoration => BoxDecoration(
    color: Colors.white.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
  );
}
