import 'package:build_up/features/workout_goal/widgets/glass_panal.dart';
import 'package:build_up/features/workout_goal/workout_goal_screen.dart';
import 'package:flutter/material.dart';


class RecommendedHeroCard extends StatelessWidget {
  final String tag;
  final String title;
  final int avgSteps;
  final String zone;
  final String timeline, timelineSub;
  final String deficit, deficitSub;
  final String quota, quotaSub;
  final VoidCallback? onStart;
  final VoidCallback? onTune;

  const RecommendedHeroCard({
    super.key,
    this.tag = 'FAT LOSS + CORE FOCUS',
    this.title = '4-Week Metabolic Shred',
    this.avgSteps = 8432,
    this.zone = 'Zone 3/4',
    this.timeline = '28 Days',
    this.timelineSub = '4 Microcycles',
    this.deficit = '-3.5 kg',
    this.deficitSub = '-18,000 kcal',
    this.quota = '10k Steps',
    this.quotaSub = '+15m Core',
    this.onStart,
    this.onTune,
  });

  String get _steps => avgSteps
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 1. badge row
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: CustomColors.surfaceHighest.withValues(alpha: .8),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.auto_graph, size: 14, color: CustomColors.lime),
                const SizedBox(width: 6),
                Flexible(
                  child: Text('RECOMMENDED • $_steps STEPS AVG',
                      overflow: TextOverflow.ellipsis,
                      style: AppText.mono(10, color: CustomColors.lime)),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          Row(children: [
            const Icon(Icons.bolt, size: 14, color: CustomColors.lime),
            Text(' $zone', style: AppText.mono(11)),
          ]),
        ]),
        const SizedBox(height: 16),

        // 2. gradient banner (swap for Image.asset later if you want a photo)
        Container(
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                CustomColors.lime.withValues(alpha: .35),
                CustomColors.surfaceHighest,
                CustomColors.surfaceLowest,
              ],
            ),
          ),
          child: Stack(children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      CustomColors.surface,
                      CustomColors.surface.withValues(alpha: .2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tag, style: AppText.mono(12, color: CustomColors.lime)),
                    Text(title, style: AppText.sora(24)),
                  ]),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: CustomColors.lime,
                    boxShadow: [BoxShadow(color: CustomColors.lime, blurRadius: 15)],
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: CustomColors.onLime),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // 3. KPI strip
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CustomColors.surfaceLowest.withValues(alpha: .8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            _Kpi('TIMELINE', timeline, timelineSub),
            _Kpi('DEFICIT TARGET', deficit, deficitSub, lime: true),
            _Kpi('DAILY QUOTA', quota, quotaSub),
          ]),
        ),
        const SizedBox(height: 20),

        // 4. actions
        Row(children: [
          Expanded(
            child: FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: CustomColors.lime,
                foregroundColor: CustomColors.onLime,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
              child: Text('Start Program', style: AppText.sora(15, color: CustomColors.onLime)),
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filled(
            onPressed: onTune,
            tooltip: 'Adjust program',
            style: IconButton.styleFrom(backgroundColor: CustomColors.surfaceHigh),
            icon: const Icon(Icons.tune, size: 20, color: Colors.white),
          ),
        ]),
      ]),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String label, value, sub;
  final bool lime;
  const _Kpi(this.label, this.value, this.sub, {this.lime = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppText.mono(10), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(value,
            style: AppText.sora(15, color: lime ? CustomColors.lime : Colors.white)),
        Text(sub, style: AppText.mono(9, color: CustomColors.outline)),
      ]),
    );
  }
}