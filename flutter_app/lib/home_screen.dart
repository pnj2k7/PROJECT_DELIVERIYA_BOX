import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import 'firebase_service.dart';
import 'session.dart';
import 'theme/app_theme.dart';
import 'widgets/glass_card.dart';
import 'widgets/status_chip.dart';
import 'widgets/pulse_dot.dart';
import 'widgets/door_button.dart';
import 'widgets/fan_control.dart';
import 'widgets/call_button.dart';
import 'widgets/hero_reveal_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final _service = FirebaseService(AppSession.instance.boxId!);

  StreamSubscription<DatabaseEvent>? _sensorsSub;
  StreamSubscription<DatabaseEvent>? _deviceSub;
  StreamSubscription<DatabaseEvent>? _controlSub;
  StreamSubscription<DatabaseEvent>? _senderSub;

  double temperature = 0;
  double humidity = 0;
  String doorStatus = "Closed";

  bool isOnline = false;
  bool doorOpen = false;
  bool doorUpdating = false;

  Map<String, dynamic>? sender;

  @override
  void initState() {
    super.initState();

    _sensorsSub = _service.sensorsStream().listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;
      setState(() {
        temperature = toDoubleSafe(data['temperature']);
        humidity = toDoubleSafe(data['humidity']);
        doorStatus = (data['doorStatus'] ?? 'Closed').toString();
      });
    });

    _deviceSub = _service.deviceStream().listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;
      setState(() => isOnline = (data['status'] ?? 'offline').toString() == 'online');
    });

    _controlSub = _service.controlStream().listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;
      setState(() => doorOpen = data['door'] == true);
    });

    _senderSub = FirebaseDatabase.instance
        .ref('boxes/${AppSession.instance.boxId}/sender')
        .onValue
        .listen((event) {
      final data = event.snapshot.value as Map?;
      if (!mounted) return;
      setState(() => sender = data == null ? null : Map<String, dynamic>.from(data));
    });
  }

  @override
  void dispose() {
    _sensorsSub?.cancel();
    _deviceSub?.cancel();
    _controlSub?.cancel();
    _senderSub?.cancel();
    super.dispose();
  }

  Future<void> _toggleDoor() async {
    setState(() => doorUpdating = true);
    try {
      await _service.setDoor(!doorOpen);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update door: $e')));
      }
    } finally {
      if (mounted) setState(() => doorUpdating = false);
    }
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
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

  Widget _metricTile(IconData icon, String title, String value, Color color) {
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A0D14), Color(0xFF161C2C)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShaderMask(
                    shaderCallback: (b) => AppColors.accentGradient.createShader(b),
                    child: const Text(
                      "DELIVERIYA",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.6),
                    ),
                  ),
                  Row(
                    children: [
                      PulseDot(color: isOnline ? AppColors.success : AppColors.danger),
                      const SizedBox(width: 6),
                      StatusChip(label: isOnline ? "ONLINE" : "OFFLINE", color: isOnline ? AppColors.success : AppColors.danger),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Center(
                child: Column(
                  children: [
                    Text(
                      "${temperature.toStringAsFixed(1)}°",
                      style: const TextStyle(fontSize: 88, fontWeight: FontWeight.w800, height: 1, color: Colors.white),
                    ),
                    const Text(
                      "Live cargo temperature",
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HeroRevealSheet(
        hero: _buildHero(),
        details: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              _metricTile(Icons.thermostat_rounded, "Temperature", "${temperature.toStringAsFixed(1)}°C", AppColors.warning),
              _metricTile(Icons.water_drop_rounded, "Humidity", "${humidity.toStringAsFixed(0)}%", AppColors.accentB),
              _metricTile(
                Icons.door_front_door_rounded,
                "Door",
                doorStatus,
                doorStatus == "Open" ? AppColors.danger : AppColors.success,
              ),
              _metricTile(
                Icons.podcasts_rounded,
                "Connection",
                isOnline ? "Live" : "Lost",
                isOnline ? AppColors.success : AppColors.danger,
              ),
            ],
          ),
          if (sender != null) ...[
            _sectionLabel("Your Sender"),
            GlassCard(
              margin: EdgeInsets.zero,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accentB.withOpacity(0.15)),
                    child: const Icon(Icons.storefront_rounded, color: AppColors.accentB),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Builder(builder: (_) {
                      final first = sender!['firstName']?.toString() ?? '';
                      final last = sender!['lastName']?.toString() ?? '';
                      final fullName = "$first $last".trim();
                      final company = sender!['company']?.toString() ?? '';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fullName.isNotEmpty ? fullName : "Sender", style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          if (company.isNotEmpty)
                            Text(company, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      );
                    }),
                  ),
                  CallButton(phone: sender!['phone']?.toString() ?? ''),
                ],
              ),
            ),
          ],
          _sectionLabel("Door access"),
          doorUpdating
              ? const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
              : DoorButton(isLocked: !doorOpen, onPressed: _toggleDoor),
          _sectionLabel("Cooling system"),
          const FanControl(),
        ],
      ),
    );
  }
}
