import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _gnucashFilePathKey = 'gnucash_file_path';

  Future<void> setGnuCashFilePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_gnucashFilePathKey, path);
  }

  Future<String?> getGnuCashFilePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_gnucashFilePathKey);
  }

  Future<void> clearGnuCashFilePath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_gnucashFilePathKey);
  }
}
