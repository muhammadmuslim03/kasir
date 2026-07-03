import 'package:flutter/material.dart';

import '../controller/formatters.dart';
import '../controller/report_controller.dart';
import 'widgets/common.dart';
import 'widgets/transaction_summary.dart';

class ReportView extends StatelessWidget {
  const ReportView({super.key, required this.reportController});

  final ReportController reportController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: reportController,
      builder: (context, _) {
        final report = reportController.report;
        return RefreshIndicator(
          onRefresh: () => reportController.load(),
          child: ListView(
            padding: responsivePagePadding(context),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tanggal ${formatDate(reportController.selectedDate)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(context),
                    icon: const Icon(Icons.calendar_month),
                    label: const Text('Pilih'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (reportController.error != null) ...[
                ErrorBanner(message: reportController.error!),
                const SizedBox(height: 12),
              ],
              if (reportController.loading) const LinearProgressIndicator(),
              const SizedBox(height: 12),
              AdaptiveMetricGrid(
                children: [
                  MetricCard(
                    label: 'Total Penjualan',
                    value: formatCurrency(report.totalSales),
                    icon: Icons.payments,
                  ),
                  MetricCard(
                    label: 'Transaksi',
                    value: '${report.transactionCount}',
                    icon: Icons.receipt_long,
                  ),
                  MetricCard(
                    label: 'Estimasi Untung',
                    value: formatCurrency(report.estimatedProfit),
                    icon: Icons.trending_up,
                  ),
                  MetricCard(
                    label: 'Item Terjual',
                    value: '${report.totalItemsSold}',
                    icon: Icons.shopping_basket,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transaksi Tanggal Ini',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      if (report.transactions.isEmpty)
                        const EmptyState(
                          message: 'Belum ada transaksi pada tanggal ini.',
                        )
                      else
                        ...report.transactions.asMap().entries.expand((entry) {
                          final widgets = <Widget>[
                            TransactionSummary(
                              transaction: entry.value,
                              showProfit: true,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ];
                          if (entry.key < report.transactions.length - 1) {
                            widgets.add(const Divider(height: 24));
                          }
                          return widgets;
                        }),
                    ],
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
      initialDate: reportController.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      await reportController.load(date: picked);
    }
  }
}
