import 'package:flutter/material.dart';

import '../session.dart';
import '../location_screen.dart';
import '../history_screen.dart';
import '../settings_screen.dart';
import '../widgets/new_tab_button.dart';
import 'sender_dashboard_screen.dart';
import 'sender_monitor_screen.dart';

/// Sender's app shell — Monitor + Location + History + Settings.
/// Still no Control tab: senders never get normal door/fan control,
/// only the Emergency Open action inside Monitor.
class SenderNavigation extends StatefulWidget {
  const SenderNavigation({super.key});

  @override
  State<SenderNavigation> createState() => _SenderNavigationState();
}

class _SenderNavigationState extends State<SenderNavigation> {
  int currentIndex = 0;

  final List<Widget> screens = const [
    SenderMonitorScreen(),
    LocationScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  // Returns to the sender's portfolio without signing out or losing
  // any box data — the box stays exactly as it is, you can always
  // tap back into it from the portfolio list.
  void _backToPortfolio() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SenderDashboardScreen()),
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
          tooltip: 'Back to portfolio',
          onPressed: _backToPortfolio,
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
              NavigationDestination(icon: Icon(Icons.monitor_heart_outlined), selectedIcon: Icon(Icons.monitor_heart_rounded), label: 'Monitor'),
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
