import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

/// Boxed digit display over a single hidden field.
///
/// One real input, not one per box: that is what keeps the OS autofill of
/// e-mailed codes working — separate per-digit TextFields break it, and the
/// user then has to type a code their phone was offering to fill.
class OtpCodeField extends StatelessWidget {
  const OtpCodeField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onCompleted,
    this.length = 6,
    this.hasError = false,
    this.enabled = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onCompleted;
  final int length;
  final bool hasError;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              autofillHints: const [AutofillHints.oneTimeCode],
              keyboardType: TextInputType.number,
              maxLength: length,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (v) {
                onChanged(v);
                if (v.length == length) onCompleted();
              },
              decoration: const InputDecoration(counterText: ''),
            ),
          ),
        ),
        GestureDetector(
          // Dismissing the keyboard (back gesture, "done") does NOT clear the
          // focus, so requestFocus on an already-focused node is a no-op and
          // the keyboard never comes back. Ask the platform directly instead.
          onTap: enabled
              ? () {
                  if (focusNode.hasFocus) {
                    SystemChannels.textInput.invokeMethod('TextInput.show');
                  } else {
                    focusNode.requestFocus();
                  }
                }
              : null,
          behavior: HitTestBehavior.opaque,
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final code = value.text;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(length, (i) {
                  final filled = i < code.length;
                  final active = i == code.length && focusNode.hasFocus;
                  final border = hasError
                      ? AppColors.danger
                      : active
                          ? AppColors.primary
                          : filled
                              ? AppColors.primary.withValues(alpha: 0.45)
                              : context.borderColor;
                  return Padding(
                    padding: EdgeInsets.only(right: i == length - 1 ? 0 : 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 46,
                      height: 58,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color:
                            enabled ? context.colors.surface : context.surfaceAlt,
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: border, width: active ? 1.8 : 1.3),
                      ),
                      child: Text(
                        filled ? code[i] : '',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: hasError
                              ? AppColors.danger
                              : context.colors.onSurface,
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }
}
