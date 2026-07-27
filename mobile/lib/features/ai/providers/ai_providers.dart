import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../data/ai_models.dart';

class AiRepository {
  final _api = ApiClient.instance;

  /// Returns (reply, status). Retries transient network failures (e.g. the
  /// connection dropped because the app was backgrounded during a long request)
  /// so the answer still arrives when the user returns to the app.
  Future<(String, ChatStatus)> chat(String message, List<ChatMessage> history) async {
    const maxAttempts = 3;
    for (var attempt = 1; ; attempt++) {
      try {
        final data = await _api.post('/ai/chat', body: {
          'message': message,
          'history': history.map((m) => m.toWire()).toList(),
        });
        final map = Map<String, dynamic>.from(data);
        return (map['reply'] as String? ?? '', chatStatusFrom(map['status'] as String?));
      } on ApiException catch (e) {
        // statusCode == null → network-level failure (no HTTP response), the
        // typical result of a dropped socket while backgrounded. Retry it.
        if (e.statusCode == null && attempt < maxAttempts) {
          await Future.delayed(Duration(milliseconds: 800 * attempt));
          continue;
        }
        rethrow;
      }
    }
  }

  Future<ForecastData> forecast(int horizon) async {
    final data = await _api.get('/ai/forecast', query: {'horizon': horizon});
    return ForecastData.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<RealAiInsight>> generateInsights(int month, int year, {String scope = 'GLOBAL'}) async {
    final data = await _api.post('/ai/insights/generate', query: {
      'month': month,
      'year': year,
      'scope': scope,
    });
    final map = Map<String, dynamic>.from(data);
    final rawList = (map['insights'] as List?) ?? [];
    return rawList
        .map((e) => RealAiInsight.fromJson(Map<String, dynamic>.from(e)))
        .take(5)
        .toList();
  }

  Future<List<RealAiInsight>> listInsights() async {
    final data = await _api.get('/ai/insights');
    final rawList = (data as List?) ?? [];
    return rawList
        .map((e) => RealAiInsight.fromJson(Map<String, dynamic>.from(e)))
        .take(5)
        .toList();
  }
}

final aiRepositoryProvider = Provider((_) => AiRepository());

/// Forecast horizon in days (30/60/90).
class _ForecastHorizonNotifier extends Notifier<int> {
  @override
  int build() => 30;
  void set(int value) => state = value;
}
final forecastHorizonProvider = NotifierProvider<_ForecastHorizonNotifier, int>(_ForecastHorizonNotifier.new);

final forecastProvider = FutureProvider.autoDispose<ForecastData>((ref) async {
  final horizon = ref.watch(forecastHorizonProvider);
  return ref.watch(aiRepositoryProvider).forecast(horizon);
});

// ---------------------------------------------------------- AI Insights Controller

class AiInsightsParam {
  final DateTime date;
  final String scope;
  const AiInsightsParam(this.date, {this.scope = 'GLOBAL'});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiInsightsParam &&
          runtimeType == other.runtimeType &&
          date.year == other.date.year &&
          date.month == other.date.month &&
          scope == other.scope;

  @override
  int get hashCode => date.year.hashCode ^ date.month.hashCode ^ scope.hashCode;
}

class AiInsightsController extends Notifier<AsyncValue<List<RealAiInsight>>> {
  AiInsightsController(this._param);
  final AiInsightsParam _param;

  AiRepository get _repo => ref.read(aiRepositoryProvider);

  @override
  AsyncValue<List<RealAiInsight>> build() {
    Future.microtask(generate);
    return const AsyncValue.loading();
  }

  Future<void> generate() async {
    state = const AsyncValue.loading();
    try {
      final list = await _repo.generateInsights(_param.date.month, _param.date.year, scope: _param.scope);
      state = AsyncValue.data(list.take(5).toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final aiInsightsProvider = NotifierProvider.family<AiInsightsController,
    AsyncValue<List<RealAiInsight>>, AiInsightsParam>((param) => AiInsightsController(param));


// ---------------------------------------------------------- Chat state

class ChatController extends Notifier<List<ChatMessage>> {
  @override
  List<ChatMessage> build() => const [];
  AiRepository get _repo => ref.read(aiRepositoryProvider);
  bool _busy = false;
  bool get busy => _busy;

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _busy) return;
    _busy = true;
    final history = List<ChatMessage>.from(state);
    state = [
      ...state,
      ChatMessage(role: 'user', content: trimmed),
      const ChatMessage(role: 'assistant', content: '', status: ChatStatus.sending),
    ];
    try {
      final (reply, status) = await _repo.chat(trimmed, history);
      _replaceLast(ChatMessage(role: 'assistant', content: reply, status: status));
    } on ApiException catch (e) {
      _replaceLast(ChatMessage(role: 'assistant', content: e.message, status: ChatStatus.error));
    } catch (_) {
      _replaceLast(const ChatMessage(
          role: 'assistant',
          content: 'Une erreur est survenue. Réessayez.',
          status: ChatStatus.error));
    } finally {
      _busy = false;
    }
  }

  void _replaceLast(ChatMessage m) {
    final list = List<ChatMessage>.from(state);
    list[list.length - 1] = m;
    state = list;
  }

  void clear() => state = const [];
}

final chatProvider =
    NotifierProvider<ChatController, List<ChatMessage>>(ChatController.new);
