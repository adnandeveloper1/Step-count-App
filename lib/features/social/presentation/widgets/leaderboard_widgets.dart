import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../app/theme/theme_extensions.dart';
import '../../../../core/widgets/pro_avatar.dart';
import '../../../step_tracking/presentation/providers/step_provider.dart';
import '../../../step_tracking/presentation/widgets/glass_step_card.dart';
import '../providers/leaderboard_provider.dart';

const _ink = Color(0xFF0D0F12);

/// League colour for the avatar ring: the stored league, or one worked out
/// from the monthly best for users synced before leagues existed.
Color leagueColor(LeaderboardUser user) {
  switch (user.currentLeague?.toLowerCase()) {
    case 'diamond':
      return LeagueTier.diamond.color;
    case 'gold':
      return LeagueTier.gold.color;
    case 'silver':
      return LeagueTier.silver.color;
    case 'bronze':
      return LeagueTier.bronze.color;
  }
  if (user.monthlyHighScore >= 12000) return LeagueTier.diamond.color;
  if (user.monthlyHighScore >= 8000) return LeagueTier.gold.color;
  if (user.monthlyHighScore >= 5000) return LeagueTier.silver.color;
  return LeagueTier.bronze.color;
}

/// Fill behind an emoji or person icon inside the league ring: deep navy in
/// dark themes, the page background in light themes so it doesn't show as a
/// black disc on a white card.
Color avatarBackground(BuildContext context) =>
    context.isDarkMode ? const Color(0xFF1E293B) : context.backgroundColor;

/// The user's photo, emoji or a person icon inside a coloured ring. Pro
/// emoji avatars keep their animated frame.
class LeaderAvatar extends StatelessWidget {
  final LeaderboardUser user;
  final double size;
  final Color ringColor;

  const LeaderAvatar({
    super.key,
    required this.user,
    required this.size,
    required this.ringColor,
  });

  @override
  Widget build(BuildContext context) {
    final isImageUrl = user.avatarUrl.startsWith('http');
    if (user.showsProAvatar && !isImageUrl) {
      return ProAvatar(
        emojiAvatar: user.avatarUrl.isNotEmpty ? user.avatarUrl : '👤',
        radius: size / 2,
        isPro: true,
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: 2),
      ),
      child: CircleAvatar(
        backgroundColor: avatarBackground(context),
        backgroundImage: isImageUrl ? NetworkImage(user.avatarUrl) : null,
        // A broken photo URL falls back to the plain circle instead of throwing.
        onBackgroundImageError: isImageUrl ? (_, _) {} : null,
        child: isImageUrl
            ? null
            : (user.avatarUrl.isNotEmpty
                  ? Text(
                      user.avatarUrl,
                      style: TextStyle(fontSize: size * 0.48),
                    )
                  : Icon(
                      Icons.person,
                      color: context.primaryColor,
                      size: size * 0.5,
                    )),
      ),
    );
  }
}

/// "This month / Today" switch.
class PeriodTabs extends StatelessWidget {
  final LeaderboardPeriod selected;
  final ValueChanged<LeaderboardPeriod> onChanged;

