import 'package:build_up/app/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:ui';
import '../providers/step_provider.dart';

class StepDetailsScreen extends ConsumerStatefulWidget {
  const StepDetailsScreen({super.key});

  @override
  ConsumerState<StepDetailsScreen> createState() => _StepDetailsScreenState();
}

class _StepDetailsScreenState extends ConsumerState<StepDetailsScreen> {
  int _selectedDateIndex = 6;

  @override
  Widget build(BuildContext context) {
    final stepState = ref.watch(stepNotifierProvider);
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;

    // Logic to calculate dates for the selector (last 7 days ending today)
    final now = DateTime.now();
    final List<DateTime> weekDays = List.generate(
      7,
      (index) => now.subtract(Duration(days: 6 - index)),
    );
    
    final selectedDate = weekDays[_selectedDateIndex];
    
    // Fetch steps: if today (index 6), use current live steps; otherwise pull from weekly history array.
    // Index in weeklySteps is weekday - 1 (0=Mon, 6=Sun)
    int displaySteps = (_selectedDateIndex == 6) 
        ? stepState.currentSteps 
        : stepState.weeklySteps[selectedDate.weekday - 1];
    
    double displayDistance = displaySteps * 0.00075;
    double displayCalories = displaySteps * 0.04;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'ACTIVITY DETAILS',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: screenWidth * 0.045,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: screenHeight * 0.02),
              _buildWeeklySelector(weekDays, screenWidth),
              SizedBox(height: screenHeight * 0.03),
              _buildChartCard(displaySteps.toDouble(), screenWidth, screenHeight),
              SizedBox(height: screenHeight * 0.03),
              _buildSummaryStats(displayDistance, displayCalories, screenWidth),
              SizedBox(height: screenHeight * 0.05),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklySelector(List<DateTime> weekDays, double screenWidth) {
    return SizedBox(
      height: 85,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        itemBuilder: (context, index) {
          final date = weekDays[index];
          final isSelected = index == _selectedDateIndex;
          final dayName = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];

          return GestureDetector(
            onTap: () => setState(() => _selectedDateIndex = index),
            child: Container(
              width: screenWidth * 0.16,
              margin: EdgeInsets.only(right: screenWidth * 0.03),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryEmerald : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayName,
                    style: GoogleFonts.inter(
                      color: isSelected ? Colors.black : Colors.white54,
                      fontSize: screenWidth * 0.03,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    date.day.toString(),
                    style: GoogleFonts.inter(
                      color: isSelected ? Colors.black : Colors.white,
                      fontSize: screenWidth * 0.045,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChartCard(double steps, double screenWidth, double screenHeight) {
    int currentHour = DateTime.now().hour;
    int activeIndex = -1;

    // For Today (index 6), highlight the bar for the current time slot
    if (_selectedDateIndex == 6) {
      if (currentHour >= 22) activeIndex = 4;
      else if (currentHour >= 18) activeIndex = 3;
      else if (currentHour >= 14) activeIndex = 2;
      else if (currentHour >= 10) activeIndex = 1;
      else if (currentHour >= 6) activeIndex = 0;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: screenHeight * 0.35,
          padding: EdgeInsets.all(screenWidth * 0.05),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedDateIndex == 6 ? 'Steps Today' : 'Daily Progress',
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: screenWidth * 0.035,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 25),
              Expanded(
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 10000,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            const style = TextStyle(color: Colors.white54, fontSize: 10);
                            String text = '';
                            if (_selectedDateIndex == 6) {
                              switch (value.toInt()) {
                                case 0: text = '6AM'; break;
                                case 1: text = '10AM'; break;
                                case 2: text = '2PM'; break;
                                case 3: text = '6PM'; break;
                                case 4: text = '10PM'; break;
                              }
                            } else {
                              // For history, we just show one main indicator or labels for a single bar
                              if (value == 2) text = 'TOTAL';
                            }
                            return SideTitleWidget(meta: meta, child: Text(text, style: style));
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 35,
                          getTitlesWidget: (value, meta) => SideTitleWidget(
                            meta: meta,
                            child: Text(value.toInt().toString(), style: const TextStyle(color: Colors.white54, fontSize: 9)),
                          ),
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      horizontalInterval: 2500,
                      getDrawingHorizontalLine: (value) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1),
                    ),
                    barGroups: [
                      // If it's a history day, we show one large bar in the middle. 
                      // If it's today, we show progress in the current time slot.
                      _buildBar(0, (_selectedDateIndex == 6 && activeIndex == 0) ? steps : 0, screenWidth),
                      _buildBar(1, (_selectedDateIndex == 6 && activeIndex == 1) ? steps : 0, screenWidth),
                      _buildBar(2, (_selectedDateIndex != 6) ? steps : ((activeIndex == 2) ? steps : 0), screenWidth),
                      _buildBar(3, (_selectedDateIndex == 6 && activeIndex == 3) ? steps : 0, screenWidth),
                      _buildBar(4, (_selectedDateIndex == 6 && activeIndex == 4) ? steps : 0, screenWidth),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BarChartGroupData _buildBar(int x, double y, double screenWidth) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: AppColors.primaryEmerald,
          width: screenWidth * 0.045,
          borderRadius: BorderRadius.circular(4),
          backDrawRodData: BackgroundBarChartRodData(show: true, toY: 10000, color: Colors.white.withOpacity(0.05)),
        ),
      ],
    );
  }

  Widget _buildSummaryStats(double distance, double calories, double screenWidth) {
    return Row(
      children: [
        Expanded(child: _buildGlassStatCard('DISTANCE', '${distance.toStringAsFixed(2)} km', Icons.map_outlined, screenWidth)),
        SizedBox(width: screenWidth * 0.04),
        Expanded(child: _buildGlassStatCard('CALORIES', '${calories.toStringAsFixed(0)} kcal', Icons.local_fire_department_outlined, screenWidth)),
      ],
    );
  }

  Widget _buildGlassStatCard(String title, String value, IconData icon, double screenWidth) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: EdgeInsets.all(screenWidth * 0.05),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.primaryEmerald, size: screenWidth * 0.075),
              const SizedBox(height: 12),
              Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: screenWidth * 0.055, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(title, style: GoogleFonts.inter(color: Colors.white54, fontSize: screenWidth * 0.025, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ],
          ),
        ),
      ),
    );
  }
}
