import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
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
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryEmerald,
              surface: AppColors.glassCardBackground,
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

    // Note: To make this trigger at a specific time in the future,
    // you must update your service to use timezone scheduling.
    // For now, this triggers the immediate alert pattern you provided.
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
        backgroundColor: AppColors.primaryEmerald,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'DAILY WALK',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set a daily reminder to get your steps in.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            GlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.timer, color: AppColors.primaryEmerald, size: 48),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () => _selectTime(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryEmerald.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primaryEmerald.withOpacity(0.3)),
                      ),
                      child: Text(
                        selectedTime.format(context),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryEmerald,
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
                        backgroundColor: isScheduled ? AppColors.glassCardBorder : AppColors.primaryEmerald,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        isScheduled ? 'Scheduled' : 'Set Reminder',
                        style: TextStyle(
                          color: isScheduled ? AppColors.textSecondary : Colors.black,
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