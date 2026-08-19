import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/app_theme.dart';
import '../box_service.dart';
import '../auth_service.dart';
import '../session.dart';
import '../role_select_screen.dart';
import 'customer_navigation.dart';

class BoxConnectScreen extends StatefulWidget {
  const BoxConnectScreen({super.key});

  @override
  State<BoxConnectScreen> createState() => _BoxConnectScreenState();
}

class _BoxConnectScreenState extends State<BoxConnectScreen> {
  final _boxIdCtrl = TextEditingController();
  final _boxPasswordCtrl = TextEditingController();

  bool loading = false;
  String? error;

  @override
  void dispose() {
    _boxIdCtrl.dispose();
    _boxPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final boxId = _boxIdCtrl.text.trim().toUpperCase();
    final password = _boxPasswordCtrl.text.trim();

    if (boxId.isEmpty || password.isEmpty) {
      setState(() => error = "Enter both Box ID and Box Password");
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final valid =
          await BoxService.instance.validateBoxCredentials(boxId, password);

      if (!valid) {
        setState(() => error = "Incorrect Box ID or Password");
        return;
      }

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await BoxService.instance.logEvent(boxId, uid, 'customer_connected');
        await BoxService.instance.logCustomerConnection(uid, boxId);
        await BoxService.instance.attachCustomerToBox(boxId, uid);
        await BoxService.instance.lockBoxCredentials(boxId);
      }

      await AppSession.instance.setBox(boxId);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CustomerNavigation()),
      );
    } catch (e) {
      setState(() => error = "Something went wrong: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Customer"),
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
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Connect to Your Box",
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text(
                "Enter the Box ID and Password given by your sender",
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _boxIdCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: "Box ID"),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _boxPasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Box Password"),
              ),
              if (error != null) ...[
                const SizedBox(height: 14),
                Text(error!, style: const TextStyle(color: AppColors.danger)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentA,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.all(16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                  onPressed: loading ? null : _connect,
                  child: loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("CONNECT",
                          style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
