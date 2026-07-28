import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';

// ---------------------------------------------------------------- Chat

class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final ChatStatus status;
  const ChatMessage({required this.role, required this.content, this.status = ChatStatus.ok});

  bool get isUser => role == 'user';

  Map<String, dynamic> toWire() => {'role': role, 'content': content};
}

enum ChatStatus { ok, sending, notConfigured, rateLimited, error }

ChatStatus chatStatusFrom(String? s) => switch (s) {
      'not_configured' => ChatStatus.notConfigured,
      'rate_limited' => ChatStatus.rateLimited,
      'error' => ChatStatus.error,
      _ => ChatStatus.ok,
    };

// ------------------------------------------------------------ Forecast

class ForecastModelInfo {
  final String name, label;
  final int? mae;
  ForecastModelInfo(this.name, this.label, this.mae);
  factory ForecastModelInfo.fromJson(Map<String, dynamic> j) =>
      ForecastModelInfo(j['name'] ?? '', j['label'] ?? '', j['mae']);
}

class ForecastOverview {
  final double projectedIncome, incomeTrend;
  final double projectedExpenses, expenseTrend;
  final double projectedSavings, savingsTrend;
  final double projectedBalance;
  final String balanceDate;
  ForecastOverview.fromJson(Map<String, dynamic> j)
      : projectedIncome = asDouble(j['projectedIncome']),
        incomeTrend = asDouble(j['incomeTrend']),
        projectedExpenses = asDouble(j['projectedExpenses']),
        expenseTrend = asDouble(j['expenseTrend']),
        projectedSavings = asDouble(j['projectedSavings']),
        savingsTrend = asDouble(j['savingsTrend']),
        projectedBalance = asDouble(j['projectedBalance']),
        balanceDate = j['balanceDate'] ?? '';
}

class CashPoint {
  final DateTime date;
  final double? actual, forecast, lower, upper;
  CashPoint(this.date, this.actual, this.forecast, this.lower, this.upper);
  factory CashPoint.fromJson(Map<String, dynamic> j) => CashPoint(
        DateTime.tryParse(j['date'] ?? '') ?? DateTime.now(),
        j['actual'] == null ? null : asDouble(j['actual']),
        j['forecast'] == null ? null : asDouble(j['forecast']),
        j['lower'] == null ? null : asDouble(j['lower']),
        j['upper'] == null ? null : asDouble(j['upper']),
      );
}

class ForecastCategory {
  final String name;
  final Color color;
  final double projected, evolution;
  final int percentage;
  ForecastCategory.fromJson(Map<String, dynamic> j)
      : name = j['name'] ?? '',
        color = AppColors.hexToColor(j['color']),
        projected = asDouble(j['projected']),
        evolution = asDouble(j['evolution']),
        percentage = j['percentage'] ?? 0;
}

class ForecastAlert {
  final String type, title, detail;
  ForecastAlert.fromJson(Map<String, dynamic> j)
      : type = j['type'] ?? 'good',
        title = j['title'] ?? '',
        detail = j['detail'] ?? '';
  bool get isWarning => type == 'warning';
}

class ForecastSuggestion {
  final String text, cta;
  ForecastSuggestion.fromJson(Map<String, dynamic> j)
      : text = j['text'] ?? '',
        cta = j['cta'] ?? '';
}

class ForecastObjective {
  final String name;
  final double current, target;
  final int percentage;
  final String? etaDate;
  ForecastObjective.fromJson(Map<String, dynamic> j)
      : name = j['name'] ?? '',
        current = asDouble(j['current']),
        target = asDouble(j['target']),
        percentage = j['percentage'] ?? 0,
        etaDate = j['etaDate'];
}

/// How much history the forecast is standing on. When [hasEnoughData] is false
/// the backend returns no alerts, suggestions or objectives at all — the UI
/// must show a call to action rather than an empty prediction.
class ForecastDataQuality {
  final bool hasEnoughData;
  final int monthsWithData;
  final int transactions;
  final int monthsRequired;
  final int transactionsRequired;

