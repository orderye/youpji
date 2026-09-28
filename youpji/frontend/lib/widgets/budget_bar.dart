import 'package:flutter/material.dart';
import '../core/constants/theme_constants.dart';
import '../models/itinerary_model.dart';

class BudgetBar extends StatelessWidget {
  final BudgetBreakdown budget;

  const BudgetBar({super.key, required this.budget});

  @override
  Widget build(BuildContext context) {
    final progress = budget.limit > 0 ? (budget.total / budget.limit).clamp(0.0, 1.0) : 0.0;
    final isOver = budget.total > budget.limit;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9E3D6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '预算管控与核算',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppTheme.darkInk,
                ),
              ),
              Text(
                '¥${budget.total} / ¥${budget.limit}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isOver ? AppTheme.dangerRed : AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFFEEEAE0),
              valueColor: AlwaysStoppedAnimation<Color>(
                isOver ? AppTheme.dangerRed : AppTheme.primaryBlue,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _buildTag('门票', '¥${budget.tickets}'),
              _buildTag('住宿', '¥${budget.lodging}'),
              _buildTag('餐饮', '¥${budget.food}'),
              _buildTag('交通油费', '¥${budget.transport}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String title, String cost) {
    return Text(
      '$title: $cost',
      style: const TextStyle(
        fontSize: 11,
        color: AppTheme.mutedGray,
      ),
    );
  }
}
