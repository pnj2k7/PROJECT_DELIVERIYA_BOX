import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/status_chip.dart';
import '../box_service.dart';
import '../auth_service.dart';
import '../session.dart';
import '../role_select_screen.dart';
import 'sender_navigation.dart';

class SenderDashboardScreen extends StatefulWidget {
  const SenderDashboardScreen({super.key});

  @override
  State<SenderDashboardScreen> createState() => _SenderDashboardScreenState();
}

class _SenderDashboardScreenState extends State<SenderDashboardScreen> {
  final _boxService = BoxService.instance;
  StreamSubscription<DatabaseEvent>? _boxesSub;
  StreamSubscription<DatabaseEvent>? _notifSub;

  bool _initialNotifLoadDone = false;

  // boxId -> {name, delivered}
  Map<String, Map<String, dynamic>> boxes = {};
  bool creating = false;

  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _attachBoxesListener();

    final u = uid;
    if (u != null) {
      _notifSub = FirebaseDatabase.instance
          .ref('users/$u/deliveryNotifications')
          .limitToLast(1)
          .onChildAdded
          .listen(_onNotificationAdded);
    }
  }

  // Parses ownedBoxes defensively: older app versions stored an entry
  // as a plain `true` instead of {name, delivered}. A single legacy
  // entry like that must not crash parsing of every other box.
  Map<String, Map<String, dynamic>> _parseOwnedBoxes(Map? raw) {
    final result = <String, Map<String, dynamic>>{};
    raw?.forEach((k, v) {
      if (v is Map) {
        result[k.toString()] = Map<String, dynamic>.from(v);
      } else {
        result[k.toString()] = {'name': k.toString(), 'delivered': false};
      }
    });
    return result;
  }

  void _attachBoxesListener() {
    _boxesSub?.cancel();
    final u = uid;
    if (u == null) return;
    _boxesSub = FirebaseDatabase.instance.ref('users/$u/ownedBoxes').onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      setState(() => boxes = _parseOwnedBoxes(data));
    }, onError: (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load boxes: $e')));
      }
    });
  }

  void _onNotificationAdded(DatabaseEvent event) {
    if (!_initialNotifLoadDone) {
      _initialNotifLoadDone = true;
      return;
    }

    final data = event.snapshot.value as Map?;
    if (data == null || !mounted) return;

    final boxName = data['boxName']?.toString() ?? 'A box';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: const [
            Icon(Icons.celebration_rounded, color: AppColors.success),
            SizedBox(width: 10),
            Text("Delivered"),
          ],
        ),
        content: Text("$boxName has been confirmed delivered by the customer."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _boxesSub?.cancel();
    _notifSub?.cancel();
    super.dispose();
  }

  Future<void> _openCreateBoxDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final contentsCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("New Cargo Consignment"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Box name")),
              const SizedBox(height: 12),
              TextField(controller: descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: "Description")),
              const SizedBox(height: 12),
              TextField(controller: contentsCtrl, decoration: const InputDecoration(labelText: "Contents / cargo type")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentB),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Generate Box"),
          ),
        ],
      ),
    );

    if (confirmed != true || uid == null) return;

    if (nameCtrl.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Box name is required')));
      }
      return;
    }

    setState(() => creating = true);

    try {
      final result = await _boxService.createBox(
        uid!,
        boxName: nameCtrl.text.trim(),
        description: descCtrl.text.trim(),
        contents: contentsCtrl.text.trim(),
      );
      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text("Box Created"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Share these with your customer:", style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              SelectableText("Box ID: ${result['boxId']}", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 6),
              SelectableText("Box Password: ${result['boxPassword']}", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Done")),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text("Box Creation Failed"),
            content: SelectableText(
              "$e",
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  void _openBox(String boxId) async {
    await AppSession.instance.setBox(boxId);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SenderNavigation()));
  }

  void _refresh() => _attachBoxesListener();

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
        title: const Text("Sender"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
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
              const Text("Your Consignments", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text("Manage delivery boxes you own", style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentB,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.all(16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                  ),
                  onPressed: creating ? null : _openCreateBoxDialog,
                  icon: creating
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.add),
                  label: const Text("GENERATE NEW BOX", style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: entries.isEmpty
                    ? const Center(
                        child: Text("No boxes yet — create one above", style: TextStyle(color: AppColors.textSecondary)),
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
                                delivered ? Icons.check_circle_rounded : Icons.inventory_2_rounded,
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
