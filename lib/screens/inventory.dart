import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:smart_inventory/database/database_helper.dart';
import 'package:smart_inventory/main.dart'; // Contains global formatter

// --- INVENTORY MODULE ---
class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  InventoryPageState createState() => InventoryPageState();
}

class InventoryPageState extends RefreshableState<InventoryPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];

  bool _isLoading = true;
  bool _isSearching = false;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  /// Fetches products from DB once and updates state
  Future<void> _loadData() async {
    final data = await DBProvider.db.getProducts();

    if (mounted) {
      setState(() {
        _products = data;
        _isLoading = false;
      });
      _runFilter(_searchController.text);
    }
  }

  void _onSearchChanged() {
    _runFilter(_searchController.text);
  }

  /// Filters product list efficiently in memory
  void _runFilter(String enteredKeyword) {
    final query = enteredKeyword.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = List.from(_products);
      } else {
        _filteredProducts = _products.where((product) {
          final name = product['name']?.toString().toLowerCase() ?? '';
          return name.contains(query);
        }).toList();
      }
    });
  }

  @override
  void refreshData() {
    _loadData();
  }

  // --- DELETION CONFIRMATION DIALOG ---
  void _confirmDelete(BuildContext context, int id, String name) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          "Delete Product?",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        content: Text(
          "Are you sure you want to remove '$name' from inventory?",
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
        backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "CANCEL",
              style: TextStyle(color: isDark ? Colors.white : Colors.indigo),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              await DBProvider.db.deleteProduct(id);

              if (!ctx.mounted) return;
              Navigator.pop(ctx);

              _loadData();

              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "$name deleted successfully",
                    style: TextStyle(color: colorScheme.onErrorContainer),
                  ),
                  backgroundColor: colorScheme.errorContainer,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text("DELETE"),
          ),
        ],
      ),
    );
  }

  // --- ADD / EDIT PRODUCT TRIGGER ---
  Future<void> _showProductDialog(
      BuildContext context, {
        Map<String, dynamic>? product,
      }) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _ProductDialog(product: product),
    );

    if (result == null) return;

    final bool isEditing = product != null;

    if (isEditing) {
      await DBProvider.db.updateProduct(
        product['id'],
        result['name'],
        result['price'],
        result['cost'],
        result['stock'],
      );
    } else {
      await DBProvider.db.addProduct(
        result['name'],
        result['price'],
        result['cost'],
        result['stock'],
      );
    }

    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final appBarTheme = Theme.of(context).appBarTheme;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          cursorColor: appBarTheme.foregroundColor,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Search products...",
            hintStyle: TextStyle(
              color: appBarTheme.foregroundColor?.withValues(alpha: 0.7),
            ),
            border: InputBorder.none,
          ),
        )
            : const Text(
          "Inventory Management",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: appBarTheme.backgroundColor,
        iconTheme: appBarTheme.iconTheme,
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductDialog(context),
        backgroundColor: isDark ? colorScheme.surfaceBright : Colors.indigo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3.h)),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredProducts.isEmpty
          ? Center(
        child: Text(
          _isSearching
              ? "No matching products found."
              : "Stock is empty. Add products.",
          style: TextStyle(
            fontSize: 16.sp,
            color: isDark ? Colors.white70 : Colors.grey[600],
          ),
        ),
      )
          : ListView.builder(
        itemCount: _filteredProducts.length,
        itemBuilder: (itemCtx, i) {
          final p = _filteredProducts[i];
          final double price = (p['price'] as num?)?.toDouble() ?? 0.0;
          final int stock = (p['stock'] as num?)?.toInt() ?? 0;

          return Container(
            margin: EdgeInsets.symmetric(
              horizontal: 4.w,
              vertical: 0.8.h,
            ),
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: isDark ? 0.2 : 0.03,
                  ),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['name']?.toString() ?? 'Product',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Price: ${formatter.format(price)}",
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white70
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 3.w,
                        vertical: 0.5.h,
                      ),
                      decoration: BoxDecoration(
                        color: stock < 5
                            ? (isDark
                            ? Colors.red.withValues(alpha: 0.15)
                            : Colors.red[50])
                            : (isDark
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.green[50]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "Stock: $stock",
                        style: TextStyle(
                          color: stock < 5
                              ? Colors.redAccent
                              : (isDark
                              ? Colors.greenAccent
                              : Colors.green[700]),
                          fontWeight: FontWeight.bold,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  ],
                ),
                Divider(
                  height: 2.h,
                  color: isDark ? Colors.white10 : Colors.grey[200],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        await DBProvider.db.updateProduct(
                          p['id'],
                          p['name'],
                          price,
                          (p['cost'] as num?)?.toDouble() ?? 0.0,
                          stock + 5,
                        );
                        _loadData();
                      },
                      icon: Icon(
                        Icons.add_box_outlined,
                        color: isDark
                            ? Colors.greenAccent
                            : Colors.green,
                        size: 16.sp,
                      ),
                      label: Text(
                        "Refill +5",
                        style: TextStyle(
                          color: isDark
                              ? Colors.greenAccent
                              : Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 15.sp,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.edit_outlined,
                            color: isDark
                                ? Colors.white
                                : Colors.indigo,
                            size: 20.sp,
                          ),
                          onPressed: () => _showProductDialog(
                            context,
                            product: p,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                            size: 20.sp,
                          ),
                          onPressed: () => _confirmDelete(
                            context,
                            p['id'],
                            p['name']?.toString() ?? '',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// --- SELF-CONTAINED PRODUCT FORM DIALOG ---
class _ProductDialog extends StatefulWidget {
  final Map<String, dynamic>? product;

  const _ProductDialog({this.product});

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _costController;
  late final TextEditingController _stockController;

  @override
  void initState() {
    super.initState();
    final isEditing = widget.product != null;
    _nameController = TextEditingController(
      text: isEditing ? widget.product!['name']?.toString() : '',
    );
    _priceController = TextEditingController(
      text: isEditing ? widget.product!['price']?.toString() : '',
    );
    _costController = TextEditingController(
      text: isEditing ? widget.product!['cost']?.toString() : '',
    );
    _stockController = TextEditingController(
      text: isEditing ? widget.product!['stock']?.toString() : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Widget _buildTextField(
      TextEditingController controller,
      String label,
      IconData icon,
      bool isDark, {
        bool isNumber = false,
      }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          color: isDark ? Colors.white : Colors.indigo,
          size: 20,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.indigo, width: 2),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final bool isEditing = widget.product != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(
            isEditing ? Icons.edit : Icons.add_business,
            color: isDark ? Colors.white : Colors.indigo,
          ),
          const SizedBox(width: 10),
          Text(
            isEditing ? "Update Product" : "New Product",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.sp),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField(
              _nameController,
              "Product Name",
              Icons.label_outline,
              isDark,
            ),
            SizedBox(height: 1.5.h),
            _buildTextField(
              _priceController,
              "Selling Price (₹)",
              Icons.sell_outlined,
              isDark,
              isNumber: true,
            ),
            SizedBox(height: 1.5.h),
            _buildTextField(
              _costController,
              "Cost Price (₹)",
              Icons.account_balance_wallet_outlined,
              isDark,
              isNumber: true,
            ),
            SizedBox(height: 1.5.h),
            _buildTextField(
              _stockController,
              "Initial Stock",
              Icons.inventory_2_outlined,
              isDark,
              isNumber: true,
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? colorScheme.surfaceBright : Colors.indigo,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          onPressed: () {
            final name = _nameController.text.trim();
            final priceText = _priceController.text.trim();

            if (name.isEmpty || priceText.isEmpty) return;

            final price = double.tryParse(priceText) ?? 0.0;
            final cost = double.tryParse(_costController.text.trim()) ?? 0.0;
            final stock = int.tryParse(_stockController.text.trim()) ?? 0;

            Navigator.pop(context, {
              'name': name,
              'price': price,
              'cost': cost,
              'stock': stock,
            });
          },
          child: const Text(
            "SAVE PRODUCT",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}