import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme/app_colors.dart';
import 'glass_step_card.dart';


class MetricGlassCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;

  const MetricGlassCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryEmerald, size: 20),
          const SizedBox(height: 12),
          Text(
            '$value $unit',
            style: GoogleFonts.sora(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: .8,
            ),
          ),
          Text(
            label,
            style:  GoogleFonts.sora(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: .8,
          ),
          ),
        ],
      ),
    );
  }
}