import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'session.dart';

import 'role_select_screen.dart';
import 'sender/sender_dashboard_screen.dart';
import 'sender/sender_navigation.dart';
import 'customer/customer_dashboard_screen.dart';
import 'customer/customer_navigation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // On web, scope the LOGIN ITSELF to this browser tab (not just our
  // own session data — Firebase Auth has its own separate persistence).
  // Without this, Firebase Auth defaults to sharing one login across
  // every tab of the same browser via localStorage/IndexedDB, so a
  // second tab always mirrors whichever account signed in most
  // recently — making simultaneous sender + customer tabs impossible.
  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
  }

  // Wait for Firebase Auth to finish rehydrating this tab's session
  // before we decide where to route. Skipping this can make
  // `currentUser` briefly read null on a fresh tab even though a
  // session actually exists, causing a flash of the Role Select
  // screen before snapping to the real destination.
  await FirebaseAuth.instance.authStateChanges().first;

  await AppSession.instance.restore();

  runApp(const SmartDeliveryBoxApp());
}

class SmartDeliveryBoxApp extends StatelessWidget {
  const SmartDeliveryBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DELIVERIYA',
      theme: buildAppTheme(),
      home: const SplashRouter(),
    );
  }
}

/// Decides where to land the user on launch, and which role's
/// navigation shell to show (sender = monitor-only, customer = full
/// control) based on the saved session.
class SplashRouter extends StatelessWidget {
  const SplashRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final role = AppSession.instance.role;
    final boxId = AppSession.instance.boxId;

    if (user == null || role == null) {
      return const RoleSelectScreen();
    }

    if (boxId != null) {
      return role == 'sender' ? const SenderNavigation() : const CustomerNavigation();
    }

    return role == 'sender'
        ? const SenderDashboardScreen()
        : const CustomerDashboardScreen();
  }
}
