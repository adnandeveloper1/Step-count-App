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
  final _scrollController = ScrollController();
  final _viewportKey = GlobalKey();
  final _myRowKey = GlobalKey();

  LeaderboardPeriod _period = LeaderboardPeriod.month;

  /// Whether the signed-in user's own row (or podium spot) is on screen.
  /// Starts true so the pinned bar doesn't flash before the first layout.
  bool _myRowVisible = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_checkMyRowVisible);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _checkMyRowVisible() {
    final row = _myRowKey.currentContext?.findRenderObject() as RenderBox?;
    final viewport =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    var visible = false;
    if (row != null && row.attached && viewport != null) {
      final top = row.localToGlobal(Offset.zero, ancestor: viewport).dy;
      // Count the row as visible while at least half of it shows.
      final mid = top + row.size.height / 2;
      visible = mid >= 0 && mid <= viewport.size.height;
    }
    if (visible != _myRowVisible) setState(() => _myRowVisible = visible);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final horizontalPadding = size.width * 0.05;
    final myId = ref.watch(authStateProvider).value?.uid;
    final leaderboardAsync = ref.watch(leaderboardProvider(_period));

    // Re-check after every layout: the list can change under a still scroll.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkMyRowVisible();
    });

    final users = leaderboardAsync.value ?? const <LeaderboardUser>[];
    final ranks = leaderboardRanks(users, _period);
    final myIndex = users.indexWhere((u) => u.id == myId);

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
              child: Container(
                key: _viewportKey,
                child: leaderboardAsync.when(
                  skipLoadingOnReload: true,
                  data: (_) => _buildBoard(context, users, ranks, myId),
                  loading: () => Center(
                    child: CircularProgressIndicator(
                      color: context.primaryColor,
                    ),
                  ),
                  error: (error, stack) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        'Error loading leaderboard',
                        style: TextStyle(color: context.primaryColor),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (myIndex >= 0 && !_myRowVisible)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  size.height * 0.008,
                  horizontalPadding,
                  size.height * 0.012,
                ),
                child: MyPositionBar(
                  user: users[myIndex],
                  rank: ranks[myIndex],
                  score: users[myIndex].scoreFor(_period),
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
    List<int> ranks,
    String? myId,
  ) {
    final size = MediaQuery.of(context).size;
    final horizontalPadding = size.width * 0.05;
    final podiumCount = users.length < 3 ? users.length : 3;
    final meOnPodium =
        myId != null && users.take(podiumCount).any((u) => u.id == myId);

    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        size.height * 0.02,
        horizontalPadding,
        size.height * 0.03,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (users.isEmpty)
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
          else
            KeyedSubtree(
              key: meOnPodium ? _myRowKey : null,
              child: Podium(
                users: users.take(podiumCount).toList(),
                ranks: ranks.take(podiumCount).toList(),
                period: _period,
                myId: myId,
              ),
            ),
          SizedBox(height: size.height * 0.02),
          for (var i = podiumCount; i < users.length; i++)
            Padding(
              key: users[i].id == myId ? _myRowKey : null,
              padding: EdgeInsets.only(bottom: size.height * 0.012),
              child: LeaderboardRow(
                user: users[i],
                rank: ranks[i],
                score: users[i].scoreFor(_period),
                isMe: users[i].id == myId,
              ),
            ),
          SizedBox(height: size.height * 0.01),
          const InviteFriendsCard(),
        ],
      ),
    );
  }

  static String _daysLabel(int days) => days == 1 ? '1 day' : '$days days';
}
