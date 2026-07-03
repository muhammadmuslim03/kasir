import 'package:flutter/foundation.dart';

import '../model/sale_transaction.dart';
import 'api_client.dart';
import 'formatters.dart';

class TransactionController extends ChangeNotifier {
  TransactionController(this._apiClient);

  final ApiClient _apiClient;

  List<SaleTransaction> _transactions = [];
  bool _loading = false;
  String? _error;
  DateTime? _selectedDate;

  List<SaleTransaction> get transactions => List.unmodifiable(_transactions);
  bool get loading => _loading;
  String? get error => _error;
  DateTime? get selectedDate => _selectedDate;

  int get totalSales => _transactions.fold(
    0,
    (sum, transaction) => sum + transaction.totalAmount,
  );
  int get estimatedProfit => _transactions.fold(
    0,
    (sum, transaction) => sum + transaction.estimatedProfit,
  );
  int get itemCount =>
      _transactions.fold(0, (sum, transaction) => sum + transaction.itemCount);

  Future<void> load({DateTime? date, bool clearDate = false}) async {
    if (clearDate) {
      _selectedDate = null;
    } else if (date != null) {
      _selectedDate = date;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final query = _selectedDate == null
          ? null
          : {'date': apiDate(_selectedDate!)};
      final decoded =
          await _apiClient.getJson('/api/transactions', query: query)
              as List<dynamic>;
      _transactions = decoded
          .map((item) => SaleTransaction.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (error) {
      _error = error.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
