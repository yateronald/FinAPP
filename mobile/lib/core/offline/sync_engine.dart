import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';
import 'sync_queue.dart';

class _IsOnlineNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void set(bool value) => state = value;
}
final isOnlineProvider = NotifierProvider<_IsOnlineNotifier, bool>(_IsOnlineNotifier.new);

/// Number of writes waiting to be synced.
class _PendingCountNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void set(int value) => state = value;
}
final pendingCountProvider = NotifierProvider<_PendingCountNotifier, int>(_PendingCountNotifier.new);

/// Increments each time a flush drains the queue — screens watch this to refresh.
class _SyncTickNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void set(int value) => state = value;
}
final syncTickProvider = NotifierProvider<_SyncTickNotifier, int>(_SyncTickNotifier.new);

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final engine = SyncEngine(ref);
  ref.onDispose(engine.dispose);
  engine.start();
  return engine;
});

class SyncEngine {
  SyncEngine(this._ref);
  final Ref _ref;
  final _connectivity = Connectivity();
  StreamSubscription? _sub;
  bool _flushing = false;

  Future<void> start() async {
    await _refreshCount();
    final initial = await _connectivity.checkConnectivity();
    _updateOnline(initial);
    _sub = _connectivity.onConnectivityChanged.listen(_updateOnline);
  }

  void _updateOnline(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    _ref.read(isOnlineProvider.notifier).set(online);
    if (online) flush();
  }

  Future<void> _refreshCount() async {
    _ref.read(pendingCountProvider.notifier).set(await SyncQueue.instance.count());
  }

  /// Public hook so UI can refresh the badge after enqueuing an offline write.
  Future<void> refreshCount() => _refreshCount();

  /// Replays every queued op in order. Safe to call repeatedly.
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final ops = await SyncQueue.instance.pending();
      if (ops.isEmpty) return;
      var synced = 0;
      for (final op in ops) {
        try {
          await _replay(op);
          await SyncQueue.instance.remove(op.id);
          synced++;
        } on ApiException catch (e) {
          // 4xx = permanent failure → drop it so the queue never wedges.
          if (e.statusCode != null && e.statusCode! >= 400 && e.statusCode! < 500) {
            await SyncQueue.instance.remove(op.id);
          } else {
            break; // transient — stop and retry on next connectivity event.
          }
        } catch (_) {
          break;
        }
      }
      await _refreshCount();
      if (synced > 0) {
        _ref.read(syncTickProvider.notifier).set(_ref.read(syncTickProvider) + 1);
      }
    } finally {
      _flushing = false;
    }
  }

  Future<void> _replay(PendingOp op) async {
    final api = ApiClient.instance;
    switch (op.op) {
      case 'create':
        await api.post('/${op.entity}', body: op.payload);
        break;
      case 'update':
        await api.patch('/${op.entity}/${op.targetId}', body: op.payload);
        break;
      case 'delete':
        await api.delete('/${op.entity}/${op.targetId}');
        break;
    }
  }

  void dispose() => _sub?.cancel();
}
