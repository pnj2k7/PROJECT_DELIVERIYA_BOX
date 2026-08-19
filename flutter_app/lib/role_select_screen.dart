import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'session.dart';
import 'auth/auth_screen.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  void _pick(BuildContext context, String role) async {
    await AppSession.instance.setRole(role);
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AuthScreen(role: role)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Soft ambient glow in the background for a premium feel.
          Positioned(
            top: -120,
            right: -100,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.accentB.withOpacity(0.25), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.accentA.withOpacity(0.18), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.accentGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentB.withOpacity(0.4),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.shield_moon_rounded, size: 34, color: Colors.black),
                  ),
                  const SizedBox(height: 22),
                  ShaderMask(
                    shaderCallback: (b) => AppColors.accentGradient.createShader(b),
                    child: const Text(
                      "DELIVERIYA",
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Precision cargo telemetry — worldwide",
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 46),
                  _RoleCard(
                    icon: Icons.inventory_2_rounded,
                    title: "I'm a Sender",
                    subtitle: "Create and monitor consignments",
                    color: AppColors.accentB,
                    onTap: () => _pick(context, 'sender'),
                  ),
                  const SizedBox(height: 16),
                  _RoleCard(
                    icon: Icons.local_shipping_rounded,
                    title: "I'm a Customer",
                    subtitle: "Track and control your delivery",
                    color: AppColors.accentA,
                    onTap: () => _pick(context, 'customer'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.15)),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
