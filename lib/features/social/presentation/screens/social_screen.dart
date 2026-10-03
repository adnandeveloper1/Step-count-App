import 'package:build_up/features/social/presentation/screens/all_challenges_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../shop/presentation/providers/theme_provider.dart';
import '../../../step_tracking/presentation/providers/step_provider.dart';
import '../providers/challenge_provider.dart';
import '../providers/leaderboard_provider.dart';
import 'challenge_card.dart';

class ChallengeScreen extends ConsumerWidget {
  const ChallengeScreen({super.key});

  Color _getUserTierColor(LeaderboardUser user) {
    // Priority 1: Use the actual league saved in Firestore
    final league = user.currentLeague?.toLowerCase();
    if (league == 'diamond') return LeagueTier.diamond.color;
    if (league == 'gold') return LeagueTier.gold.color;
    if (league == 'silver') return LeagueTier.silver.color;
    if (league == 'bronze') return LeagueTier.bronze.color;

    // Priority 2: Fallback calculation for legacy data
    if (user.monthlyHighScore >= 12000) return LeagueTier.diamond.color;
    if (user.monthlyHighScore >= 8000) return LeagueTier.gold.color;
    if (user.monthlyHighScore >= 5000) return LeagueTier.silver.color;
    return LeagueTier.bronze.color;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final themeState = ref.watch(themeProvider);
    final leaderboardAsync = ref.watch(leaderboardProvider);
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final challenges = ref.watch(challengeProvider);
    
    final double horizontalPadding = size.width * 0.05;
    final double verticalSpacing = size.height * 0.02;
    final double titleFontSize = size.width * 0.06;

     //DisplayList logic
    final activeList = challenges.where((c) => c.isActive && !c.isCompleted).toList();
    final displayList = [...activeList.take(2)];

    if (displayList.length < 2) {
      final fallbackList = challenges
          .where((c) => !c.isActive && !c.isCompleted && !displayList.contains(c))
          .toList();
      displayList.addAll(fallbackList.take(2 - displayList.length));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(

          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 10,
              ),
              child: SizedBox(
                height: 50, // Force consistent height
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Expanded(child: SizedBox.shrink()),
                    Text(
                      'CHALLENGES',
                      style: GoogleFonts.sora( // Changed to Sora for consistency
                        fontSize: screenWidth * 0.06,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: .1,
                      ),
                    ),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: verticalSpacing),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding * 1.5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Active',
                            style: GoogleFonts.sora(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: 1.2,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AllChallengesScreen(),
                                ),
                              );
                            },
                            child: Text(
                              'VIEW All',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: titleFontSize / 2,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: Column(
                        children: displayList.map((c) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: verticalSpacing),
                            child: ChallengeCard(challenge: c),
                          );
                        }).toList(),
                      ),
                    ),
                    SizedBox(height: verticalSpacing / 2),

                    Center(
                      child: Text(
                        'STEP RACE',
                        style: GoogleFonts.inter(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    SizedBox(height: verticalSpacing),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: leaderboardAsync.when(
                        data: (users) {
                          if (users.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20.0),
                                child: Text(
                                  'No data available',
                                  style: TextStyle(color: AppColors.textSecondary),
                                ),
                              ),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: users.length,
                            itemBuilder: (context, index) {
                              final user = users[index];
                              final bool isImageUrl = user.avatarUrl.startsWith('http');
                              final double avatarSize = size.width * 0.12;
                              final userTierColor = _getUserTierColor(user);

                              return Container(
                                margin: EdgeInsets.only(bottom: size.height * 0.015),
                                padding: EdgeInsets.symmetric(
                                  horizontal: size.width * 0.05,
                                  vertical: size.height * 0.02,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.glassCardBackground.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(24),

                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: avatarSize,
                                      height: avatarSize,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: userTierColor,
                                          width: 2,
                                        ),
                                      ),
                                      child: CircleAvatar(
                                        backgroundColor: const Color(0xFF1E293B),
                                        backgroundImage: isImageUrl ? NetworkImage(user.avatarUrl) : null,
                                        child: !isImageUrl && user.avatarUrl.isNotEmpty
                                            ? Text(user.avatarUrl, style: TextStyle(fontSize: size.width * 0.06))
                                            : (user.avatarUrl.isEmpty
                                            ? Icon(Icons.person, color: AppColors.primaryEmerald, size: size.width * 0.06)
                                            : null),
                                      ),
                                    ),
                                    SizedBox(width: size.width * 0.04),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            user.name,
                                            style: GoogleFonts.inter(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: size.width * 0.04,
                                            ),
                                          ),
                                          SizedBox(height: size.height * 0.005),
                                          Text(
                                            'HIGH SCORE',
                                            style: GoogleFonts.inter(
                                              color: AppColors.textSecondary,
                                              fontSize: size.width * 0.028,
                                              letterSpacing: 1.2,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${user.monthlyHighScore}',
                                      style: GoogleFonts.inter(
                                        color: userTierColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: size.width * 0.05,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                        loading: () => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(color: themeState.primaryColor),
                          ),
                        ),
                        error: (error, stack) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Text(
                              'Error loading leaderboard',
                              style: TextStyle(color: themeState.primaryColor),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: size.height * 0.05),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
