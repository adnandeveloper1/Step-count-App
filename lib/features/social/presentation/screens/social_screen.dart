import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme/theme_extensions.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/leaderboard_provider.dart';
import '../widgets/leaderboard_widgets.dart';

/// Social tab: the Step Race leaderboard.
class ChallengeScreen extends ConsumerStatefulWidget {
  const ChallengeScreen({super.key});

  @override
  ConsumerState<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends ConsumerState<ChallengeScreen> {
  LeaderboardPeriod _period = LeaderboardPeriod.month;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final horizontalPadding = size.width * 0.05;
    final myId = ref.watch(authStateProvider).value?.uid;
    final leaderboardAsync = ref.watch(leaderboardProvider(_period));

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
                height: 50,
                child: Center(
                  child: Text(
                    'STEP RACE',
                    style: GoogleFonts.sora(
                      fontSize: size.width * 0.06,
                      fontWeight: FontWeight.w900,
                      color: context.textPrimary,
                      letterSpacing: .1,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: PeriodTabs(
                selected: _period,
                onChanged: (period) => setState(() => _period = period),
              ),
            ),
            SizedBox(height: size.height * 0.012),
            Text(
              _period == LeaderboardPeriod.month
                  ? 'Best day this month · Resets in '
                        '${_daysLabel(daysUntilMonthlyReset(DateTime.now()))}'
                  : 'Steps so far today · Resets at midnight',
              key: const Key('leaderboard-reset'),
              style: GoogleFonts.inter(
                color: context.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: size.width * 0.031,
              ),
            ),
            Expanded(
              child: leaderboardAsync.when(
                skipLoadingOnReload: true,
                data: (users) => _buildBoard(context, users, myId),
                loading: () => Center(
                  child: CircularProgressIndicator(color: context.primaryColor),
                ),
                error: (error, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      'Error loading leaderboard',
                      style: TextStyle(color: context.textSecondary),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoard(
    BuildContext context,
    List<LeaderboardUser> users,
    String? myId,
  ) {
    final size = MediaQuery.of(context).size;
    final horizontalPadding = size.width * 0.05;
    final board = StepRaceBoard.from(users, _period);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        size.height * 0.02,
        horizontalPadding,
        size.height * 0.03,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (board.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: size.height * 0.04),
              child: Text(
                _period == LeaderboardPeriod.today
                    ? 'No steps synced today yet.'
                    : 'No scores this month yet.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: context.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: size.width * 0.036,
                ),
              ),
            )
          else ...[
            StepRaceRankCard(standing: StepRaceStanding.from(board, myId)),
            SizedBox(height: size.height * 0.02),
            StepRaceList(board: board, myId: myId),
          ],
          SizedBox(height: size.height * 0.02),
          const InviteFriendsCard(),
        ],
      ),
    );
  }

  static String _daysLabel(int days) => days == 1 ? '1 day' : '$days days';
}
