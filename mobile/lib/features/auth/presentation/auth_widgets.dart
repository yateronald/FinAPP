import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

/// Fynexa emblem + "Fynexa" wordmark.
class AuthBrand extends StatelessWidget {
  final double logoSize;
  final bool showText;
  const AuthBrand({super.key, this.logoSize = 44, this.showText = true});

  @override
  Widget build(BuildContext context) {
    final mark = Image.asset(
      'img/logo_mark.png',
      width: logoSize,
      height: logoSize,
      filterQuality: FilterQuality.high,
    );
    if (!showText) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: logoSize * 0.2),
        Text(
          'Fynexa',
          style: TextStyle(
            fontSize: logoSize * 0.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: context.colors.onSurface,
          ),
        ),
      ],
    );
  }
}

/// Styled input decoration matching the auth mockups (white field, soft border,
/// tinted prefix icon).
InputDecoration authDecoration(
  BuildContext context, {
  required String hint,
  required IconData icon,
  Widget? suffix,
}) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: context.muted.withValues(alpha: 0.8), fontSize: 14.5),
    prefixIcon: Padding(
      padding: const EdgeInsets.only(left: 14, right: 10),
      child: Icon(icon, color: AppColors.primary.withValues(alpha: 0.75), size: 20),
    ),
    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    suffixIcon: suffix,
    filled: true,
    fillColor: context.colors.surface,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    enabledBorder: border(context.borderColor),
    focusedBorder: border(AppColors.primary, 1.6),
    errorBorder: border(AppColors.danger),
    focusedErrorBorder: border(AppColors.danger, 1.6),
  );
}

/// Field label above an input.
class AuthLabel extends StatelessWidget {
  final String text;
  const AuthLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
      );
}

/// The lavender hero with the phone illustration and the brand/text on the left.
class AuthHero extends StatelessWidget {
  final Widget left;
  final double height;
  const AuthHero({super.key, required this.left, this.height = 320});

  @override
  Widget build(BuildContext context) {
    // On tablets/landscape the hero is capped and centred, otherwise the brand
    // block and the illustration get pushed to opposite screen edges leaving a
    // large empty gap in the middle.
    const maxHeroWidth = 760.0;
    return SizedBox(
      height: height,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxHeroWidth),
          child: LayoutBuilder(
            builder: (context, c) => Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  right: 0,
                  top: -10,
                  bottom: -12,
                  width: c.maxWidth * 0.54,
                  child: const AuthHeroImage(alignment: Alignment.centerRight),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 12, 8),
                  child: left,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The login/register header illustration, chosen by UI language. French uses
/// `french_login_register.png`, English uses `english_login_register.png`;
/// falls back to the English image if the language-specific one is missing.
class AuthHeroImage extends StatelessWidget {
  final Alignment alignment;
  const AuthHeroImage({super.key, this.alignment = Alignment.bottomRight});

  static const _english = 'img/english_login_register.png';
  static const _french = 'img/french_login_register.png';

  @override
  Widget build(BuildContext context) {
    final fr = Localizations.localeOf(context).languageCode == 'fr';
    return Image.asset(
      fr ? _french : _english,
      fit: BoxFit.contain,
      alignment: alignment,
      errorBuilder: (_, __, ___) => Image.asset(
        _english,
        fit: BoxFit.contain,
        alignment: alignment,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}

/// Gradient primary button with a trailing circular arrow.
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const AuthPrimaryButton(
      {super.key, required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8)),
          ],
        ),
        child: loading
            ? const Center(
                child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
              )
            : Stack(
                alignment: Alignment.center,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  Positioned(
                    right: 8,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child:
                          const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Full-width "Continue with Google" button (visual — shows a "coming soon" hint).
