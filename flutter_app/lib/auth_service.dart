import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

/// Wraps Firebase Authentication. People type a plain "username" in
/// the UI; internally we turn it into a fake email address because
/// Firebase Auth's email/password sign-in requires an email format.
///
/// IMPORTANT: the email is scoped by ROLE as well as username, so
/// the same username can have a completely separate sender account
/// and customer account. This is what stops a sender from logging
/// straight into the customer app (and vice versa) without ever
/// registering there.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _auth = FirebaseAuth.instance;

  String _pseudoEmail(String username, String role) =>
      '${username.trim().toLowerCase()}+$role@smartpetti.local';

  User? get currentUser => _auth.currentUser;

  Future<User> register(
    String username,
    String password,
    String role, {
    required String firstName,
    required String lastName,
    required String company,
    required String phone,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: _pseudoEmail(username, role),
      password: password,
    );

    await FirebaseDatabase.instance.ref('users/${cred.user!.uid}').set({
      'username': username,
      'role': role,
      'firstName': firstName,
      'lastName': lastName,
      'company': company,
      'phone': phone,
      'createdAt': ServerValue.timestamp,
    });

    return cred.user!;
  }

  Future<User> login(String username, String password, String role) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: _pseudoEmail(username, role),
      password: password,
    );

    // Belt-and-braces: even if the stored role in the DB was ever
    // edited out of band, refuse to let the session proceed if it
    // doesn't match the section the person logged in from.
    final profile = await fetchProfile(cred.user!.uid);
    if (profile != null && profile['role'] != role) {
      await _auth.signOut();
      throw FirebaseAuthException(
        code: 'role-mismatch',
        message:
            'This account is registered as a ${profile['role']} account.',
      );
    }

    return cred.user!;
  }

  Future<Map<String, dynamic>?> fetchProfile(String uid) async {
    final snap = await FirebaseDatabase.instance.ref('users/$uid').get();
    if (!snap.exists) return null;
    return Map<String, dynamic>.from(snap.value as Map);
  }

  Future<void> signOut() => _auth.signOut();
}
