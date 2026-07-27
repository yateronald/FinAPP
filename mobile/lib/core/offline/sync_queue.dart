import 'dart:convert';
import 'dart:math';
import 'local_db.dart';

/// A queued write waiting to be replayed against the backend.
class PendingOp {
  final String id;
  final String entity; // 'income' | 'expenses'
  final String op; // 'create' | 'update' | 'delete'
  final String? targetId;
  final Map<String, dynamic>? payload;
  final String title;
  final int createdAt;

  PendingOp({
    required this.id,
    required this.entity,
    required this.op,
    required this.targetId,
    required this.payload,
    required this.title,
    required this.createdAt,
  });

  factory PendingOp.fromRow(Map<String, dynamic> r) => PendingOp(
        id: r['id'] as String,
        entity: r['entity'] as String,
        op: r['op'] as String,
        targetId: r['target_id'] as String?,
        payload: r['payload'] != null
            ? Map<String, dynamic>.from(jsonDecode(r['payload'] as String))
            : null,
        title: (r['title'] as String?) ?? '',
        createdAt: r['created_at'] as int,
      );
}

class SyncQueue {
  SyncQueue._();
  static final SyncQueue instance = SyncQueue._();

  final _rand = Random();

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_rand.nextInt(1 << 32)}';

  Future<void> enqueue({
    required String entity,
    required String op,
    String? targetId,
    Map<String, dynamic>? payload,
    String title = '',
  }) async {
    final db = await LocalDb.instance.database;
    await db.insert('pending_ops', {
      'id': _newId(),
      'entity': entity,
      'op': op,
      'target_id': targetId,
      'payload': payload == null ? null : jsonEncode(payload),
      'title': title,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<PendingOp>> pending() async {
    final db = await LocalDb.instance.database;
    final rows = await db.query('pending_ops', orderBy: 'created_at ASC');
    return rows.map(PendingOp.fromRow).toList();
  }

  Future<int> count() async {
    final db = await LocalDb.instance.database;
    final r = await db.rawQuery('SELECT COUNT(*) c FROM pending_ops');
    return (r.first['c'] as int?) ?? 0;
  }

  Future<void> remove(String id) async {
    final db = await LocalDb.instance.database;
    await db.delete('pending_ops', where: 'id = ?', whereArgs: [id]);
  }
}
