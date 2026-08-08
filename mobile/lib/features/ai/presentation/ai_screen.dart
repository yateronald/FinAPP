import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/ai_providers.dart';
import 'chat_panel.dart';
import 'forecast_panel.dart';
import 'ai_access.dart';

class AiScreen extends ConsumerStatefulWidget {
  const AiScreen({super.key});
  @override
  ConsumerState<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends ConsumerState<AiScreen> {
  int _tab = 0; // 0 = assistant, 1 = prévisions

  @override
  Widget build(BuildContext context) {
    // Return before watching chat/forecast providers. Opening the AI tab while
    // disabled therefore makes no AI request.
    if (!isAiEnabled(ref)) return const AiDisabledState();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: context.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      _seg(
                        context.t.aiAssistant,
                        0,
                        Icons.auto_awesome_rounded,
                      ),
                      _seg(context.t.aiForecast, 1, Icons.show_chart_rounded),
                    ],
                  ),
                ),
              ),
              if (_tab == 0 && ref.watch(chatProvider).isNotEmpty) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: context.t.clearChat,
                  onPressed: () => ref.read(chatProvider.notifier).clear(),
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: const [ChatPanel(), ForecastPanel()],
          ),
        ),
      ],
    );
  }

  Widget _seg(String label, int index, IconData icon) {
    final sel = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: sel ? context.colors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: sel
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: sel ? AppColors.primary : context.muted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: sel ? AppColors.primary : context.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
