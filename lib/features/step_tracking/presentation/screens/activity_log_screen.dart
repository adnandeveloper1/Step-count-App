import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/theme_extensions.dart';
import '../../../../core/services/native_health_service.dart';
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
    // Kept while it reloads after each sync, so the chart does not jump.
    final recorded = ref.watch(recordedStepsProvider(day)).value;
    ref.listen(
      stepNotifierProvider.select((s) => s.currentSteps),
      (_, _) => ref.invalidate(recordedStepsProvider),
    );
    final activity = summarizeDay(
      storage.getActivityLog().day(day),
      day,
      recorded: recorded,
    );
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
          _buildTimeline(activity, day),
          if (_showSyncs) ...[
            const SizedBox(height: 16),
            _buildSyncList(activity),
          ],
          const SizedBox(height: 16),
          Text(
            recorded == null || recorded.since.isAfter(day)
                ? 'Steps are checked about every 15 minutes while the app is '
                      'closed, so times are approximate. Steps taken in a '
                      'car, bus or other vehicle are not counted.'
                : 'Times come from your phone\'s step recording. Steps '
                      'taken in a car, bus or other vehicle are not counted.',
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
    // No fixed height: the chips grow with the system text size.
    return Row(
      children: [
        for (var ago = activityLogDays - 1; ago >= 0; ago--) ...[
          Expanded(child: _dayChip(now, ago)),
          if (ago > 0) const SizedBox(width: 6),
        ],
      ],
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
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? context.primaryColor : context.cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Shrinks rather than spill out of a narrow chip.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                ago == 0 ? 'Today' : _dayNames[date.weekday - 1],
                maxLines: 1,
                softWrap: false,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.black : context.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${date.day}',
                maxLines: 1,
                style: GoogleFonts.sora(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.black : context.textPrimary,
                ),
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
                        // Centred under its bar, but nudged in at the edges so
                        // "12:00 AM" under the first bar is not cut off.
                        return SideTitleWidget(
                          meta: meta,
                          space: 6,
                          fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
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

  Widget _buildTimeline(DayActivity activity, DateTime day) {
    // Newest first.
    final items = <({DateTime at, Widget row})>[
      for (final walk in activity.walks) (at: walk.end, row: _walkRow(walk)),
      for (final ride in activity.rides)
        (
          at: ride.end ?? ride.start ?? DateTime.now(),
          row: _rideRow(ride, day),
        ),
      for (final reward in activity.goalRewards)
        (at: reward.check.at, row: _goalRewardRow(reward)),
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
      subtitle:
          switch ((walk.timeUnknown, fromMidnight)) {
            (true, true) => 'Before ${_time(walk.end)}',
            (true, false) =>
              'Between ${_time(walk.start)} and ${_time(walk.end)}',
            (false, true) => 'Until ${_time(walk.end)}',
            (false, false) => '${_time(walk.start)} – ${_time(walk.end)}',
          } +
          switch (walk) {
            WalkPeriod(unseen: true) =>
              ' · not seen as walking, maybe a vehicle',
            WalkPeriod(timeUnknown: true) => ' · time not recorded',
            _ => '',
          },
    );
  }

  Widget _goalRewardRow(CheckRow reward) => _TimelineEntry(
    key: Key(
      'activity_log_goal_reward_${reward.check.at.millisecondsSinceEpoch}',
    ),
    icon: Icons.emoji_events_rounded,
    iconColor: context.primaryColor,
    title: '+${formatThousands(reward.added)} steps',
    subtitle: '${_time(reward.check.at)} · goal completed with a reward',
  );

  Widget _rideRow(LoggedRide ride, DateTime day) {
    final start = ride.start == null ? null : _rideTime(ride.start!, day);
    final end = ride.end == null ? null : _rideTime(ride.end!, day);
    final past = _daysAgo > 0;
    final (title, detail) = switch (ride.status) {
      RideStatus.ongoing when !ride.measured => (
        past ? 'Vehicle ride' : 'In a vehicle',
        'Since ${start ?? 'earlier'} · steps could not be measured, '
            'still counted',
      ),
      RideStatus.ongoing when past => (
        'Vehicle ride',
        '${start ?? '?'} – still going · '
            '${formatThousands(ride.steps)} steps not counted',
      ),
      RideStatus.ongoing => (
        'In a vehicle',
        'Since ${start ?? 'earlier'} · steps paused',
      ),
      RideStatus.ended when !ride.measured => (
        'Vehicle ride',
        '${start ?? '?'} – ${end ?? '?'} · steps could not be measured, '
            'counted',
      ),
      RideStatus.ended => (
        'Vehicle ride',
        '${start ?? '?'} – ${end ?? '?'} · '
            '${formatThousands(ride.steps)} steps not counted',
      ),
      RideStatus.timedOut => (
        'Vehicle ride',
        ride.kept > 0
            ? 'From ${start ?? '?'} · end not detected, '
                  '${formatThousands(ride.kept)} steps kept'
            : 'From ${start ?? '?'} · end not detected, steps kept',
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

  /// [t] as a time, named by its day when it is not [day] (a ride over
  /// midnight).
  String _rideTime(DateTime t, DateTime day) {
    final date = DateTime(t.year, t.month, t.day);
    if (date == day) return _time(t);
    if (date == DateTime(day.year, day.month, day.day - 1)) {
      return '${_time(t)} the day before';
    }
    if (date == DateTime(day.year, day.month, day.day + 1)) {
      return '${_time(t)} the next day';
    }
    return '${_time(t)} ${_dayNames[t.weekday - 1]}';
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
                      switch (row.check.source) {
                        CheckSource.app => 'app',
                        CheckSource.background => 'bg',
                        CheckSource.goalReward => 'ad',
                      },
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
///
/// The line is positioned against [child]'s own height. Avoid IntrinsicHeight
/// here: text intrinsics are cached per font, so on a first open (Google Fonts
/// still loading) rows kept the fallback font's height and overflowed.
class _TimelineTile extends StatelessWidget {
  final bool isLast;
  final Widget child;

  const _TimelineTile({required this.isLast, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (!isLast)
          Positioned(
            left: 9.25,
            top: 22,
            bottom: 0,
            child: Container(width: 1.5, color: context.cardBorderColor),
          ),
        Positioned(
          left: 6,
          top: 14,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.primaryColor,
            ),
          ),
        ),
        Padding(padding: const EdgeInsets.only(left: 28), child: child),
      ],
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
