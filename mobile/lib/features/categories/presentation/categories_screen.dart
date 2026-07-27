import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/category_icons.dart';
import '../data/category_model.dart';
import '../providers/categories_provider.dart';

/// Icon slugs offered in the picker (must exist in category_icons.dart).
const _iconChoices = [
  // money & work
  'wallet', 'bank', 'credit-card', 'piggy-bank', 'coins', 'percent', 'chart-pie',
  'briefcase', 'laptop', 'trending-up', 'receipt', 'gift', 'rotate-ccw',
  // home & bills
  'home', 'building', 'zap', 'droplet', 'wifi', 'phone', 'tv', 'tools', 'shield',
  // living
  'utensils', 'coffee', 'shopping-bag', 'shopping-cart', 'shirt', 'scissors',
  // transport
  'car', 'bus', 'train', 'bike', 'fuel', 'plane',
  // health & family
  'heart-pulse', 'pill', 'stethoscope', 'dumbbell', 'users', 'baby', 'paw',
  // education & leisure
  'book-open', 'graduation-cap', 'film', 'music', 'gamepad', 'ticket', 'camera',
  // other
  'hand-heart', 'church', 'sun', 'leaf', 'star',
];

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});
  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t.categories),
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.primary,
          unselectedLabelColor: context.muted,
          indicatorColor: AppColors.primary,
          tabs: [Tab(text: context.t.expensesTab), Tab(text: context.t.incomeTab)],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCategorySheet(
          context,
          type: _tab.index == 0 ? 'EXPENSE' : 'INCOME',
        ),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.t.newCategory),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (all) => TabBarView(
          controller: _tab,
          children: [
            _CategoryList(items: all.where((c) => c.type == 'EXPENSE').toList()),
            _CategoryList(items: all.where((c) => c.type == 'INCOME').toList()),
          ],
        ),
      ),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  final List<Category> items;
  const _CategoryList({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return Center(child: Text(context.t.noCategory, style: TextStyle(color: context.muted)));
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => ref.refresh(categoriesProvider.future),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final c = items[i];
          return Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor),
            ),
            child: ListTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: c.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(categoryIcon(c.icon), color: c.color, size: 20),
              ),
              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: c.isDefault
                  ? Text(context.t.isDefault, style: TextStyle(color: context.muted, fontSize: 12))
                  : null,
              trailing: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: context.muted),
                onSelected: (v) async {
                  final repo = ref.read(categoriesRepositoryProvider);
                  try {
                    if (v == 'edit') {
                      showCategorySheet(context, existing: c);
                      return;
                    } else if (v == 'delete') {
                      await repo.remove(c.id);
                    }
                    await refreshCategories(ref);
                  } on ApiException catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(e.message)));
                    }
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(context.t.edit)),
                  if (!c.isDefault)
                    PopupMenuItem(value: 'delete', child: Text(context.t.delete)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------- Sheet

/// Opens the create/edit category sheet. On a successful *create* it returns
/// the new category's name so callers (e.g. the transaction/budget pickers) can
/// select it straight away; otherwise null.
Future<String?> showCategorySheet(BuildContext context,
    {String? type, Category? existing}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CategorySheet(type: type ?? existing?.type ?? 'EXPENSE', existing: existing),
  );
}

class _CategorySheet extends ConsumerStatefulWidget {
  final String type;
  final Category? existing;
  const _CategorySheet({required this.type, this.existing});
  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  late final TextEditingController _name;
  late String _icon;
  late Color _color;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _icon = widget.existing?.icon ?? _iconChoices.first;
    _color = widget.existing?.color ?? AppColors.palette.first;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = context.t.nameRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(categoriesRepositoryProvider);
    try {
      if (_isEdit) {
        await repo.update(widget.existing!.id,
            name: _name.text.trim(), icon: _icon, color: _hex(_color));
      } else {
        await repo.create(
            name: _name.text.trim(), type: widget.type, icon: _icon, color: _hex(_color));
      }
      // Wait for the refreshed list so any screen opened next (transaction /
      // budget pickers) is guaranteed to include the new category.
      await refreshCategories(ref);
      // Return the created name so the caller can auto-select it.
      if (mounted) Navigator.pop(context, _isEdit ? null : _name.text.trim());
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.of(context).padding.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                      color: context.borderColor, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                        color: _color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14)),
                    child: Icon(categoryIcon(_icon), color: _color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _isEdit ? context.t.editCategory : context.t.newCategoryTitle,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: context.t.name),
              ),
              const SizedBox(height: 18),
              Text(context.t.icon, style: TextStyle(color: context.muted, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _iconChoices.map((slug) {
                  final sel = slug == _icon;
                  return GestureDetector(
                    onTap: () => setState(() => _icon = slug),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: sel ? _color.withValues(alpha: 0.16) : context.surfaceAlt,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                            color: sel ? _color : Colors.transparent, width: 1.5),
                      ),
                      child: Icon(categoryIcon(slug),
                          color: sel ? _color : context.muted, size: 20),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              Text(context.t.color, style: TextStyle(color: context.muted, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: AppColors.palette.map((c) {
                  final sel = c.toARGB32() == _color.toARGB32();
                  return GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: sel ? context.colors.onSurface : Colors.transparent,
                            width: 2.5),
                      ),
                      child: sel
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Text(_isEdit ? context.t.save : context.t.create),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
