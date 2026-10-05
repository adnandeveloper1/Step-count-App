import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/theme_extensions.dart';
import '../../../core/notification_provider/notification_provider.dart';
import '../../step_tracking/presentation/widgets/glass_step_card.dart';

class WalkSchedulerScreen extends ConsumerStatefulWidget {
  const WalkSchedulerScreen({super.key});

  @override
  ConsumerState<WalkSchedulerScreen> createState() => _WalkSchedulerScreenState();
}

class _WalkSchedulerScreenState extends ConsumerState<WalkSchedulerScreen> {
  TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 0);
  bool isScheduled = false;

  Future<void> _selectTime(BuildContext context) async {
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

    if (picked != null && picked != selectedTime) {
      setState(() {
        selectedTime = picked;
        isScheduled = false;
      });
    }
  }

  void _scheduleWalk() {
    final notificationService = ref.read(notificationServiceProvider);

    notificationService.scheduleDailyWalkReminder(
      selectedTime.hour,
      selectedTime.minute,
    );

    setState(() {
      isScheduled = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Walk scheduled for ${selectedTime.format(context)}'),
        backgroundColor: context.primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'DAILY WALK',
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        iconTheme: IconThemeData(color: context.textPrimary),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set a daily reminder to get your steps in.',
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            GlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.timer, color: context.primaryColor, size: 48),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () => _selectTime(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      decoration: BoxDecoration(
                        color: context.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.primaryColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        selectedTime.format(context),
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: context.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _scheduleWalk,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isScheduled
                            ? context.textSecondary.withValues(alpha: 0.3)
                            : context.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        isScheduled ? 'Scheduled' : 'Set Reminder',
                        style: TextStyle(
                          color: isScheduled ? context.textSecondary : Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}