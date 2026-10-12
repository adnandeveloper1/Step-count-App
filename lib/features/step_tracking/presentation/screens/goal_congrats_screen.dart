import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme/theme_extensions.dart';
import '../../../../core/utils/number_format.dart';
import '../../../../core/utils/step_history.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../social/presentation/providers/challenge_provider.dart'
    hide storageProvider;
import '../providers/step_provider.dart';
import '../widgets/achievement_story_card.dart';
import '../widgets/goal_arc_painter.dart';
import '../widgets/glass_step_card.dart';

// Celebration shown once the daily step goal is reached.
// Reads today's numbers straight from the app's providers.

class GoalCongratsScreen extends ConsumerWidget {
  final VoidCallback? onContinue;
  final VoidCallback? onShare;

  const GoalCongratsScreen({super.key, this.onContinue, this.onShare});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stepState = ref.watch(stepNotifierProvider);
    final challenges = ref.watch(challengeProvider);
    final avatar = ref.watch(userProfileProvider).value?['avatarUrl'] ?? '👦';
    final now = DateTime.now();

    return GoalCongratsView(
      steps: stepState.currentSteps,
      goalSteps: stepState.goalSteps,
      distanceKm: stepState.distanceKm,
      calories: stepState.calories,
      // Same estimate the dashboard uses: 100 steps per active minute.
      activeTime: Duration(minutes: stepState.currentSteps ~/ 100),
      streakDays: goalStreak(
        // Use the live count for today so the streak always includes it.
        recordDay(
          ref.watch(storageProvider).getDailyHistory(),
          now,
          stepState.currentSteps,
        ),
        stepState.goalSteps,
        now,
      ),
      challenges: challenges
          .where((c) => c.isActive && !c.isCompleted && !c.isFailed)
          .toList(),
      avatar: avatar,
      onContinue: onContinue,
      onShare: onShare,
    );
  }
}

// Pure UI: every number comes in through the constructor.

class GoalCongratsView extends StatefulWidget {
  final int steps;
  final int goalSteps;
  final double distanceKm;
  final double calories;
  final Duration activeTime;
  final int streakDays;
  final List<ChallengeItem> challenges;
  final String avatar;
  final VoidCallback? onContinue;
  final VoidCallback? onShare;

  const GoalCongratsView({
    super.key,
    required this.steps,
    required this.goalSteps,
    required this.distanceKm,
    required this.calories,
    required this.activeTime,
    this.streakDays = 0,
    this.challenges = const [],
    this.avatar = '👦',
    this.onContinue,
    this.onShare,
  });

  @override
  State<GoalCongratsView> createState() => _GoalCongratsViewState();
}

