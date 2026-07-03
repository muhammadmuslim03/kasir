import 'package:flutter/foundation.dart';

import '../model/product.dart';
import 'api_client.dart';

class ProductController extends ChangeNotifier {
  ProductController(this._apiClient);

  final ApiClient _apiClient;

  List<Product> _products = [];
  bool _loading = false;
  String? _error;

  List<Product> get products => List.unmodifiable(_products);
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final decoded =
          await _apiClient.getJson('/api/products') as List<dynamic>;
      _products = decoded
          .map((item) => Product.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (error) {
      _error = error.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> save({int? id, required ProductInput input}) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      if (id == null) {
        await _apiClient.postJson('/api/products', input.toJson());
      } else {
        await _apiClient.putJson('/api/products/$id', input.toJson());
      }
      await load();
      return true;
    } catch (error) {
      _error = error.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> delete(int id) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiClient.deleteJson('/api/products/$id');
      await load();
      return true;
    } catch (error) {
      _error = error.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }
}
