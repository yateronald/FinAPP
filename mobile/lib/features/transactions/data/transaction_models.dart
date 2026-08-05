import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';

enum TxType { income, expense }

extension TxTypeX on TxType {
  bool get isIncome => this == TxType.income;
  String get path => this == TxType.income ? 'income' : 'expenses';
  String get label => this == TxType.income ? 'Revenu' : 'Dépense';
  /// Matching category type ('INCOME' | 'EXPENSE').
  String get categoryType => this == TxType.income ? 'INCOME' : 'EXPENSE';
}

class Transaction {
  final String id;
  final TxType type;
  final String title;
  final double amount;
  final DateTime date;
  final String? description;
  final String categoryId;
  final String categoryName;
  final String? categoryIcon;
  final Color categoryColor;

  /// Set when this expense repays a loan. Always null for income.
  final String? loanId;

  Transaction({
    required this.id,
    required this.type,
    required this.title,
    required this.amount,
    required this.date,
    required this.description,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
    this.loanId,
  });

  factory Transaction.fromJson(Map<String, dynamic> j, TxType type) {
    final cat = (j['category'] ?? {}) as Map;
    return Transaction(
      id: j['id'] ?? '',
      type: type,
      title: j['title'] ?? '',
      amount: asDouble(j['amount']),
      date: DateTime.tryParse(j['date'] ?? '')?.toLocal() ?? DateTime.now(),
      description: j['description'],
      categoryId: j['categoryId'] ?? cat['id'] ?? '',
      categoryName: cat['name'] ?? '',
      categoryIcon: cat['icon'],
      categoryColor: AppColors.hexToColor(
        cat['color'],
        type == TxType.income ? AppColors.success : AppColors.danger,
      ),
      loanId: type == TxType.income ? null : j['loanId'] as String?,
    );
  }
}

class TxPage {
  final List<Transaction> items;
  final int total;
  final int page;
  final int totalPages;
  final double totalAmount;

  TxPage({
    required this.items,
    required this.total,
    required this.page,
    required this.totalPages,
    required this.totalAmount,
  });

  factory TxPage.fromJson(Map<String, dynamic> j, TxType type) => TxPage(
        items: ((j['items'] ?? []) as List)
            .map((e) => Transaction.fromJson(Map<String, dynamic>.from(e), type))
            .toList(),
        total: j['total'] ?? 0,
        page: j['page'] ?? 1,
        totalPages: j['totalPages'] ?? 1,
        totalAmount: asDouble(j['totalAmount']),
      );
}
