import 'package:flutter/material.dart';
import '../core/constants/theme_constants.dart';
import '../models/itinerary_model.dart';

class WarningBanner extends StatelessWidget {
  final List<WarningItem> warnings;

  const WarningBanner({super.key, required this.warnings});

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) return const SizedBox.shrink();

    return Column(
      children: warnings.map((w) {
        final isConflict = w.code == 'opening_hours_conflict';
        final isBudget = w.code == 'plan_degraded';

        final Color bg = isConflict
            ? AppTheme.dangerRed.withValues(alpha: 0.1)
            : (isBudget ? AppTheme.warmAccent.withValues(alpha: 0.12) : const Color(0xFFFFF3CD));
        final Color text = isConflict
            ? AppTheme.dangerRed
            : (isBudget ? AppTheme.warmAccent : const Color(0xFF856404));

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: text.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 16, color: text),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  w.message,
                  style: TextStyle(
                    fontSize: 12,
                    color: text,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
