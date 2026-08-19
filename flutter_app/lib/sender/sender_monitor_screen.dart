import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../firebase_service.dart';
import '../box_service.dart';
import '../session.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/status_chip.dart';
import '../widgets/pulse_dot.dart';
import '../widgets/call_button.dart';
import '../widgets/hero_reveal_sheet.dart';

/// Senders can monitor temperature/humidity/MPU6050, and can trigger an
/// Emergency Open — the ONLY way a sender can touch the door. Every
/// emergency action is confirmed first and logged to the activity feed,
/// and fires a real-time alert to the connected customer.
class SenderMonitorScreen extends StatefulWidget {
  const SenderMonitorScreen({super.key});

  @override
  State<SenderMonitorScreen> createState() => _SenderMonitorScreenState();
}

class _SenderMonitorScreenState extends State<SenderMonitorScreen> {
  late final _service = FirebaseService(AppSession.instance.boxId!);

  StreamSubscription<DatabaseEvent>? _sensorsSub;
  StreamSubscription<DatabaseEvent>? _deviceSub;
  StreamSubscription<DatabaseEvent>? _controlSub;
  StreamSubscription<DatabaseEvent>? _customerSub;
  StreamSubscription<DatabaseEvent>? _passwordSub;

  double temperature = 0;
  double humidity = 0;
  double accelX = 0;
  double accelY = 0;
  double accelZ = 0;

  bool isOnline = false;
  bool doorOpen = false;
  bool fanOn = false;
  bool fanAuto = false;
  bool emergencyBusy = false;

  Map<String, dynamic>? customer;
  String? boxPassword;

  @override
  void initState() {
    super.initState();

    _customerSub = FirebaseDatabase.instance.ref('boxes/${AppSession.instance.boxId}/customer').onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (!mounted) return;
      setState(() => customer = data == null ? null : Map<String, dynamic>.from(data));
    });

    // Live-listens so this disappears from the sender's screen the
    // instant a customer connects and the password gets erased —
    // no manual refresh needed.
    _passwordSub = FirebaseDatabase.instance
        .ref('boxes/${AppSession.instance.boxId}/meta/boxPassword')
        .onValue
        .listen((event) {
      if (!mounted) return;
      setState(() => boxPassword = event.snapshot.value?.toString());
    });

    _sensorsSub = _service.sensorsStream().listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;
      setState(() {
        temperature = toDoubleSafe(data['temperature']);
        humidity = toDoubleSafe(data['humidity']);
        accelX = toDoubleSafe(data['accelerationX']);
        accelY = toDoubleSafe(data['accelerationY']);
        accelZ = toDoubleSafe(data['accelerationZ']);
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
      setState(() {
        doorOpen = data['door'] == true;
        fanOn = data['fan'] == true;
        fanAuto = data['fanAuto'] == true;
      });
    });
  }

  @override
  void dispose() {
    _sensorsSub?.cancel();
    _deviceSub?.cancel();
    _controlSub?.cancel();
    _customerSub?.cancel();
    _passwordSub?.cancel();
    super.dispose();
  }

  Future<void> _confirmEmergency() async {
    final action = doorOpen ? "re-lock" : "open";

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            SizedBox(width: 10),
            Text("Confirm Emergency Action"),
          ],
        ),
        content: Text(
          "This will $action the box remotely and notify the customer "
          "immediately that an emergency action was taken during transit. "
          "Only use this for genuine emergencies.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(action == "open" ? "OPEN NOW" : "RE-LOCK NOW"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => emergencyBusy = true);
    try {
      await _service.setDoor(!doorOpen);
      await BoxService.instance.logEvent(
        AppSession.instance.boxId!,
        uid,
        doorOpen ? 'emergency_close' : 'emergency_open',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Emergency action failed: $e')));
      }
    } finally {
      if (mounted) setState(() => emergencyBusy = false);
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

  Widget _axisRow(String label, double value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accentA.withOpacity(0.15)),
              child: Text(label, style: const TextStyle(color: AppColors.accentA, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Text("Acceleration $label", style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
        Text("${value.toStringAsFixed(2)} m/s²", style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
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
                    Icon(
                      doorOpen ? Icons.lock_open_rounded : Icons.lock_rounded,
                      size: 64,
                      color: doorOpen ? AppColors.danger : AppColors.success,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      doorOpen ? "OPEN" : "SECURED",
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: doorOpen ? AppColors.danger : AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "${temperature.toStringAsFixed(1)}°C cargo temperature",
                      style: const TextStyle(color: AppColors.textSecondary),
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
          if (boxPassword != null) ...[
            _sectionLabel("Share With Your Customer"),
            GlassCard(
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Not yet claimed",
                    style: TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Box ID", style: TextStyle(color: AppColors.textSecondary)),
                      SelectableText(AppSession.instance.boxId ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Box Password", style: TextStyle(color: AppColors.textSecondary)),
                      SelectableText(boxPassword!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "These will disappear automatically once your customer connects.",
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
          if (customer != null) ...[
            _sectionLabel("Delivering To"),
            GlassCard(
              margin: EdgeInsets.zero,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accentA.withOpacity(0.15)),
                    child: const Icon(Icons.person_rounded, color: AppColors.accentA),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Builder(builder: (_) {
                      final first = customer!['firstName']?.toString() ?? '';
                      final last = customer!['lastName']?.toString() ?? '';
                      final fullName = "$first $last".trim();
                      final username = customer!['username']?.toString() ?? '';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName.isNotEmpty ? fullName : (username.isNotEmpty ? username : "Customer"),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          if (username.isNotEmpty)
                            Text("@$username", style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      );
                    }),
                  ),
                  CallButton(phone: customer!['phone']?.toString() ?? ''),
                ],
              ),
            ),
          ],
          _sectionLabel("Environment"),
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
                Icons.air_rounded,
                "Fan",
                fanOn ? (fanAuto ? "ON (AUTO)" : "ON") : "OFF",
                fanOn ? AppColors.success : AppColors.textSecondary,
              ),
            ],
          ),
          _sectionLabel("Motion (MPU6050)"),
          GlassCard(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                _axisRow("X", accelX),
                const Divider(color: AppColors.border, height: 24),
                _axisRow("Y", accelY),
                const Divider(color: AppColors.border, height: 24),
                _axisRow("Z", accelZ),
              ],
            ),
          ),
          _sectionLabel("Emergency access"),
          GlassCard(
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (doorOpen ? AppColors.danger : AppColors.success).withOpacity(0.15),
                      ),
                      child: Icon(
                        doorOpen ? Icons.lock_open_rounded : Icons.lock_rounded,
                        color: doorOpen ? AppColors.danger : AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doorOpen ? "Currently OPEN" : "Currently LOCKED",
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          const Text("For emergency use only", style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(15),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                    ),
                    onPressed: emergencyBusy ? null : _confirmEmergency,
                    icon: emergencyBusy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.warning_amber_rounded),
                    label: Text(doorOpen ? "EMERGENCY RE-LOCK" : "EMERGENCY OPEN", style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
