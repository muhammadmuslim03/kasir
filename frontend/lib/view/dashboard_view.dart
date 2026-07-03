import 'package:flutter/material.dart';

import '../controller/formatters.dart';
import '../controller/product_controller.dart';
import '../controller/report_controller.dart';
import 'widgets/common.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({
    super.key,
    required this.productController,
    required this.reportController,
    required this.onProducts,
  });

  final ProductController productController;
  final ReportController reportController;
  final VoidCallback onProducts;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([productController, reportController]),
      builder: (context, _) {
        final report = reportController.report;
        final products = productController.products;

        return RefreshIndicator(
          onRefresh: () async {
            await productController.load();
            await reportController.load();
          },
          child: ListView(
            padding: responsivePagePadding(context),
            children: [
              _DashboardHeader(
                totalSales: report.totalSales,
                transactionCount: report.transactionCount,
                menuCount: products.length,
              ),
              const SizedBox(height: 16),
              if (reportController.error != null) ...[
                ErrorBanner(message: reportController.error!),
                const SizedBox(height: 12),
              ],
              AdaptiveMetricGrid(
                children: [
                  MetricCard(
                    label: 'Penjualan Hari Ini',
                    value: formatCurrency(report.totalSales),
                    icon: Icons.payments,
                  ),
                  MetricCard(
                    label: 'Transaksi',
                    value: '${report.transactionCount}',
                    icon: Icons.shopping_cart_checkout,
                  ),
                  MetricCard(
                    label: 'Estimasi Untung',
                    value: formatCurrency(report.estimatedProfit),
                    icon: Icons.trending_up,
                  ),
                  MetricCard(
                    label: 'Menu',
                    value: '${products.length}',
                    icon: Icons.restaurant_menu,
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
                      Row(
                        children: [
                          Text(
                            'Menu',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: onProducts,
                            child: const Text('Kelola'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (productController.loading)
                        const LinearProgressIndicator()
                      else if (products.isEmpty)
                        const EmptyState(message: 'Belum ada menu.')
                      else
                        ...products
                            .take(5)
                            .map(
                              (product) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: ProductImage(
                                  imageUrl: product.imageUrl,
                                  label: product.name,
                                  width: 48,
                                  height: 48,
                                  iconSize: 22,
                                ),
                                title: Text(
                                  product.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  formatCurrency(product.sellingPrice),
                                ),
                                trailing: Text(
                                  product.imageUrl.trim().isEmpty
                                      ? 'Tanpa gambar'
                                      : 'Bergambar',
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                            ),
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
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.totalSales,
    required this.transactionCount,
    required this.menuCount,
  });

  final int totalSales;
  final int transactionCount;
  final int menuCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 680;
          final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Warung',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: colors.onPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Penjualan hari ini ${formatCurrency(totalSales)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onPrimary.withValues(alpha: 0.82),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );
          final stats = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeaderChip(
                icon: Icons.receipt_long,
                label: '$transactionCount transaksi',
              ),
              _HeaderChip(
                icon: Icons.restaurant_menu,
                label: '$menuCount menu',
              ),
            ],
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 14), stats],
            );
          }

          return Row(
            children: [
              Expanded(child: title),
              stats,
            ],
          );
        },
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: colors.onPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.onPrimary.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colors.onPrimary),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: colors.onPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
