import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../data/categories_repository.dart';
import '../data/category_model.dart';

final categoriesRepositoryProvider = Provider((_) => CategoriesRepository());

/// All categories, cached for the session and refreshed after any mutation.
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final data = await ApiClient.instance.get('/categories');
  return (data as List)
      .map((e) => Category.fromJson(Map<String, dynamic>.from(e)))
      .toList();
});

/// Categories filtered by type ('INCOME' | 'EXPENSE').
///
/// autoDispose is deliberate: a plain family would keep a *stale* computed list
/// alive for the whole session, so a category created elsewhere (Settings, or
/// the quick-add in a picker) could fail to show up in a later picker.
/// Disposing when unwatched guarantees it is always recomputed from the latest
/// `categoriesProvider` data.
final categoriesByTypeProvider =
    Provider.autoDispose.family<List<Category>, String>((ref, type) {
  final all = ref.watch(categoriesProvider).value ?? const <Category>[];
  return all.where((c) => c.type == type && !c.isArchived).toList();
});

/// Re-fetches the category list and waits for it, so callers can rely on the
/// new data being present before they continue (e.g. selecting a category they
/// just created). Use this after every create/update/archive/delete.
///
/// Accepts either a `Ref` (providers) or a `WidgetRef` (widgets).
Future<List<Category>> refreshCategories(dynamic ref) {
  ref.invalidate(categoriesProvider);
  return ref.read(categoriesProvider.future) as Future<List<Category>>;
}
