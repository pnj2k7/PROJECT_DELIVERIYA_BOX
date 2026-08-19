import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'firebase_service.dart';
import 'theme/app_theme.dart';
import 'widgets/glass_card.dart';
import 'widgets/status_chip.dart';
import 'session.dart';
import 'auth_service.dart';
import 'role_select_screen.dart';
import 'sender/sender_dashboard_screen.dart';
import 'customer/customer_dashboard_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _service = FirebaseService(AppSession.instance.boxId!);

  StreamSubscription<DatabaseEvent>? _deviceSub;

  bool isOnline = false;
  Map<String, dynamic>? profile;

  bool get isCustomer => AppSession.instance.role == 'customer';

  @override
  void initState() {
    super.initState();

    _deviceSub = _service.deviceStream().listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;
      setState(() => isOnline = (data['status'] ?? 'offline').toString() == 'online');
    });

    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final data = await AuthService.instance.fetchProfile(uid);
    if (mounted) setState(() => profile = data);
  }

  @override
  void dispose() {
    _deviceSub?.cancel();
    super.dispose();
  }

  Widget _infoLine(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textSecondary)),
          Flexible(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _hardwareRow(IconData icon, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.15)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
        ],
      ),
    );
  }

  Future<void> _disconnectBox() async {
    await AppSession.instance.clearBox();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => isCustomer ? const CustomerDashboardScreen() : const SenderDashboardScreen(),
      ),
      (route) => false,
    );
  }

  Future<void> _signOut() async {
    await AuthService.instance.signOut();
    await AppSession.instance.clearAll();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fullName = profile == null
        ? "-"
        : "${profile!['firstName'] ?? ''} ${profile!['lastName'] ?? ''}".trim();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
          children: [
            Text(
              "Settings",
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text("Your profile & device information", style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            GlassCard(
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Profile", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  _infoLine("Name", fullName.isEmpty ? "-" : fullName),
                  _infoLine("Username", profile?['username']?.toString() ?? "-"),
                  _infoLine("Company", (profile?['company']?.toString().isNotEmpty ?? false) ? profile!['company'] : "-"),
                  _infoLine("Phone", profile?['phone']?.toString() ?? "-"),
                  _infoLine("Role", (AppSession.instance.role ?? "-").toUpperCase()),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GlassCard(
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Device", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      StatusChip(
                        label: isOnline ? "ONLINE" : "OFFLINE",
                        color: isOnline ? AppColors.success : AppColors.danger,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _infoLine("Box ID", AppSession.instance.boxId ?? "-"),
                  _infoLine("Board", "ESP8266 (NodeMCU)"),
                  _infoLine("Database", "Firebase Realtime DB"),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GlassCard(
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Connected Hardware", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  _hardwareRow(Icons.thermostat_rounded, "DHT22 — Temperature & Humidity", AppColors.warning),
                  _hardwareRow(Icons.vibration_rounded, "MPU6050 — Acceleration", AppColors.accentB),
                  _hardwareRow(Icons.gps_fixed_rounded, "GPS — Location", AppColors.success),
                  _hardwareRow(Icons.lock_rounded, "Servo — Door Lock", AppColors.accentA),
                  _hardwareRow(Icons.electrical_services_rounded, "Relay — Fan", AppColors.accentA),
                  _hardwareRow(Icons.campaign_rounded, "Buzzer — Alerts (reserved)", AppColors.textSecondary),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GlassCard(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _disconnectBox,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: Text(isCustomer ? "Disconnect from Box" : "Back to Dashboard"),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text("Sign Out"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
