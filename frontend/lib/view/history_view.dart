import 'package:flutter/material.dart';

import '../controller/formatters.dart';
import '../controller/transaction_controller.dart';
import '../model/sale_transaction.dart';
import '../model/user_role.dart';
import 'widgets/common.dart';
import 'widgets/transaction_summary.dart';

class HistoryView extends StatelessWidget {
  const HistoryView({
    super.key,
    required this.transactionController,
    required this.role,
    required this.onOpenReceipt,
  });

  final TransactionController transactionController;
  final UserRole role;
  final ValueChanged<SaleTransaction> onOpenReceipt;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: transactionController,
      builder: (context, _) {
        final selectedDate = transactionController.selectedDate;
        final metrics = <Widget>[
          MetricCard(
            label: 'Total Penjualan',
            value: formatCurrency(transactionController.totalSales),
            icon: Icons.payments,
          ),
          MetricCard(
            label: 'Transaksi',
            value: '${transactionController.transactions.length}',
            icon: Icons.receipt_long,
          ),
          if (role.canViewReports)
            MetricCard(
              label: 'Estimasi Untung',
              value: formatCurrency(transactionController.estimatedProfit),
              icon: Icons.trending_up,
            ),
          MetricCard(
            label: 'Item',
            value: '${transactionController.itemCount}',
            icon: Icons.shopping_basket,
          ),
        ];

        return RefreshIndicator(
          onRefresh: () => transactionController.load(),
          child: ListView(
            padding: responsivePagePadding(context),
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(context),
                    icon: const Icon(Icons.calendar_month),
                    label: Text(
                      selectedDate == null
                          ? 'Pilih tanggal'
                          : formatDate(selectedDate),
                    ),
                  ),
                  if (selectedDate != null)
                    TextButton(
                      onPressed: () =>
                          transactionController.load(clearDate: true),
                      child: const Text('Semua tanggal'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (transactionController.error != null) ...[
                ErrorBanner(message: transactionController.error!),
                const SizedBox(height: 12),
              ],
              if (transactionController.loading)
                const LinearProgressIndicator(),
              const SizedBox(height: 12),
              AdaptiveMetricGrid(children: metrics),
              const SizedBox(height: 16),
              if (transactionController.transactions.isEmpty)
                const Card(child: EmptyState(message: 'Tidak ada transaksi.'))
              else
                ...transactionController.transactions.map(
                  (transaction) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TransactionSummaryCard(
                      transaction: transaction,
                      showProfit: role.canViewReports,
                      onOpenReceipt: () => onOpenReceipt(transaction),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: transactionController.selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      await transactionController.load(date: picked);
    }
  }
}
