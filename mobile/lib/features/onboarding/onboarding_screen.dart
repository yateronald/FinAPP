import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../core/storage/app_prefs.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';

class _Slide {
  final Color accent;
  final IconData icon;
  final int index; // 1..4
  final List<String> title; // [before, accentWord, after]
  final String subtitle;
  const _Slide({
    required this.accent,
    required this.icon,
    required this.index,
    required this.title,
    required this.subtitle,
  });

  String image(bool fr) => 'img/${index}_${fr ? 'French' : 'English'}.png';
}

const _purple = Color(0xFF4F46E5);
const _green = Color(0xFF16A34A);
const _violet = Color(0xFF7C3AED);
const _blue = Color(0xFF2563EB);

List<_Slide> _slides(bool fr) => [
      _Slide(
        accent: _purple,
        icon: Icons.bar_chart_rounded,
        index: 1,
        title: fr
            ? ['Prenez le ', 'contrôle', ' de votre argent']
            : ['Take ', 'control', ' of your money'],
        subtitle: fr
            ? 'Suivez vos revenus, dépenses et épargne facilement au quotidien.'
            : 'Easily track your income, expenses and savings every day.',
      ),
      _Slide(
        accent: _green,
        icon: Icons.savings_rounded,
        index: 2,
        title: fr
            ? ['Fixez des ', 'budgets', ' atteignables']
            : ['Set ', 'achievable', ' budgets'],
        subtitle: fr
            ? 'Définissez vos budgets et recevez des alertes en temps réel.'
            : 'Set your budgets and get real-time alerts.',
      ),
      _Slide(
        accent: _violet,
        icon: Icons.auto_awesome_rounded,
        index: 3,
        title: fr
            ? ['Obtenez des conseils avec ', 'l\'assistant IA', '']
            : ['Get advice from the ', 'AI assistant', ''],
        subtitle: fr
            ? 'Posez vos questions et recevez des conseils personnalisés pour mieux gérer vos finances.'
            : 'Ask questions and get personalized advice to better manage your finances.',
      ),
      _Slide(
        accent: _blue,
        icon: Icons.verified_user_rounded,
        index: 4,
        title: fr
            ? ['Vos données, notre ', 'priorité', '']
            : ['Your data, our ', 'priority', ''],
        subtitle: fr
            ? 'Vos données sont sécurisées avec un chiffrement de niveau bancaire.'
            : 'Your data is secured with bank-grade encryption.',
      ),
    ];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;
  bool _precached = false;

  bool get _isFrench => Localizations.localeOf(context).languageCode == 'fr';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precached) {
      _precached = true;
      for (final s in _slides(_isFrench)) {
        precacheImage(AssetImage(s.image(_isFrench)), context);
      }
    }
  }

  Future<void> _finish() async {
    await AppPrefs.instance.setOnboarded();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final fr = _isFrench;
    final slides = _slides(fr);
    final current = slides[_index];
    final last = _index == slides.length - 1;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              current.accent.withValues(alpha: context.isDark ? 0.16 : 0.08),
              context.colors.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: ResponsiveCenter(
            maxWidth: 640,
            child: Column(
            children: [
              // Skip
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12, top: 2),
                  child: TextButton(
                    onPressed: _finish,
                    child: Text(fr ? 'Ignorer' : 'Skip',
                        style: GoogleFonts.poppins(
                            color: current.accent, fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemCount: slides.length,
                  itemBuilder: (_, i) => _SlideView(slide: slides[i], fr: fr),
                ),
              ),
              const SizedBox(height: 8),
              SmoothPageIndicator(
                controller: _controller,
                count: slides.length,
                effect: ExpandingDotsEffect(
                  activeDotColor: current.accent,
                  dotColor: context.borderColor,
                  dotHeight: 8,
                  dotWidth: 8,
                  expansionFactor: 3.2,
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
                child: _NextButton(
                  color: current.accent,
                  label: last ? (fr ? 'Commencer' : 'Get started') : (fr ? 'Suivant' : 'Next'),
                  onTap: () {
                    if (last) {
                      _finish();
                    } else {
                      _controller.nextPage(
                          duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
                    }
                  },
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  final bool fr;
  const _SlideView({required this.slide, required this.fr});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: GoogleFonts.poppins(
                fontSize: 27,
                fontWeight: FontWeight.w700,
                height: 1.3,
                letterSpacing: -0.3,
                color: context.colors.onSurface,
              ),
              children: [
                TextSpan(text: slide.title[0]),
                TextSpan(text: slide.title[1], style: TextStyle(color: slide.accent)),
                TextSpan(text: slide.title[2]),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: context.muted,
              fontSize: 14.5,
              height: 1.55,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Image.asset(
              slide.image(fr),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Icon(slide.icon, size: 120, color: slide.accent.withValues(alpha: 0.3)),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: slide.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(slide.icon, color: slide.accent, size: 26),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _NextButton({required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.38), blurRadius: 18, offset: const Offset(0, 10)),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Centred label with side padding so long labels never hit the arrow.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 52),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w600),
              ),
            ),
            Positioned(
              right: 9,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 21),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
