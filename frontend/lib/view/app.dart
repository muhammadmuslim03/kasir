import 'package:flutter/material.dart';

import '../controller/api_client.dart';
import '../controller/auth_controller.dart';
import '../controller/checkout_controller.dart';
import '../controller/product_controller.dart';
import '../controller/report_controller.dart';
import '../controller/transaction_controller.dart';
import '../model/sale_transaction.dart';
import '../model/user_role.dart';
import 'checkout_view.dart';
import 'dashboard_view.dart';
import 'history_view.dart';
import 'products_view.dart';
import 'receipt_view.dart';
import 'report_view.dart';
import 'widgets/common.dart';

class KasirWarungApp extends StatefulWidget {
  const KasirWarungApp({super.key, required this.apiBaseUrls});

  final List<String> apiBaseUrls;

  @override
  State<KasirWarungApp> createState() => _KasirWarungAppState();
}

class _KasirWarungAppState extends State<KasirWarungApp> {
  late AuthController _authController;
  late ApiClient _apiClient;
  late ProductController _productController;
  late CheckoutController _checkoutController;
  late ReportController _reportController;
  late TransactionController _transactionController;
  late Future<void> _startup;
  late String _apiBaseUrl;
  String? _startupError;

  _PageKey _selected = _PageKey.dashboard;
  SaleTransaction? _receipt;

  @override
  void initState() {
    super.initState();
    _apiBaseUrl = _apiCandidates.isEmpty ? '' : _apiCandidates.first;
    _configureControllers(_apiBaseUrl);
    _startup = _initialize();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  List<String> get _apiCandidates {
    return widget.apiBaseUrls;
  }

  void _configureControllers(String apiBaseUrl) {
    _authController = AuthController(baseUrl: apiBaseUrl);
    _apiClient = ApiClient(
      baseUrl: apiBaseUrl,
      authController: _authController,
    );
    _productController = ProductController(_apiClient);
    _checkoutController = CheckoutController(_apiClient);
    _reportController = ReportController(_apiClient);
    _transactionController = TransactionController(_apiClient);
  }

  void _disposeControllers() {
    _authController.dispose();
    _productController.dispose();
    _checkoutController.dispose();
    _reportController.dispose();
    _transactionController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kasir Warung',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF172033),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      home: FutureBuilder<void>(
        future: _startup,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(body: LoadingPane());
          }
          if (_authController.token == null) {
            return _StartupError(
              apiBaseUrl: _apiBaseUrl,
              apiBaseUrls: _apiCandidates,
              message:
                  _startupError ??
                  _authController.error ??
                  'Backend belum siap',
              onRetry: _retryStartup,
            );
          }
          return AnimatedBuilder(
            animation: _authController,
            builder: (context, _) => _Shell(
              apiBaseUrl: _apiBaseUrl,
              authController: _authController,
              selected: _selected,
              receipt: _receipt,
              destinations: _destinationsForRole(_authController.role),
              body: _buildBody(),
              onSelect: (page) {
                setState(() {
                  _receipt = null;
                  _selected = page;
                });
              },
              onRoleChanged: _switchRole,
            ),
          );
        },
      ),
    );
  }

  Future<void> _initialize() async {
    _startupError = null;
    if (_apiCandidates.isEmpty) {
      _startupError =
          'API_BASE_URL wajib diisi saat build production Flutter web.';
      return;
    }

    String? lastError;

    for (final candidate in _apiCandidates) {
      if (_apiBaseUrl != candidate) {
        _disposeControllers();
        _apiBaseUrl = candidate;
        _configureControllers(candidate);
      }

      await _authController.initialize();
      if (_authController.token == null) {
        lastError = _authController.error;
        continue;
      }

      _selected = _authController.role == UserRole.owner
          ? _PageKey.dashboard
          : _PageKey.checkout;
      await _loadDataForRole();
      if (_productController.error == null) {
        return;
      }

      lastError =
          'Tidak dapat memuat produk dari $candidate: '
          '${_productController.error}';
      await _authController.clearSession();
    }

    _startupError = lastError ?? 'Tidak dapat menemukan backend aktif';
  }

  Future<void> _loadDataForRole() async {
    await _productController.load();
    final roleDataLoads = <Future<void>>[];
    if (_authController.role.canViewReports) {
      roleDataLoads.add(_reportController.load());
    }
    if (_authController.role.canViewHistory) {
      roleDataLoads.add(_transactionController.load());
    }
    if (roleDataLoads.isNotEmpty) {
      await Future.wait(roleDataLoads);
    }
  }

  void _retryStartup() {
    setState(() {
      _startup = _initialize();
    });
  }

  Future<void> _switchRole(BuildContext roleContext, UserRole role) async {
    try {
      String? ownerPin;
      if (role == UserRole.owner && _authController.role != UserRole.owner) {
        ownerPin = await showDialog<String>(
          context: roleContext,
          barrierDismissible: false,
          builder: (context) => const _OwnerLoginDialog(),
        );
        if (ownerPin == null) {
          return;
        }
      }

      if (role == UserRole.owner) {
        await _authController.loginOwnerWithPin(ownerPin ?? '');
      } else {
        await _authController.loginAs(role);
      }
      await _loadDataForRole();
      if (!mounted || !roleContext.mounted) {
        return;
      }
      setState(() {
        _receipt = null;
        _selected = role == UserRole.owner
            ? _PageKey.dashboard
            : _PageKey.checkout;
      });
      showSnack(roleContext, 'Mode ${role.label} aktif');
    } catch (error) {
      if (mounted && roleContext.mounted) {
        showSnack(roleContext, error.toString());
      }
    }
  }

  Widget _buildBody() {
    final receipt = _receipt;
    if (receipt != null) {
      return ReceiptView(
        transaction: receipt,
        onBackToCheckout: () => setState(() {
          _receipt = null;
          _selected = _PageKey.checkout;
        }),
        onClose: () => setState(() => _receipt = null),
      );
    }

    return switch (_selected) {
      _PageKey.dashboard => DashboardView(
        productController: _productController,
        reportController: _reportController,
        onProducts: () => setState(() => _selected = _PageKey.products),
      ),
      _PageKey.checkout => CheckoutView(
        productController: _productController,
        checkoutController: _checkoutController,
        onCompleted: _handleCompletedSale,
      ),
      _PageKey.products => ProductsView(
        productController: _productController,
        role: _authController.role,
      ),
      _PageKey.report => ReportView(reportController: _reportController),
      _PageKey.history => HistoryView(
        transactionController: _transactionController,
        role: _authController.role,
        onOpenReceipt: (transaction) => setState(() => _receipt = transaction),
      ),
    };
  }

  Future<void> _handleCompletedSale(SaleTransaction transaction) async {
    setState(() => _receipt = transaction);
    await _productController.load();
    final roleDataLoads = <Future<void>>[];
    if (_authController.role.canViewReports) {
      roleDataLoads.add(_reportController.load());
    }
    if (_authController.role.canViewHistory) {
      roleDataLoads.add(_transactionController.load());
    }
    if (roleDataLoads.isNotEmpty) {
      await Future.wait(roleDataLoads);
    }
  }

  List<_Destination> _destinationsForRole(UserRole role) {
    if (role == UserRole.cashier) {
      return const [
        _Destination(_PageKey.checkout, 'Kasir', Icons.point_of_sale),
        _Destination(_PageKey.history, 'Riwayat', Icons.receipt_long),
        _Destination(_PageKey.products, 'Produk', Icons.inventory_2),
      ];
    }

    return const [
      _Destination(_PageKey.dashboard, 'Dashboard', Icons.dashboard),
      _Destination(_PageKey.checkout, 'Kasir', Icons.point_of_sale),
      _Destination(_PageKey.products, 'Produk', Icons.inventory_2),
      _Destination(_PageKey.report, 'Laporan', Icons.summarize),
      _Destination(_PageKey.history, 'Riwayat', Icons.receipt_long),
    ];
  }
}

