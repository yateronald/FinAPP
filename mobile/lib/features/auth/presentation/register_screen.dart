import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/data/countries.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/responsive.dart';
import '../data/user_model.dart';
import '../../currency/presentation/currency_picker_sheet.dart';
import '../../currency/providers/currency_provider.dart';
import '../providers/auth_provider.dart';
import 'auth_widgets.dart';
import 'google_auth_button.dart';
import 'legal_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _obscure2 = true;
  bool _loading = false;
  bool _accepted = false;
  bool _showDetailsForm = false;
  (String, String) _currency = kCurrencies.first;
  (String, String)? _country;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  int _strength(String p) {
    var s = 0;
    if (p.length >= 8) s++;
    if (RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p)) s++;
    if (RegExp(r'[0-9]').hasMatch(p)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) s++;
    return s.clamp(0, 3);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_accepted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t.mustAcceptTerms)));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final lang =
          Localizations.localeOf(context).languageCode.toUpperCase() == 'EN'
          ? 'EN'
          : 'FR';
      final res = await ref
          .read(authRepositoryProvider)
          .register(
            email: _email.text.trim(),
            password: _password.text,
            firstName: _first.text.trim(),
            lastName: _last.text.trim(),
            language: lang,
            country: _country?.$2,
            currency: _currency.$1,
            acceptedTerms: _accepted,
          );
      if (!mounted) return;
      // No verification step when the server has no mail configured — it hands
      // back a session with the account, so go straight in.
      if (res['requiresVerification'] == false && res['user'] != null) {
        ref
            .read(authProvider.notifier)
            .setUser(AppUser.fromJson(Map<String, dynamic>.from(res['user'])));
        context.go('/home');
      } else {
        context.push('/verify', extra: _email.text.trim());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException ? e.message : context.t.genericError,
            ),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickCountry() async {
    final result = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CountrySheet(),
    );
    if (result != null) setState(() => _country = result);
  }

  Future<void> _pickCurrency() async {
    // The full ISO catalogue rather than a shortlist. `convertibleOnly` because
    // this is the account's base currency: everything is expressed in it, so a
    // currency the rate feed cannot price would leave the account unable to
    // convert anything at all.
    final code = await showCurrencyPicker(
      context,
      selected: _currency.$1,
      convertibleOnly: true,
      title: context.t.currencyDefaultTitle,
    );
    if (code == null) return;
    final match = ref
        .read(currenciesProvider)
        .value
        ?.where((c) => c.code == code)
        .firstOrNull;
    setState(() => _currency = (code, match == null ? code : '${match.display} – ${match.name}'));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final compact = context.useCompactLayout;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuthBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(16, 4, 16, compact ? 12 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header + hero share a wider band (like the login screen), while
                // the form below sits in a narrower, comfortable column.
                ResponsiveCenter(
                  maxWidth: 500,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 20, 0),
                        child: Row(
                          children: [
                            Material(
                              color: context.colors.surface.withValues(
                                alpha: 0.88,
                              ),
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => context.canPop()
                                    ? context.pop()
                                    : context.go('/login'),
                                child: const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Icon(
                                    Icons.arrow_back_rounded,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                            const AuthBrand(logoSize: 34),
                            const Spacer(),
                            const SizedBox(width: 40),
                          ],
                        ),
                      ),
                      // Hero: title + subtitle on the left, illustration on the
                      // right. The feature cards used to live in here too, at
                      // 62% width against a 44%-wide image — 106% of the band,
                      // which is why they collided. They now sit below it.
                      // A Row, not a fixed-height Stack: the band is now as tall
                      // as whatever the text needs, so a longer translation or a
                      // bigger font scale can never overflow it, and the two
                      // columns cannot overlap by construction.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 6, 0, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 56,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text.rich(
                                    TextSpan(
                                      style: TextStyle(
                                        fontSize: compact ? 23 : 26,
                                        fontWeight: FontWeight.w800,
                                        height: 1.12,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: t.createTitlePrefix,
                                          style: TextStyle(
                                            color: context.colors.onSurface,
                                          ),
                                        ),
                                        TextSpan(
                                          text: t.createTitleAccent,
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    t.registerSubtitle,
                                    style: TextStyle(
                                      color: context.muted,
                                      fontSize: 12,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 42,
                              child: SizedBox(
                                height: compact ? 118 : 134,
                                child: const AuthHeroImage(
                                  alignment: Alignment.centerRight,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Full width, clear of the illustration: each card now
                      // gets a third of the screen instead of a third of 62%
                      // of it, so the labels stop truncating.
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        // A bounded height, not IntrinsicHeight: inside a
                        // scroll view `stretch` alone resolves to an infinite
                        // constraint, and IntrinsicHeight disagrees with the
                        // laid-out text height by a pixel or two.
                        child: SizedBox(
                          height: compact ? 92 : 96,
                          child: Row(
                            key: const Key('register-feature-cards'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _FeatureCard(
                                icon: Icons.verified_user_rounded,
                                color: AppColors.primary,
                                title: t.regFeat1Title,
                                body: t.regFeat1Body,
                              ),
                              const SizedBox(width: 9),
                              _FeatureCard(
                                icon: Icons.insights_rounded,
                                color: AppColors.success,
                                title: t.regFeat2Title,
                                body: t.regFeat2Body,
                              ),
                              const SizedBox(width: 9),
                              _FeatureCard(
                                icon: Icons.bolt_rounded,
                                color: AppColors.warning,
                                title: t.regFeat3Title,
                                body: t.regFeat3Body,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: compact ? 12 : 16),
                // Form card — narrower, comfortable reading column.
                ResponsiveCenter(
                  maxWidth: 560,
                  child: AuthPanel(
                    key: const Key('register-auth-panel'),
                    icon: Icons.person_add_alt_1_rounded,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!_showDetailsForm) ...[
                            Text(
                              '${t.createTitlePrefix}${t.createTitleAccent}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              t.chooseSignUpMethodBody,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: context.muted,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                            SizedBox(height: compact ? 16 : 20),
                            AuthMethodButton(
                              emphasized: true,
                              leading: const Icon(
                                Icons.mail_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              label: t.signUpWithDetails,
                              subtitle: t.signUpWithDetailsBody,
                              onTap: () =>
                                  setState(() => _showDetailsForm = true),
                            ),
                            SizedBox(height: compact ? 11 : 14),
                            AuthMethodDivider(label: t.orSeparator),
                            SizedBox(height: compact ? 11 : 14),
                            GoogleAuthButton(
                              intent: 'signup',
                              canProceed: () {
                                if (_accepted) return true;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(context.t.mustAcceptTerms),
                                  ),
                                );
                                return false;
                              },
                            ),
                            SizedBox(height: compact ? 12 : 16),
                            AuthSecurityBanner(
                              title: t.authSecurityTitle,
                              body: t.bankGrade,
                            ),
                            SizedBox(height: compact ? 12 : 16),
                            _TermsRow(
                              accepted: _accepted,
                              onChanged: (v) => setState(() => _accepted = v),
                            ),
                            SizedBox(height: compact ? 10 : 12),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  t.haveAccount,
                                  style: TextStyle(color: context.muted),
                                ),
                                TextButton(
                                  onPressed: () => context.canPop()
                                      ? context.pop()
                                      : context.go('/login'),
                                  child: Text(t.signIn),
                                ),
                              ],
                            ),
                          ] else ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                IconButton.filledTonal(
                                  onPressed: _loading
                                      ? null
                                      : () => setState(
                                          () => _showDetailsForm = false,
                                        ),
                                  icon: const Icon(
                                    Icons.arrow_back_rounded,
                                    size: 19,
                                  ),
                                  tooltip: t.backToSignUpOptions,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.signUpWithDetails,
                                        style: const TextStyle(
                                          fontSize: 18.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        t.signUpWithDetailsBody,
                                        style: TextStyle(
                                          color: context.muted,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      AuthLabel(t.firstName),
                                      TextFormField(
                                        controller: _first,
                                        textCapitalization:
                                            TextCapitalization.words,
                                        textInputAction: TextInputAction.next,
                                        autofillHints: const [
                                          AutofillHints.givenName,
                                        ],
                                        decoration: authDecoration(
                                          context,
                                          hint: t.firstNameHint,
                                          icon: Icons.person_outline_rounded,
                                        ),
                                        validator: (v) =>
                                            (v == null || v.trim().isEmpty)
                                            ? t.required
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      AuthLabel(t.lastName),
                                      TextFormField(
                                        controller: _last,
                                        textCapitalization:
                                            TextCapitalization.words,
                                        textInputAction: TextInputAction.next,
                                        autofillHints: const [
                                          AutofillHints.familyName,
                                        ],
                                        decoration: authDecoration(
                                          context,
                                          hint: t.lastNameHint,
                                          icon: Icons.person_outline_rounded,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            AuthLabel(t.emailAddress),
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              decoration: authDecoration(
                                context,
                                hint: t.emailHint,
                                icon: Icons.mail_outline_rounded,
                              ),
                              validator: (v) => (v == null || !v.contains('@'))
                                  ? t.emailInvalid
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            AuthLabel(t.password),
                            TextFormField(
                              controller: _password,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.newPassword],
                              onChanged: (_) => setState(() {}),
                              decoration: authDecoration(
                                context,
                                hint: t.createPasswordHint,
                                icon: Icons.lock_outline_rounded,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: context.muted,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: (v) =>
                                  (v == null || v.length < 8) ? t.pwMin : null,
                            ),
                            if (_password.text.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _StrengthMeter(level: _strength(_password.text)),
                            ],
                            const SizedBox(height: 16),
                            AuthLabel(t.confirmPassword),
                            TextFormField(
                              controller: _confirm,
                              obscureText: _obscure2,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: authDecoration(
                                context,
                                hint: t.confirmPasswordHint,
                                icon: Icons.lock_outline_rounded,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscure2
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: context.muted,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure2 = !_obscure2),
                                ),
                              ),
                              validator: (v) =>
                                  v != _password.text ? t.pwMismatch : null,
                            ),
                            const SizedBox(height: 16),
                            AuthLabel(t.preferredCurrency),
                            _PickerField(
                              icon: Icons.account_balance_wallet_outlined,
                              text: _currency.$2,
                              onTap: _pickCurrency,
                            ),
                            const SizedBox(height: 16),
                            AuthLabel(t.countryOfResidence),
                            _PickerField(
                              icon: Icons.public_rounded,
                              leadingText: _country?.$1,
                              text: _country?.$2 ?? t.selectCountry,
                              muted: _country == null,
                              onTap: _pickCountry,
                            ),
                            const SizedBox(height: 18),
                            _TermsRow(
                              accepted: _accepted,
                              onChanged: (v) => setState(() => _accepted = v),
                            ),
                            const SizedBox(height: 22),
                            AuthPrimaryButton(
                              label: t.createMyAccount,
                              loading: _loading,
                              onTap: _submit,
                            ),
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: _loading
                                  ? null
                                  : () => setState(
                                      () => _showDetailsForm = false,
                                    ),
                              icon: const Icon(
                                Icons.swap_horiz_rounded,
                                size: 18,
                              ),
                              label: Text(t.backToSignUpOptions),
                            ),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  t.haveAccount,
                                  style: TextStyle(color: context.muted),
                                ),
                                TextButton(
                                  onPressed: () => context.canPop()
                                      ? context.pop()
                                      : context.go('/login'),
                                  child: Text(t.signIn),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _FeatureCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              body,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.muted,
                fontSize: 9.5,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StrengthMeter extends StatelessWidget {
  final int level; // 0..3
  const _StrengthMeter({required this.level});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final (label, color) = switch (level) {
      >= 3 => (t.pwStrong, AppColors.success),
      2 => (t.pwMedium, AppColors.warning),
      _ => (t.pwWeak, AppColors.danger),
    };
    return Row(
      children: [
        Icon(Icons.shield_outlined, size: 15, color: context.muted),
        const SizedBox(width: 6),
        Text(
          '${t.pwStrength} ',
          style: TextStyle(color: context.muted, fontSize: 12),
        ),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 10),
        for (var i = 0; i < 3; i++) ...[
          Expanded(
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                color: i < level ? color : context.surfaceAlt,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          if (i < 2) const SizedBox(width: 5),
        ],
      ],
    );
  }
}

class _PickerField extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? leadingText;
  final bool muted;
  final VoidCallback onTap;
  const _PickerField({
    required this.icon,
    required this.text,
    this.leadingText,
    this.muted = false,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: context.borderColor),
        ),
        child: Row(
          children: [
            if (leadingText != null) ...[
              Text(leadingText!, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
            ] else ...[
              Icon(
                icon,
                color: AppColors.primary.withValues(alpha: 0.75),
                size: 20,
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  color: muted ? context.muted : context.colors.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.expand_more_rounded, color: context.muted),
          ],
        ),
      ),
    );
  }
}

class _TermsRow extends StatelessWidget {
  final bool accepted;
  final ValueChanged<bool> onChanged;
  const _TermsRow({required this.accepted, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    const linkStyle = TextStyle(
      color: AppColors.primary,
      fontWeight: FontWeight.w600,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: accepted,
            onChanged: (v) => onChanged(v ?? false),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            activeColor: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.colors.onSurface,
                  height: 1.4,
                ),
                children: [
                  TextSpan(text: t.acceptPrefix),
                  // Tappable: consent is not informed if the text cannot be read.
                  TextSpan(
                    text: t.termsOfUse,
                    style: linkStyle,
                    recognizer: TapGestureRecognizer()
                      ..onTap = () =>
                          showLegalDocument(context, LegalDocument.terms),
                  ),
                  TextSpan(text: t.acceptMiddle),
                  TextSpan(
                    text: t.privacyPolicy,
                    style: linkStyle,
                    recognizer: TapGestureRecognizer()
                      ..onTap = () =>
                          showLegalDocument(context, LegalDocument.privacy),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------- Pickers

class _CountrySheet extends StatefulWidget {
  const _CountrySheet();
  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final results = _query.isEmpty
        ? kCountries
        : kCountries
              .where((c) => c.$2.toLowerCase().contains(_query.toLowerCase()))
              .toList();
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: context.borderColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.countryOfResidence,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  autofocus: true,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: t.search,
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: results.length,
              itemBuilder: (_, i) {
                final c = results[i];
                return ListTile(
                  leading: Text(c.$1, style: const TextStyle(fontSize: 24)),
                  title: Text(
                    c.$2,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () => Navigator.pop(context, c),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

