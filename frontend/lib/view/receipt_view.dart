import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controller/formatters.dart';
import '../model/sale_transaction.dart';
import 'widgets/common.dart';

class ReceiptView extends StatelessWidget {
  const ReceiptView({
    super.key,
    required this.transaction,
    required this.onBackToCheckout,
    required this.onClose,
  });

  final SaleTransaction transaction;
  final VoidCallback onBackToCheckout;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final receiptText = transaction.receiptText();

    return ListView(
      padding: responsivePagePadding(context),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: receiptText));
                if (context.mounted) {
                  showSnack(context, 'Struk disalin dan siap dibagikan');
                }
              },
              icon: const Icon(Icons.share),
              label: const Text('Bagikan Struk'),
            ),
            OutlinedButton.icon(
              onPressed: onBackToCheckout,
              icon: const Icon(Icons.point_of_sale),
              label: const Text('Kasir'),
            ),
            TextButton.icon(
              onPressed: onClose,
              icon: const Icon(Icons.close),
              label: const Text('Tutup'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final paper = Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: SelectionArea(
                  child: Text(
                    receiptText,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      height: 1.45,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            );
            final summary = _ReceiptSummary(transaction: transaction);

            if (!wide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [paper, const SizedBox(height: 16), summary],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 520, child: paper),
                const SizedBox(width: 16),
                Expanded(child: summary),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ReceiptSummary extends StatelessWidget {
  const _ReceiptSummary({required this.transaction});

  final SaleTransaction transaction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              transaction.transactionNumber,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(formatDateTime(transaction.transactionDate)),
            const Divider(height: 24),
            _Row(
              label: 'Total',
              value: formatCurrency(transaction.totalAmount),
            ),
            _Row(
              label: 'Tunai',
              value: formatCurrency(transaction.cashReceived),
            ),
            _Row(
              label: 'Kembalian',
              value: formatCurrency(transaction.changeAmount),
            ),
            _Row(
              label: 'Estimasi untung',
              value: formatCurrency(transaction.estimatedProfit),
            ),
            const Divider(height: 24),
            ...transaction.items.map(
              (item) => _Row(
                label: '${item.productName} x${item.quantity}',
                value: formatCurrency(item.subtotal),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
