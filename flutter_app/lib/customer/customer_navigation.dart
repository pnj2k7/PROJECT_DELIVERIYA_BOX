import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import '../session.dart';
import '../theme/app_theme.dart';
import '../home_screen.dart';
import '../control_screen.dart';
import '../location_screen.dart';
import '../history_screen.dart';
import '../settings_screen.dart';
import '../widgets/new_tab_button.dart';
import 'customer_dashboard_screen.dart';

class CustomerNavigation extends StatefulWidget {
  const CustomerNavigation({super.key});

  @override
  State<CustomerNavigation> createState() => _CustomerNavigationState();
}

class _CustomerNavigationState extends State<CustomerNavigation> {
  int currentIndex = 0;

  StreamSubscription<DatabaseEvent>? _activitySub;
  bool _initialLoadDone = false;

  final List<Widget> screens = const [
    HomeScreen(),
    ControlScreen(),
    LocationScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();

    final boxId = AppSession.instance.boxId;
    if (boxId != null) {
      _activitySub = FirebaseDatabase.instance
          .ref('boxes/$boxId/activity')
          .limitToLast(1)
          .onChildAdded
          .listen(_onActivityAdded);
    }
  }

  void _onActivityAdded(DatabaseEvent event) {
    if (!_initialLoadDone) {
      _initialLoadDone = true;
      return;
    }

    final data = event.snapshot.value as Map?;
    if (data == null || !mounted) return;

    final type = data['type']?.toString();

    if (type == 'emergency_open') {
      _showEmergencyDialog(
        title: "Emergency Alert",
        message: "Your box has been opened by the sender while in transit, for an emergency reason.",
        icon: Icons.warning_amber_rounded,
        color: AppColors.danger,
      );
    } else if (type == 'emergency_close') {
      _showEmergencyDialog(
        title: "Emergency Alert",
        message: "Your box has been re-locked by the sender following an emergency access.",
        icon: Icons.lock_rounded,
        color: AppColors.warning,
      );
    }
  }

  void _showEmergencyDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _activitySub?.cancel();
    super.dispose();
  }

  // Disconnects from this box and returns to the connect screen. This
  // does NOT confirm delivery — it's for backing out (e.g. connected
  // to the wrong box). Confirm Delivery lives on the Control tab.
  Future<void> _backToConnect() async {
    await AppSession.instance.clearBox();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const CustomerDashboardScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Disconnect and go back',
          onPressed: _backToConnect,
        ),
        title: Text(AppSession.instance.boxId ?? 'Box'),
        actions: const [NewTabButton(), SizedBox(width: 4)],
      ),
      body: screens[currentIndex],
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 12)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: (index) => setState(() => currentIndex = index),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.settings_remote_outlined), selectedIcon: Icon(Icons.settings_remote_rounded), label: 'Control'),
              NavigationDestination(icon: Icon(Icons.location_on_outlined), selectedIcon: Icon(Icons.location_on_rounded), label: 'Location'),
              NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history_rounded), label: 'History'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Settings'),
            ],
          ),
        ),
      ),
    );
  }
}
