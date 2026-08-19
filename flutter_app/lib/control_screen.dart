import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'firebase_service.dart';
import 'box_service.dart';
import 'session.dart';
import 'theme/app_theme.dart';
import 'widgets/glass_card.dart';
import 'widgets/fan_control.dart';
import 'customer/box_connect_screen.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  late final _service = FirebaseService(AppSession.instance.boxId!);

  StreamSubscription<DatabaseEvent>? _controlSub;

  bool doorOpen = false;
  bool doorUpdating = false;
  bool confirmingDelivery = false;

  @override
  void initState() {
    super.initState();

    _controlSub = _service.controlStream().listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;
      setState(() => doorOpen = data['door'] == true);
    });
  }

  @override
  void dispose() {
    _controlSub?.cancel();
    super.dispose();
  }

  Future<void> _toggleDoor() async {
    setState(() => doorUpdating = true);
    try {
      final opening = !doorOpen;
      await _service.setDoor(opening);

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await BoxService.instance.logEvent(
          AppSession.instance.boxId!,
          uid,
          opening ? 'door_opened' : 'door_closed',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to update door: $e')));
      }
    } finally {
      if (mounted) setState(() => doorUpdating = false);
    }
  }

  Future<void> _confirmDelivery() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Confirm Delivery"),
        content: const Text(
          "Confirm that you've received this delivery? The sender will be "
          "notified, and the box will be removed from your device.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => confirmingDelivery = true);
    try {
      final boxId = AppSession.instance.boxId!;
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid != null) {
        await BoxService.instance.logEvent(boxId, uid, 'delivery_confirmed');
        await BoxService.instance.confirmDelivery(boxId, uid);
      }

      await AppSession.instance.clearBox();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BoxConnectScreen()),
        (route) => false,
      );
    } finally {
      if (mounted) setState(() => confirmingDelivery = false);
    }
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _tile(IconData icon, String title, String status, Color color, Widget action) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.15)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(status, style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
          action,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 110),
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Control",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  const Text("Manage your smart delivery box", style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
            _sectionLabel("Security"),
            _tile(
              Icons.lock_rounded,
              "Door Lock",
              doorOpen ? "OPEN" : "SECURED",
              doorOpen ? AppColors.danger : AppColors.success,
              doorUpdating
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: doorOpen ? AppColors.success : AppColors.danger,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                      ),
                      onPressed: _toggleDoor,
                      child: Text(doorOpen ? "LOCK" : "OPEN"),
                    ),
            ),
            _sectionLabel("Climate"),
            const FanControl(),
            _sectionLabel("Delivery"),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GlassCard(
                margin: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Received your delivery?",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "This notifies the sender and closes out the box.",
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.all(15),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                        ),
                        onPressed: confirmingDelivery ? null : _confirmDelivery,
                        icon: confirmingDelivery
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.celebration_rounded),
                        label: const Text("Confirm Delivery"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
