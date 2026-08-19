import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

class DoorButton extends StatelessWidget {
  final bool isLocked;
  final VoidCallback onPressed;

  const DoorButton({
    super.key,
    required this.isLocked,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = isLocked ? AppColors.success : AppColors.danger;

    return GlassCard(
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.15),
            ),
            child: Icon(
              isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
              size: 30,
              color: color,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Door Status",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isLocked ? "LOCKED" : "OPEN",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
            ),
            onPressed: onPressed,
            child: Text(
              isLocked ? "UNLOCK" : "LOCK",
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
