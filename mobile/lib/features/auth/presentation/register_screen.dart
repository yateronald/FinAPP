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
import '../providers/auth_provider.dart';
import 'auth_widgets.dart';

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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.t.mustAcceptTerms)));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final lang = Localizations.localeOf(context).languageCode.toUpperCase() == 'EN' ? 'EN' : 'FR';
      await ref.read(authRepositoryProvider).register(
            email: _email.text.trim(),
            password: _password.text,
            firstName: _first.text.trim(),
            lastName: _last.text.trim(),
            language: lang,
            country: _country?.$2,
            currency: _currency.$1,
          );
      if (mounted) context.push('/verify', extra: _email.text.trim());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is ApiException ? e.message : context.t.genericError),
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
    final result = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CurrencySheet(selected: _currency.$1),
    );
    if (result != null) setState(() => _currency = result);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      backgroundColor: context.isDark ? context.colors.surface : const Color(0xFFEFEEFB),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header + hero share a wider band (like the login screen), while
              // the form below sits in a narrower, comfortable column.
              ResponsiveCenter(
                maxWidth: 760,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 20, 0),
                child: Row(
                  children: [
                    Material(
                      color: context.colors.surface,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => context.canPop() ? context.pop() : context.go('/login'),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(Icons.arrow_back_rounded, size: 20),
                        ),
                      ),
                    ),
                    const Spacer(),
                    const AuthBrand(logoSize: 34),
                  ],
                ),
              ),
              // Hero: title + subtitle + small feature cards on the left,
              // big illustration on the right (like the mockup).
              SizedBox(
                height: 250,
                child: LayoutBuilder(
                  builder: (context, c) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      right: 0,
                      top: -6,
                      bottom: 0,
                      // Size against the (constrained) container, not the whole
                      // screen — otherwise it overflows on tablets.
                      width: c.maxWidth * 0.44,
                      child: const AuthHeroImage(alignment: Alignment.centerRight),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 0, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            // Constrained to the hero band, not the whole screen,
                            // so the text never runs under the illustration.
                            width: c.maxWidth * 0.56,
                            child: Text.rich(
                              TextSpan(
                                style: const TextStyle(
                                    fontSize: 30, fontWeight: FontWeight.w800, height: 1.12),
                                children: [
                                  TextSpan(
                                      text: t.createTitlePrefix,
                                      style: TextStyle(color: context.colors.onSurface)),
                                  TextSpan(
                                      text: t.createTitleAccent,
                                      style: const TextStyle(color: AppColors.primary)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: c.maxWidth * 0.5,
                            child: Text(t.registerSubtitle,
                                style:
                                    TextStyle(color: context.muted, fontSize: 13, height: 1.4)),
                          ),
                          const SizedBox(height: 16),
                          // Small feature cards, on the left, right under the subtitle.
                          SizedBox(
                            width: c.maxWidth * 0.62,
                            child: Row(
                              children: [
                                _FeatureCard(
                                    icon: Icons.verified_user_rounded,
                                    color: AppColors.primary,
                                    title: t.regFeat1Title,
                                    body: t.regFeat1Body),
                                const SizedBox(width: 8),
                                _FeatureCard(
                                    icon: Icons.insights_rounded,
                                    color: AppColors.success,
                                    title: t.regFeat2Title,
                                    body: t.regFeat2Body),
                                const SizedBox(width: 8),
                                _FeatureCard(
                                    icon: Icons.bolt_rounded,
                                    color: AppColors.warning,
                                    title: t.regFeat3Title,
                                    body: t.regFeat3Body),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                ),
              ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Form card — narrower, comfortable reading column.
              ResponsiveCenter(
                maxWidth: 560,
                child: Container(
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                ),
                padding:
                    EdgeInsets.fromLTRB(24, 26, 24, 24 + MediaQuery.of(context).padding.bottom),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AuthLabel(t.firstName),
                              TextFormField(
                                controller: _first,
                                textCapitalization: TextCapitalization.words,
                                decoration: authDecoration(context,
                                    hint: t.firstNameHint, icon: Icons.person_outline_rounded),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty) ? t.required : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AuthLabel(t.lastName),
                              TextFormField(
                                controller: _last,
                                textCapitalization: TextCapitalization.words,
                                decoration: authDecoration(context,
                                    hint: t.lastNameHint, icon: Icons.person_outline_rounded),
                              ),
                            ],
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      AuthLabel(t.emailAddress),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: authDecoration(context,
                            hint: t.emailHint, icon: Icons.mail_outline_rounded),
                        validator: (v) =>
                            (v == null || !v.contains('@')) ? t.emailInvalid : null,
                      ),
                      const SizedBox(height: 16),
                      AuthLabel(t.password),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
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
                                color: context.muted),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 8) ? t.pwMin : null,
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
                        decoration: authDecoration(
                          context,
                          hint: t.confirmPasswordHint,
                          icon: Icons.lock_outline_rounded,
                          suffix: IconButton(
                            icon: Icon(
                                _obscure2
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: context.muted),
                            onPressed: () => setState(() => _obscure2 = !_obscure2),
                          ),
                        ),
                        validator: (v) => v != _password.text ? t.pwMismatch : null,
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
                          label: t.createMyAccount, loading: _loading, onTap: _submit),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(t.haveAccount, style: TextStyle(color: context.muted)),
                          TextButton(
                            onPressed: () =>
                                context.canPop() ? context.pop() : context.go('/login'),
                            child: Text(t.signIn),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0),
              ),
            ],
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
  const _FeatureCard(
      {required this.icon, required this.color, required this.title, required this.body});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, color: color, size: 14),
            ),
            const SizedBox(height: 5),
            Text(title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10.5)),
            const SizedBox(height: 2),
            Text(body,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.muted, fontSize: 8, height: 1.2)),
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
        Text('${t.pwStrength} ',
            style: TextStyle(color: context.muted, fontSize: 12)),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
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
              Icon(icon, color: AppColors.primary.withValues(alpha: 0.75), size: 20),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14.5,
                      color: muted ? context.muted : context.colors.onSurface,
                      fontWeight: FontWeight.w500)),
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
    const linkStyle = TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: accepted,
            onChanged: (v) => onChanged(v ?? false),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            activeColor: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 12.5, color: context.colors.onSurface, height: 1.4),
                children: [
                  TextSpan(text: t.acceptPrefix),
                  TextSpan(text: t.termsOfUse, style: linkStyle),
                  TextSpan(text: t.acceptMiddle),
                  TextSpan(text: t.privacyPolicy, style: linkStyle),
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
      padding: EdgeInsets.only(top: 12, bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
                color: context.borderColor, borderRadius: BorderRadius.circular(4)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.countryOfResidence,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
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
                  title: Text(c.$2, style: const TextStyle(fontWeight: FontWeight.w600)),
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

class _CurrencySheet extends StatelessWidget {
  final String selected;
  const _CurrencySheet({required this.selected});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(top: 12, bottom: 12 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
                color: context.borderColor, borderRadius: BorderRadius.circular(4)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(t.preferredCurrency,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: kCurrencies.map((c) {
                final sel = c.$1 == selected;
                return ListTile(
                  title: Text(c.$2, style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: sel
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                      : null,
                  onTap: () => Navigator.pop(context, c),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
