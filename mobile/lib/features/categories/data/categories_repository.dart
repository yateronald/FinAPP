import '../../../core/network/api_client.dart';

class CategoriesRepository {
  final _api = ApiClient.instance;

  Future<void> create({
    required String name,
    required String type, // INCOME | EXPENSE
    String? icon,
    String? color,
  }) async {
    await _api.post('/categories', body: {
      'name': name,
      'type': type,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
    });
  }

  Future<void> update(String id, {String? name, String? icon, String? color}) async {
    await _api.patch('/categories/$id', body: {
      if (name != null) 'name': name,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
    });
  }

  Future<void> archive(String id, bool archived) async {
    await _api.patch('/categories/$id/${archived ? 'archive' : 'unarchive'}');
  }

  Future<void> remove(String id) async {
    await _api.delete('/categories/$id');
  }
}
