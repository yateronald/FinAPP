import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../data/currency_models.dart';
import '../providers/currency_provider.dart';
import 'currency_picker_sheet.dart';

/// Changes the account's base currency, converting everything already recorded.
///
/// This is the one destructive action in the currency feature, so it is shown
/// before it is done: the rate, how many records move, a worked example, and an
/// explicit statement that it is not exactly reversible. Confirmation is only
/// possible after the preview has loaded — the user should never be able to
/// agree to a conversion whose size they have not been shown.
///
/// Resolves true when the change was applied.
Future<bool?> showChangeBaseCurrencyDialog(
  BuildContext context, {
  required String current,
}) async {
  final target = await showCurrencyPicker(
    context,
    selected: current,
    convertibleOnly: true,
    title: context.t.currencyChangeTitle,
  );
  if (target == null || target == current || !context.mounted) return null;

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ConfirmDialog(from: current, to: target),
  );
}

class _ConfirmDialog extends ConsumerStatefulWidget {
  const _ConfirmDialog({required this.from, required this.to});
  final String from;
  final String to;

  @override
  ConsumerState<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends ConsumerState<_ConfirmDialog> {
  BaseCurrencyPreview? _preview;
  String? _error;
  bool _working = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p =
          await ref.read(currencyRepositoryProvider).previewBaseChange(widget.to);
      if (mounted) setState(() => _preview = p);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = context.t.genericError);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _apply() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final res =
          await ref.read(currencyRepositoryProvider).changeBase(widget.to);
      if (!mounted) return;
      final rows = (res['rowsConverted'] as num?)?.toInt() ?? 0;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.t.currencyChangeDone(rows))));
    } on ApiException catch (e) {
      // The server changes nothing when rates are unavailable, so the account
      // is still consistent — say what happened and leave the dialog open.
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = context.t.genericError);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final p = _preview;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(t.currencyChangeTitle,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (p == null && _error == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (p != null) ...[
              Text(t.currencyChangeBody(p.from, p.to, p.affectedRows),
                  style: const TextStyle(fontSize: 13.5, height: 1.45)),
              const SizedBox(height: 10),
              Text(t.currencyRateLine(p.rate.toStringAsFixed(6)),
                  style: TextStyle(fontSize: 12, color: context.muted)),
              if (p.sampleBefore != null && p.sampleAfter != null) ...[
                const SizedBox(height: 6),
                Text(
                  t.currencyChangeExample(
                    Money.format(p.sampleBefore!, p.from),
                    Money.format(p.sampleAfter!, p.to),
                  ),
                  style: TextStyle(fontSize: 12, color: context.muted),
                ),
              ],
              const SizedBox(height: 14),
              _Warning(text: t.currencyChangeIrreversible),
              // Rounding compounds, so someone who has done this before gets a
              // stronger warning than someone doing it for the first time.
              if (p.previousChanges > 0) ...[
                const SizedBox(height: 8),
                _Warning(text: t.currencyChangeRepeat(p.previousChanges)),
              ],
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _working ? null : () => Navigator.pop(context, false),
          child: Text(t.cancel),
        ),
        FilledButton(
          // Never confirmable before the preview has loaded: agreeing to a
          // conversion whose size you have not seen is not consent.
          onPressed: _working || p == null ? null : _apply,
          child: _working
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                )
              : Text(t.currencyChangeConfirm),
        ),
      ],
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 12, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
