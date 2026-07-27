import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/theme/app_colors.dart';
import 'chat_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../data/ai_models.dart';
import '../providers/ai_providers.dart';

class ChatPanel extends ConsumerStatefulWidget {
  const ChatPanel({super.key});
  @override
  ConsumerState<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends ConsumerState<ChatPanel> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    _ctrl.clear();
    FocusScope.of(context).unfocus();
    _scrollToBottom();
    await ref.read(chatProvider.notifier).send(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider);
    final busy = ref.read(chatProvider.notifier).busy;

    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? _Intro(onPick: _send)
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  itemCount: messages.length,
                  itemBuilder: (_, i) => _MessageRow(message: messages[i]),
                ),
        ),
        _InputBar(controller: _ctrl, busy: busy, onSend: _send),
      ],
    );
  }
}

// ------------------------------------------------------------- Intro

class _Intro extends StatelessWidget {
  final ValueChanged<String> onPick;
  const _Intro({required this.onPick});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final suggestions = [
      (t.aiSuggest1, Icons.pie_chart_outline_rounded),
      (t.aiSuggest2, Icons.trending_down_rounded),
      (t.aiSuggest3, Icons.savings_outlined),
      (t.aiSuggest4, Icons.tips_and_updates_outlined),
    ];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 34),
          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
        ),
        const SizedBox(height: 20),
        Text(t.aiAssistantTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(t.aiIntro,
            textAlign: TextAlign.center, style: TextStyle(color: context.muted, height: 1.5)),
        const SizedBox(height: 32),
        ...suggestions.asMap().entries.map((e) {
          final (text, icon) = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => onPick(text),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderColor),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: AppColors.primary),
                    const SizedBox(width: 14),
                    Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w500))),
                    Icon(Icons.arrow_forward_rounded, size: 16, color: context.muted),
                  ],
                ),
              ),
            ),
          ).animate(delay: (80 * e.key).ms).fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0);
        }),
      ],
    );
  }
}

// ----------------------------------------------------------- Message

class _MessageRow extends StatelessWidget {
  final ChatMessage message;
  const _MessageRow({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    if (isUser) return _UserBubble(text: message.content);
    return _AssistantMessage(message: message);
  }
}

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6, left: 44),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Text(text, style: const TextStyle(color: Colors.white, height: 1.4)),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.1, end: 0);
  }
}

class _AssistantMessage extends StatelessWidget {
  final ChatMessage message;
  const _AssistantMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: message.status == ChatStatus.sending
                ? const _ThinkingBubble()
                : _AssistantBody(message: message),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}

class _AssistantBody extends StatelessWidget {
  final ChatMessage message;
  const _AssistantBody({required this.message});

