import 'package:sqflite/sqflite.dart';

class DatabaseValidator {
  static const String _validationTableName = 'accounts';

  /// Checks if the given database is a valid GnuCash database.
  ///
  /// It does this by querying for the existence of a known GnuCash table.
  /// Returns `true` if the table exists and the query is successful, `false` otherwise.
  static Future<bool> isValidGnuCashDatabase(Database db) async {
    if (!db.isOpen) {
      return false;
    }
    try {
      // Query sqlite_master to see if the 'accounts' table exists.
      // sqlite_master contains metadata about the database schema.
      // We are looking for a row where type is 'table' and name is 'accounts'.
      final List<Map<String, Object?>> result = await db.query(
        'sqlite_master',
        columns: ['name'],
        where: 'type = ? AND name = ?',
        whereArgs: ['table', _validationTableName],
      );
      // If the result list is not empty, it means the 'accounts' table was found.
      return result.isNotEmpty;
    } catch (e) {
      // If any exception occurs during the query (e.g., DB is corrupted,
      // or not a SQLite file at all in a way that openDatabase didn't catch),
      // consider it invalid.
      print('Error validating GnuCash database: $e');
      return false;
    }
  }
}
