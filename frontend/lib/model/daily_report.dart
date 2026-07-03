import 'sale_transaction.dart';

class DailyReport {
  const DailyReport({
    required this.date,
    required this.totalSales,
    required this.transactionCount,
    required this.estimatedProfit,
    required this.totalItemsSold,
    required this.transactions,
  });

  final String date;
  final int totalSales;
  final int transactionCount;
  final int estimatedProfit;
  final int totalItemsSold;
  final List<SaleTransaction> transactions;

  factory DailyReport.fromJson(Map<String, dynamic> json) {
    return DailyReport(
      date: json['date'] as String,
      totalSales: json['total_sales'] as int,
      transactionCount: json['transaction_count'] as int,
      estimatedProfit: json['estimated_profit'] as int,
      totalItemsSold: json['total_items_sold'] as int,
      transactions: (json['transactions'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => SaleTransaction.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  static DailyReport empty(String date) {
    return DailyReport(
      date: date,
      totalSales: 0,
      transactionCount: 0,
      estimatedProfit: 0,
      totalItemsSold: 0,
      transactions: const [],
    );
  }
}
