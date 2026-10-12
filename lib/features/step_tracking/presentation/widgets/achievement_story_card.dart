import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/number_format.dart';
import '../../../../core/utils/step_history.dart';
import 'goal_arc_painter.dart';

// Everything the share image shows about today's goal.
class GoalAchievement {
  final int steps;
  final int goalSteps;
  final double distanceKm;
  final double calories;
  final Duration activeTime;
  final int streakDays;
  final DateTime date;

  const GoalAchievement({
    required this.steps,
    required this.goalSteps,
    required this.distanceKm,
    required this.calories,
    required this.activeTime,
    required this.streakDays,
    required this.date,
  });
}

// "12-DAY STREAK", "30+ DAY STREAK" once it fills the history, or null for
// a streak too short to brag about.
String? streakLabel(int streakDays) {
  if (streakDays >= stepHistoryDays) {
    return '${stepHistoryDays - 1}+ DAY STREAK';
  }
  return streakDays > 1 ? '$streakDays-DAY STREAK' : null;
}

String formatActiveTime(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  if (hours == 0) return '${minutes}m';
  return '${hours}h ${minutes}m';
}

const _weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
const _months = [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
];

// "SUN, OCT 18".
String storyDateLabel(DateTime date) =>
    '${_weekdays[date.weekday - 1]}, ${_months[date.month - 1]} ${date.day}';

// 9:16 story image, laid out at 360x640 and captured at 3x (1080x1920).
class AchievementStoryCard extends StatelessWidget {
  static const Size size = Size(360, 640);
  static const double capturePixelRatio = 3;

  final GoalAchievement achievement;

  const AchievementStoryCard({super.key, required this.achievement});

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final exceeded = a.steps > a.goalSteps;
    final streak = streakLabel(a.streakDays);

    return SizedBox.fromSize(
      size: size,
      child: ClipRect(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.35),
              radius: 0.95,
              colors: [Color(0xFF1F2A05), AppColors.backgroundDark],
            ),
          ),
          child: Stack(
            children: [
              ..._decorations(),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'BUILD UP',
                          style: GoogleFonts.sora(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          storyDateLabel(a.date),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(flex: 2),
                    _buildGauge(a),
                    const SizedBox(height: 18),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        exceeded ? 'GOAL CRUSHED' : 'GOAL REACHED',
                        style: GoogleFonts.sora(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryEmerald,
                          letterSpacing: -1,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        exceeded
                            ? '+${formatThousands(a.steps - a.goalSteps)} STEPS OVER TARGET'
                            : 'DAILY TARGET COMPLETE',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    if (streak != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.glassCardBackground,
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(
                            color: AppColors.glassCardBorder.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        child: Text(
                          '$streak 🔥',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(flex: 3),
                    _buildStats(a),
                    const SizedBox(height: 22),
                    Text(
                      'TRACKED WITH BUILD UP',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary.withValues(alpha: 0.6),
                        letterSpacing: 2.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGauge(GoalAchievement a) {
    const gaugeSize = 230.0;
    return SizedBox(
      width: gaugeSize,
      height: gaugeSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(gaugeSize),
            painter: GoalArcPainter(progress: 1, strokeWidth: 13),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'STEPS',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatThousands(a.steps),
                  style: GoogleFonts.sora(
                    fontSize: 50,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -1.5,
                    height: 1.1,
                  ),
                ),
              ),
              Text(
                '/ ${formatThousands(a.goalSteps)} GOAL',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryEmerald,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStats(GoalAchievement a) {
    Widget stat(String label, String value, String unit) => Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              text: value,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              children: [
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: AppColors.primaryEmerald,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    final divider = Container(
      width: 1,
      height: 32,
      color: AppColors.glassCardBorder.withValues(alpha: 0.5),
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.glassCardBackground.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.glassCardBorder.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          stat('DISTANCE', a.distanceKm.toStringAsFixed(1), 'km'),
          divider,
          stat('BURN', a.calories.toStringAsFixed(0), 'kcal'),
          divider,
          stat('TIME', formatActiveTime(a.activeTime), ''),
        ],
      ),
    );
  }

  // A few fixed sparkles so the story looks celebratory as a still image.
  List<Widget> _decorations() {
    const sparkles = [
      (x: 40.0, y: 110.0, size: 10.0, color: AppColors.primaryEmerald),
      (x: 300.0, y: 90.0, size: 14.0, color: Colors.white),
      (x: 318.0, y: 220.0, size: 8.0, color: Color(0xFFFFD54F)),
      (x: 26.0, y: 300.0, size: 12.0, color: Colors.white),
      (x: 290.0, y: 380.0, size: 9.0, color: AppColors.primaryEmerald),
      (x: 60.0, y: 420.0, size: 7.0, color: AppColors.neonGreen),
      (x: 180.0, y: 70.0, size: 6.0, color: AppColors.primaryEmerald),
    ];
    return [
      for (final s in sparkles)
        Positioned(
          left: s.x,
          top: s.y,
          child: Icon(
            Icons.auto_awesome,
            size: s.size * 1.6,
            color: s.color.withValues(alpha: 0.8),
          ),
        ),
    ];
  }
}

// Bottom sheet that previews the story image and shares it as a PNG.
Future<void> showAchievementShareSheet(
  BuildContext context,
  GoalAchievement achievement,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.backgroundDark,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (context) => _AchievementShareSheet(achievement: achievement),
  );
}

class _AchievementShareSheet extends StatefulWidget {
  final GoalAchievement achievement;

  const _AchievementShareSheet({required this.achievement});

  @override
  State<_AchievementShareSheet> createState() => _AchievementShareSheetState();
}

class _AchievementShareSheetState extends State<_AchievementShareSheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final boundary =
          _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(
        pixelRatio: AchievementStoryCard.capturePixelRatio,
      );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/build_up_goal_${dateKey(widget.achievement.date)}.png',
      );
      await file.writeAsBytes(bytes!.buffer.asUint8List());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text:
              'I hit ${formatThousands(widget.achievement.steps)} steps today on Build Up 🔥',
        ),
      );
    } catch (e) {
      debugPrint('Story share failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create the story image')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.glassCardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'SHARE YOUR WIN',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            // Preview scaled to fit; the boundary inside still captures
            // at the card's own 360x640 size.
            SizedBox(
              height: height * 0.62,
              child: FittedBox(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: RepaintBoundary(
                    key: _cardKey,
                    child: AchievementStoryCard(
                      key: const Key('goalStory.card'),
                      achievement: widget.achievement,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                key: const Key('goalStory.share'),
                onPressed: _sharing ? null : _share,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryEmerald,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: AppColors.primaryEmerald.withValues(
                    alpha: 0.5,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
                icon: _sharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.ios_share_rounded),
                label: Text(
                  'Share to Stories',
                  style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
