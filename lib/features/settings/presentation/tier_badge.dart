import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../step_tracking/presentation/providers/step_provider.dart';


class LeagueTierBadge extends StatelessWidget {
  final LeagueTier tier;
  final String tierName;

  const LeagueTierBadge({
    super.key,
    required this.tier,
    required this.tierName,
  });

  @override
  Widget build(BuildContext context) {
    Color tierColor;
    IconData tierIcon;

    switch (tier) {
      case LeagueTier.diamond:
        tierColor = Colors.cyanAccent;
        tierIcon = Icons.diamond;
        break;
      case LeagueTier.gold:
        tierColor = Colors.amber;
        tierIcon = Icons.military_tech;
        break;
      case LeagueTier.silver:
        tierColor = const Color(0xFFC0C0C0);
        tierIcon = Icons.shield;
        break;
      case LeagueTier.bronze:
        tierColor = const Color(0xFFCD7F32);
        tierIcon = Icons.star;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: tierColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: tierColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tierIcon, color: tierColor, size: 16),
          const SizedBox(width: 8),
          Text(
            tierName.toUpperCase(),
            style: GoogleFonts.sora(
              color: tierColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}