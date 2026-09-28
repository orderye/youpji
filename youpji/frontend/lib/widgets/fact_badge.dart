import 'package:flutter/material.dart';
import '../core/constants/theme_constants.dart';

class FactBadge extends StatelessWidget {
  final String status; // verified | pending | unverified

  const FactBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    String label;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'verified':
        bg = AppTheme.verifiedGreen.withValues(alpha: 0.12);
        text = AppTheme.verifiedGreen;
        label = '官方核验';
        icon = Icons.verified;
        break;
      case 'pending':
        bg = AppTheme.pendingYellow.withValues(alpha: 0.12);
        text = AppTheme.pendingYellow;
        label = '地图参考';
        icon = Icons.schedule;
        break;
      default:
        bg = AppTheme.unverifiedGray.withValues(alpha: 0.12);
        text = AppTheme.unverifiedGray;
        label = '待核验';
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: text,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
