import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme/app_colors.dart';
import '../providers/challenge_provider.dart';
import 'challenge_card.dart';

class AllChallengesScreen extends ConsumerWidget {
  const AllChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challenges = ref.watch(challengeProvider);

    // Filter challenges into three distinct groups
    final activeNow = challenges.where((c) => c.isActive && !c.isCompleted).toList();
    final completed = challenges.where((c) => c.isCompleted).toList();
    final available = challenges.where((c) => !c.isActive && !c.isCompleted).toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(
          'ALL CHALLENGES',
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. ACTIVE NOW SECTION
              if (activeNow.isNotEmpty) ...[
                _buildSectionHeader('ACTIVE NOW', Colors.grey),
                const SizedBox(height: 12),
                ...activeNow.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: ChallengeCard(challenge: c),
                    )),
                const SizedBox(height: 16),
              ],

              // 2. COMPLETED SECTION
              if (completed.isNotEmpty) ...[
                _buildSectionHeader('COMPLETED', Colors.grey),
                const SizedBox(height: 12),
                ...completed.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: ChallengeCard(challenge: c),
                    )),
                const SizedBox(height: 16),
              ],

              // 3. AVAILABLE SECTION
              if (available.isNotEmpty) ...[
                _buildSectionHeader('AVAILABLE', AppColors.textSecondary),
                const SizedBox(height: 12),
                ...available.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: ChallengeCard(challenge: c),
                    )),
              ],
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Text(
      title,
      style: GoogleFonts.inter(
        color: color,
        fontWeight: FontWeight.w900,
        fontSize: 14,
        letterSpacing: 1.5,
      ),
    );
  }
}
