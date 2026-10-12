import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/theme_extensions.dart';
import '../../../../core/utils/activity_log.dart';
import '../../../../core/utils/number_format.dart';
import '../../../../core/utils/step_counter_math.dart';
import '../providers/step_provider.dart';
import '../widgets/glass_step_card.dart';

/// A day's steps hour by hour, the walks and vehicle rides behind them, and
/// (long-press the title) every step sync, from the activity log.
class ActivityLogScreen extends ConsumerStatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  ConsumerState<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends ConsumerState<ActivityLogScreen> {
  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// 0 is today, up to activityLogDays - 1.
  int _daysAgo = 0;
  bool _showSyncs = false;

  @override
  Widget build(BuildContext context) {
    // Rebuilds on every sync, which also updates the log.
    final stepState = ref.watch(stepNotifierProvider);
    final storage = ref.watch(storageProvider);
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day - _daysAgo);
    final activity = summarizeDay(storage.getActivityLog().day(day), day);
    final total = _daysAgo == 0
        ? stepState.currentSteps
        : storage.getDailyHistory()[dayKey(day)] ??
              activity.checks.lastOrNull?.check.steps ??
              0;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: context.textPrimary),
        title: GestureDetector(
          key: const Key('activity_log_title'),
          // Hidden: shows each step sync, to check the counting.
          onLongPress: () => setState(() => _showSyncs = !_showSyncs),
          child: Text(
            'ACTIVITY',
            style: GoogleFonts.sora(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: context.textPrimary,
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _buildDaySelector(now),
          const SizedBox(height: 16),
          _buildSummary(total, activity),
          const SizedBox(height: 16),
          _buildHourlyChart(activity, now),
          const SizedBox(height: 16),
          _buildTimeline(activity),
          if (_showSyncs) ...[
            const SizedBox(height: 16),
            _buildSyncList(activity),
          ],
          const SizedBox(height: 16),
          Text(
            'Steps are checked about every 15 minutes while the app is '
            'closed, so times are approximate. Steps taken in a car, bus or '
            'other vehicle are not counted.',
            textAlign: TextAlign.center,
            style: GoogleFonts.sora(
              fontSize: 11,
              height: 1.5,
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelector(DateTime now) {
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          for (var ago = activityLogDays - 1; ago >= 0; ago--) ...[
            Expanded(child: _dayChip(now, ago)),
            if (ago > 0) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _dayChip(DateTime now, int ago) {
    final date = DateTime(now.year, now.month, now.day - ago);
    final selected = ago == _daysAgo;
    return GestureDetector(
      key: Key('activity_log_day_$ago'),
      onTap: () => setState(() => _daysAgo = ago),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected ? context.primaryColor : context.cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              ago == 0 ? 'Today' : _dayNames[date.weekday - 1],
              maxLines: 1,
              overflow: TextOverflow.visible,
              softWrap: false,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.black : context.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${date.day}',
              style: GoogleFonts.sora(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.black : context.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(int total, DayActivity activity) {
    final rideSteps = activity.rideSteps;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatThousands(total),
                  key: const Key('activity_log_total'),
                  style: GoogleFonts.sora(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                Text(
                  'STEPS',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (activity.rides.isNotEmpty)
            Column(
              key: const Key('activity_log_ride_steps'),
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.directions_car_rounded,
                      size: 16,
                      color: context.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formatThousands(rideSteps),
                      style: GoogleFonts.sora(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
                Text(
                  'NOT COUNTED',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHourlyChart(DayActivity activity, DateTime now) {
    final hourly = activity.hourly;
    final peak = hourly.fold(0, (max, s) => s > max ? s : max);
    final maxY = (peak < 100 ? 100 : peak) * 1.15;
    final currentHour = _daysAgo == 0 ? now.hour : -1;

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('BY HOUR'),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: BarChart(
              key: const Key('activity_log_hourly_chart'),
              BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceBetween,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => context.backgroundColor,
                    tooltipBorderRadius: BorderRadius.circular(12),
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                      '${_hourLabel(group.x)}\n'
                      '${formatThousands(rod.toY.toInt())} steps',
                      GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        final hour = value.toInt();
                        if (hour % 6 != 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _hourLabel(hour),
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: context.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var hour = 0; hour < 24; hour++)
                    BarChartGroupData(
                      x: hour,
                      barRods: [
                        BarChartRodData(
                          toY: hourly[hour].toDouble(),
                          width: 7,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                          color: hour == currentHour
                              ? context.primaryColor
                              : context.primaryColor.withValues(alpha: 0.55),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: maxY,
                            color: context.textPrimary.withValues(alpha: 0.04),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(DayActivity activity) {
    // Newest first.
    final items = <({DateTime at, Widget row})>[
      for (final walk in activity.walks) (at: walk.end, row: _walkRow(walk)),
      for (final ride in activity.rides)
        (at: ride.end ?? ride.start ?? DateTime.now(), row: _rideRow(ride)),
    ]..sort((a, b) => b.at.compareTo(a.at));

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('TIMELINE'),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Padding(
              key: const Key('activity_log_empty'),
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _daysAgo == 0
                    ? 'Nothing yet today. Your walks will show up here.'
                    : 'No activity logged this day.',
                style: GoogleFonts.sora(
                  fontSize: 13,
                  color: context.textSecondary,
                ),
              ),
            ),
          for (var i = 0; i < items.length; i++)
            _TimelineTile(isLast: i == items.length - 1, child: items[i].row),
        ],
      ),
    );
  }

  Widget _walkRow(WalkPeriod walk) {
    final fromMidnight = walk.start.hour == 0 && walk.start.minute == 0;
    return _TimelineEntry(
      icon: Icons.directions_walk_rounded,
      iconColor: context.primaryColor,
      title: '${formatThousands(walk.steps)} steps',
      subtitle: fromMidnight
          ? 'Until ${_time(walk.end)}'
          : '${_time(walk.start)} – ${_time(walk.end)}',
    );
  }

  Widget _rideRow(LoggedRide ride) {
    final start = ride.start == null ? null : _time(ride.start!);
    final end = ride.end == null ? null : _time(ride.end!);
    final (title, detail) = switch (ride.status) {
      RideStatus.ongoing => (
        'In a vehicle',
        'Since ${start ?? 'earlier'} · steps paused',
      ),
      RideStatus.ended => (
        'Vehicle ride',
        '${start ?? '?'} – ${end ?? '?'} · '
            '${formatThousands(ride.steps)} steps not counted',
      ),
      RideStatus.timedOut => (
        'Vehicle ride',
        'From ${start ?? '?'} · end not detected, steps kept',
      ),
    };
    return _TimelineEntry(
      key: Key('activity_log_ride_${ride.id}'),
      icon: Icons.directions_car_rounded,
      iconColor: context.textSecondary,
      title: title,
      subtitle: detail,
    );
  }

  Widget _buildSyncList(DayActivity activity) {
    final rows = activity.checks.reversed.toList();
    TextStyle mono(Color color) =>
        GoogleFonts.jetBrainsMono(fontSize: 12, color: color);
    return GlassCard(
      key: const Key('activity_log_syncs'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('STEP CHECKS (${rows.length})'),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Text('None this day.', style: mono(context.textSecondary)),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: Text(
                      _time(row.check.at),
                      style: mono(context.textSecondary),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      formatThousands(row.check.steps),
                      style: mono(context.textPrimary),
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      row.added == 0
                          ? '·'
                          : '${row.added > 0 ? '+' : ''}${row.added}',
                      textAlign: TextAlign.right,
                      style: mono(
                        row.added > 0
                            ? context.primaryColor
                            : context.textSecondary,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      row.check.source == CheckSource.app ? 'app' : 'bg',
                      textAlign: TextAlign.right,
                      style: mono(context.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: GoogleFonts.jetBrainsMono(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.5,
      color: context.primaryColor,
    ),
  );

  String _time(DateTime t) => MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(t),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );

  String _hourLabel(int hour) => _time(DateTime(2000, 1, 1, hour));
}

/// A dot on the timeline line with [child] beside it.
class _TimelineTile extends StatelessWidget {
  final bool isLast;
  final Widget child;

  const _TimelineTile({required this.isLast, required this.child});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                const SizedBox(height: 14),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.primaryColor,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: context.cardBorderColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _TimelineEntry({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.sora(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.sora(
                    fontSize: 12,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
