import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class VerifyScreen extends ConsumerStatefulWidget {
  final String email;
  const VerifyScreen({super.key, required this.email});
  @override
  ConsumerState<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends ConsumerState<VerifyScreen> {
  final _code = TextEditingController();
  bool _loading = false;

  Future<void> _verify() async {
    if (_code.text.length < 6) return;
    setState(() => _loading = true);
    try {
      final user =
          await ref.read(authRepositoryProvider).verifyEmail(widget.email, _code.text.trim());
      ref.read(authProvider.notifier).completeVerification(user);
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t.verifyTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.t.verifyBody, style: TextStyle(color: context.muted)),
              const SizedBox(height: 4),
              Text(widget.email, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 28),
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 28, letterSpacing: 12, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(hintText: '000000', counterText: ''),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _verify,
                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : Text(context.t.verify),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.read(authRepositoryProvider).resendOtp(widget.email),
                child: Text(context.t.verifyResend),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
