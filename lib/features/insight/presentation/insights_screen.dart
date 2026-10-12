import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/theme_extensions.dart';
import '../../../core/utils/number_format.dart';
import '../../step_tracking/presentation/providers/step_provider.dart';
import '../../step_tracking/presentation/widgets/glass_step_card.dart';
import '../week_steps.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  static const dayNames = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  static const fullDayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  // Page 0 is this week. The PageView is reversed so swiping right goes
  // back in time, like Apple Health.
  final PageController _pageController = PageController();
  int _weeksAgo = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToWeek(int weeksAgo) {
    _pageController.animateToPage(
      weeksAgo,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final stepState = ref.watch(stepNotifierProvider);
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final today = DateTime.now();

    final weeks = buildWeeks(
      history: ref.watch(storageProvider).getDailyHistory(),
      weeklySteps: stepState.weeklySteps,
      todaySteps: stepState.currentSteps,
      today: today,
    );
    final weeksAgo = _weeksAgo.clamp(0, weeks.length - 1);
    final week = weeks[weeks.length - 1 - weeksAgo];

    final totalSteps = week.total;
    final totalCalories = totalSteps * 0.04;
    final totalActiveMinutes = totalSteps ~/ 100;
    final hours = totalActiveMinutes ~/ 60;
    final minutes = totalActiveMinutes % 60;
    final bestIndex = week.bestDayIndex;

    return Scaffold(
      backgroundColor: Colors.transparent,

      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.05,
                vertical: 10,
              ),
              child: SizedBox(
                height: 50, // Force consistent height across all screens
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'WEEKLY INSIGHTS',
                      style: GoogleFonts.sora(
                        fontSize: screenWidth * 0.06,
                        fontWeight: FontWeight.w900,
                        color: context.textPrimary,
                        letterSpacing: .1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(size.width * 0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWeekSelector(week, weeksAgo, weeks.length),
                    SizedBox(height: size.height * 0.02),
                    _buildGraphCard(
                      weeks,
                      week,
                      stepState.goalSteps,
                      today,
                      size,
                    ),
                    SizedBox(height: size.height * 0.03),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _buildInsightCard(
                              label: 'Total Steps',
                              value: formatThousands(totalSteps),
                              valueKey: const Key('insights.totalSteps'),
                              unit: 'steps',
                              icon: Icons.directions_walk,
                            ),
                          ),
                          SizedBox(width: size.width * 0.03),
                          Expanded(
                            child: _buildInsightCard(
                              label: 'Total Burn',
                              value: formatThousands(totalCalories.toInt()),
                              unit: 'kcal',
                              icon: Icons.local_fire_department,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: size.height * 0.03),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _buildInsightCard(
                              label: 'Active Time',
                              value:
                                  '$hours:${minutes.toString().padLeft(2, '0')}',
                              unit: 'hrs',
                              icon: Icons.timer,
                            ),
                          ),
                          SizedBox(width: size.width * 0.03),
                          Expanded(
                            child: _buildInsightCard(
                              label: 'Best Day',
                              value: bestIndex == null
                                  ? '0'
                                  : formatThousands(week.days[bestIndex]!),
                              unit: 'steps',
                              subtitle: bestIndex == null
                                  ? 'None'
                                  : fullDayNames[bestIndex],
                              icon: Icons.star,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // "< THIS WEEK / Oct 6 – 12, 2026 >" with arrows to step through weeks.
  Widget _buildWeekSelector(WeekSteps week, int weeksAgo, int weekCount) {
    final canGoBack = weeksAgo < weekCount - 1;
    final canGoForward = weeksAgo > 0;

    Widget arrow(IconData icon, bool enabled, int target, String key) {
      return IconButton(
        key: Key(key),
        onPressed: enabled ? () => _goToWeek(target) : null,
        icon: Icon(icon),
        color: context.primaryColor,
        disabledColor: context.textSecondary.withValues(alpha: 0.3),
        iconSize: 28,
      );
    }

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          arrow(
            Icons.chevron_left_rounded,
            canGoBack,
            weeksAgo + 1,
            'insights.olderWeek',
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  weekTitle(weeksAgo),
                  key: const Key('insights.weekTitle'),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.primaryColor,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  weekRangeLabel(week),
                  key: const Key('insights.weekRange'),
                  style: GoogleFonts.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          arrow(
            Icons.chevron_right_rounded,
            canGoForward,
            weeksAgo - 1,
            'insights.newerWeek',
          ),
        ],
      ),
    );
  }

  Widget _buildGraphCard(
    List<WeekSteps> weeks,
    WeekSteps week,
    int goalSteps,
    DateTime today,
    Size size,
  ) {
    return GlassCard(
      padding: EdgeInsets.all(size.width * 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: size.height * 0.24,
            child: PageView.builder(
              controller: _pageController,
              reverse: true,
              itemCount: weeks.length,
              onPageChanged: (page) => setState(() => _weeksAgo = page),
              itemBuilder: (context, page) => _buildChart(
                weeks[weeks.length - 1 - page],
                goalSteps,
                today,
                size,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(WeekSteps week, int goalSteps, DateTime today, Size size) {
    final maxStep = week.days.fold<int>(
      0,
      (max, steps) => (steps ?? 0) > max ? steps! : max,
    );
    final top = [maxStep, goalSteps, 10000].reduce((a, b) => a > b ? a : b);
    final maxY = top * 1.2;
    final todayIndex = mondayOf(today) == week.start ? today.weekday - 1 : -1;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => context.backgroundColor,
            tooltipBorderRadius: BorderRadius.circular(20),
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            tooltipMargin: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (week.days[group.x] == null) return null;
              return BarTooltipItem(
                formatThousands(rod.toY.toInt()),
                GoogleFonts.jetBrainsMono(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: size.width * 0.035,
                ),
              );
            },
          ),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (goalSteps > 0)
              HorizontalLine(
                y: goalSteps.toDouble(),
                color: context.primaryColor.withValues(alpha: 0.5),
                strokeWidth: 1,
                dashArray: [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  labelResolver: (_) => 'GOAL',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: context.primaryColor.withValues(alpha: 0.8),
                  ),
                ),
              ),
          ],
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: size.height * 0.030,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= 7) return const SizedBox.shrink();
                final isToday = index == todayIndex;
                return Padding(
                  padding: EdgeInsets.only(top: size.height * 0.008),
                  child: Text(
                    dayNames[index],
                    style: GoogleFonts.jetBrainsMono(
                      color: isToday
                          ? context.primaryColor
                          : context.textSecondary,
                      fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                      fontSize: size.width * 0.03,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(7, (index) {
          final steps = week.days[index] ?? 0;
          final metGoal = goalSteps > 0 && steps >= goalSteps;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: steps.toDouble(),
                // Full lime when the goal was met, dimmer otherwise.
                color: metGoal
                    ? context.primaryColor
                    : context.primaryColor.withValues(alpha: 0.45),
                width: size.width * 0.075,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
                  color: context.cardColor.withValues(alpha: 0.05),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildInsightCard({
    required String label,
    required String value,
    required String unit,
    required IconData icon,
    String? subtitle,
    Key? valueKey,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: context.primaryColor, size: 28),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        key: valueKey,
                        style: GoogleFonts.sora(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3.0),
                    child: Text(
                      unit,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.sora(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.primaryColor,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.sora(
                  fontSize: 12,
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
