import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Premium card treatment used across every screen: a soft surface,
/// a subtle gradient hairline border, and a deep, layered shadow.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin = const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        gradient: LinearGradient(
          colors: [
            AppColors.border.withOpacity(0.9),
            AppColors.border.withOpacity(0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(1), // reveals the gradient as a hairline border
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card - 1),
        ),
        child: child,
      ),
    );
  }
}