  /// 'low' | 'medium' | 'high' — how many months the models had to learn from.
  final String confidence;

  const ForecastDataQuality({
    required this.hasEnoughData,
    required this.monthsWithData,
    required this.transactions,
    required this.monthsRequired,
    required this.transactionsRequired,
    required this.confidence,
  });

  int get missingMonths =>
      (monthsRequired - monthsWithData).clamp(0, monthsRequired);
  int get missingTransactions =>
      (transactionsRequired - transactions).clamp(0, transactionsRequired);

  factory ForecastDataQuality.fromJson(Map<String, dynamic> j) {
    int i(dynamic v, [int d = 0]) => (v as num?)?.toInt() ?? d;
    return ForecastDataQuality(
      // Absent field = an older backend that always produced a forecast.
      hasEnoughData: j['hasEnoughData'] as bool? ?? true,
      monthsWithData: i(j['monthsWithData']),
      transactions: i(j['transactions']),
      monthsRequired: i(j['monthsRequired'], 2),
      transactionsRequired: i(j['transactionsRequired'], 5),
      confidence: j['confidence'] as String? ?? 'high',
    );
  }
}

class ForecastData {
  final int horizonDays;
  final ForecastModelInfo incomeModel, expenseModel;
  final ForecastOverview overview;
  final List<CashPoint> cashflow;
  final List<ForecastCategory> byCategory;
  final List<ForecastAlert> alerts;
  final List<ForecastSuggestion> suggestions;
  final List<ForecastObjective> objectives;
  final ForecastDataQuality dataQuality;

  ForecastData({
    required this.horizonDays,
    required this.incomeModel,
    required this.expenseModel,
    required this.overview,
    required this.cashflow,
    required this.byCategory,
    required this.alerts,
    required this.suggestions,
    required this.objectives,
    required this.dataQuality,
  });

  factory ForecastData.fromJson(Map<String, dynamic> j) {
    final models = (j['models'] ?? {}) as Map;
    List<T> mapList<T>(String key, T Function(Map<String, dynamic>) f) =>
        ((j[key] ?? []) as List).map((e) => f(Map<String, dynamic>.from(e))).toList();
    return ForecastData(
      horizonDays: j['horizonDays'] ?? 30,
      incomeModel: ForecastModelInfo.fromJson(Map<String, dynamic>.from(models['income'] ?? {})),
      expenseModel:
          ForecastModelInfo.fromJson(Map<String, dynamic>.from(models['expenses'] ?? {})),
      overview: ForecastOverview.fromJson(Map<String, dynamic>.from(j['overview'] ?? {})),
      cashflow: mapList('cashflow', CashPoint.fromJson),
      byCategory: mapList('byCategory', ForecastCategory.fromJson),
      alerts: mapList('alerts', ForecastAlert.fromJson),
      suggestions: mapList('suggestions', ForecastSuggestion.fromJson),
      objectives: mapList('objectives', ForecastObjective.fromJson),
      dataQuality:
          ForecastDataQuality.fromJson(Map<String, dynamic>.from(j['dataQuality'] ?? {})),
    );
  }
}

// ----------------------------------------------------------- Real AI Insight

class RealAiInsight {
  final String id;
  final String type; // SPENDING_ANALYSIS, ADVICE, UNUSUAL_SPENDING, BUDGET_SUGGESTION, SAVING_RECOMMENDATION, PREDICTION, ALERT
  final String title;
  final String content;
  final String severity; // info, warning, critical
  final bool isRead;

  RealAiInsight({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.severity,
    this.isRead = false,
  });

  factory RealAiInsight.fromJson(Map<String, dynamic> j) => RealAiInsight(
        id: j['id'] ?? '',
        type: j['type'] ?? 'ADVICE',
        title: j['title'] ?? '',
        content: j['content'] ?? '',
        severity: j['severity'] ?? 'info',
        isRead: j['isRead'] ?? false,
      );
}

