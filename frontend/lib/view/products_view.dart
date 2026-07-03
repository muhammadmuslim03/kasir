import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controller/formatters.dart';
import '../controller/product_controller.dart';
import '../model/product.dart';
import '../model/user_role.dart';
import 'widgets/common.dart';

class ProductsView extends StatefulWidget {
  const ProductsView({
    super.key,
    required this.productController,
    required this.role,
  });

  final ProductController productController;
  final UserRole role;

  @override
  State<ProductsView> createState() => _ProductsViewState();
}

class _ProductsViewState extends State<ProductsView> {
  static const _maxProductImageBytes = 2 * 1024 * 1024;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _imageUrlController = TextEditingController();

  Product? _editing;

  @override
  void dispose() {
    _nameController.dispose();
    _sellingPriceController.dispose();
    _costPriceController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.productController,
      builder: (context, _) {
        final canCreateProducts = widget.role.canCreateProducts;
        final canEditProducts = widget.role.canEditProducts;
        final canDeleteProducts = widget.role.canDeleteProducts;
        return RefreshIndicator(
          onRefresh: widget.productController.load,
          child: ListView(
            padding: responsivePagePadding(context),
            children: [
              if (widget.productController.error != null) ...[
                ErrorBanner(message: widget.productController.error!),
                const SizedBox(height: 12),
              ],
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 980;
                  final table = _ProductTable(
                    products: widget.productController.products,
                    loading: widget.productController.loading,
                    canEditProducts: canEditProducts,
                    canDeleteProducts: canDeleteProducts,
                    onEdit: _edit,
                    onDelete: _delete,
                  );

                  if (!canCreateProducts && _editing == null) {
                    return table;
                  }

                  final form = _ProductForm(
                    formKey: _formKey,
                    editing: _editing,
                    nameController: _nameController,
                    sellingPriceController: _sellingPriceController,
                    costPriceController: _costPriceController,
                    imageUrlController: _imageUrlController,
                    loading: widget.productController.loading,
                    onPickImage: _pickImage,
                    onCancel: _clearForm,
                    onSubmit: _submit,
                  );

                  if (!wide) {
                    return Column(
                      children: [form, const SizedBox(height: 16), table],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: table),
                      const SizedBox(width: 16),
                      SizedBox(width: 390, child: form),
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

  Future<void> _submit() async {
    if (_editing == null && !widget.role.canCreateProducts) {
      return;
    }
    if (_editing != null && !widget.role.canEditProducts) {
      return;
    }

    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final input = ProductInput(
      name: _nameController.text.trim(),
      sellingPrice: parseWholeNumber(_sellingPriceController.text),
      costPrice: parseWholeNumber(_costPriceController.text),
      imageUrl: _imageUrlController.text.trim(),
    );
    final success = await widget.productController.save(
      id: _editing?.id,
      input: input,
    );
    if (!mounted) {
      return;
    }
    if (success) {
      showSnack(
        context,
        _editing == null ? 'Produk ditambahkan' : 'Produk diperbarui',
      );
      _clearForm();
    }
  }

  void _edit(Product product) {
    if (!widget.role.canEditProducts) {
      return;
    }

    setState(() {
      _editing = product;
      _nameController.text = product.name;
      _sellingPriceController.text = '${product.sellingPrice}';
      _costPriceController.text = '${product.costPrice}';
      _imageUrlController.text = product.imageUrl;
    });
  }

  Future<void> _delete(Product product) async {
    if (!widget.role.canDeleteProducts) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus produk'),
        content: Text('Hapus ${product.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    final success = await widget.productController.delete(product.id);
    if (!mounted) {
      return;
    }
    if (success) {
      showSnack(context, 'Produk dihapus');
      if (_editing?.id == product.id) {
        _clearForm();
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'gif'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
      if (file.size > _maxProductImageBytes) {
        if (mounted) {
          showSnack(context, 'Ukuran gambar maksimal 2 MB');
        }
        return;
      }

      final mimeType = _imageMimeType(file.extension);
      if (mimeType == null) {
        if (mounted) {
          showSnack(context, 'Format gambar harus JPG, PNG, WEBP, atau GIF');
        }
        return;
      }

      final bytes = file.bytes;
      if (bytes == null) {
        if (mounted) {
          showSnack(context, 'Gagal membaca data gambar');
        }
        return;
      }
      if (bytes.isEmpty || bytes.length > _maxProductImageBytes) {
        if (mounted) {
          showSnack(context, 'Ukuran gambar maksimal 2 MB');
        }
        return;
      }

      _imageUrlController.text = 'data:$mimeType;base64,${base64Encode(bytes)}';
    } catch (error) {
      if (mounted) {
        showSnack(context, 'Gagal memilih gambar: $error');
      }
    }
  }

  void _clearForm() {
    setState(() {
      _editing = null;
      _formKey.currentState?.reset();
      _nameController.clear();
      _sellingPriceController.clear();
      _costPriceController.clear();
      _imageUrlController.clear();
    });
  }
}

String? _imageMimeType(String? extension) {
  switch (extension?.toLowerCase()) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
  }

  return null;
}

class _ProductForm extends StatelessWidget {
  const _ProductForm({
    required this.formKey,
    required this.editing,
    required this.nameController,
    required this.sellingPriceController,
    required this.costPriceController,
    required this.imageUrlController,
    required this.loading,
    required this.onPickImage,
    required this.onCancel,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final Product? editing;
  final TextEditingController nameController;
  final TextEditingController sellingPriceController;
  final TextEditingController costPriceController;
  final TextEditingController imageUrlController;
  final bool loading;
  final Future<void> Function() onPickImage;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                editing == null ? 'Tambah Produk' : 'Ubah Produk',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama produk',
                  prefixIcon: Icon(Icons.inventory_2),
                ),
                validator: requiredText,
              ),
              const SizedBox(height: 10),
              _NumberField(
                controller: sellingPriceController,
                label: 'Harga jual',
              ),
              const SizedBox(height: 10),
              _NumberField(
                controller: costPriceController,
                label: 'Harga modal',
              ),
              const SizedBox(height: 10),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: imageUrlController,
                builder: (context, value, _) => _ImagePickerField(
                  controller: imageUrlController,
                  productName: nameController.text.trim(),
                  loading: loading,
                  onPickImage: onPickImage,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: loading ? null : onSubmit,
                icon: const Icon(Icons.save),
                label: const Text('Simpan Produk'),
              ),
              if (editing != null)
                TextButton(
                  onPressed: loading ? null : onCancel,
                  child: const Text('Batal ubah'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePickerField extends StatelessWidget {
  const _ImagePickerField({
    required this.controller,
    required this.productName,
    required this.loading,
    required this.onPickImage,
  });

  final TextEditingController controller;
  final String productName;
  final bool loading;
  final Future<void> Function() onPickImage;

  @override
  Widget build(BuildContext context) {
    final value = controller.text.trim();
    final uploaded = value.toLowerCase().startsWith('data:image/');
    final label = productName.isEmpty ? 'Preview gambar menu' : productName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: loading ? null : () => onPickImage(),
                icon: const Icon(Icons.upload_file),
                label: const Text('Pilih Gambar'),
              ),
            ),
            if (value.isNotEmpty) ...[
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: loading ? null : controller.clear,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Hapus gambar',
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        if (uploaded)
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Gambar menu',
              prefixIcon: Icon(Icons.image),
            ),
            child: const Text('Gambar tersimpan ke database saat disimpan'),
          )
        else
          TextFormField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'URL gambar menu',
              prefixIcon: Icon(Icons.link),
            ),
            keyboardType: TextInputType.url,
            validator: optionalImageValue,
          ),
        const SizedBox(height: 10),
        ProductImage(imageUrl: value, label: label, height: 150, iconSize: 42),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: nonNegativeInteger,
    );
  }
}

class _ProductTable extends StatelessWidget {
  const _ProductTable({
    required this.products,
    required this.loading,
    required this.canEditProducts,
    required this.canDeleteProducts,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Product> products;
  final bool loading;
  final bool canEditProducts;
  final bool canDeleteProducts;
  final ValueChanged<Product> onEdit;
  final ValueChanged<Product> onDelete;

  @override
  Widget build(BuildContext context) {
    if (loading && products.isEmpty) {
      return const Card(child: LoadingPane());
    }
    if (products.isEmpty) {
      return const Card(child: EmptyState(message: 'Belum ada produk.'));
    }
    final canUseActions = canEditProducts || canDeleteProducts;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            const DataColumn(label: Text('Produk')),
            const DataColumn(label: Text('Harga Jual'), numeric: true),
            if (canUseActions)
              const DataColumn(label: Text('Modal'), numeric: true),
            if (canUseActions) const DataColumn(label: Text('Aksi')),
          ],
          rows: products
              .map(
                (product) => DataRow(
                  cells: [
                    DataCell(_ProductNameCell(product: product)),
                    DataCell(Text(formatCurrency(product.sellingPrice))),
                    if (canUseActions)
                      DataCell(Text(formatCurrency(product.costPrice))),
                    if (canUseActions)
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (canEditProducts)
                              IconButton(
                                onPressed: () => onEdit(product),
                                icon: const Icon(Icons.edit),
                                tooltip: 'Ubah',
                              ),
                            if (canDeleteProducts)
                              IconButton(
                                onPressed: () => onDelete(product),
                                icon: const Icon(Icons.delete),
                                tooltip: 'Hapus',
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _ProductNameCell extends StatelessWidget {
  const _ProductNameCell({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProductImage(
          imageUrl: product.imageUrl,
          label: product.name,
          width: 48,
          height: 48,
          iconSize: 22,
        ),
        const SizedBox(width: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(product.name, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

String? optionalImageValue(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) {
    return null;
  }
  if (text.toLowerCase().startsWith('data:image/')) {
    return null;
  }
  final uri = Uri.tryParse(text);
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
    return 'URL gambar tidak valid';
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return 'URL harus diawali http atau https';
  }
  return null;
}
