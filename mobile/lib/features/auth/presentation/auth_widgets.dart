import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

/// Atmospheric background shared by login and registration. It keeps the
/// reference's deep, premium appearance in dark mode while using a quiet
/// lavender canvas in light mode.
class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.isDark
        ? const [Color(0xFF050816), Color(0xFF080D24), Color(0xFF0B1120)]
        : const [Color(0xFFF8F7FF), Color(0xFFEFEEFF), Color(0xFFF7F8FC)];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -100,
            right: -90,
            child: _AuthGlow(
              size: 260,
              color: AppColors.primaryBright.withValues(
                alpha: context.isDark ? 0.13 : 0.10,
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: -130,
            child: _AuthGlow(
              size: 300,
              color: AppColors.accent.withValues(
                alpha: context.isDark ? 0.10 : 0.07,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _AuthGlow extends StatelessWidget {
  const _AuthGlow({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, Colors.transparent]),
    ),
  );
}

class AuthFeatureData {
  const AuthFeatureData({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;
}

class AuthFeatureStrip extends StatelessWidget {
  const AuthFeatureStrip({super.key, required this.features});
  final List<AuthFeatureData> features;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < features.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _AuthFeature(data: features[i])),
        ],
      ],
    );
  }
}

class _AuthFeature extends StatelessWidget {
  const _AuthFeature({required this.data});
  final AuthFeatureData data;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(
            alpha: context.isDark ? 0.11 : 0.07,
          ),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: AppColors.primaryBright.withValues(
              alpha: context.isDark ? 0.44 : 0.25,
            ),
          ),
          boxShadow: [
            if (context.isDark)
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.14),
                blurRadius: 12,
              ),
          ],
        ),
        child: Icon(data.icon, color: AppColors.primaryBright, size: 20),
      ),
      const SizedBox(height: 7),
      Text(
        data.title,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 3),
      Text(
        data.body,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: context.muted, fontSize: 9.5, height: 1.25),
      ),
    ],
  );
}

class AuthPanel extends StatelessWidget {
  const AuthPanel({super.key, required this.child, required this.icon});
  final Widget child;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.topCenter,
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 42, 20, 20),
        decoration: BoxDecoration(
          color: context.isDark
              ? const Color(0xFF11162F).withValues(alpha: 0.94)
              : Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppColors.primaryBright.withValues(
              alpha: context.isDark ? 0.34 : 0.18,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: context.isDark
                  ? Colors.black.withValues(alpha: 0.30)
                  : AppColors.primary.withValues(alpha: 0.10),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: child,
      ),
      Positioned(
        top: -23,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            shape: BoxShape.circle,
            border: Border.all(
              color: context.isDark
                  ? const Color(0xFF302567)
                  : const Color(0xFFE7E3FF),
              width: 5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.42),
                blurRadius: 16,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    ],
  );
}

class AuthSecurityBanner extends StatelessWidget {
  const AuthSecurityBanner({
    super.key,
    required this.title,
    required this.body,
  });
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: context.isDark ? 0.12 : 0.055),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: AppColors.primaryBright.withValues(
          alpha: context.isDark ? 0.15 : 0.08,
        ),
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 10,
              ),
            ],
          ),
          child: const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: TextStyle(
                  color: context.muted,
                  fontSize: 10.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.auto_awesome_rounded,
          color: AppColors.accent.withValues(alpha: 0.75),
          size: 20,
        ),
      ],
    ),
  );
}

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
    hintStyle: TextStyle(
      color: context.muted.withValues(alpha: 0.8),
      fontSize: 14.5,
    ),
    prefixIcon: Padding(
      padding: const EdgeInsets.only(left: 14, right: 10),
      child: Icon(
        icon,
        color: AppColors.primary.withValues(alpha: 0.75),
        size: 20,
      ),
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
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
    ),
  );
}

/// A high-quality authentication method selector used before showing a form.
/// Keeping the choices separate makes the first screen calm and easy to scan.
class AuthMethodButton extends StatelessWidget {
  const AuthMethodButton({
    super.key,
    required this.leading,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.loading = false,
    this.emphasized = false,
  });

  final Widget leading;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;
  final bool loading;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final border = emphasized
        ? AppColors.primaryBright.withValues(alpha: 0.55)
        : context.isDark
        ? Colors.white.withValues(alpha: 0.75)
        : context.borderColor;
    final foreground = emphasized ? Colors.white : const Color(0xFF17203A);
    final secondary = emphasized ? Colors.white70 : const Color(0xFF64748B);

    return Material(
      color: emphasized
          ? Colors.transparent
          : context.isDark
          ? const Color(0xFFF8FAFC)
          : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border, width: emphasized ? 1.35 : 1),
            gradient: emphasized ? AppColors.heroGradient : null,
            boxShadow: emphasized
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.30),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: emphasized
                      ? Colors.white.withValues(alpha: 0.18)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : leading,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: secondary,
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_rounded,
                size: 19,
                color: emphasized ? Colors.white : const Color(0xFF64748B),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthMethodDivider extends StatelessWidget {
  const AuthMethodDivider({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Divider(color: context.borderColor)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          label,
          style: TextStyle(color: context.muted, fontSize: 12),
        ),
      ),
      Expanded(child: Divider(color: context.borderColor)),
    ],
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
      width: double.infinity,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxHeroWidth),
          child: SizedBox(
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, c) => Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: c.maxWidth * 0.54,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: left,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: const AuthHeroImage(
                        alignment: Alignment.centerRight,
                      ),
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
      errorBuilder: (_, _, _) => Image.asset(
        _english,
        fit: BoxFit.contain,
        alignment: alignment,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}

/// Gradient primary button with a trailing circular arrow.
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onTap,
  });

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
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: loading
            ? const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
              )
            : Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Positioned(
                    right: 8,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Full-width "Continue with Google" button (visual — shows a "coming soon" hint).
