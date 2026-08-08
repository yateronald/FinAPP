import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Shared form design system.
///
/// Every "create / edit" sheet in the app is built from these pieces so the
/// loan, expense and income forms are the same screen wearing a different
/// colour: a tall rounded sheet, a large title with a decorative glyph, a
/// stack of white cards each carrying an icon tile, and a sticky gradient CTA.
///
/// Only [accent] changes between them — indigo for loans, red for expenses,
/// green for income.
class FormKit {
  FormKit._();

  static const double cardRadius = 20;
  static const double cardGap = 10;
  static const double iconTile = 52;
}

// ═══════════════════════════════════════════════════════════ shell

/// The sheet shell: grab bar, back button, completion pill, big title,
/// decorative glyph, scrolling body and a sticky footer action.
class FormSheetShell extends StatelessWidget {
  const FormSheetShell({
    super.key,
    required this.accent,
    required this.title,
    required this.icon,
    required this.formKey,
    required this.children,
    required this.footer,
    this.subtitle,
    this.progress,
    this.onClose,
  });

  final Color accent;
  final String title;
  final String? subtitle;

  /// Drawn inside the decorative glyph at the top right.
  final IconData icon;

  final GlobalKey<FormState> formKey;
  final List<Widget> children;
  final Widget footer;

  /// 0..1 — how much of the form is filled in. Null hides the pill.
  final double? progress;

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDark = context.isDark;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      // Height follows the content up to a ceiling, instead of always taking
      // 93% of the screen — a short form (income, budget) would otherwise end
      // in a band of empty space above the action button.
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.93),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                // A whisper of the accent at the top, fading into the page.
                Color.alphaBlend(
                  accent.withValues(alpha: isDark ? 0.10 : 0.055),
                  context.colors.surface,
                ),
                isDark ? AppColors.darkBg : AppColors.lightBg,
              ],
              stops: const [0, 0.42],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ShellTopBar(
                accent: accent,
                progress: progress,
                onClose: onClose ?? () => Navigator.pop(context),
              ),
              // Flexible + shrinkWrap: takes what the content needs, scrolls
              // only once it would exceed the ceiling above.
              Flexible(
                child: Form(
                  key: formKey,
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
                    children: [
                      _ShellHeader(
                        accent: accent,
                        title: title,
                        subtitle: subtitle,
                        icon: icon,
                      ),
                      const SizedBox(height: 22),
                      ...children,
                    ],
                  ),
                ),
              ),
              _ShellFooter(child: footer),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShellTopBar extends StatelessWidget {
  const _ShellTopBar({
    required this.accent,
    required this.progress,
    required this.onClose,
  });
  final Color accent;
  final double? progress;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Row(
        children: [
          _CircleIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: onClose,
          ),
          Expanded(
            child: Center(
              child: progress == null
                  ? Container(
                      width: 44,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: context.borderColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )
                  : _ProgressPill(accent: accent, value: progress!),
            ),
          ),
          // Balances the back button so the pill stays optically centred.
          const SizedBox(width: 42),
        ],
      ),
    );
  }
}

/// Fills as the required fields get answered — a quiet sense of progress
/// rather than a decorative stripe.
class _ProgressPill extends StatelessWidget {
  const _ProgressPill({required this.accent, required this.value});
  final Color accent;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 5,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedFractionallySizedBox(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          widthFactor: value.clamp(0.06, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: context.colors.surface,
          shape: BoxShape.circle,
          boxShadow: context.isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Icon(icon, size: 17, color: context.colors.onSurface),
      ),
    );
  }
}

class _ShellHeader extends StatelessWidget {
  const _ShellHeader({
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
  final Color accent;
  final String title;
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                  height: 1.12,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: 38,
                height: 5,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 12),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: context.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        FormHeaderGlyph(accent: accent, icon: icon),
      ],
    );
  }
}

/// Decorative mark beside the title: a soft gradient tile holding the form's
/// icon, with a confirmation badge and a couple of sparks around it.
class FormHeaderGlyph extends StatelessWidget {
  const FormHeaderGlyph({super.key, required this.accent, required this.icon});
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 96,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Halo.
          Positioned(
            right: 2,
            top: 6,
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned(
            right: 14,
            top: 16,
            child: Transform.rotate(
              angle: -0.12,
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.alphaBlend(
                        Colors.white.withValues(alpha: 0.28),
                        accent,
                      ),
                      accent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.34),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(icon, size: 30, color: Colors.white),
              ),
            ),
          ),
          // Confirmation badge.
          Positioned(
            right: 6,
            bottom: 8,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.success,
                border: Border.all(color: context.colors.surface, width: 2.5),
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 13,
                color: Colors.white,
              ),
            ),
          ),
          _Spark(right: 4, top: 4, size: 9, color: AppColors.warning),
          _Spark(
            right: 74,
            top: 30,
            size: 7,
            color: accent.withValues(alpha: 0.55),
          ),
          _Spark(
            right: 62,
            top: 8,
            size: 5,
            color: accent.withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }
}

