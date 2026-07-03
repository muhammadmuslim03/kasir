import 'package:flutter/foundation.dart';

import '../model/product.dart';
import '../model/sale_transaction.dart';
import 'api_client.dart';
import 'app_exception.dart';

class CartLine {
  const CartLine({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  int get subtotal => product.sellingPrice * quantity;
}

class CheckoutController extends ChangeNotifier {
  CheckoutController(this._apiClient);

  final ApiClient _apiClient;

  final Map<int, int> _cart = {};
  int _cashReceived = 0;
  bool _loading = false;
  String? _error;
  SaleTransaction? _lastTransaction;

  bool get loading => _loading;
  String? get error => _error;
  int get cashReceived => _cashReceived;
  SaleTransaction? get lastTransaction => _lastTransaction;

  List<CartLine> lines(List<Product> products) {
    final productById = {for (final product in products) product.id: product};
    return _cart.entries
        .map((entry) {
          final product = productById[entry.key];
          if (product == null) {
            return null;
          }
          return CartLine(product: product, quantity: entry.value);
        })
        .whereType<CartLine>()
        .toList();
  }

  int total(List<Product> products) {
    return lines(products).fold(0, (sum, line) => sum + line.subtotal);
  }

  int change(List<Product> products) {
    final value = _cashReceived - total(products);
    return value > 0 ? value : 0;
  }

  int quantityFor(Product product) => _cart[product.id] ?? 0;

  void setCashReceived(int value) {
    _cashReceived = value < 0 ? 0 : value;
    notifyListeners();
  }

  void add(Product product) {
    final current = _cart[product.id] ?? 0;
    _cart[product.id] = current + 1;
    _error = null;
    notifyListeners();
  }

  void decrement(Product product) {
    final current = _cart[product.id] ?? 0;
    if (current <= 1) {
      _cart.remove(product.id);
    } else {
      _cart[product.id] = current - 1;
    }
    notifyListeners();
  }

  void remove(Product product) {
    _cart.remove(product.id);
    notifyListeners();
  }

  void reset() {
    _cart.clear();
    _cashReceived = 0;
    _error = null;
    notifyListeners();
  }

  Future<SaleTransaction?> complete(List<Product> products) async {
    final currentLines = lines(products);
    final currentTotal = total(products);
    if (currentLines.isEmpty) {
      _error = 'Keranjang masih kosong';
      notifyListeners();
      return null;
    }
    if (_cashReceived < currentTotal) {
      _error = 'Uang diterima belum mencukupi';
      notifyListeners();
      return null;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final decoded =
          await _apiClient.postJson('/api/checkout', {
                'cash_received': _cashReceived,
                'items': currentLines
                    .map(
                      (line) => {
                        'product_id': line.product.id,
                        'quantity': line.quantity,
                      },
                    )
                    .toList(),
              })
              as Map<String, dynamic>;
      final transaction = SaleTransaction.fromJson(decoded);
      _lastTransaction = transaction;
      _cart.clear();
      _cashReceived = 0;
      return transaction;
    } on ApiException catch (error) {
      _error = error.message;
      return null;
    } catch (error) {
      _error = error.toString();
      return null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
