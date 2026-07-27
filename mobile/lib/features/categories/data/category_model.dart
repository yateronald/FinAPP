import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class Category {
  final String id;
  final String name;
  final String type; // INCOME | EXPENSE
  final String? icon;
  final Color color;
  final bool isDefault;
  final bool isArchived;

  Category({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    required this.isDefault,
    required this.isArchived,
  });

  bool get isIncome => type == 'INCOME';

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        type: j['type'] ?? 'EXPENSE',
        icon: j['icon'],
        color: AppColors.hexToColor(
          j['color'],
          j['type'] == 'INCOME' ? AppColors.success : AppColors.danger,
        ),
        isDefault: j['isDefault'] ?? false,
        isArchived: j['isArchived'] ?? false,
      );
}
