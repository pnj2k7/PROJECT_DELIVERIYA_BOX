import 'dart:html' as html;

/// Web only. Uses sessionStorage instead of localStorage: sessionStorage
/// is scoped to a single browser TAB — a new tab starts empty, and two
/// tabs never read or overwrite each other's values. This is what makes
/// independently logged-in sender + customer tabs possible at all.
class TabStorage {
  static Future<String?> get(String key) async => html.window.sessionStorage[key];

  static Future<void> set(String key, String value) async {
    html.window.sessionStorage[key] = value;
  }

  static Future<void> remove(String key) async {
    html.window.sessionStorage.remove(key);
  }
}
