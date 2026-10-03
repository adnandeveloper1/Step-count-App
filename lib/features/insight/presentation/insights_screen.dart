import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../step_tracking/presentation/providers/step_provider.dart';
import '../../step_tracking/presentation/widgets/glass_step_card.dart';


class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stepState = ref.watch(stepNotifierProvider);
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final currentDayIndex = DateTime.now().weekday - 1;

    final List<int> rawWeeklySteps = List<int>.from(stepState.weeklySteps);
    if (rawWeeklySteps.length == 7 && stepState.currentSteps > rawWeeklySteps[currentDayIndex]) {
      rawWeeklySteps[currentDayIndex] = stepState.currentSteps;
    }

    final List<int> orderedSteps = [];
    final List<String> orderedLabels = [];
    const dayNames = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const fullDayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    for (int i = 0; i < 7; i++) {
      int index = (currentDayIndex - 6 + i) % 7;
      if (index < 0) index += 7;
      orderedSteps.add(rawWeeklySteps[index]);
      orderedLabels.add(dayNames[index]);
    }

    int activeDays = rawWeeklySteps.where((steps) => steps > 0).length;
    if (activeDays == 0) activeDays = 1;

    final int totalSteps = rawWeeklySteps.reduce((a, b) => a + b);
    final int avgSteps = totalSteps ~/ activeDays;
    final double totalCalories = totalSteps * 0.04;

    final int totalActiveMinutes = totalSteps ~/ 100;
    final int hours = totalActiveMinutes ~/ 60;
    final int minutes = totalActiveMinutes % 60;

    final int todaySteps = rawWeeklySteps[currentDayIndex];
    double trendPercentage = 0;
    if (avgSteps > 0) {
      trendPercentage = ((todaySteps - avgSteps) / avgSteps) * 100;
    }
    final bool isTrendPositive = trendPercentage >= 0;
    final String trendText = '${trendPercentage.abs().toInt()}%';

    int maxSteps = 0;
    int bestDayRawIndex = 0;
    for (int i = 0; i < rawWeeklySteps.length; i++) {
      if (rawWeeklySteps[i] > maxSteps) {
        maxSteps = rawWeeklySteps[i];
        bestDayRawIndex = i;
      }
    }
    final String bestDayName = maxSteps > 0 ? fullDayNames[bestDayRawIndex] : 'None';

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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left Spacer (Matches Dashboard Avatar space)
                    const Expanded(child: SizedBox.shrink()),

                    Text(
                      'WEEKLY INSIGHTS',
                      style: GoogleFonts.sora(
                        fontSize: screenWidth * 0.06,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: .1,
                      ),
                    ),

                    // Right Spacer (Matches Dashboard Coin space)
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(size.width * 0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGraphCard(orderedSteps, orderedLabels, size),
                    SizedBox(height: size.height * 0.03),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _buildInsightCard(
                              label: 'Daily Average',
                              value: '$avgSteps',
                              unit: 'steps',
                              icon: Icons.directions_walk,
                              trendText: trendText,
                              isPositive: isTrendPositive,
                            ),
                          ),
                          SizedBox(width: size.width * 0.03),
                          Expanded(
                            child: _buildInsightCard(
                              label: 'Total Burn',
                              value: '${totalCalories.toInt()}',
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
                              value: '$hours:${minutes.toString().padLeft(2, '0')}',
                              unit: 'hrs',
                              icon: Icons.timer,
                            ),
                          ),
                          SizedBox(width: size.width * 0.03),
                          Expanded(
                            child: _buildInsightCard(
                              label: 'Best Day',
                              value: maxSteps > 0 ? '$maxSteps' : '0',
                              unit: 'steps',
                              subtitle: bestDayName,
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

  Widget _buildInsightCard({
    required String label,
    required String value,
    required String unit,
    required IconData icon,
    String? subtitle,
    String? trendText,
    bool? isPositive,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: AppColors.primaryEmerald, size: 28),
              if (trendText != null && isPositive != null)
                Row(
                  children: [
                    Text(
                      trendText,
                      style: GoogleFonts.jetBrainsMono(
                        color: isPositive ? AppColors.primaryEmerald : Colors.redAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    Icon(
                      isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                      color: isPositive ? AppColors.primaryEmerald : Colors.redAccent,
                      size: 14,
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.sora(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
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
                        color: AppColors.textSecondary,
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
                    color: AppColors.primaryEmerald,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.sora(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGraphCard(List<int> steps, List<String> labels, Size size) {
    final double maxStep = steps.isEmpty ? 0 : steps.reduce((a, b) => a > b ? a : b).toDouble();
    final double calculatedMaxY = maxStep > 10000 ? maxStep * 1.2 : 10000.0;

    return GlassCard(
      padding: EdgeInsets.all(size.width * 0.05),
      child: SizedBox(
        height: size.height * 0.265,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.center,
            groupsSpace: size.width * 0.030,
            maxY: calculatedMaxY,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (group) =>AppColors.backgroundDark,
                tooltipBorderRadius: BorderRadius.circular(20),
                tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                tooltipMargin: 8,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    '${rod.toY.toInt()}',
                    GoogleFonts.jetBrainsMono(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: size.width * 0.035,
                    ),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: size.height * 0.030,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= labels.length) return const SizedBox.shrink();
                    final isToday = index == 6;
                    return Padding(
                      padding: EdgeInsets.only(top: size.height * 0.008),
                      child: Text(
                        labels[index],
                        style: GoogleFonts.jetBrainsMono(
                          color: isToday ? AppColors.primaryEmerald : AppColors.textSecondary,
                          fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                          fontSize: size.width * 0.032,
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(
              7,
                  (index) => BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: index < steps.length ? steps[index].toDouble() : 0,
                    color: AppColors.primaryEmerald,
                    width: size.width * 0.095,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}