class _Shell extends StatelessWidget {
  const _Shell({
    required this.apiBaseUrl,
    required this.authController,
    required this.selected,
    required this.receipt,
    required this.destinations,
    required this.body,
    required this.onSelect,
    required this.onRoleChanged,
  });

  final String apiBaseUrl;
  final AuthController authController;
  final _PageKey selected;
  final SaleTransaction? receipt;
  final List<_Destination> destinations;
  final Widget body;
  final ValueChanged<_PageKey> onSelect;
  final void Function(BuildContext context, UserRole role) onRoleChanged;

  @override
  Widget build(BuildContext context) {
    final rawIndex = destinations.indexWhere(
      (destination) => destination.key == selected,
    );
    final currentIndex = rawIndex < 0 ? 0 : rawIndex;
    final currentTitle = receipt == null
        ? destinations[currentIndex].label
        : 'Struk';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final sidebar = _Sidebar(
          apiBaseUrl: apiBaseUrl,
          title: currentTitle,
          selected: selected,
          receipt: receipt,
          destinations: destinations,
          role: authController.role,
          roleLoading: authController.loading,
          onSelect: onSelect,
          onRoleChanged: onRoleChanged,
        );
        final drawerWidth = constraints.maxWidth < 340
            ? constraints.maxWidth * 0.9
            : 292.0;

        return Scaffold(
          drawer: compact ? Drawer(width: drawerWidth, child: sidebar) : null,
          body: DecoratedBox(
            decoration: const BoxDecoration(color: Color(0xFFF5F7FA)),
            child: Row(
              children: [
                if (!compact) SizedBox(width: 292, child: sidebar),
                Expanded(
                  child: compact
                      ? Stack(
                          children: [
                            Positioned.fill(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 68),
                                child: body,
                              ),
                            ),
                            const _MobileSidebarButton(),
                          ],
                        )
                      : body,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.apiBaseUrl,
    required this.title,
    required this.selected,
    required this.receipt,
    required this.destinations,
    required this.role,
    required this.roleLoading,
    required this.onSelect,
    required this.onRoleChanged,
  });

  final String apiBaseUrl;
  final String title;
  final _PageKey selected;
  final SaleTransaction? receipt;
  final List<_Destination> destinations;
  final UserRole role;
  final bool roleLoading;
  final ValueChanged<_PageKey> onSelect;
  final void Function(BuildContext context, UserRole role) onRoleChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final minHeight = constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : 0.0;
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SidebarHeader(title: title),
                        const SizedBox(height: 18),
                        Text(
                          'Menu',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...destinations.map(
                          (destination) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _SidebarItem(
                              destination: destination,
                              selected:
                                  receipt == null &&
                                  selected == destination.key,
                              onTap: () => onSelect(destination.key),
                            ),
                          ),
                        ),
                        const Spacer(),
                        _ApiBadge(apiBaseUrl: apiBaseUrl),
                        const SizedBox(height: 10),
                        _OwnerModeCard(
                          role: role,
                          loading: roleLoading,
                          onRoleChanged: onRoleChanged,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MobileSidebarButton extends StatelessWidget {
  const _MobileSidebarButton();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 10,
      left: 12,
      child: Material(
        color: colors.surface,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        child: IconButton.filledTonal(
          onPressed: () => Scaffold.of(context).openDrawer(),
          icon: const Icon(Icons.menu),
          tooltip: 'Sidebar',
        ),
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.storefront, color: colors.onPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kasir Warung',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.onPrimaryContainer.withValues(alpha: 0.74),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              destination.icon,
              color: selected ? colors.onPrimary : colors.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                destination.label,
                style: TextStyle(
                  color: selected ? colors.onPrimary : colors.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApiBadge extends StatelessWidget {
  const _ApiBadge({required this.apiBaseUrl});

  final String apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        apiBaseUrl,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _OwnerModeCard extends StatelessWidget {
  const _OwnerModeCard({
    required this.role,
    required this.loading,
    required this.onRoleChanged,
  });

  final UserRole role;
  final bool loading;
  final void Function(BuildContext context, UserRole role) onRoleChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user, color: colors.onSecondaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Mode ${role.label}',
                  style: TextStyle(
                    color: colors.onSecondaryContainer,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: loading
                ? null
                : () => onRoleChanged(
                    context,
                    role == UserRole.owner ? UserRole.cashier : UserRole.owner,
                  ),
            icon: Icon(role == UserRole.owner ? Icons.logout : Icons.lock_open),
            label: Text(
              role == UserRole.owner ? 'Keluar Pemilik' : 'Login Pemilik',
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerLoginDialog extends StatefulWidget {
  const _OwnerLoginDialog();

  @override
  State<_OwnerLoginDialog> createState() => _OwnerLoginDialogState();
}

class _OwnerLoginDialogState extends State<_OwnerLoginDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.lock, color: colors.primary),
          const SizedBox(width: 10),
          const Expanded(child: Text('Login Pemilik')),
        ],
      ),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _pinController,
          autofocus: true,
          obscureText: _obscure,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'PIN pemilik',
            prefixIcon: const Icon(Icons.pin),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'PIN wajib diisi';
            }
            if (value.trim().length < 4) {
              return 'PIN minimal 4 digit';
            }
            return null;
          },
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.login),
          label: const Text('Masuk'),
        ),
      ],
    );
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    Navigator.pop(context, _pinController.text.trim());
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({
    required this.apiBaseUrl,
    required this.apiBaseUrls,
    required this.message,
    required this.onRetry,
  });

  final String apiBaseUrl;
  final List<String> apiBaseUrls;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final activeApi = apiBaseUrl.isEmpty ? 'belum dikonfigurasi' : apiBaseUrl;
    final attemptedApis = apiBaseUrls.isEmpty
        ? 'tidak ada'
        : apiBaseUrls.join(', ');
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Backend belum terhubung',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(message),
                  const SizedBox(height: 8),
                  Text(
                    'API aktif: $activeApi',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dicoba: $attemptedApis',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _PageKey { dashboard, checkout, products, report, history }

class _Destination {
  const _Destination(this.key, this.label, this.icon);

  final _PageKey key;
  final String label;
  final IconData icon;
}
