import 'package:shared_preferences/shared_preferences.dart';

const _kAdminModeKey = 'adminMode';

class AdminModeStorage {
  const AdminModeStorage();

  Future<bool> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAdminModeKey) ?? false;
  }

  Future<bool?> readNullable() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAdminModeKey);
  }

  Future<void> write(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAdminModeKey, value);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAdminModeKey);
  }
}

const adminModeStorage = AdminModeStorage();
