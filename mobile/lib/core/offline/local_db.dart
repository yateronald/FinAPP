import 'package:sqflite/sqflite.dart';

/// Local SQLite database. Holds the offline mutation queue so writes made
/// without a network connection are replayed once connectivity returns.
class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final path = '${await getDatabasesPath()}/fintrack.db';
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE pending_ops (
            id TEXT PRIMARY KEY,
            entity TEXT NOT NULL,     -- 'income' | 'expenses'
            op TEXT NOT NULL,         -- 'create' | 'update' | 'delete'
            target_id TEXT,           -- server id for update/delete
            payload TEXT,             -- JSON body for create/update
            title TEXT,               -- for the pending-list UI
            created_at INTEGER NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }
}