class _Spark extends StatelessWidget {
  const _Spark({
    required this.right,
    required this.top,
    required this.size,
    required this.color,
  });
  final double right, top, size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: right,
      top: top,
      child: Icon(Icons.auto_awesome_rounded, size: size, color: color),
    );
  }
}

/// Sticky action area. Sits above the content with a soft lift so the primary
/// action is always reachable, however long the form gets.
class _ShellFooter extends StatelessWidget {
  const _ShellFooter({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        18,
        12,
        18,
        14 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.darkBg : AppColors.lightBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.30 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ═══════════════════════════════════════════════════════════ cards

/// The base card every field sits in: icon tile on the left, content in the
/// middle, optional trailing affordance.
class FormCard extends StatelessWidget {
  const FormCard({
    super.key,
    required this.icon,
    required this.accent,
    required this.child,
    this.onTap,
    this.trailing,
    this.hasError = false,
    this.focused = false,
    this.errorText,
    this.footer,
  });

  final IconData icon;
  final Color accent;
  final Widget child;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool hasError;
  final bool focused;
  final String? errorText;

  /// Extra content below the row, inside the same card (helper text, chips…).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? AppColors.danger
        : focused
        ? accent.withValues(alpha: 0.55)
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.only(bottom: FormKit.cardGap),
      child: Material(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(FormKit.cardRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FormKit.cardRadius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(FormKit.cardRadius),
              border: Border.all(color: borderColor, width: 1.4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _IconTile(icon: icon, accent: accent, hasError: hasError),
                    const SizedBox(width: 13),
                    Expanded(child: child),
                    if (trailing != null) ...[
                      const SizedBox(width: 6),
                      trailing!,
                    ],
                  ],
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 14,
                        color: AppColors.danger,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          errorText!,
                          style: const TextStyle(
                            fontSize: 11.5,
                            height: 1.35,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (footer != null) ...[const SizedBox(height: 10), footer!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.icon,
    required this.accent,
    required this.hasError,
  });
  final IconData icon;
  final Color accent;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final c = hasError ? AppColors.danger : accent;
    return Container(
      width: FormKit.iconTile,
      height: FormKit.iconTile,
      decoration: BoxDecoration(
        color: c.withValues(alpha: context.isDark ? 0.20 : 0.11),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, size: 24, color: c),
    );
  }
}

/// Small caption above a field value.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.required = false, this.accent});
  final String text;
  final bool required;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
        if (required)
          Padding(
            padding: const EdgeInsets.only(left: 3),
            child: Text(
              '*',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════ text field

/// Text input inside a [FormCard]. Tapping anywhere on the card focuses it, so
/// the chevron in the mock-up is an honest affordance.
class FormTextCard extends StatefulWidget {
  const FormTextCard({
    super.key,
    required this.icon,
    required this.accent,
    required this.label,
    required this.controller,
    this.hint,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.sentences,
    this.maxLines = 1,
    this.maxLength,
    this.required = false,
    this.suffix,
    this.onChanged,
    this.textStyle,
  });

  final IconData icon;
  final Color accent;
  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final int? maxLength;
  final bool required;

  /// Trailing text inside the field, e.g. a currency code.
  final String? suffix;
  final ValueChanged<String>? onChanged;
  final TextStyle? textStyle;

  @override
  State<FormTextCard> createState() => _FormTextCardState();
}

class _FormTextCardState extends State<FormTextCard> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // FormField gives us the validation state so the card itself can react,
    // instead of the default underline error the design does not use.
    return FormField<String>(
      initialValue: widget.controller.text,
      validator: widget.validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      builder: (state) {
        final count = widget.maxLength == null
            ? null
            : '${widget.controller.text.characters.length}/${widget.maxLength}';

        return FormCard(
          icon: widget.icon,
          accent: widget.accent,
          hasError: state.hasError,
          focused: _focus.hasFocus,
          errorText: state.errorText,
          onTap: () => _focus.requestFocus(),
          footer: count == null
              ? null
              : Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    count,
                    style: TextStyle(fontSize: 11, color: context.muted),
                  ),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _FieldLabel(
                widget.label,
                required: widget.required,
                accent: widget.accent,
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focus,
                      keyboardType: widget.keyboardType,
                      inputFormatters: widget.inputFormatters,
                      textCapitalization: widget.textCapitalization,
                      maxLines: widget.maxLines,
                      maxLength: widget.maxLength,
                      cursorColor: widget.accent,
                      style:
                          widget.textStyle ??
                          const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                      decoration: InputDecoration(
                        hintText: widget.hint,
                        hintStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: context.muted,
                        ),
                        isDense: true,
                        filled: false,
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                      ),
                      onChanged: (v) {
                        state.didChange(v);
                        widget.onChanged?.call(v);
                        if (widget.maxLength != null) setState(() {});
                      },
                    ),
                  ),
                  if (widget.suffix != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      widget.suffix!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════ picker card

/// Read-only card that opens something on tap (date picker, category sheet…).
class FormPickerCard extends StatelessWidget {
  const FormPickerCard({
    super.key,
    required this.icon,
    required this.accent,
    required this.label,
    required this.value,
    required this.onTap,
    this.placeholder = false,
    this.required = false,
    this.errorText,
    this.leading,
    this.onClear,
  });

  final IconData icon;
  final Color accent;
  final String label;
  final String value;
  final VoidCallback onTap;

  /// Greys the value out — nothing has been chosen yet.
  final bool placeholder;
  final bool required;
  final String? errorText;

  /// Replaces the icon tile, e.g. with a category's own colour and glyph.
  final Widget? leading;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final row = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _FieldLabel(label, required: required, accent: accent),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16,
            fontWeight: placeholder ? FontWeight.w500 : FontWeight.w700,
            color: placeholder ? context.muted : context.colors.onSurface,
          ),
        ),
      ],
    );

    return FormCard(
      icon: icon,
      accent: accent,
      onTap: onTap,
      hasError: errorText != null,
      errorText: errorText,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onClear != null)
            InkWell(
              onTap: onClear,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: context.muted,
                ),
              ),
            ),
          Icon(
            Icons.chevron_right_rounded,
            size: 22,
            color: context.muted.withValues(alpha: 0.7),
          ),
        ],
      ),
      child: leading == null
          ? row
          : Row(
              children: [
                leading!,
                const SizedBox(width: 10),
                Expanded(child: row),
              ],
            ),
    );
  }
}

