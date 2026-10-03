import 'package:flutter/material.dart';
import 'package:build_up/app/theme/app_colors.dart';

import 'programs_catrgory.dart';
import '../workout_goal_screen.dart';


class FilterChipBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const FilterChipBar({super.key, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ProgramCategory.chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final (label, emoji) = ProgramCategory.chips[i];
          final active = selected == label;
          return GestureDetector(
            onTap: () => onSelected(label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? CustomColors.lime
                    : CustomColors.surfaceHigh.withValues(alpha: .6),
                borderRadius: BorderRadius.circular(999),
                boxShadow: active
                    ? [BoxShadow(color: CustomColors.lime.withValues(alpha: .3), blurRadius: 15)]
                    : const [],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (active)
                  const Icon(Icons.check, size: 16, color: CustomColors.onLime)
                else if (emoji.isNotEmpty)
                  Text(emoji),
                const SizedBox(width: 6),
                Text(label,
                    style: AppText.mono(12,
                        color: active ? CustomColors.onLime : Colors.white)),
              ]),
            ),
          );
        },
      ),
    );
  }
}