class _GoalCongratsViewState extends State<GoalCongratsView>
    with TickerProviderStateMixin {
  static const int _maxChallengesShown = 2;

  late final AnimationController _introController;
  late final AnimationController _pulseController;
  late final AnimationController _sparkleController;
  final List<_Sparkle> _sparkles = _Sparkle.burst(math.Random(), 80);

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
    _introController.forward();
    _sparkleController.forward();
  }

  // Skip the intro, pulse and sparkles when the system asks for less motion.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _introController.value = 1;
      _sparkleController.value = 1;
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _introController.dispose();
    _pulseController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  // Default share: preview and send the story image.
  void _shareStory() {
    showAchievementShareSheet(
      context,
      GoalAchievement(
        steps: widget.steps,
        goalSteps: widget.goalSteps,
        distanceKm: widget.distanceKm,
        calories: widget.calories,
        activeTime: widget.activeTime,
        streakDays: widget.streakDays,
        date: DateTime.now(),
      ),
    );
  }

  void _close() {
    if (widget.onContinue != null) {
      widget.onContinue!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final gaugeSize = math.min(screenWidth * 0.7, 280.0);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: Stack(
        children: [
          // Ambient lime glow behind the gauge
          Positioned(
            top: size.height * 0.14,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: gaugeSize * 1.1,
                height: gaugeSize * 1.1,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: context.primaryColor.withValues(alpha: 0.12),
                      blurRadius: 120,
                      spreadRadius: 30,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  _buildTopBar(),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 12),
                              _buildGauge(gaugeSize),
                              if (widget.steps >= widget.goalSteps) ...[
                                const SizedBox(height: 28),
                                _fadeIn(0.45, _buildStreakBadge()),
                              ],
                              const SizedBox(height: 28),
                              _fadeIn(0.55, _buildStatsRow()),
                              if (widget.challenges.isNotEmpty) ...[
                                const SizedBox(height: 28),
                                _fadeIn(0.65, _buildChallenges()),
                              ],
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  _fadeIn(0.7, _buildActions()),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          // Sparkles rain down from the top over everything
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _sparkleController,
                builder: (context, _) => CustomPaint(
                  painter: _SparklePainter(
                    sparkles: _sparkles,
                    time: _sparkleController.value,
                    palette: _sparklePalette(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return SizedBox(
      height: 50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GlassCard(
            padding: EdgeInsets.zero,
            child: IconButton(
              key: const Key('goalCongrats.close'),
              onPressed: _close,
              icon: Icon(Icons.close, color: context.textPrimary),
              tooltip: 'Close',
            ),
          ),
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.cardColor,
              border: Border.all(color: context.cardBorderColor),
            ),
            child: Center(
              child: Text(widget.avatar, style: const TextStyle(fontSize: 22)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGauge(double gaugeSize) {
    // Fills to steps / goal, so the arc is only full once the goal is met.
    final goalFraction = widget.goalSteps > 0
        ? (widget.steps / widget.goalSteps).clamp(0.0, 1.0)
        : 1.0;
    final sweep = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
    );

    return SizedBox(
      width: gaugeSize,
      height: gaugeSize,
      child: AnimatedBuilder(
        animation: sweep,
        builder: (context, _) {
          final countedSteps = (widget.steps * sweep.value).round();
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(gaugeSize),
                painter: GoalArcPainter(
                  progress: sweep.value * goalFraction,
                  strokeWidth: gaugeSize * 0.05,
                  color: context.primaryColor,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'STEPS',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondary,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatThousands(countedSteps),
                      key: const Key('goalCongrats.steps'),
                      style: GoogleFonts.sora(
                        fontSize: gaugeSize * 0.2,
                        fontWeight: FontWeight.w800,
                        color: context.primaryColor,
                        height: 1.1,
                        letterSpacing: -1.5,
                        shadows: [
                          Shadow(
                            color: context.primaryColor.withValues(alpha: 0.35),
                            blurRadius: 24,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '/ ${formatThousands(widget.goalSteps)} GOAL',
                    key: const Key('goalCongrats.goal'),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildTargetChip(),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTargetChip() {
    final extra = widget.steps - widget.goalSteps;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: context.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: context.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween<double>(
              begin: 0.35,
              end: 1,
            ).animate(_pulseController),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            extra > 0
                ? 'TARGET EXCEEDED +${formatThousands(extra)}'
                : extra == 0
                ? 'GOAL REACHED'
                : '${formatThousands(-extra)} TO GO',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: context.primaryColor,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakBadge() {
    final label = streakLabel(widget.streakDays) ?? 'DAILY GOAL COMPLETE';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: context.cardBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            widget.streakDays > 1 ? '🔥' : '🏆',
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final divider = Container(
      width: 1,
      height: 40,
      color: context.cardBorderColor,
    );
    return Row(
      children: [
        Expanded(
          child: _buildStat(
            'DISTANCE',
            widget.distanceKm.toStringAsFixed(1),
            'km',
          ),
        ),
        divider,
        Expanded(
          child: _buildStat('BURN', widget.calories.toStringAsFixed(0), 'kcal'),
        ),
        divider,
        Expanded(
          child: _buildStat('TIME', formatActiveTime(widget.activeTime), ''),
        ),
      ],
    );
  }

  Widget _buildStat(String label, String value, String unit) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: context.textSecondary,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(
              text: value,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
              children: [
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: context.primaryColor,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Active challenges from the social tab, closest to finishing first.
  Widget _buildChallenges() {
    final sorted = [...widget.challenges]
      ..sort((a, b) => b.progress.compareTo(a.progress));
    final shown = sorted.take(_maxChallengesShown).toList();
    final hidden = sorted.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'ACTIVE CHALLENGES',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.textSecondary,
                letterSpacing: 1.5,
              ),
            ),
            const Spacer(),
            if (hidden > 0)
              Text(
                '+$hidden MORE',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.primaryColor,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        for (final challenge in shown) ...[
          _buildChallengeRow(challenge),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildChallengeRow(ChallengeItem challenge) {
    return GlassCard(
      key: Key('goalCongrats.challenge.${challenge.id}'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  challenge.title,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.monetization_on_outlined,
                color: context.primaryColor,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                '+${challenge.rewardCoins}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: challenge.progress,
              minHeight: 6,
              backgroundColor: context.primaryColor.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(context.primaryColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${formatThousands(challenge.currentSteps)} / '
            '${formatThousands(challenge.targetSteps)} STEPS',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: context.textSecondary,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: context.primaryColor.withValues(alpha: 0.35),
                blurRadius: 24,
              ),
            ],
          ),
          child: ElevatedButton(
            key: const Key('goalCongrats.continue'),
            onPressed: _close,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primaryColor,
              foregroundColor: context.theme.colorScheme.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(40),
              ),
            ),
            child: Text(
              'Continue',
              style: GoogleFonts.sora(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          key: const Key('goalCongrats.share'),
          onPressed: widget.onShare ?? _shareStory,
          style: TextButton.styleFrom(
            foregroundColor: context.textSecondary,
            minimumSize: const Size(double.infinity, 44),
          ),
          icon: const Icon(Icons.share_outlined, size: 18),
          label: Text(
            'Share Achievement',
            style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  // Slides a section up and fades it in, starting at [start] of the intro.
  Widget _fadeIn(double start, Widget child) {
    final animation = CurvedAnimation(
      parent: _introController,
      curve: Interval(start, 1.0, curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}

enum _SparkleShape { star, dot, ribbon }

// One falling piece. Positions are fractions of the screen size and times
// are fractions of the whole shower.
class _Sparkle {
  final double startX;
  final double delay;
  final double life;
  final double fall;
  final double drift;
  final double phase;
  final double spin;
  final double size;
  // Index into the palette, so colours follow the theme at paint time.
  final int colorIndex;
  final _SparkleShape shape;

  const _Sparkle({
    required this.startX,
    required this.delay,
    required this.life,
    required this.fall,
    required this.drift,
    required this.phase,
    required this.spin,
    required this.size,
    required this.colorIndex,
    required this.shape,
  });

  static List<_Sparkle> burst(math.Random random, int count) {
    return List.generate(count, (_) {
      final roll = random.nextDouble();
      return _Sparkle(
        startX: random.nextDouble(),
        delay: random.nextDouble() * 0.35,
        life: 0.5 + random.nextDouble() * 0.15,
        fall: 0.8 + random.nextDouble() * 0.5,
        drift: 0.01 + random.nextDouble() * 0.04,
        phase: random.nextDouble() * math.pi * 2,
        spin: (random.nextDouble() - 0.5) * 12,
        size: 3 + random.nextDouble() * 5,
        colorIndex: random.nextInt(_sparklePaletteSize),
        shape: roll < 0.45
            ? _SparkleShape.star
            : roll < 0.75
            ? _SparkleShape.dot
            : _SparkleShape.ribbon,
      );
    });
  }
}

const int _sparklePaletteSize = 5;

// Mostly the theme colour, plus a light accent and gold. In light themes
// the accent is the dark text colour so it still shows on the background.
List<Color> _sparklePalette(BuildContext context) => [
  context.primaryColor,
  context.primaryColor,
  Color.lerp(context.primaryColor, context.textPrimary, 0.4)!,
  context.isDarkMode ? Colors.white : context.textPrimary,
  const Color(0xFFFFC107),
];

class _SparklePainter extends CustomPainter {
  final List<_Sparkle> sparkles;
  final double time;
  final List<Color> palette;

  _SparklePainter({
    required this.sparkles,
    required this.time,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (time <= 0 || time >= 1) return;
    final paint = Paint();

    for (final s in sparkles) {
      final t = (time - s.delay) / s.life;
      if (t <= 0 || t >= 1) continue;

      // Starts just above the screen and speeds up as it falls.
      final y = (-0.05 + s.fall * (0.35 * t + 0.65 * t * t)) * size.height;
      final x =
          (s.startX + math.sin(t * math.pi * 3 + s.phase) * s.drift) *
          size.width;
      final fadeIn = (t / 0.08).clamp(0.0, 1.0);
      final fadeOut = ((1 - t) / 0.3).clamp(0.0, 1.0);
      final twinkle = s.shape == _SparkleShape.star
          ? 0.6 + 0.4 * math.sin(t * math.pi * 8 + s.phase).abs()
          : 1.0;
      paint.color = palette[s.colorIndex].withValues(
        alpha: fadeIn * fadeOut * twinkle,
      );

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(s.spin * t);
      switch (s.shape) {
        case _SparkleShape.star:
          canvas.drawPath(_starPath(s.size * 1.4), paint);
        case _SparkleShape.dot:
          canvas.drawCircle(Offset.zero, s.size * 0.45, paint);
        case _SparkleShape.ribbon:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: s.size * 0.6,
                height: s.size * 1.8,
              ),
              const Radius.circular(1),
            ),
            paint,
          );
      }
      canvas.restore();
    }
  }

  // Four pointed twinkle star.
  Path _starPath(double radius) {
    final inner = radius * 0.28;
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final r = i.isEven ? radius : inner;
      final angle = i * math.pi / 4 - math.pi / 2;
      final point = Offset(math.cos(angle) * r, math.sin(angle) * r);
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) => oldDelegate.time != time;
}
