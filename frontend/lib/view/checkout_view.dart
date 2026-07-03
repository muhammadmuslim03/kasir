import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controller/checkout_controller.dart';
import '../controller/formatters.dart';
import '../controller/product_controller.dart';
import '../model/product.dart';
import '../model/sale_transaction.dart';
import 'widgets/common.dart';

class CheckoutView extends StatefulWidget {
  const CheckoutView({
    super.key,
    required this.productController,
    required this.checkoutController,
    required this.onCompleted,
  });

  final ProductController productController;
  final CheckoutController checkoutController;
  final ValueChanged<SaleTransaction> onCompleted;

  @override
  State<CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends State<CheckoutView> {
  final _cashController = TextEditingController();
  final _searchController = TextEditingController();

  String _searchQuery = '';

  @override
  void dispose() {
    _cashController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.productController,
        widget.checkoutController,
      ]),
      builder: (context, _) {
        final products = widget.productController.products;
        final visibleProducts = _filteredProducts(products);
        final lines = widget.checkoutController.lines(products);
        final total = widget.checkoutController.total(products);
        final change = widget.checkoutController.change(products);
        final canComplete =
            lines.isNotEmpty &&
            widget.checkoutController.cashReceived >= total &&
            !widget.checkoutController.loading;

        return RefreshIndicator(
          onRefresh: widget.productController.load,
          child: ListView(
            padding: responsivePagePadding(context),
            children: [
              if (widget.productController.error != null) ...[
                ErrorBanner(message: widget.productController.error!),
                const SizedBox(height: 12),
              ],
              if (widget.checkoutController.error != null) ...[
                ErrorBanner(message: widget.checkoutController.error!),
                const SizedBox(height: 12),
              ],
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 980;
                  final productGrid = _ProductGrid(
                    products: visibleProducts,
                    totalProductCount: products.length,
                    searchController: _searchController,
                    searchQuery: _searchQuery,
                    onSearchChanged: _setSearchQuery,
                    onClearSearch: _clearSearch,
                    checkoutController: widget.checkoutController,
                    loading: widget.productController.loading,
                  );
                  final cart = _CartPanel(
                    lines: lines,
                    total: total,
                    change: change,
                    cashController: _cashController,
                    checkoutController: widget.checkoutController,
                    canComplete: canComplete,
                    onComplete: () => _complete(products),
                  );

                  if (!wide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [productGrid, const SizedBox(height: 16), cart],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: productGrid),
                      const SizedBox(width: 16),
                      SizedBox(width: 390, child: cart),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _complete(List<Product> products) async {
    final transaction = await widget.checkoutController.complete(products);
    if (!mounted || transaction == null) {
      return;
    }

    _cashController.clear();
    showSnack(context, 'Transaksi selesai');
    widget.onCompleted(transaction);
  }

  List<Product> _filteredProducts(List<Product> products) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return products;
    }

    return products
        .where((product) => product.name.toLowerCase().contains(query))
        .toList();
  }

  void _setSearchQuery(String value) {
    setState(() => _searchQuery = value);
  }

  void _clearSearch() {
    _searchController.clear();
    _setSearchQuery('');
  }
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({
    required this.products,
    required this.totalProductCount,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.checkoutController,
    required this.loading,
  });

  final List<Product> products;
  final int totalProductCount;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final CheckoutController checkoutController;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final body = _buildBody(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProductSearchField(
          controller: searchController,
          query: searchQuery,
          onChanged: onSearchChanged,
          onClear: onClearSearch,
        ),
        const SizedBox(height: 12),
        body,
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (loading) {
      return const LoadingPane();
    }
    if (totalProductCount == 0) {
      return const Card(child: EmptyState(message: 'Belum ada produk.'));
    }
    if (products.isEmpty) {
      return const Card(child: EmptyState(message: 'Produk tidak ditemukan.'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1120
            ? 4
            : width >= 760
            ? 3
            : width >= 440
            ? 2
            : 1;
        final ratio = crossAxisCount == 1
            ? 2.15
            : crossAxisCount == 2
            ? 0.78
            : 0.86;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: ratio,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            final inCart = checkoutController.quantityFor(product);
            return Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => checkoutController.add(product),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ProductImage(
                        imageUrl: product.imageUrl,
                        label: product.name,
                        width: double.infinity,
                        borderRadius: 0,
                        iconSize: 42,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: FittedBox(
                                  alignment: Alignment.centerLeft,
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    formatCurrency(product.sellingPrice),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ),
                              if (inCart > 0) ...[
                                const SizedBox(width: 8),
                                Chip(
                                  label: Text('x$inCart'),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ProductSearchField extends StatelessWidget {
  const _ProductSearchField({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        labelText: 'Cari produk',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: query.trim().isEmpty
            ? null
            : IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close),
                tooltip: 'Bersihkan pencarian',
              ),
      ),
      onChanged: onChanged,
    );
  }
}

class _CartPanel extends StatelessWidget {
  const _CartPanel({
    required this.lines,
    required this.total,
    required this.change,
    required this.cashController,
    required this.checkoutController,
    required this.canComplete,
    required this.onComplete,
  });

  final List<CartLine> lines;
  final int total;
  final int change;
  final TextEditingController cashController;
  final CheckoutController checkoutController;
  final bool canComplete;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Keranjang',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: checkoutController.reset,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                ),
              ],
            ),
            const Divider(),
            if (lines.isEmpty)
              const EmptyState(message: 'Keranjang kosong.')
            else
              ...lines.map(
                (line) => _CartLineTile(
                  line: line,
                  onDecrement: () => checkoutController.decrement(line.product),
                  onIncrement: () => checkoutController.add(line.product),
                  onRemove: () => checkoutController.remove(line.product),
                ),
              ),
            const Divider(),
            _TotalRow(
              label: 'Total',
              value: formatCurrency(total),
              emphasized: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cashController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Uang diterima',
                prefixIcon: Icon(Icons.payments),
              ),
              onChanged: (value) =>
                  checkoutController.setCashReceived(parseWholeNumber(value)),
            ),
            const SizedBox(height: 12),
            _TotalRow(
              label: 'Kembalian',
              value: formatCurrency(change),
              emphasized: true,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: canComplete ? onComplete : null,
              icon: checkoutController.loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle),
              label: const Text('Selesaikan Transaksi'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({
    required this.line,
    required this.onDecrement,
    required this.onIncrement,
    required this.onRemove,
  });

  final CartLine line;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 360;
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.product.name,
                maxLines: narrow ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                '${formatCurrency(line.product.sellingPrice)} x ${line.quantity}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
          final controls = _QuantityControls(
            quantity: line.quantity,
            onDecrement: onDecrement,
            onIncrement: onIncrement,
            onRemove: onRemove,
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                details,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: controls),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: details),
              const SizedBox(width: 8),
              controls,
            ],
          );
        },
      ),
    );
  }
}

class _QuantityControls extends StatelessWidget {
  const _QuantityControls({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
    required this.onRemove,
  });

  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          constraints: const BoxConstraints.tightFor(width: 38, height: 38),
          visualDensity: VisualDensity.compact,
          onPressed: onDecrement,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        IconButton.filledTonal(
          constraints: const BoxConstraints.tightFor(width: 38, height: 38),
          visualDensity: VisualDensity.compact,
          onPressed: onIncrement,
          icon: const Icon(Icons.add),
        ),
        IconButton(
          constraints: const BoxConstraints.tightFor(width: 38, height: 38),
          visualDensity: VisualDensity.compact,
          onPressed: onRemove,
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)
        : Theme.of(context).textTheme.bodyLarge;
    return Row(
      children: [
        Expanded(child: Text(label)),
        Flexible(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: style),
            ),
          ),
        ),
      ],
    );
  }
}
