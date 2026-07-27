import '../../../core/network/api_client.dart';
import '../../../core/offline/sync_queue.dart';
import '../../../core/utils/formatters.dart';
import 'overview_models.dart';
import 'transaction_models.dart';

/// Result of a write: either it reached the backend, or it was queued offline.
enum WriteResult { synced, queued }

class TransactionInput {
  final String title;
  final String categoryId;
  final double amount;
  final DateTime date;
  final String? description;

  TransactionInput({
    required this.title,
    required this.categoryId,
    required this.amount,
    required this.date,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'categoryId': categoryId,
        'amount': amount,
        'date': Dates.iso(date),
        if (description != null && description!.trim().isNotEmpty) 'description': description,
      };
}

class TransactionRepository {
  final _api = ApiClient.instance;

  Future<TxPage> list(
    TxType type, {
    int page = 1,
    int limit = 30,
    String? search,
    String? categoryId,
    Set<String>? categoryIds,
    DateTime? from,
    DateTime? to,
  }) async {
    final data = await _api.get('/${type.path}', query: {
      'page': page,
      'limit': limit,
      if (search != null && search.isNotEmpty) 'search': search,
      if (categoryId != null) 'categoryId': categoryId,
      if (categoryIds != null && categoryIds.isNotEmpty)
        'categoryIds': categoryIds.join(','),
      if (from != null) 'from': Dates.iso(from),
      if (to != null) 'to': Dates.iso(to),
    });
    return TxPage.fromJson(Map<String, dynamic>.from(data), type);
  }

  Future<FinanceOverview> overview(
    TxType type, {
    required DateTime from,
    required DateTime toInclusive,
    Set<String>? categoryIds,
  }) async {
    final data = await _api.get('/${type.path}/overview', query: {
      'from': Dates.iso(from),
      'to': Dates.iso(toInclusive),
      if (categoryIds != null && categoryIds.isNotEmpty)
        'categoryIds': categoryIds.join(','),
    });
    return FinanceOverview.fromJson(Map<String, dynamic>.from(data), type);
  }

  Future<WriteResult> create(TxType type, TransactionInput input) async {
    try {
      await _api.post('/${type.path}', body: input.toJson());
      return WriteResult.synced;
    } on ApiException catch (e) {
      if (_isOffline(e)) {
        await SyncQueue.instance.enqueue(
          entity: type.path,
          op: 'create',
          payload: input.toJson(),
          title: input.title,
        );
        return WriteResult.queued;
      }
      rethrow;
    }
  }

  Future<WriteResult> update(TxType type, String id, TransactionInput input) async {
    try {
      await _api.patch('/${type.path}/$id', body: input.toJson());
      return WriteResult.synced;
    } on ApiException catch (e) {
      if (_isOffline(e)) {
        await SyncQueue.instance.enqueue(
          entity: type.path,
          op: 'update',
          targetId: id,
          payload: input.toJson(),
          title: input.title,
        );
        return WriteResult.queued;
      }
      rethrow;
    }
  }

  Future<WriteResult> remove(TxType type, String id) async {
    try {
      await _api.delete('/${type.path}/$id');
      return WriteResult.synced;
    } on ApiException catch (e) {
      if (_isOffline(e)) {
        await SyncQueue.instance.enqueue(entity: type.path, op: 'delete', targetId: id);
        return WriteResult.queued;
      }
      rethrow;
    }
  }

  /// A null status code means the request never reached the server → offline.
  bool _isOffline(ApiException e) => e.statusCode == null;
}
