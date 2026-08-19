import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

/// A one-tap call pill that launches the phone dialer directly with
/// the given number — used so senders and customers can call each
/// other without leaving the app.
class CallButton extends StatelessWidget {
  final String phone;
  final String label;

  const CallButton({super.key, required this.phone, this.label = "Call"});

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (phone.isEmpty) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: _call,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.call_rounded, size: 16, color: Colors.black),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
