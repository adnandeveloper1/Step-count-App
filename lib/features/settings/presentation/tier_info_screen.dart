import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme/app_colors.dart';

class TierLevel {
  final String id;
  final String name;
  final String criteria;
  final String description;
  final Color badgeColor;

  const TierLevel({
    required this.id,
    required this.name,
    required this.criteria,
    required this.description,
    required this.badgeColor,
  });
}

final appTiers = [
  const TierLevel(
    id: '1',
    name: 'Diamond Tier',
    criteria: '12,000+ Daily Average',
    description: 'Elite performance. You have mastered daily movement and endurance.',
    badgeColor: AppColors.primaryEmerald,
  ),
  const TierLevel(
    id: '2',
    name: 'Gold Tier',
    criteria: '8,000+ Daily Average',
    description: 'Advanced dedication. Your step counts sit well above average.',
    badgeColor: Colors.amber,
  ),
  const TierLevel(
    id: '3',
    name: 'Silver Tier',
    criteria: '5,000+ Daily Average',
    description: 'Consistent movement. You are establishing a solid walking routine.',
    badgeColor: Colors.grey,
  ),
  const TierLevel(
    id: '4',
    name: 'Bronze Tier',
    criteria: '< 5,000 Daily Average',
    description: 'The starting point. Begin your fitness journey and build daily habits.',
    badgeColor: Colors.orangeAccent,
  ),
];

class TierInfoScreen extends StatelessWidget {
  const TierInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double horizontalPadding = size.width * 0.05;
    final double cardPadding = size.width * 0.04;
    final double titleFontSize = size.width * 0.05;
    final double criteriaFontSize = size.width * 0.035;
    final double descFontSize = size.width * 0.03;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(
          'LEAGUE TIERS',
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            fontSize: size.width * 0.05,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: EdgeInsets.only(
          left: horizontalPadding,
          right: horizontalPadding,
          top: size.height * 0.02,
          bottom: size.height * 0.05,
        ),
        itemCount: appTiers.length,
        itemBuilder: (context, index) {
          final tier = appTiers[index];

          return Container(
            margin: EdgeInsets.only(bottom: size.height * 0.02),
            padding: EdgeInsets.all(cardPadding),
            decoration: BoxDecoration(
              color: AppColors.glassCardBackground.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: tier.badgeColor.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: size.width * 0.15,
                  height: size.width * 0.15,
                  decoration: BoxDecoration(
                    color: tier.badgeColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: tier.badgeColor,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.military_tech,
                    color: tier.badgeColor,
                    size: size.width * 0.08,
                  ),
                ),
                SizedBox(width: size.width * 0.04),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tier.name,
                        style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: size.height * 0.005),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: size.width * 0.025,
                          vertical: size.height * 0.004,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tier.criteria,
                          style: GoogleFonts.inter(
                            color: tier.badgeColor,
                            fontSize: criteriaFontSize,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(height: size.height * 0.01),
                      Text(
                        tier.description,
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: descFontSize,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}