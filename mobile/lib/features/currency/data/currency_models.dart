/// A currency the app can offer.
class CurrencyInfo {
  final String code;
  final String name;

  /// ISO 4217 minor units — 0 for XOF and JPY, 3 for the Gulf dinars.
  final int decimals;
  final String? symbol;

  /// False when the rate feed does not currently carry this currency. It can
  /// still be chosen; amounts simply will not be converted until rates return.
  final bool convertible;

  const CurrencyInfo({
    required this.code,
    required this.name,
    this.decimals = 2,
    this.symbol,
    this.convertible = true,
  });

  /// What to show beside an amount: the symbol when we have one, else the code.
  String get display => symbol ?? code;

  factory CurrencyInfo.fromJson(Map<String, dynamic> j) => CurrencyInfo(
        code: j['code'] as String? ?? '',
        name: j['name'] as String? ?? '',
        decimals: (j['decimals'] as num?)?.toInt() ?? 2,
        symbol: j['symbol'] as String?,
        convertible: j['convertible'] as bool? ?? true,
      );
}

/// How much the converted figures can be trusted right now.
enum FxQuality {
  /// Rates fresh enough to show without comment.
  live,

  /// Real rates, but old enough that the user should be told.
  stale,

  /// No rates at all. Nothing is being converted.
  unavailable;

  static FxQuality parse(String? v) => switch (v) {
        'live' => FxQuality.live,
        'stale' => FxQuality.stale,
        _ => FxQuality.unavailable,
      };

  bool get isUsable => this != FxQuality.unavailable;
}

/// The state of the rate feed, used to decide whether to caveat a figure.
class FxStatus {
  final FxQuality quality;
  final DateTime? publishedAt;
  final int? ageMinutes;
  final int currencyCount;

  const FxStatus({
    required this.quality,
    this.publishedAt,
    this.ageMinutes,
    this.currencyCount = 0,
  });

  /// Assumed when the status call itself fails — the app carries on and simply
  /// does not promise conversion.
  static const unknown = FxStatus(quality: FxQuality.unavailable);

  factory FxStatus.fromJson(Map<String, dynamic> j) => FxStatus(
        quality: FxQuality.parse(j['quality'] as String?),
        publishedAt: j['publishedAt'] == null
            ? null
            : DateTime.tryParse(j['publishedAt'] as String)?.toLocal(),
        ageMinutes: (j['ageMinutes'] as num?)?.toInt(),
        currencyCount: (j['currencyCount'] as num?)?.toInt() ?? 0,
      );
}

/// The result of converting one amount.
class Conversion {
  final double amount;
  final double rate;
  final FxQuality quality;
  final int? ageMinutes;

  const Conversion({
    required this.amount,
    required this.rate,
    required this.quality,
    this.ageMinutes,
  });

  factory Conversion.fromJson(Map<String, dynamic> j) => Conversion(
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        rate: (j['rate'] as num?)?.toDouble() ?? 1,
        quality: FxQuality.parse(j['quality'] as String?),
        ageMinutes: (j['ageMinutes'] as num?)?.toInt(),
      );
}

/// What changing the base currency would do, shown before it is committed.
class BaseCurrencyPreview {
  final String from;
  final String to;
  final double rate;
  final int affectedRows;
  final double? sampleBefore;
  final double? sampleAfter;

  /// How many times this user has already changed base currency. Each pass
  /// rounds, so repeated changes compound — the warning says so.
  final int previousChanges;

  const BaseCurrencyPreview({
    required this.from,
    required this.to,
    required this.rate,
    required this.affectedRows,
    this.sampleBefore,
    this.sampleAfter,
    this.previousChanges = 0,
  });

  factory BaseCurrencyPreview.fromJson(Map<String, dynamic> j) {
    final sample = j['sample'] as Map<String, dynamic>?;
    return BaseCurrencyPreview(
      from: j['from'] as String? ?? '',
      to: j['to'] as String? ?? '',
      rate: (j['rate'] as num?)?.toDouble() ?? 1,
      affectedRows: (j['affectedRows'] as num?)?.toInt() ?? 0,
      sampleBefore: (sample?['before'] as num?)?.toDouble(),
      sampleAfter: (sample?['after'] as num?)?.toDouble(),
      previousChanges: (j['previousChanges'] as num?)?.toInt() ?? 0,
    );
  }
}
