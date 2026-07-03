import '../controller/formatters.dart';

class SaleTransaction {
  const SaleTransaction({
    required this.id,
    required this.transactionNumber,
    required this.totalAmount,
    required this.cashReceived,
    required this.changeAmount,
    required this.estimatedProfit,
    required this.transactionDate,
    required this.items,
  });

  final int id;
  final String transactionNumber;
  final int totalAmount;
  final int cashReceived;
  final int changeAmount;
  final int estimatedProfit;
  final DateTime transactionDate;
  final List<SaleTransactionItem> items;

  int get itemCount => items.fold(0, (total, item) => total + item.quantity);

  factory SaleTransaction.fromJson(Map<String, dynamic> json) {
    return SaleTransaction(
      id: json['id'] as int,
      transactionNumber: json['transaction_number'] as String,
      totalAmount: json['total_amount'] as int,
      cashReceived: json['cash_received'] as int,
      changeAmount: json['change_amount'] as int,
      estimatedProfit: json['estimated_profit'] as int,
      transactionDate: DateTime.parse(json['transaction_date'] as String),
      items: (json['items'] as List<dynamic>? ?? <dynamic>[])
          .map(
            (item) =>
                SaleTransactionItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  String receiptText({String storeName = 'WARUNG MAJU JAYA'}) {
    final lines = <String>[
      storeName.toUpperCase(),
      'Tanggal: ${formatDateTime(transactionDate)}',
      'No. Transaksi: $transactionNumber',
      '',
    ];

    for (final item in items) {
      lines.add(
        '${item.productName} x${item.quantity} @ ${formatCurrency(item.sellingPrice)}',
      );
      lines.add(_receiptAmountLine('Subtotal', item.subtotal));
    }

    lines
      ..add('------------------------------')
      ..add(_receiptAmountLine('Total', totalAmount))
      ..add(_receiptAmountLine('Tunai', cashReceived))
      ..add(_receiptAmountLine('Kembalian', changeAmount))
      ..add('')
      ..add('Terima kasih sudah berbelanja.');

    return lines.join('\n');
  }
}

class SaleTransactionItem {
  const SaleTransactionItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.sellingPrice,
    required this.costPrice,
    required this.subtotal,
    required this.profit,
  });

  final int id;
  final int productId;
  final String productName;
  final int quantity;
  final int sellingPrice;
  final int costPrice;
  final int subtotal;
  final int profit;

  factory SaleTransactionItem.fromJson(Map<String, dynamic> json) {
    return SaleTransactionItem(
      id: json['id'] as int,
      productId: json['product_id'] as int,
      productName: json['product_name'] as String,
      quantity: json['quantity'] as int,
      sellingPrice: json['selling_price'] as int,
      costPrice: json['cost_price'] as int,
      subtotal: json['subtotal'] as int,
      profit: json['profit'] as int,
    );
  }
}

String _receiptAmountLine(String label, int amount) {
  final price = formatCurrency(amount);
  final gap = 30 - label.length - price.length;
  return '$label${''.padRight(gap > 1 ? gap : 1)}$price';
}
