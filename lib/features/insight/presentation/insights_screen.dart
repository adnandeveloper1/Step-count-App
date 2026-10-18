import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/theme_extensions.dart';
import '../../../core/utils/number_format.dart';
import '../../../core/utils/calorie_calculator.dart';
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

  // Page 0 is the last 7 days. The PageView is reversed so swiping right goes
  // back in time, like Apple Health.
  final PageController _pageController = PageController();
  int _weeksAgo = 0;

  // The bar whose step count is pinned open on the current page, or null.
  int? _selectedBar;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToWeek(int weeksAgo) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _pageController.jumpToPage(weeksAgo);
      return;
    }
    _pageController.animateToPage(
      weeksAgo,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  // Tap a bar to pin its step count, tap it again to close it. Days older
  // than the history window have no count to show.
  void _onBarTouch(
    WeekSteps week,
    FlTouchEvent event,
    BarTouchResponse? response,
  ) {
    if (event is! FlTapUpEvent) return;
    final index = response?.spot?.touchedBarGroupIndex;
    final next =
        index == null || index == _selectedBar || week.days[index] == null
        ? null
        : index;
    if (next != _selectedBar) setState(() => _selectedBar = next);
  }

  // "Steps for Oct 12 – 18, 2026. Monday, 4,210 steps. ... Today, 7,000 steps."
  String _chartSemantics(WeekSteps week, int todayIndex) {
    final days = [
      for (int i = 0; i < 7; i++)
        if (week.days[i] case final steps?)
          '${_dayName(week, i, todayIndex)}, ${formatThousands(steps)} steps',
    ];
    return 'Steps for ${weekRangeLabel(week)}. ${days.join('. ')}.';
  }

  String _dayName(WeekSteps week, int index, int todayIndex) =>
      index == todayIndex
      ? 'Today'
      : fullDayNames[week.dayAt(index).weekday - 1];

  @override
  Widget build(BuildContext context) {
    final stepState = ref.watch(stepNotifierProvider);
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final today = DateTime.now();

    final weeks = buildWeeks(
      history: ref.watch(storageProvider).getDailyHistory(),
      todaySteps: stepState.currentSteps,
      today: today,
    );
    final weeksAgo = _weeksAgo.clamp(0, weeks.length - 1);
    final week = weeks[weeks.length - 1 - weeksAgo];

    final totalSteps = week.total;
    // Same formula as the home screen, from the profile's height and weight.
    final totalCalories = CalorieCalculator.calories(
      totalSteps,
      heightCm: stepState.height,
      weightKg: stepState.weight,
    );
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
                              valueKey: const Key('insights.totalBurn'),
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
                                  : fullDayNames[week.dayAt(bestIndex).weekday -
                                        1],
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

  // "< LAST 7 DAYS / Oct 8 – 14, 2026 >" with arrows to step through weeks.
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
              onPageChanged: (page) => setState(() {
                _weeksAgo = page;
                _selectedBar = null;
              }),
              itemBuilder: (context, page) => _buildChart(
                weeks[weeks.length - 1 - page],
                goalSteps,
                today,
                size,
                // Only the page on screen keeps a pinned count.
                isCurrent: page == _weeksAgo,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(
    WeekSteps week,
    int goalSteps,
    DateTime today,
    Size size, {
    required bool isCurrent,
  }) {
    final maxStep = week.days.fold<int>(
      0,
      (max, steps) => (steps ?? 0) > max ? steps! : max,
    );
    final top = [maxStep, goalSteps, 10000].reduce((a, b) => a > b ? a : b);
    final maxY = top * 1.2;
    // Only the newest page ends with today.
    final todayIndex = DateUtils.isSameDay(week.end, today) ? 6 : -1;
    final textScaler = MediaQuery.textScalerOf(context);
    final labelSize = size.width * 0.03;

    return Semantics(
      key: isCurrent ? const Key('insights.chart') : null,
      container: true,
      label: _chartSemantics(week, todayIndex),
      excludeSemantics: true,
      child: BarChart(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 150),
        BarChartData(
          alignment: BarChartAlignment.spaceBetween,
          maxY: maxY,
          barTouchData: BarTouchData(
            enabled: true,
            // Built-in touches clear the count when the finger lifts, so a tap
            // only flashed it. Taps pin it instead.
            handleBuiltInTouches: false,
            // Short bars are hard to hit; the whole track counts.
            allowTouchBarBackDraw: true,
            touchCallback: (event, response) =>
                _onBarTouch(week, event, response),
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => context.backgroundColor,
              tooltipBorderRadius: BorderRadius.circular(20),
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              tooltipMargin: 8,
              // Keep the count inside the chart: above the tallest bar there
              // is no room, and the first/last bars sit at the card edges.
              fitInsideVertically: true,
              fitInsideHorizontally: true,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                if (week.days[group.x] == null) return null;
                return BarTooltipItem(
                  '${_dayName(week, group.x, todayIndex)}\n',
                  GoogleFonts.sora(
                    color: context.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: size.width * 0.028,
                  ),
                  children: [
                    TextSpan(
                      text: '${formatThousands(rod.toY.toInt())} steps',
                      style: GoogleFonts.jetBrainsMono(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: size.width * 0.035,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                // Grows with the text size so labels are never cut off.
                reservedSize:
                    textScaler.scale(labelSize) + size.height * 0.008 + 6,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= 7) return const SizedBox.shrink();
                  final isToday = index == todayIndex;
                  return Padding(
                    padding: EdgeInsets.only(top: size.height * 0.008),
                    child: Text(
                      dayNames[week.dayAt(index).weekday - 1],
                      style: GoogleFonts.jetBrainsMono(
                        color: isToday
                            ? context.primaryColor
                            : context.textSecondary,
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                        fontSize: labelSize,
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
            return BarChartGroupData(
              x: index,
              showingTooltipIndicators: [
                if (isCurrent && index == _selectedBar) 0,
              ],
              barRods: [
                BarChartRodData(
                  toY: steps.toDouble(),
                  color: context.primaryColor,
                  width: size.width * 0.1,
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
              // Number and unit shrink together, so large text never pushes
              // the unit past the card edge.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      value,
                      key: valueKey,
                      style: GoogleFonts.sora(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
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