  @override
  Widget build(BuildContext context) {
    final isError =
        message.status == ChatStatus.error || message.status == ChatStatus.rateLimited;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Fynexa', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            if (isError) ...[
              const SizedBox(width: 6),
              Icon(Icons.error_outline_rounded, size: 14, color: AppColors.danger),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: isError
                ? AppColors.danger.withValues(alpha: 0.06)
                : context.colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isError ? AppColors.danger.withValues(alpha: 0.2) : context.borderColor),
          ),
          child: _renderContent(context),
        ),
        if (!isError && message.content.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.t.copied), duration: const Duration(seconds: 1)),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.copy_rounded, size: 13, color: context.muted),
                    const SizedBox(width: 4),
                    Text(context.t.copy, style: TextStyle(color: context.muted, fontSize: 11.5)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Renders the message, turning ```chart fenced JSON blocks into real charts
  /// and everything else into markdown.
  Widget _renderContent(BuildContext context) {
    if (message.content.isEmpty) {
      return MarkdownBody(data: '…', styleSheet: _md(context));
    }
    final segments = _parseSegments(message.content);
    if (segments.length == 1 && segments.first.chart == null) {
      return MarkdownBody(
          data: segments.first.text!, selectable: true, styleSheet: _md(context));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final seg in segments)
          if (seg.chart != null)
            ChatChart(spec: seg.chart!)
          else
            MarkdownBody(data: seg.text!, selectable: true, styleSheet: _md(context)),
      ],
    );
  }

  static final _fence = RegExp(r'```(\w*)[ \t]*\r?\n(.*?)```', dotAll: true);

  List<_Segment> _parseSegments(String content) {
    final out = <_Segment>[];
    var last = 0;
    for (final m in _fence.allMatches(content)) {
      final lang = (m.group(1) ?? '').toLowerCase();
      final spec = _tryChart(lang, m.group(2) ?? '');
      if (spec == null) continue; // leave non-chart code blocks inside the text
      final pre = content.substring(last, m.start);
      if (pre.trim().isNotEmpty) out.add(_Segment.text(pre.trim()));
      out.add(_Segment.chart(spec));
      last = m.end;
    }
    final rest = content.substring(last);
    if (rest.trim().isNotEmpty) out.add(_Segment.text(rest.trim()));
    if (out.isEmpty) out.add(_Segment.text(content));
    return out;
  }

  // All chart types ChatChart can render (normalized: no spaces/underscores/dashes).
  static const _chartTypes = {
    'pie', 'donut', 'doughnut', 'bar', 'column', 'stackedbar', 'stacked',
    'horizontalbar', 'hbar', 'barh', 'line', 'area', 'gauge', 'radial',
    'radialbar', 'progress', 'radar', 'spider',
  };
  static const _gaugeTypes = {'gauge', 'radial', 'radialbar', 'progress'};

  Map<String, dynamic>? _tryChart(String lang, String code) {
    if (lang != 'chart' && lang != 'json' && lang != '') return null;
    try {
      final obj = jsonDecode(code.trim());
      if (obj is! Map || obj['type'] == null) return null;
      final type = obj['type'].toString().toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
      if (!_chartTypes.contains(type)) return null;
      // Every type needs a data list EXCEPT gauge (which uses value/max).
      if (!_gaugeTypes.contains(type) && obj['data'] is! List) return null;
      return Map<String, dynamic>.from(obj);
    } catch (_) {}
    return null;
  }

  MarkdownStyleSheet _md(BuildContext context) =>
      MarkdownStyleSheet.fromTheme(context.theme).copyWith(
        p: context.theme.textTheme.bodyMedium?.copyWith(height: 1.5),
        listBullet: context.theme.textTheme.bodyMedium?.copyWith(height: 1.5),
        tableBorder: TableBorder.all(color: context.borderColor, width: 1),
        tableHead: const TextStyle(fontWeight: FontWeight.w700),
        tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        code: TextStyle(
            backgroundColor: context.surfaceAlt, fontSize: 13, fontFamily: 'monospace'),
        codeblockDecoration: BoxDecoration(
          color: context.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
        ),
        blockquoteDecoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: AppColors.primary, width: 3)),
        ),
        h1: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        h2: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        h3: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      );
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Fynexa IA',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 11, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text(
                    'Réfléchit...',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              const Text(
                'Analyse de vos finances en cours...',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.primary)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 600.ms),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- Input

class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final bool busy;
  final ValueChanged<String> onSend;
  const _InputBar({required this.controller, required this.busy, required this.onSend});

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.borderColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              onChanged: (_) => setState(() {}),
              onSubmitted: widget.busy ? null : widget.onSend,
              decoration: InputDecoration(
                hintText: widget.busy ? 'Fynexa réfléchit...' : context.t.aiMessageHint,
                filled: true,
                fillColor: context.surfaceAlt,
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(26), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SendButton(
            enabled: !widget.busy && widget.controller.text.trim().isNotEmpty,
            busy: widget.busy,
            onTap: () => widget.onSend(widget.controller.text),
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool enabled;
  final bool busy;
  final VoidCallback onTap;
  const _SendButton({required this.enabled, required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = enabled || busy;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: 200.ms,
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          gradient: active ? AppColors.brandGradient : null,
          color: active ? null : context.surfaceAlt,
          shape: BoxShape.circle,
        ),
        child: busy
            ? const Padding(
                padding: EdgeInsets.all(13),
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
              )
            : Icon(Icons.arrow_upward_rounded,
                color: enabled ? Colors.white : context.muted),
      ),
    );
  }
}

/// A parsed piece of an assistant message: either markdown text or a chart spec.
class _Segment {
  final String? text;
  final Map<String, dynamic>? chart;
  const _Segment.text(this.text) : chart = null;
  const _Segment.chart(this.chart) : text = null;
}
