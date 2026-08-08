import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../shell/shell_providers.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/ai_models.dart';
import '../providers/ai_providers.dart';
import 'ai_access.dart';

class RealAiAnalyticsWidget extends ConsumerStatefulWidget {
  final DateTime date;
  final String scope; // 'GLOBAL' | 'BUDGET' | 'EXPENSE' | 'INCOME'
  final bool isEmbedded;
  const RealAiAnalyticsWidget({
    super.key,
    required this.date,
    this.scope = 'GLOBAL',
    this.isEmbedded = false,
  });

  @override
  ConsumerState<RealAiAnalyticsWidget> createState() =>
      _RealAiAnalyticsWidgetState();
}

class _RealAiAnalyticsWidgetState extends ConsumerState<RealAiAnalyticsWidget> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.94);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(
      authProvider.select((state) => state.user?.settings?.aiEnabled == true),
    );
    // Do not construct/watch the auto-generating insights provider until the
    // user has opted in. This covers dashboard, budgets and finances.
    if (!enabled) return const AiDisabledState(compact: true);

    final param = AiInsightsParam(widget.date, scope: widget.scope);
    final state = ref.watch(aiInsightsProvider(param));
    final controller = ref.read(aiInsightsProvider(param).notifier);

    final title = switch (widget.scope) {
      'BUDGET' => 'Analytique IA Budgets',
      'EXPENSE' => 'Analytique IA Dépenses',
      'INCOME' => 'Analytique IA Revenus',
      _ => 'Analytique IA',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Compact Professional Header Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'En direct',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: state.isLoading ? null : () => controller.generate(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.surfaceAlt,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (state.isLoading)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      else
                        const Icon(
                          Icons.refresh_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                      const SizedBox(width: 4),
                      Text(
                        state.isLoading ? 'Analyse...' : 'Actualiser',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
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

        // Horizontal Carousel (Compact 110px Height)
        state.when(
          loading: () => _buildSkeleton(context),
          error: (err, _) => _buildError(context, controller),
          data: (result) {
            // Nothing recorded for this period → invite the user to add data
            // rather than showing analysis of an empty month.
            if (result.empty) return _buildNoData(context);

            final list = result.insights.take(5).toList();
            if (list.isEmpty) return _buildEmpty(context, controller);

            return Column(
              children: [
                SizedBox(
                  height: 108,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _CompactInsightCard(
                          insight: list[index],
                          index: index,
                          ref: ref,
                        ),
                      );
                    },
                  ),
                ),
                if (list.length > 1) ...[
                  const SizedBox(height: 6),
                  Center(
                    child: SmoothPageIndicator(
                      controller: _pageController,
                      count: list.length,
                      effect: ExpandingDotsEffect(
                        dotWidth: 5,
                        dotHeight: 5,
                        activeDotColor: AppColors.primary,
                        dotColor: context.borderColor,
                        expansionFactor: 3,
                        spacing: 4,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  /// Shown when the period genuinely has no records for this scope. Not an
  /// error and not retryable — the user simply has nothing to analyse yet.
  Widget _buildNoData(BuildContext context) {
    final t = context.t;
    final message = switch (widget.scope) {
      'BUDGET' => t.aiNoDataBudget,
      'EXPENSE' => t.aiNoDataExpense,
      'INCOME' => t.aiNoDataIncome,
      _ => t.aiNoDataDashboard,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.insights_rounded,
              color: AppColors.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.aiNoDataTitle,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: context.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    return Container(
      height: 108,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Shimmer.fromColors(
        baseColor: context.surfaceAlt,
        highlightColor: context.colors.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 140, height: 12, color: context.surfaceAlt),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              height: 10,
              color: context.surfaceAlt,
            ),
            const SizedBox(height: 6),
            Container(width: 180, height: 10, color: context.surfaceAlt),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, AiInsightsController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 16,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Erreur lors de l\'analyse IA.',
              style: TextStyle(
                color: AppColors.danger,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          InkWell(
            onTap: () => controller.generate(),
            child: const Text(
              'Réessayer',
              style: TextStyle(
                color: AppColors.danger,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, AiInsightsController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline_rounded, color: context.muted, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Aucune analyse IA disponible.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(
            onPressed: () => controller.generate(),
            child: const Text('Lancer l\'analyse'),
          ),
        ],
      ),
    );
  }
}

class _CompactInsightCard extends StatelessWidget {
  final RealAiInsight insight;
  final int index;
  final WidgetRef ref;
  const _CompactInsightCard({
    required this.insight,
    required this.index,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final (accentColor, iconData, _) = switch (insight.severity) {
      'critical' => (AppColors.danger, Icons.error_outline_rounded, 'Alerte'),
      'warning' => (
        AppColors.warning,
        Icons.warning_amber_rounded,
        'Attention',
      ),
      _ => (AppColors.primary, Icons.lightbulb_outline_rounded, 'Conseil'),
    };

    final typeLabel = switch (insight.type) {
      'SPENDING_ANALYSIS' => 'Dépenses',
      'BUDGET_SUGGESTION' => 'Budget',
      'SAVING_RECOMMENDATION' => 'Épargne',
      'UNUSUAL_SPENDING' => 'Inhabituel',
      'PREDICTION' => 'Prédiction',
      'ALERT' => 'Alerte',
      _ => 'Conseil',
    };

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDetailModal(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(iconData, size: 15, color: accentColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        insight.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        typeLabel,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  insight.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.onSurface.withValues(alpha: 0.8),
                    fontSize: 11.5,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate(delay: (40 * index).ms).fadeIn(duration: 200.ms);
  }

  void _showDetailModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          20 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.borderColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    insight.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              insight.content,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: context.colors.onSurface.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ref.read(shellIndexProvider.notifier).set(3);
                },
                icon: const Icon(Icons.forum_rounded, size: 16),
                label: const Text('Discuter avec l\'assistant IA'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
