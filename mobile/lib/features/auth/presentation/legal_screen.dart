import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/legal/legal_documents.dart';
import '../../../core/theme/app_theme.dart';

enum LegalDocument { terms, privacy }

/// Shows the Terms of Use or Privacy Policy.
///
/// Presented as a sheet rather than a route so it can be opened from the
/// register screen without losing the half-filled form behind it.
Future<void> showLegalDocument(BuildContext context, LegalDocument doc) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LegalSheet(doc: doc),
  );
}

class _LegalSheet extends StatelessWidget {
  const _LegalSheet({required this.doc});
  final LegalDocument doc;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final fr = t.isFr;
    final isTerms = doc == LegalDocument.terms;
    final title = isTerms ? t.termsOfUse : t.privacyPolicy;
    final body = isTerms ? termsOfUse(fr: fr) : privacyPolicy(fr: fr);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: context.borderColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Markdown(
                controller: scrollController,
                data: body,
                padding: EdgeInsets.fromLTRB(
                    20, 16, 20, 24 + MediaQuery.of(context).padding.bottom),
                styleSheet: MarkdownStyleSheet(
                  h2: const TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.w800, height: 2.2),
                  p: TextStyle(
                      fontSize: 13.5, height: 1.55, color: context.colors.onSurface),
                  strong: const TextStyle(fontWeight: FontWeight.w700),
                  listBullet: const TextStyle(fontSize: 13.5, height: 1.55),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