/// Compact half-width variant used for the side-by-side date pair.
class FormCompactPicker extends StatelessWidget {
  const FormCompactPicker({
    super.key,
    required this.icon,
    required this.accent,
    required this.label,
    required this.value,
    required this.onTap,
    this.placeholder = false,
    this.onClear,
  });

  final IconData icon;
  final Color accent;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool placeholder;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FormKit.cardGap),
      child: Material(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(FormKit.cardRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FormKit.cardRadius),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Icon(icon, size: 19, color: accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: placeholder
                              ? FontWeight.w500
                              : FontWeight.w700,
                          color: placeholder
                              ? context.muted
                              : context.colors.onSurface,
                        ),
                      ),
                    ),
                    if (onClear != null)
                      InkWell(
                        onTap: onClear,
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: Icon(
                            Icons.close_rounded,
                            size: 15,
                            color: context.muted,
                          ),
                        ),
                      )
                    else
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 19,
                        color: context.muted.withValues(alpha: 0.7),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════ banners

/// Tinted explanatory banner, as under the amount fields in the design.
class FormInfoBanner extends StatelessWidget {
  const FormInfoBanner({
    super.key,
    required this.accent,
    required this.text,
    this.icon = Icons.info_outline_rounded,
  });

  final Color accent;
  final Widget text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FormKit.cardGap),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(13, 12, 14, 12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: context.isDark ? 0.16 : 0.08),
          borderRadius: BorderRadius.circular(FormKit.cardRadius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
              child: Icon(icon, size: 15, color: Colors.white),
            ),
            const SizedBox(width: 11),
            Expanded(child: text),
          ],
        ),
      ),
    );
  }
}

/// Full-width error line shown above the footer action.
class FormErrorLine extends StatelessWidget {
  const FormErrorLine({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FormKit.cardGap),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(
            alpha: context.isDark ? 0.18 : 0.09,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 17,
              color: AppColors.danger,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: AppColors.danger,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════ action

/// The gradient pill CTA. Fades to a flat disabled state while saving.
class FormPrimaryButton extends StatelessWidget {
  const FormPrimaryButton({
    super.key,
    required this.accent,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon = Icons.auto_awesome_rounded,
  });

  final Color accent;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: enabled ? 1 : 0.65,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              accent,
              Color.alphaBlend(
                AppColors.accent.withValues(alpha: 0.45),
                accent,
              ),
            ],
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.36),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(28),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 19, color: Colors.white),
                        const SizedBox(width: 10),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
