import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../data/currency_models.dart';

/// Talks to our own API, never to the rate provider directly.
///
/// The phone has no business calling a third-party feed: it would fan one user
/// action out into thousands of outbound requests, put an unaudited response
/// straight into the UI, and make every device's behaviour depend on a service
/// with no SLA. The server validates and caches; the app just reads.
class CurrencyRepository {
  final _api = ApiClient.instance;

  Future<List<CurrencyInfo>> list({String? search}) async {
    final data = await _api.get('/currency/list', query: {
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return ((data as List?) ?? [])
        .map((e) => CurrencyInfo.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<FxStatus> status() async {
    final data = await _api.get('/currency/status');
    return FxStatus.fromJson(Map<String, dynamic>.from(data));
  }

  Future<Conversion> convert({
    required double amount,
    required String from,
    required String to,
  }) async {
    final data = await _api.get('/currency/convert', query: {
      'amount': amount.toString(),
      'from': from,
      'to': to,
    });
    return Conversion.fromJson(Map<String, dynamic>.from(data));
  }

  Future<BaseCurrencyPreview> previewBaseChange(String currency) async {
    final data =
        await _api.get('/currency/base/preview', query: {'currency': currency});
    return BaseCurrencyPreview.fromJson(Map<String, dynamic>.from(data));
  }

  Future<Map<String, dynamic>> changeBase(String currency) async {
    final data = await _api.post('/currency/base', body: {'currency': currency});
    return Map<String, dynamic>.from(data);
  }
}

final currencyRepositoryProvider = Provider((_) => CurrencyRepository());

/// The full catalogue. Cached for the session — it is static data and 160 rows.
final currenciesProvider = FutureProvider<List<CurrencyInfo>>((ref) async {
  try {
    return await ref.watch(currencyRepositoryProvider).list();
  } catch (_) {
    // A picker that cannot reach the server still has to offer something, or
    // sign-up would be blocked by an unrelated outage.
    return _fallbackCurrencies;
  }
});

/// Rate freshness. autoDispose so a screen reopened after an outage re-checks.
final fxStatusProvider = FutureProvider.autoDispose<FxStatus>((ref) async {
  try {
    return await ref.watch(currencyRepositoryProvider).status();
  } catch (_) {
    // Never surface a failure here as an error state: the app works fine
    // without conversion, it just stops promising it.
    return FxStatus.unknown;
  }
});

/// A minimal offline catalogue.
///
/// Only the currencies most likely to be someone's base, so a user can finish
/// signing up while the network is flaky. The full list arrives on the next
/// successful load.
const _fallbackCurrencies = <CurrencyInfo>[
  CurrencyInfo(code: 'XOF', name: 'CFA Franc BCEAO', decimals: 0, symbol: 'FCFA'),
  CurrencyInfo(code: 'XAF', name: 'CFA Franc BEAC', decimals: 0, symbol: 'FCFA'),
  CurrencyInfo(code: 'EUR', name: 'Euro', symbol: '€'),
  CurrencyInfo(code: 'USD', name: 'United States Dollar', symbol: '\$'),
  CurrencyInfo(code: 'GBP', name: 'British Pound Sterling', symbol: '£'),
  CurrencyInfo(code: 'NGN', name: 'Nigerian Naira', symbol: '₦'),
  CurrencyInfo(code: 'GHS', name: 'Ghanaian Cedi', symbol: '₵'),
  CurrencyInfo(code: 'MAD', name: 'Moroccan Dirham', symbol: 'DH'),
  CurrencyInfo(code: 'CAD', name: 'Canadian Dollar', symbol: 'CA\$'),
  CurrencyInfo(code: 'CHF', name: 'Swiss Franc', symbol: 'CHF'),
];
