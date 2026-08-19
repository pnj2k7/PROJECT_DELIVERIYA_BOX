import 'tab_storage.dart';

/// Holds the current user's session state (role, connected box, username).
/// On web this is scoped PER TAB via sessionStorage (see tab_storage.dart)
/// so two browser tabs can each hold a genuinely independent session —
/// e.g. sender logged in on one tab, customer logged in on another, at
/// the same time. On mobile/desktop it behaves as before (one instance
/// of the app anyway, so persisting across restarts is what you want).
class AppSession {
  AppSession._();
  static final AppSession instance = AppSession._();

  String? role;
  String? boxId;
  String? username;

  static const _kRole = 'session_role';
  static const _kBoxId = 'session_box_id';
  static const _kUsername = 'session_username';

  Future<void> restore() async {
    role = await TabStorage.get(_kRole);
    boxId = await TabStorage.get(_kBoxId);
    username = await TabStorage.get(_kUsername);
  }

  Future<void> setRole(String newRole) async {
    role = newRole;
    await TabStorage.set(_kRole, newRole);
  }

  Future<void> setBox(String newBoxId) async {
    boxId = newBoxId;
    await TabStorage.set(_kBoxId, newBoxId);
  }

  Future<void> setUsername(String newUsername) async {
    username = newUsername;
    await TabStorage.set(_kUsername, newUsername);
  }

  Future<void> clearBox() async {
    boxId = null;
    await TabStorage.remove(_kBoxId);
  }

  Future<void> clearAll() async {
    role = null;
    boxId = null;
    username = null;
    await TabStorage.remove(_kRole);
    await TabStorage.remove(_kBoxId);
    await TabStorage.remove(_kUsername);
  }
}
