import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/status_chip.dart';
import '../auth_service.dart';
import '../session.dart';
import '../role_select_screen.dart';
import 'box_connect_screen.dart';
import 'customer_navigation.dart';

/// Customer's "My Boxes" screen — every box they've ever connected
/// to, past or present. A customer can receive many deliveries over
/// time, so this is a running history, not a single active box.
class CustomerDashboardScreen extends StatefulWidget {
  const CustomerDashboardScreen({super.key});

  @override
  State<CustomerDashboardScreen> createState() => _CustomerDashboardScreenState();
}

class _CustomerDashboardScreenState extends State<CustomerDashboardScreen> {
  StreamSubscription<DatabaseEvent>? _boxesSub;

  // boxId -> {name, delivered}
  Map<String, Map<String, dynamic>> boxes = {};

  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    final u = uid;
    if (u != null) {
      _boxesSub = FirebaseDatabase.instance.ref('users/$u/connectedBoxes').onValue.listen((event) {
        final data = event.snapshot.value as Map?;
        setState(() {
          boxes = {};
          data?.forEach((k, v) {
            if (v is Map) {
              boxes[k.toString()] = Map<String, dynamic>.from(v);
            } else {
              boxes[k.toString()] = {'name': k.toString(), 'delivered': false};
            }
          });
        });
      }, onError: (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load boxes: $e')));
        }
      });
    }
  }

  @override
  void dispose() {
    _boxesSub?.cancel();
    super.dispose();
  }

  void _openBox(String boxId) async {
    await AppSession.instance.setBox(boxId);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CustomerNavigation()));
  }

  void _connectNewBox() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BoxConnectScreen()));
  }

  Future<void> _switchRole() async {
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
    final entries = boxes.entries.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Boxes"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Switch role / sign out',
            onPressed: _switchRole,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Your Deliveries", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text("Every box you've connected to", style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentA,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.all(16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                  ),
                  onPressed: _connectNewBox,
                  icon: const Icon(Icons.add),
                  label: const Text("CONNECT NEW BOX", style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: entries.isEmpty
                    ? const Center(
                        child: Text(
                          "No boxes yet — connect one above",
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final id = entries[index].key;
                          final name = entries[index].value['name']?.toString() ?? id;
                          final delivered = entries[index].value['delivered'] == true;
                          return GlassCard(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                delivered ? Icons.check_circle_rounded : Icons.local_shipping_rounded,
                                color: delivered ? AppColors.success : AppColors.accentB,
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text(id, style: const TextStyle(color: AppColors.textSecondary)),
                              trailing: StatusChip(
                                label: delivered ? "DELIVERED" : "IN TRANSIT",
                                color: delivered ? AppColors.success : AppColors.warning,
                              ),
                              onTap: () => _openBox(id),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
