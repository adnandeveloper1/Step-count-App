import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../app/theme/theme_extensions.dart';
import '../../../../core/widgets/pro_avatar.dart';
import '../../../step_tracking/presentation/providers/step_provider.dart';
import '../providers/leaderboard_provider.dart';

const _ink = Color(0xFF0D0F12);

/// Gold, silver and bronze for positions 1–3; null below that.
Color? medalColor(int rank) => switch (rank) {
  1 => const Color(0xFFFFC83D),
  2 => const Color(0xFFC0C7D1),
  3 => const Color(0xFFCD7F32),
  _ => null,
};

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

/// Position shown left of the avatar: a medal circle for the top three, a
/// plain number for everyone else.
class RankBadge extends StatelessWidget {
  final int rank;
  final double size;

  const RankBadge({super.key, required this.rank, required this.size});

  @override
  Widget build(BuildContext context) {
    final medal = medalColor(rank);
    final text = Text(
      '$rank',
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        color: medal != null ? _ink : context.textSecondary,
        fontWeight: FontWeight.w800,
        fontSize: size * (rank >= 100 ? 0.36 : 0.48),
      ),
    );
    if (medal == null) return SizedBox(width: size, child: text);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: medal),
      child: text,
    );
  }
}

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
    if (user.unlockedItems.contains('avatar_pro') && !isImageUrl) {
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
        backgroundColor: const Color(0xFF1E293B),
        backgroundImage: isImageUrl ? NetworkImage(user.avatarUrl) : null,
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

/// Score with a small "steps" caption underneath.
class StepScore extends StatelessWidget {
  final int steps;
  final double fontSize;
  final CrossAxisAlignment align;

  const StepScore({
    super.key,
    required this.steps,
    required this.fontSize,
    this.align = CrossAxisAlignment.end,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formatSteps(steps),
          style: GoogleFonts.inter(
            color: context.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: fontSize,
          ),
        ),
        Text(
          'steps',
          style: GoogleFonts.inter(
            color: context.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: fontSize * 0.55,
          ),
        ),
      ],
    );
  }
}

/// Small lime "YOU" tag next to the signed-in user's name.
class YouTag extends StatelessWidget {
  final double fontSize;

  const YouTag({super.key, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    final primary = context.primaryColor;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 0.6,
        vertical: fontSize * 0.15,
      ),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(fontSize),
      ),
      child: Text(
        'YOU',
        style: GoogleFonts.inter(
          color: context.isDarkMode
              ? primary
              : Color.lerp(primary, Colors.black, 0.4),
          fontWeight: FontWeight.w800,
          fontSize: fontSize,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// One leaderboard row below the podium.
class LeaderboardRow extends StatelessWidget {
  final LeaderboardUser user;
  final int rank;
  final int score;
  final bool isMe;

  const LeaderboardRow({
    super.key,
    required this.user,
    required this.rank,
    required this.score,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: width * 0.04,
        vertical: width * 0.035,
      ),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isMe ? context.primaryColor : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          RankBadge(
            key: Key('leaderboard-rank-${user.id}'),
            rank: rank,
            size: width * 0.08,
          ),
          SizedBox(width: width * 0.03),
          LeaderAvatar(
            user: user,
            size: width * 0.12,
            ringColor: leagueColor(user),
          ),
          SizedBox(width: width * 0.035),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: width * 0.04,
                    ),
                  ),
                ),
                if (isMe) ...[
                  SizedBox(width: width * 0.02),
                  YouTag(fontSize: width * 0.024),
                ],
              ],
            ),
          ),
          SizedBox(width: width * 0.02),
          StepScore(steps: score, fontSize: width * 0.045),
        ],
      ),
    );
  }
}

/// Entry in the [Podium]: avatar, name, score and a medal-coloured block
/// whose height shows the position.
class _PodiumSpot extends StatelessWidget {
  final LeaderboardUser user;
  final int rank;
  final int score;
  final bool isMe;
  final bool isWinner;

  const _PodiumSpot({
    required this.user,
    required this.rank,
    required this.score,
    required this.isMe,
    required this.isWinner,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final medal = medalColor(rank) ?? context.textSecondary;
    final avatarSize = width * (isWinner ? 0.2 : 0.155);
    final blockHeight = width * (rank == 1 ? 0.24 : (rank == 2 ? 0.17 : 0.12));

    return Column(
      key: Key('podium-${user.id}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.workspace_premium_rounded,
          color: isWinner ? medal : Colors.transparent,
          size: width * 0.08,
        ),
        LeaderAvatar(user: user, size: avatarSize, ringColor: medal),
        SizedBox(height: width * 0.02),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: width * 0.01),
          child: Text(
            user.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: isMe ? context.primaryColor : context.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: width * 0.034,
            ),
          ),
        ),
        if (isMe) YouTag(fontSize: width * 0.022),
        SizedBox(height: width * 0.01),
        StepScore(
          steps: score,
          fontSize: width * 0.04,
          align: CrossAxisAlignment.center,
        ),
        SizedBox(height: width * 0.02),
        Container(
          height: blockHeight,
          alignment: Alignment.topCenter,
          padding: EdgeInsets.only(top: width * 0.02),
          decoration: BoxDecoration(
            color: medal.withValues(alpha: 0.18),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            border: Border(top: BorderSide(color: medal, width: 3)),
          ),
          child: Text(
            '$rank',
            style: GoogleFonts.sora(
              color: medal,
              fontWeight: FontWeight.w900,
              fontSize: width * (isWinner ? 0.08 : 0.065),
            ),
          ),
        ),
      ],
    );
  }
}

/// Top three as a podium: 2nd on the left, 1st raised in the middle, 3rd on
/// the right. Takes up to three users already sorted highest first.
class Podium extends StatelessWidget {
  final List<LeaderboardUser> users;
  final List<int> ranks;
  final LeaderboardPeriod period;
  final String? myId;

  const Podium({
    super.key,
    required this.users,
    required this.ranks,
    required this.period,
    required this.myId,
  });

  @override
  Widget build(BuildContext context) {
    Widget spot(int i) => Expanded(
      child: i < users.length
          ? _PodiumSpot(
              user: users[i],
              rank: ranks[i],
              score: users[i].scoreFor(period),
              isMe: users[i].id == myId,
              isWinner: i == 0,
            )
          : const SizedBox.shrink(),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [spot(1), spot(0), spot(2)],
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

/// Bar pinned under the list showing the signed-in user's position while
/// their own row is off screen.
class MyPositionBar extends StatelessWidget {
  final LeaderboardUser user;
  final int rank;
  final int score;

  const MyPositionBar({
    super.key,
    required this.user,
    required this.rank,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Container(
      key: const Key('leaderboard-my-position'),
      padding: EdgeInsets.symmetric(
        horizontal: width * 0.04,
        vertical: width * 0.028,
      ),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.primaryColor, width: 1.5),
      ),
      child: Row(
        children: [
          RankBadge(rank: rank, size: width * 0.08),
          SizedBox(width: width * 0.03),
          LeaderAvatar(
            user: user,
            size: width * 0.1,
            ringColor: leagueColor(user),
          ),
          SizedBox(width: width * 0.035),
          Expanded(
            child: Text(
              'Your position',
              style: GoogleFonts.inter(
                color: context.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: width * 0.038,
              ),
            ),
          ),
          StepScore(steps: score, fontSize: width * 0.042),
        ],
      ),
    );
  }
}
