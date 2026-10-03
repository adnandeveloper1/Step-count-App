import 'package:build_up/features/workout_goal/widgets/glass_panal.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../workout_goal/workout_goal_screen.dart';
import '../providers/challenge_provider.dart';

class ChallengeCard extends ConsumerWidget {
  final ChallengeItem challenge;

  const ChallengeCard({super.key, required this.challenge});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final double cardPadding = size.width * 0.035;
    final double titleFontSize = size.width * 0.07;
    final double numberFontSize = size.width * 0.06;
    final double labelFontSize = size.width * 0.022;
    final isCompleted = challenge.isCompleted;
    final isFailed = challenge.isFailed;


    String _formatNumber(int number) {
      if (number >= 100000) {
        double val = number / 100000;
        return '${val % 1 == 0 ? val.toInt() : val.toStringAsFixed(1)}L';
      } else if (number >= 1000) {
        double val = number / 1000;
        return '${val % 1 == 0 ? val.toInt() : val.toStringAsFixed(1)}K';
      }
      return number.toString();
    }

    String badgeText = '${challenge.durationInHours}H LIMIT';
    Color badgeColor = AppColors.primaryEmerald;
    IconData badgeIcon = Icons.timer_outlined;
    String coins = challenge.rewardCoins.toString();

    if (challenge.isFailed) {
      badgeText = 'FAILED';
      badgeColor = Colors.redAccent;
      badgeIcon = Icons.cancel;
    } else if (challenge.isCompleted) {
      badgeText = 'COMPLETED';
      badgeIcon = Icons.emoji_events;
    } else if (challenge.isActive && challenge.startTime != null) {
      final deadline = challenge.startTime!.add(
        Duration(hours: challenge.durationInHours),
      );
      final diff = deadline.difference(DateTime.now());
      if (diff.inDays > 0) {
        badgeText = '${diff.inDays} DAYS LEFT';
      } else {
        badgeText = '${diff.inHours}H LEFT';
      }
    }

    return GlassPanel(
      child: Container(

        width: double.infinity,
        decoration: BoxDecoration(
          color: isFailed
              ? CustomColors.error.withOpacity(0.05)
              : CustomColors.surface.withOpacity(0.0),
          borderRadius: BorderRadius.circular(16),
        ),
      
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
      
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  challenge.title,
                                  style: GoogleFonts.sora(
                                    color: AppColors.textPrimary,
                                    fontSize: titleFontSize / 1.2,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: size.height * 0.004),
                                Text(
                                  challenge.subtitle,
                                  style: GoogleFonts.sora(
                                    color: AppColors.textSecondary,
                                    fontSize: titleFontSize / 2.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
      
                          SizedBox(width: 12),
      
                          Column(
                            crossAxisAlignment: CrossAxisAlignment
                                .start,
                            children: [
      
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: size.width * 0.01,
                                  vertical: size.height * 0.006,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize
                                      .min,
                                  children: [
                                    Icon(
                                      badgeIcon,
                                      color: badgeColor,
                                      size: size.width * 0.03,
                                    ),
                                    SizedBox(width: size.width * 0.01),
                                    Text(
                                      badgeText,
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: labelFontSize * 1.3,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
      
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: size.width * 0.01,
                                  vertical: size.height * 0.004,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.paid,
                                      color: AppColors.primaryEmerald,
                                      size: size.width * 0.04,
                                    ),
                                    SizedBox(width: size.width * 0.01),
                                    Text(
                                      "+$coins Coins",
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: titleFontSize / 2.6,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: size.height * 0.002),
                      //steps progress
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          SizedBox(width: size.width * 0.012),
                          Text(
                            _formatNumber(challenge.currentSteps),
                            style: GoogleFonts.inter(
                              color: AppColors.primaryEmerald,
                              fontSize: numberFontSize * 1.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            ' /${_formatNumber(challenge.targetSteps)}',
                            style: GoogleFonts.inter(
                              color: AppColors.textSecondary,
                              fontSize: size.width * 0.04,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
      
                                children: [
                                  Text(
                                    isCompleted
                                        ? 'DONE 🏆  '
                                        : (challenge.isActive
                                              ? 'ACTIVE'
                                              : 'START'),
                                    style: GoogleFonts.inter(
                                      color: isCompleted
                                          ? Colors.amber
                                          : (challenge.isActive
                                                ? AppColors.primaryEmerald
                                                : AppColors.textSecondary),
                                      fontSize: isCompleted ?
                                      size.width * 0.042  :  size.width * 0.032,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  if (!isCompleted)
                                    Transform.scale(
                                      scale: 0.8,
                                      child: CupertinoSwitch(
                                        value: challenge.isActive,
                                        activeColor: AppColors.primaryEmerald,
                                        onChanged: (bool value) {
                                          if (value) {
                                            ref
                                                .read(challengeProvider.notifier)
                                                .startChallenge(challenge.id);
                                          } else {
                                            ref
                                                .read(challengeProvider.notifier)
                                                .stopChallenge(challenge.id);
                                          }
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
