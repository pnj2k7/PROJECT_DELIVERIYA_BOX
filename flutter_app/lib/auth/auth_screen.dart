import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../auth_service.dart';
import '../session.dart';
import '../sender/sender_dashboard_screen.dart';
import '../customer/customer_dashboard_screen.dart';

/// Shared login/register screen for both senders and customers.
/// Uses Flutter's AutofillGroup so Android/iOS offer to save the
/// password in Google Password Manager / iCloud Keychain automatically.
class AuthScreen extends StatefulWidget {
  final String role;

  const AuthScreen({super.key, required this.role});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool isRegister = false;
  bool loading = false;
  bool rememberMe = true;
  String? error;

  // Scoped per role ('last_username_sender' / 'last_username_customer')
  // so remembering a sender's username never leaks into the customer
  // login form, and vice versa.
  String get _lastUsernameKey => 'last_username_${widget.role}';

  @override
  void initState() {
    super.initState();
    _loadRememberedUsername();
  }

  Future<void> _loadRememberedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_lastUsernameKey);
    if (saved != null && mounted) {
      setState(() => _usernameCtrl.text = saved);
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _companyCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (username.isEmpty || password.length < 6) {
      setState(() => error = "Username required, password min 6 characters");
      return;
    }

    if (isRegister &&
        (_firstNameCtrl.text.trim().isEmpty ||
            _lastNameCtrl.text.trim().isEmpty ||
            _phoneCtrl.text.trim().isEmpty)) {
      setState(() => error = "First name, last name and phone are required");
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      if (isRegister) {
        await AuthService.instance.register(
          username,
          password,
          widget.role,
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          company: _companyCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
        );
      } else {
        await AuthService.instance.login(username, password, widget.role);
      }

      AppSession.instance.username = username;

      final prefs = await SharedPreferences.getInstance();
      if (rememberMe) {
        await prefs.setString(_lastUsernameKey, username);
      } else {
        await prefs.remove(_lastUsernameKey);
      }

      // Tells Android/iOS "the login just succeeded" — this is what
      // triggers the native "Save password?" prompt.
      TextInput.finishAutofillContext();

      if (!mounted) return;

      if (widget.role == 'sender') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SenderDashboardScreen()),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const CustomerDashboardScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() => error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('role-mismatch')) {
      return "That account isn't registered as a ${widget.role}. "
          "Please create a separate ${widget.role} account.";
    }
    if (msg.contains('email-already-in-use')) return "Username already taken";
    if (msg.contains('wrong-password') ||
        msg.contains('user-not-found') ||
        msg.contains('invalid-credential')) {
      return "Incorrect username or password";
    }
    if (msg.contains('weak-password')) {
      return "Password too weak (min 6 characters)";
    }
    return "Something went wrong: $msg";
  }

  @override
  Widget build(BuildContext context) {
    final isSender = widget.role == 'sender';
    final accent = isSender ? AppColors.accentB : AppColors.accentA;

    return Scaffold(
      appBar: AppBar(title: Text(isSender ? "Sender" : "Customer")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSender ? "Sender Login" : "Customer Login",
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  isRegister ? "Create a new account" : "Sign in to continue",
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 26),

                if (isRegister) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _firstNameCtrl,
                          autofillHints: const [AutofillHints.givenName],
                          decoration: const InputDecoration(labelText: "First name"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _lastNameCtrl,
                          autofillHints: const [AutofillHints.familyName],
                          decoration: const InputDecoration(labelText: "Last name"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _companyCtrl,
                    autofillHints: const [AutofillHints.organizationName],
                    decoration: const InputDecoration(labelText: "Company (optional)"),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: const InputDecoration(labelText: "Contact number"),
                  ),
                  const SizedBox(height: 16),
                ],

                TextField(
                  controller: _usernameCtrl,
                  autofillHints: const [AutofillHints.username],
                  decoration: const InputDecoration(labelText: "Username"),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(labelText: "Password"),
                ),

                if (!isRegister) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(
                        value: rememberMe,
                        activeColor: accent,
                        onChanged: (v) => setState(() => rememberMe = v ?? true),
                      ),
                      const Text("Remember me", style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ],

                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: const TextStyle(color: AppColors.danger)),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.all(16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                    ),
                    onPressed: loading ? null : _submit,
                    child: loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            isRegister ? "CREATE ACCOUNT" : "LOGIN",
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: () => setState(() => isRegister = !isRegister),
                  child: Text(
                    isRegister
                        ? "Already have an account? Login"
                        : "New here? Create an account",
                    style: TextStyle(color: accent),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
