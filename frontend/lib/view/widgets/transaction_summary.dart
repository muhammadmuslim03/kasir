import 'package:flutter/material.dart';

import '../../controller/formatters.dart';
import '../../model/sale_transaction.dart';
import 'common.dart';

class TransactionSummaryCard extends StatelessWidget {
  const TransactionSummaryCard({
    super.key,
    required this.transaction,
    this.showProfit = false,
    this.onOpenReceipt,
  });

  final SaleTransaction transaction;
  final bool showProfit;
  final VoidCallback? onOpenReceipt;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: TransactionSummary(
        transaction: transaction,
        showProfit: showProfit,
        onOpenReceipt: onOpenReceipt,
      ),
    );
  }
}

class TransactionSummary extends StatelessWidget {
  const TransactionSummary({
    super.key,
    required this.transaction,
    this.showProfit = false,
    this.onOpenReceipt,
    this.padding = const EdgeInsets.all(14),
  });

  final SaleTransaction transaction;
  final bool showProfit;
  final VoidCallback? onOpenReceipt;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TransactionHeader(transaction: transaction),
          const SizedBox(height: 12),
          _AmountSummary(transaction: transaction, showProfit: showProfit),
          const Divider(height: 24),
          Text(
            'Item Dibeli',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          if (transaction.items.isEmpty)
            const EmptyState(message: 'Detail item tidak tersedia.')
          else
            ...transaction.items.asMap().entries.expand((entry) {
              final widgets = <Widget>[_TransactionItemRow(item: entry.value)];
              if (entry.key < transaction.items.length - 1) {
                widgets.add(const Divider(height: 1));
              }
              return widgets;
            }),
          if (onOpenReceipt != null) ...[
            const SizedBox(height: 12),
            _ReceiptButton(onPressed: onOpenReceipt!),
          ],
        ],
      ),
    );
  }
}

class _TransactionHeader extends StatelessWidget {
  const _TransactionHeader({required this.transaction});

  final SaleTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.receipt_long, color: colors.onPrimaryContainer),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transaction.transactionNumber,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                '${formatDateTime(transaction.transactionDate)} | ${transaction.itemCount} item',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AmountSummary extends StatelessWidget {
  const _AmountSummary({required this.transaction, required this.showProfit});

  final SaleTransaction transaction;
  final bool showProfit;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _AmountPill(
          label: 'Total',
          value: formatCurrency(transaction.totalAmount),
          emphasized: true,
        ),
        _AmountPill(
          label: 'Tunai',
          value: formatCurrency(transaction.cashReceived),
        ),
        _AmountPill(
          label: 'Kembali',
          value: formatCurrency(transaction.changeAmount),
        ),
        if (showProfit)
          _AmountPill(
            label: 'Untung',
            value: formatCurrency(transaction.estimatedProfit),
          ),
      ],
    );
  }
}

class _AmountPill extends StatelessWidget {
  const _AmountPill({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = emphasized
        ? colors.primaryContainer
        : colors.surfaceContainerHighest;
    final foreground = emphasized
        ? colors.onPrimaryContainer
        : colors.onSurfaceVariant;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 116, maxWidth: 190),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionItemRow extends StatelessWidget {
  const _TransactionItemRow({required this.item});

  final SaleTransactionItem item;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 380;
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.productName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              '${item.quantity} x ${formatCurrency(item.sellingPrice)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
        final subtotal = Text(
          formatCurrency(item.subtotal),
          textAlign: narrow ? TextAlign.start : TextAlign.end,
          style: const TextStyle(fontWeight: FontWeight.w900),
        );

        if (narrow) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [details, const SizedBox(height: 4), subtotal],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: details),
              const SizedBox(width: 12),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(fit: BoxFit.scaleDown, child: subtotal),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReceiptButton extends StatelessWidget {
  const _ReceiptButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final button = FilledButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.description),
          label: const Text('Lihat Struk'),
        );
        if (constraints.maxWidth < 420) {
          return SizedBox(width: double.infinity, child: button);
        }
        return Align(alignment: Alignment.centerRight, child: button);
      },
    );
  }
}
