import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';

import 'session.dart';
import 'theme/app_theme.dart';
import 'widgets/glass_card.dart';
import 'widgets/status_chip.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  StreamSubscription<DatabaseEvent>? _activitySub;
  StreamSubscription<DatabaseEvent>? _sensorSub;

  List<Map<String, dynamic>> events = [];
  List<Map<String, dynamic>> sensorReadings = [];
  bool? delivered;
  StreamSubscription<DatabaseEvent>? _deliveredSub;

  @override
  void initState() {
    super.initState();

    final boxId = AppSession.instance.boxId;
    if (boxId == null) return;

    _deliveredSub = FirebaseDatabase.instance.ref('boxes/$boxId/delivered').onValue.listen((event) {
      if (!mounted) return;
      setState(() => delivered = event.snapshot.value == true);
    });

    _activitySub = FirebaseDatabase.instance.ref('boxes/$boxId/activity').onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) {
        setState(() => events = []);
        return;
      }

      final list = data.entries.map((e) {
        final v = Map<String, dynamic>.from(e.value as Map);
        return {
          'type': v['type']?.toString() ?? 'unknown',
          'timestamp': v['timestamp'] is num ? (v['timestamp'] as num).toInt() : 0,
          'temperature': v['temperature'] is num ? (v['temperature'] as num).toDouble() : null,
        };
      }).toList();

      list.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
      setState(() => events = list);
    });

    _sensorSub = FirebaseDatabase.instance
        .ref('boxes/$boxId/sensorHistory')
        .limitToLast(20)
        .onValue
        .listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) {
        setState(() => sensorReadings = []);
        return;
      }

      final list = data.entries.map((e) {
        final v = Map<String, dynamic>.from(e.value as Map);
        return {
          'temperature': v['temperature'] is num ? (v['temperature'] as num).toDouble() : 0.0,
          'humidity': v['humidity'] is num ? (v['humidity'] as num).toDouble() : 0.0,
          'accelX': v['accelX'] is num ? (v['accelX'] as num).toDouble() : 0.0,
          'accelY': v['accelY'] is num ? (v['accelY'] as num).toDouble() : 0.0,
          'accelZ': v['accelZ'] is num ? (v['accelZ'] as num).toDouble() : 0.0,
          'latitude': v['latitude'] is num ? (v['latitude'] as num).toDouble() : 0.0,
          'longitude': v['longitude'] is num ? (v['longitude'] as num).toDouble() : 0.0,
          'timestamp': v['timestamp'] is num ? (v['timestamp'] as num).toInt() : 0,
        };
      }).toList();

      list.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
      setState(() => sensorReadings = list);
    });
  }

  @override
  void dispose() {
    _activitySub?.cancel();
    _sensorSub?.cancel();
    _deliveredSub?.cancel();
    super.dispose();
  }

  String _formatTime(int millis) {
    if (millis == 0) return "";
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    final diff = DateTime.now().difference(dt);

    if (diff.inSeconds < 60) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";

    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return "${dt.day}/${dt.month}/${dt.year} · $h:$m";
  }

  Map<String, dynamic> _meta(Map<String, dynamic> e) {
    final type = e['type'] as String;
    final temp = e['temperature'] as double?;

    switch (type) {
      case 'box_created':
        return {'icon': Icons.inventory_2_rounded, 'label': 'Box created', 'color': AppColors.accentB};
      case 'customer_connected':
        return {'icon': Icons.link_rounded, 'label': 'Customer connected', 'color': AppColors.accentA};
      case 'door_opened':
        return {'icon': Icons.lock_open_rounded, 'label': 'Door unlocked', 'color': AppColors.danger};
      case 'door_closed':
        return {'icon': Icons.lock_rounded, 'label': 'Door locked', 'color': AppColors.success};
      case 'fan_on_manual':
        return {'icon': Icons.air_rounded, 'label': 'Fan turned on', 'color': AppColors.accentA};
      case 'fan_off_manual':
        return {'icon': Icons.air_rounded, 'label': 'Fan turned off', 'color': AppColors.textSecondary};
      case 'fan_auto_on':
        return {
          'icon': Icons.local_fire_department_rounded,
          'label': temp != null
              ? 'Fan auto-activated at ${temp.toStringAsFixed(1)}°C (high temp)'
              : 'Fan auto-activated (high temp)',
          'color': AppColors.warning,
        };
      case 'fan_auto_off':
        return {
          'icon': Icons.check_circle_rounded,
          'label': temp != null
              ? 'Fan auto-deactivated at ${temp.toStringAsFixed(1)}°C'
              : 'Fan auto-deactivated',
          'color': AppColors.success,
        };
      case 'emergency_open':
        return {'icon': Icons.warning_amber_rounded, 'label': 'Emergency: box opened by sender', 'color': AppColors.danger};
      case 'emergency_close':
        return {'icon': Icons.warning_amber_rounded, 'label': 'Emergency: box re-locked by sender', 'color': AppColors.warning};
      case 'delivery_confirmed':
        return {'icon': Icons.celebration_rounded, 'label': 'Delivery confirmed', 'color': AppColors.success};
      default:
        return {'icon': Icons.circle_notifications_rounded, 'label': type, 'color': AppColors.textSecondary};
    }
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }

  Widget _sensorChart() {
    if (sensorReadings.length < 2) {
      return GlassCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(24),
        child: const Center(
          child: Text("Not enough readings yet for a chart", style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    // sensorReadings is newest-first; chart wants oldest-first (left to right).
    final chronological = sensorReadings.reversed.toList();

    final tempSpots = <FlSpot>[];
    final humiditySpots = <FlSpot>[];
    for (var i = 0; i < chronological.length; i++) {
      tempSpots.add(FlSpot(i.toDouble(), chronological[i]['temperature'] as double));
      humiditySpots.add(FlSpot(i.toDouble(), chronological[i]['humidity'] as double));
    }

    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Temperature & Humidity Trend", style: TextStyle(fontWeight: FontWeight.w700)),
              Row(children: [
                _legendDot(AppColors.warning, "°C"),
                const SizedBox(width: 12),
                _legendDot(AppColors.accentB, "%"),
              ]),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 1),
                ),
                titlesData: const FlTitlesData(
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: tempSpots,
                    isCurved: true,
                    color: AppColors.warning,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: humiditySpots,
                    isCurved: true,
                    color: AppColors.accentB,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 10),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
          children: [
            Text(
              "History",
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text("Live activity & sensor log for this box", style: TextStyle(color: AppColors.textSecondary)),
            if (delivered != null) ...[
              const SizedBox(height: 14),
              StatusChip(
                label: delivered! ? "SUCCESSFULLY DELIVERED" : "IN TRANSIT",
                color: delivered! ? AppColors.success : AppColors.warning,
              ),
            ],

            _sectionLabel("Activity Log"),
            if (events.isEmpty)
              GlassCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(24),
                child: const Center(
                  child: Text("No activity yet", style: TextStyle(color: AppColors.textSecondary)),
                ),
              )
            else
              ...events.map((e) {
                final meta = _meta(e);
                return GlassCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (meta['color'] as Color).withOpacity(0.15),
                        ),
                        child: Icon(meta['icon'] as IconData, color: meta['color'] as Color, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(meta['label'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      Text(
                        _formatTime(e['timestamp'] as int),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                );
              }),

            _sectionLabel("Sensor Trend"),
            _sensorChart(),
            _sectionLabel("Sensor Readings (last 20)"),
            if (sensorReadings.isEmpty)
              GlassCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(24),
                child: const Center(
                  child: Text("No sensor snapshots yet", style: TextStyle(color: AppColors.textSecondary)),
                ),
              )
            else
              ...sensorReadings.map((r) {
                return GlassCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${(r['temperature'] as double).toStringAsFixed(1)}°C · ${(r['humidity'] as double).toStringAsFixed(0)}%",
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            _formatTime(r['timestamp'] as int),
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Accel: X ${(r['accelX'] as double).toStringAsFixed(1)} · "
                        "Y ${(r['accelY'] as double).toStringAsFixed(1)} · "
                        "Z ${(r['accelZ'] as double).toStringAsFixed(1)} m/s²",
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      if ((r['latitude'] as double) != 0 || (r['longitude'] as double) != 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          "GPS: ${(r['latitude'] as double).toStringAsFixed(4)}, ${(r['longitude'] as double).toStringAsFixed(4)}",
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