  const PeriodTabs({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final primary = context.primaryColor;
    final onPrimary =
        ThemeData.estimateBrightnessForColor(primary) == Brightness.dark
        ? Colors.white
        : _ink;

    Widget tab(LeaderboardPeriod period, String label) {
      final isOn = period == selected;
      return Expanded(
        child: GestureDetector(
          key: Key('leaderboard-tab-${period.name}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(period),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(vertical: width * 0.025),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isOn ? primary : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: isOn ? onPrimary : context.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: width * 0.034,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          tab(LeaderboardPeriod.month, 'This month'),
          tab(LeaderboardPeriod.today, 'Today'),
        ],
      ),
    );
  }
}

/// Card at the end of the list asking the user to share the app.
class InviteFriendsCard extends StatelessWidget {
  const InviteFriendsCard({super.key});

  static const shareText =
      "I'm racing my friends on steps in Build Up. Join me and see who walks "
      'more: https://play.google.com/store/apps/details?id=com.nexappra.buildup';

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final primary = context.primaryColor;
    final onPrimary =
        ThemeData.estimateBrightnessForColor(primary) == Brightness.dark
        ? Colors.white
        : _ink;

    return Container(
      padding: EdgeInsets.all(width * 0.045),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: context.isDarkMode ? 0.1 : 0.16),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(Icons.group_add_rounded, color: primary, size: width * 0.09),
          SizedBox(width: width * 0.035),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Race your friends',
                  style: GoogleFonts.sora(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: width * 0.04,
                  ),
                ),
                SizedBox(height: width * 0.008),
                Text(
                  'Invite them to Build Up and see who walks more.',
                  style: GoogleFonts.inter(
                    color: context.textSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: width * 0.031,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: width * 0.02),
          Material(
            color: primary,
            shape: const StadiumBorder(),
            child: InkWell(
              key: const Key('leaderboard-invite'),
              customBorder: const StadiumBorder(),
              onTap: () =>
                  SharePlus.instance.share(ShareParams(text: shareText)),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: width * 0.045,
                  vertical: width * 0.022,
                ),
                child: Text(
                  'INVITE',
                  style: GoogleFonts.inter(
                    color: onPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: width * 0.03,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Line under the rank card's progress bar, e.g. "1,241 STEPS TO PASS OMAR".
String stepRaceHint(StepRaceStanding standing) {
  if (!standing.isSignedIn) return 'SIGN IN TO JOIN THE RACE';
  if (!standing.isRanked) return 'WALK MORE TO JOIN THE RACE';
  if (standing.isLeader) {
    return standing.isTied ? 'TIED FOR THE LEAD' : 'YOU ARE IN THE LEAD';
  }
  final name = (standing.aheadName ?? '').trim();
  final who = name.isEmpty ? 'THE NEXT WALKER' : name.toUpperCase();
  return '${formatSteps(standing.stepsToPass!)} STEPS TO PASS $who';
}

/// The signed-in user's place in the race: rank, score, a bar towards the
/// walker just ahead and how many steps it takes to pass them.
class StepRaceRankCard extends StatelessWidget {
  final StepRaceStanding standing;

  const StepRaceRankCard({super.key, required this.standing});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final primary = context.primaryColor;
    final accent = _accent(context);
    final score = standing.score;

    return Container(
      key: const Key('leaderboard-rank-card'),
      padding: EdgeInsets.all(width * 0.05),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: context.isDarkMode ? 0.12 : 0.18),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                standing.isRanked ? '#${standing.rank}' : '--',
                style: GoogleFonts.sora(
                  fontSize: width * 0.09,
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
              SizedBox(width: width * 0.03),
              if (score != null)
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatSteps(score),
                            style: GoogleFonts.sora(
                              fontSize: width * 0.062,
                              fontWeight: FontWeight.bold,
                              color: context.textPrimary,
                            ),
                          ),
                          SizedBox(width: width * 0.01),
                          Padding(
                            padding: EdgeInsets.only(bottom: width * 0.01),
                            child: Text(
                              'steps',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: width * 0.031,
                                fontWeight: FontWeight.w600,
                                color: context.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: width * 0.035),
          ClipRRect(
            borderRadius: BorderRadius.circular(width * 0.02),
            child: LinearProgressIndicator(
              value: standing.progress,
              minHeight: width * 0.02,
              backgroundColor: context.cardBorderColor,
              color: accent,
            ),
          ),
          SizedBox(height: width * 0.025),
          Text(
            stepRaceHint(standing),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.jetBrainsMono(
              fontSize: width * 0.031,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Every walker on the board as plain rows inside one card.
class StepRaceList extends StatelessWidget {
  final StepRaceBoard board;
  final String? myId;

  const StepRaceList({super.key, required this.board, required this.myId});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return GlassCard(
      padding: EdgeInsets.symmetric(
        horizontal: width * 0.02,
        vertical: width * 0.015,
      ),
      child: Column(
        children: [
          for (var i = 0; i < board.length; i++)
            _StepRaceRow(
              user: board.users[i],
              rank: board.ranks[i],
              score: board.users[i].scoreFor(board.period),
              isMe: board.users[i].id == myId,
              showDivider: i > 0,
            ),
        ],
      ),
    );
  }
}

class _StepRaceRow extends StatelessWidget {
  final LeaderboardUser user;
  final int rank;
  final int score;
  final bool isMe;
  final bool showDivider;

  const _StepRaceRow({
    required this.user,
    required this.rank,
    required this.score,
    required this.isMe,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final accent = _accent(context);
    final numberColor = isMe ? accent : context.textSecondary;
    final numberStyle = GoogleFonts.jetBrainsMono(
      fontSize: width * 0.034,
      fontWeight: FontWeight.w700,
      color: numberColor,
    );

    return Container(
      key: Key('leaderboard-row-${user.id}'),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                top: BorderSide(color: context.cardBorderColor, width: 0.5),
              )
            : null,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: width * 0.02,
          vertical: width * 0.03,
        ),
        decoration: isMe
            ? BoxDecoration(
                color: context.primaryColor.withValues(
                  alpha: context.isDarkMode ? 0.1 : 0.16,
                ),
                borderRadius: BorderRadius.circular(width * 0.035),
              )
            : null,
        child: Row(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: width * 0.07),
              child: Text(
                '$rank',
                key: Key('leaderboard-rank-${user.id}'),
                style: numberStyle,
              ),
            ),
            LeaderAvatar(
              user: user,
              size: width * 0.09,
              ringColor: leagueColor(user),
            ),
            SizedBox(width: width * 0.03),
            Expanded(
              child: Text(
                isMe ? 'You' : user.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.sora(
                  fontSize: width * 0.038,
                  fontWeight: FontWeight.w600,
                  color: isMe ? accent : context.textPrimary,
                ),
              ),
            ),
            SizedBox(width: width * 0.02),
            Text(formatSteps(score), style: numberStyle),
          ],
        ),
      ),
    );
  }
}

/// The theme colour, darkened in light mode so lime text and bars keep
/// enough contrast on a light card.
Color _accent(BuildContext context) {
  final primary = context.primaryColor;
  return context.isDarkMode ? primary : Color.lerp(primary, Colors.black, 0.4)!;
}
