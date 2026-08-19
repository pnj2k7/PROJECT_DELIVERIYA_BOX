import 'package:shared_preferences/shared_preferences.dart';

/// Non-web fallback. Mobile/desktop only ever run one instance of the
/// app at a time, so plain shared_preferences is fine here.
class TabStorage {
  static Future<String?> get(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Future<void> set(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  static Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
