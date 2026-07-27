import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../providers/finance_filters.dart';

void showPeriodPicker(
  BuildContext context,
  WidgetRef ref, {
  dynamic targetProvider,
}) {
  final provider = targetProvider ?? financePeriodProvider;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PeriodPickerSheet(ref: ref, targetProvider: provider),
  );
}

class _PeriodPickerSheet extends StatefulWidget {
  final WidgetRef ref;
  final dynamic targetProvider;
  const _PeriodPickerSheet({required this.ref, required this.targetProvider});
  @override
  State<_PeriodPickerSheet> createState() => _PeriodPickerSheetState();
}

class _PeriodPickerSheetState extends State<_PeriodPickerSheet> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.ref.read(widget.targetProvider).from.year;
  }

  void _selectMonth(int month) {
    widget.ref.read(widget.targetProvider.notifier).set(
        FinancePeriod.month(DateTime(_year, month)));
    Navigator.pop(context);
  }

  Future<void> _selectCustom() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: now,
      ),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (range != null && mounted) {
      widget.ref.read(widget.targetProvider.notifier).set(
          FinancePeriod.custom(range.start, range.end));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.ref.read(widget.targetProvider);
    final now = DateTime.now();
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                  color: context.borderColor, borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(height: 18),
          Text(context.t.choosePeriod,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          // Year stepper
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => setState(() => _year--),
              ),
              Text('$_year',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: _year < now.year + 1 ? () => setState(() => _year++) : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Month grid
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.1,
            children: List.generate(12, (i) {
              final month = i + 1;
              final selected = current.isMonth &&
                  current.from.year == _year &&
                  current.from.month == month;
              final isFuture =
                  _year > now.year || (_year == now.year && month > now.month);
              return GestureDetector(
                onTap: isFuture ? null : () => _selectMonth(month),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : context.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    Dates.monthShort(month),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? Colors.white
                          : (isFuture ? context.muted.withValues(alpha: 0.4) : null),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _selectCustom,
              icon: const Icon(Icons.date_range_rounded, size: 20),
              label: Text(context.t.customPeriod),
            ),
          ),
        ],
      ),
    );
  }
}
