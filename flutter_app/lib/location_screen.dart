import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'firebase_service.dart';
import 'session.dart';
import 'theme/app_theme.dart';
import 'widgets/glass_card.dart';
import 'widgets/status_chip.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  late final _service = FirebaseService(AppSession.instance.boxId!);

  StreamSubscription<DatabaseEvent>? _locationSub;
  StreamSubscription<DatabaseEvent>? _deviceSub;

  final MapController _mapController = MapController();

  double latitude = 0;
  double longitude = 0;
  bool isOnline = false;

  @override
  void initState() {
    super.initState();

    _locationSub = _service.locationStream().listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;

      setState(() {
        latitude = toDoubleSafe(data['latitude']);
        longitude = toDoubleSafe(data['longitude']);
      });

      if (latitude != 0 || longitude != 0) {
        try {
          _mapController.move(LatLng(latitude, longitude), _mapController.camera.zoom);
        } catch (_) {
          // Map not laid out yet on the very first update — safe to ignore.
        }
      }
    });

    _deviceSub = _service.deviceStream().listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;
      setState(() => isOnline = (data['status'] ?? 'offline').toString() == 'online');
    });
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _deviceSub?.cancel();
    super.dispose();
  }

  Future<void> _openInMaps() async {
    final uri = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=$latitude,$longitude",
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _infoRow(IconData icon, String title, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.15)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasFix = latitude != 0 || longitude != 0;
    final point = LatLng(hasFix ? latitude : 0, hasFix ? longitude : 0);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
          children: [
            Text(
              "Location",
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text("Track your delivery box anywhere in the world", style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            GlassCard(
              margin: EdgeInsets.zero,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (isOnline ? AppColors.success : AppColors.danger).withOpacity(0.15),
                    ),
                    child: Icon(
                      Icons.gps_fixed_rounded,
                      color: isOnline ? AppColors.success : AppColors.danger,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOnline ? "GPS Connected" : "Device Offline",
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        Text(
                          hasFix ? "Live device location" : "Waiting for GPS fix...",
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(
                    label: isOnline ? "LIVE" : "OFFLINE",
                    color: isOnline ? AppColors.success : AppColors.danger,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: SizedBox(
                height: 240,
                child: hasFix
                    ? FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: point,
                          initialZoom: 14,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.deliveriya.app',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: point,
                                width: 44,
                                height: 44,
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  color: AppColors.danger,
                                  size: 44,
                                ),
                              ),
                            ],
                          ),
                          const RichAttributionWidget(
                            attributions: [
                              TextSourceAttribution('OpenStreetMap contributors'),
                            ],
                          ),
                        ],
                      )
                    : Container(
                        color: AppColors.surface,
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.satellite_alt_rounded, size: 40, color: AppColors.textSecondary),
                            SizedBox(height: 10),
                            Text("Waiting for GPS fix...", style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            GlassCard(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  _infoRow(
                    Icons.explore_rounded,
                    "Latitude",
                    hasFix ? latitude.toStringAsFixed(6) : "No fix yet",
                    AppColors.success,
                  ),
                  _infoRow(
                    Icons.navigation_rounded,
                    "Longitude",
                    hasFix ? longitude.toStringAsFixed(6) : "No fix yet",
                    AppColors.accentB,
                  ),
                  _infoRow(
                    Icons.wifi_rounded,
                    "Device Status",
                    isOnline ? "Online" : "Offline",
                    isOnline ? AppColors.success : AppColors.danger,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentA,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.all(16),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
              ),
              icon: const Icon(Icons.map),
              label: const Text("OPEN IN GOOGLE MAPS", style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: hasFix ? _openInMaps : null,
            ),
          ],
        ),
      ),
    );
  }
}
