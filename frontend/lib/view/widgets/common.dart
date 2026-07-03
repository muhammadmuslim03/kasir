import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdaptiveMetricGrid extends StatelessWidget {
  const AdaptiveMetricGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1100
            ? 4
            : width >= 760
            ? 3
            : width >= 520
            ? 2
            : 1;
        final ratio = columns == 1
            ? 3.45
            : columns == 2
            ? 1.8
            : 1.75;

        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: ratio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: children,
        );
      },
    );
  }
}

EdgeInsets responsivePagePadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < 380) {
    return const EdgeInsets.fromLTRB(10, 12, 10, 16);
  }
  if (width < 700) {
    return const EdgeInsets.fromLTRB(12, 14, 12, 18);
  }
  if (width < 1100) {
    return const EdgeInsets.all(16);
  }
  return const EdgeInsets.all(20);
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: colors.onErrorContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class LoadingPane extends StatelessWidget {
  const LoadingPane({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.imageUrl,
    required this.label,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.iconSize = 28,
  });

  final String imageUrl;
  final String label;
  final double? width;
  final double? height;
  final double borderRadius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = imageUrl.trim();
    final placeholder = _ProductImagePlaceholder(
      label: label,
      iconSize: iconSize,
    );
    final imageBytes = _decodeImageDataUrl(normalizedUrl);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: imageBytes != null
            ? Image.memory(
                imageBytes,
                fit: BoxFit.cover,
                semanticLabel: label,
                errorBuilder: (context, error, stackTrace) => placeholder,
              )
            : normalizedUrl.isEmpty
            ? placeholder
            : Image.network(
                normalizedUrl,
                fit: BoxFit.cover,
                semanticLabel: label,
                errorBuilder: (context, error, stackTrace) => placeholder,
              ),
      ),
    );
  }
}

Uint8List? _decodeImageDataUrl(String value) {
  if (!value.toLowerCase().startsWith('data:image/')) {
    return null;
  }

  final commaIndex = value.indexOf(',');
  if (commaIndex < 0) {
    return null;
  }
  final metadata = value.substring(0, commaIndex).toLowerCase();
  if (!metadata.endsWith(';base64')) {
    return null;
  }

  try {
    return base64Decode(value.substring(commaIndex + 1));
  } on FormatException {
    return null;
  }
}

class _ProductImagePlaceholder extends StatelessWidget {
  const _ProductImagePlaceholder({required this.label, required this.iconSize});

  final String label;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      color: colors.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.restaurant_menu,
        size: iconSize,
        color: colors.onSurfaceVariant,
        semanticLabel: label,
      ),
    );
  }
}

String? requiredText(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Wajib diisi';
  }
  return null;
}

String? nonNegativeInteger(String? value) {
  final number = int.tryParse(value?.trim() ?? '');
  if (number == null) {
    return 'Harus berupa angka';
  }
  if (number < 0) {
    return 'Tidak boleh negatif';
  }
  return null;
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
