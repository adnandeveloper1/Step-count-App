import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme/theme_extensions.dart';
import '../../../core/notification_provider/notification_provider.dart';
import '../../../core/services/notification_service.dart';
import '../../step_tracking/presentation/widgets/glass_step_card.dart';

class WalkSchedulerScreen extends ConsumerStatefulWidget {
  const WalkSchedulerScreen({super.key});

  @override
  ConsumerState<WalkSchedulerScreen> createState() =>
      _WalkSchedulerScreenState();
}

class _WalkSchedulerScreenState extends ConsumerState<WalkSchedulerScreen> {
  static const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _weekdays = {1, 2, 3, 4, 5};
  static const _weekend = {6, 7};

  TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 0);
  Set<int> selectedDays = NotificationService.everyDay;
  bool isEnabled = false;

  /// The reminder is on but its time is unknown (set by an older version).
  bool timeUnknown = false;

  bool _loaded = false;

  /// Reminder changes run one after another, so a quick double tap can't
  /// interleave one change's cancel with another's schedule.
  Future<void> _applying = Future.value();

  @override
  void initState() {
    super.initState();
    _loadReminder();
  }

  /// Shows the reminder that is already set, if any.
  Future<void> _loadReminder() async {
    final reminder = await ref.read(notificationServiceProvider).walkReminder();
    if (!mounted) return;
    final time = reminder?.time;
    setState(() {
      if (reminder != null) {
        if (time != null) {
          selectedTime = TimeOfDay(hour: time.hour, minute: time.minute);
        }
        selectedDays = reminder.weekdays;
        timeUnknown = time == null;
        isEnabled = true;
      }
      _loaded = true;
    });
  }

  /// Makes the scheduled reminder match what the screen shows.
  void _apply() {
    final service = ref.read(notificationServiceProvider);
    final enabled = isEnabled;
    final time = selectedTime;
    final days = Set<int>.of(selectedDays);
    _applying = _applying.then((_) async {
      if (enabled) {
        await service.scheduleWalkReminder(
          hour: time.hour,
          minute: time.minute,
          weekdays: days,
        );
      } else {
        await service.cancelWalkReminder();
      }
    });
  }

  void _setEnabled(bool value) {
    setState(() {
      isEnabled = value;
      if (!value) timeUnknown = false;
    });
    _apply();
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: context.primaryColor,
              brightness: Theme.of(context).brightness,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;

    setState(() {
      selectedTime = picked;
      timeUnknown = false;
      // Picking a time means the user wants the reminder.
      isEnabled = true;
    });
    _apply();
  }

  void _setDays(Set<int> days) {
    // At least one day: a reminder on no days is just "off".
    if (days.isEmpty) return;
    setState(() => selectedDays = days);
    // With the time unknown, the days are saved once a time is picked.
    if (isEnabled && !timeUnknown) _apply();
  }

  void _toggleDay(int weekday) {
    final days = Set<int>.of(selectedDays);
    if (!days.remove(weekday)) days.add(weekday);
    _setDays(days);
  }

  bool get _isPreset =>
      selectedDays.length == 7 ||
      _sameDays(selectedDays, _weekdays) ||
      _sameDays(selectedDays, _weekend);

  /// The chosen days in words, for a choice no preset chip names.
  String _customDaysSummary() {
    final sorted = selectedDays.toList()..sort();
    return sorted.map((d) => _dayNames[d - 1]).join(', ');
  }

  static bool _sameDays(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b);

  /// When the reminder next fires, for the status line.
  String _nextReminder() {
    final now = DateTime.now();
    for (var offset = 0; offset <= 7; offset++) {
      final date = DateTime(
        now.year,
        now.month,
        now.day + offset,
        selectedTime.hour,
        selectedTime.minute,
      );
      if (!selectedDays.contains(date.weekday) || !date.isAfter(now)) {
        continue;
      }
      final time = selectedTime.format(context);
      if (offset == 0) return 'Next: today, $time';
      if (offset == 1) return 'Next: tomorrow, $time';
      return 'Next: ${_dayNames[date.weekday - 1]}, $time';
    }
    return '';
  }

  String _status() {
    if (!isEnabled) return 'Off';
    if (timeUnknown) return 'On · pick a time to see the next reminder';
    return _nextReminder();
  }

  /// Text and icon color that reads on the theme's accent color: the store
  /// themes range from lime to purple.
  Color get _onPrimary =>
      ThemeData.estimateBrightnessForColor(context.primaryColor) ==
          Brightness.dark
      ? Colors.white
      : Colors.black;

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 24.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: context.textSecondary,
        ),
      ),
    );
  }

  Widget _buildReminderCard() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: context.primaryColor.withValues(
                alpha: isEnabled ? 0.18 : 0.08,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isEnabled
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_off_rounded,
              color: isEnabled ? context.primaryColor : context.textSecondary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WALK REMINDER',
                  style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _status(),
                  key: const Key('walk_reminder_status'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isEnabled
                        ? context.primaryColor
                        : context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            key: const Key('walk_reminder_switch'),
            value: isEnabled,
            onChanged: _loaded ? _setEnabled : null,
            activeTrackColor: context.primaryColor,
            activeThumbColor: _onPrimary,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeCard() {
    return GlassCard(
      child: InkWell(
        key: const Key('walk_reminder_time'),
        borderRadius: BorderRadius.circular(24),
        onTap: _loaded ? _selectTime : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          child: Column(
            children: [
              Text(
                timeUnknown ? '--:--' : selectedTime.format(context),
                style: GoogleFonts.sora(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  color: isEnabled ? context.primaryColor : context.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.edit_rounded,
                    size: 14,
                    color: context.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'TAP TO CHANGE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayChip(int weekday) {
    final selected = selectedDays.contains(weekday);
    return Semantics(
      button: true,
      selected: selected,
      label: _dayNames[weekday - 1],
      child: GestureDetector(
        key: Key('walk_reminder_day_$weekday'),
        onTap: _loaded ? () => _toggleDay(weekday) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? context.primaryColor : Colors.transparent,
            border: Border.all(
              color: selected
                  ? context.primaryColor
                  : context.textSecondary.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: ExcludeSemantics(
            child: Text(
              _dayLetters[weekday - 1],
              style: GoogleFonts.sora(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: selected ? _onPrimary : context.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreset(String label, Set<int> days) {
    final selected = _sameDays(selectedDays, days);
    return GestureDetector(
      onTap: _loaded ? () => _setDays(days) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? context.primaryColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? context.primaryColor
                : context.textSecondary.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: selected ? context.primaryColor : context.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildDaysCard() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [for (var d = 1; d <= 7; d++) _buildDayChip(d)],
          ),
          if (!_isPreset) ...[
            const SizedBox(height: 16),
            Text(
              _customDaysSummary(),
              style: GoogleFonts.sora(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPreset('Every day', NotificationService.everyDay),
              _buildPreset('Weekdays', _weekdays),
              _buildPreset('Weekends', _weekend),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text(
          'DAILY WALK',
          style: GoogleFonts.sora(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: context.textPrimary,
            letterSpacing: .1,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set a reminder to get your steps in.',
              style: TextStyle(color: context.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 20),
            _buildReminderCard(),
            _buildLabel('TIME'),
            _buildTimeCard(),
            _buildLabel('REPEAT'),
            _buildDaysCard(),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: context.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You\'ll get a notification at this time on the chosen '
                    'days, even when the app is closed.',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
