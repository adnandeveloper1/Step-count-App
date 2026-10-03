import 'package:flutter/material.dart';

class GlassDecoration {
  static BoxDecoration get decoration => BoxDecoration(
    color: Colors.white.withOpacity(0.1),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withOpacity(0.2)),
  );
}
