import 'package:flutter_test/flutter_test.dart';
import 'package:gnucash_helper_flutter/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PreferencesService', () {
    late PreferencesService preferencesService;
    const String testPath = '/path/to/gnucash.gnucash';

    setUp(() {
      // Set mock initial values for SharedPreferences
      SharedPreferences.setMockInitialValues({});
      preferencesService = PreferencesService();
    });

    test('setGnuCashFilePath stores the path correctly', () async {
      await preferencesService.setGnuCashFilePath(testPath);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('gnucash_file_path'), testPath);
    });

    test('getGnuCashFilePath retrieves the stored path', () async {
      // First, set a path
      await preferencesService.setGnuCashFilePath(testPath);
      // Then, retrieve it
      final retrievedPath = await preferencesService.getGnuCashFilePath();
      expect(retrievedPath, testPath);
    });

    test('getGnuCashFilePath returns null if no path is stored', () async {
      final retrievedPath = await preferencesService.getGnuCashFilePath();
      expect(retrievedPath, isNull);
    });

    test('clearGnuCashFilePath removes the stored path', () async {
      // First, set a path
      await preferencesService.setGnuCashFilePath(testPath);
      // Then, clear it
      await preferencesService.clearGnuCashFilePath();
      // Verify it's removed
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('gnucash_file_path'), isNull);
      // Also verify via the service method
      final retrievedPath = await preferencesService.getGnuCashFilePath();
      expect(retrievedPath, isNull);
    });
  });
}
