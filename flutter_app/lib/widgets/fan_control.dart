import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../firebase_service.dart';
import '../box_service.dart';
import '../session.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

class FanControl extends StatefulWidget {
  const FanControl({super.key});

  @override
  State<FanControl> createState() => _FanControlState();
}

class _FanControlState extends State<FanControl> {
  late final _service = FirebaseService(AppSession.instance.boxId!);

  StreamSubscription<DatabaseEvent>? _sub;

  bool fanOn = false;
  bool fanAuto = false;
  bool updating = false;

  @override
  void initState() {
    super.initState();

    _sub = _service.controlStream().listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;
      setState(() {
        fanOn = data['fan'] == true;
        fanAuto = data['fanAuto'] == true;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _toggle(bool value) async {
    setState(() => updating = true);

    try {
      await _service.setFan(value);

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await BoxService.instance.logEvent(
          AppSession.instance.boxId!,
          uid,
          value ? 'fan_on_manual' : 'fan_off_manual',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to update fan: $e')));
      }
    } finally {
      if (mounted) setState(() => updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final running = fanOn || fanAuto;
    final color = running ? AppColors.accentA : AppColors.textSecondary;

    return GlassCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.15)),
            child: Icon(Icons.air_rounded, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Cooling Fan", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      running ? "RUNNING" : "OFF",
                      style: TextStyle(color: color, fontWeight: FontWeight.w700),
                    ),
                    if (fanAuto) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          "AUTO · HIGH TEMP",
                          style: TextStyle(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (updating)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentA),
            )
          else
            Switch(value: fanOn, activeColor: AppColors.accentA, onChanged: _toggle),
        ],
      ),
    );
  }
}
