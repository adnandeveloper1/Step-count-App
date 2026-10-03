import 'package:build_up/features/workout_goal/widgets/program_details_screen.dart';
import 'package:build_up/features/workout_goal/widgets/programs_catrgory.dart';
import 'package:build_up/features/workout_goal/widgets/glass_panal.dart';
import 'package:build_up/features/workout_goal/workout_goal_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../step_tracking/presentation/providers/step_provider.dart';

class ProgramCard extends ConsumerStatefulWidget {
  final Program program;
  final VoidCallback? onEnroll;
  final ValueChanged<bool>? onSavedChanged;

  const ProgramCard({
    super.key,
    required this.program,
    this.onEnroll,
    this.onSavedChanged,
  });

  @override
  ConsumerState<ProgramCard> createState() => _ProgramCardState();
}

class _ProgramCardState extends ConsumerState<ProgramCard> {
  bool saved = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.program;
    final activeProgramId = ref.watch(activeProgramIdProvider);
    final stepState = ref.watch(stepNotifierProvider);
    final isActive = activeProgramId == p.title;

    return GestureDetector(
      onTap: (){
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ProgramDetailsScreen(program: p)),
        );
      },
      child: GlassPanel(
        color: CustomColors.surface.withValues(alpha: .6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: CustomColors.surfaceHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(p.icon, color: CustomColors.lime, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: CustomColors.surfaceHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(p.days, style: AppText.mono(10)),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      p.level,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.mono(10,
                          color: p.highIntensity ? CustomColors.error : CustomColors.lime),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(p.title, style: AppText.sora(17)),
              ]),
            ),
            // IconButton(
            //   visualDensity: VisualDensity.compact,
            //   tooltip: saved ? 'Remove bookmark' : 'Save program',
            //   onPressed: () {
            //     setState(() => saved = !saved);
            //     widget.onSavedChanged?.call(saved);
            //   },
            //   icon: Icon(
            //     saved ? Icons.bookmark_added : Icons.bookmark_add_outlined,
            //     color: saved ? CustomColors.lime : CustomColors.textSecondary,
            //   ),
            // ),
          ]),
          const SizedBox(height: 12),
          Text(p.desc, style: AppText.body(13)),
          const SizedBox(height: 12),
          if (isActive) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('PROGRESS', style: AppText.mono(10, color: CustomColors.lime)),
                Text(
                  '${((stepState.currentSteps / stepState.goalSteps) * 100).clamp(0, 100).toInt()}%',
                  style: AppText.mono(10, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (stepState.currentSteps / stepState.goalSteps).clamp(0, 1.0),
                backgroundColor: CustomColors.surfaceHighest,
                color: CustomColors.lime,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${stepState.currentSteps} / ${stepState.goalSteps} STEPS',
                  style: AppText.mono(9, color: CustomColors.outline),
                ),
                GestureDetector(
                  onTap: () {
                    ref.read(activeProgramIdProvider.notifier).state = null;
                  },
                  child: Text('QUIT', style: AppText.mono(9, color: CustomColors.error)),
                ),
              ],
            ),
          ] else
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(
                child: Wrap(spacing: 12, runSpacing: 4, children: [
                  _StatChip(p.stat1),
                  _StatChip(p.stat2),
                ]),
              ),
              TextButton(
                onPressed: widget.onEnroll,
                style: TextButton.styleFrom(
                  backgroundColor: CustomColors.surfaceHigh,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: const StadiumBorder(),
                ),
                child: Text('Enroll', style: AppText.mono(11, color: Colors.white)),
              ),
            ]),
        ]),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final ProgramStat stat;
  const _StatChip(this.stat);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(stat.icon,
          size: 14, color: stat.highlight ? CustomColors.lime : CustomColors.outline),
      const SizedBox(width: 4),
      Text(stat.label,
          style: AppText.mono(11,
              color: stat.highlight ? CustomColors.lime : CustomColors.textPrimary)),
    ]);
  }
}