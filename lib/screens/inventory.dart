import 'package:sizer/sizer.dart';
import 'package:flutter/material.dart';
import 'package:smart_inventory/main.dart';
import 'package:smart_inventory/database/database_helper.dart';

// --- 2. INVENTORY MODULE ---
class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});
  @override
  InventoryPageState createState() => InventoryPageState();
}

class InventoryPageState extends RefreshableState<InventoryPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  List<Map<String, dynamic>> _filteredProducts = []; // For Search
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  // 1. Store the data in a variable instead of a FutureBuilder
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await DBProvider.db.getProducts();
    if (mounted) {
      setState(() {
        _products = data;
        _filteredProducts = data;
        _isLoading = false;
      });
    }
  }

  void _runFilter(String enteredKeyword) {
    List<Map<String, dynamic>> results = [];
    if (enteredKeyword.isEmpty) {
      results = _products;
    } else {
      results = _products
          .where(
            (user) => user["name"].toLowerCase().contains(
              enteredKeyword.toLowerCase(),
            ),
          )
          .toList();
    }
    setState(() {
      _filteredProducts = results;
    });
  }

  @override
  void refreshData() {
    _loadData(); // Updates the list silently
  }

  // Use this for internal updates (like after adding a product)

  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController stockController = TextEditingController();
  final TextEditingController costController = TextEditingController();

  void _refreshData() {
    setState(() {
      _loadData();
    });
  }

  // --- NEW: DELETION CONFIRMATION DIALOG ---
  void _confirmDelete(BuildContext context, int id, String name) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        // Use standard typography from the theme
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
        // Set the background of the dialog to be theme-aware
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
              // Use the error color from the theme (usually red/maroon)
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              await DBProvider.db.deleteProduct(id);
              Navigator.pop(ctx);
              _refreshData();
              // Adaptive SnackBar
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "$name deleted successfully",
                    style: TextStyle(color: colorScheme.onErrorContainer),
                  ),
                  backgroundColor: colorScheme.errorContainer,
                  behavior: SnackBarBehavior.floating,
                  margin: EdgeInsets.all(16),
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

  void _showProductDialog(
    BuildContext context, {
    Map<String, dynamic>? product,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isEditing = product != null;
    if (isEditing) {
      nameController.text = product['name'];
      priceController.text = product['price'].toString();
      stockController.text = product['stock'].toString();
      costController.text = product['cost'].toString();
    } else {
      nameController.clear();
      priceController.clear();
      stockController.clear();
      costController.clear();
    }
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isEditing ? Icons.edit : Icons.add_business,
              color: isDark ? Colors.white : Colors.indigo,
            ),
            SizedBox(width: 10),
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
                nameController,
                "Product Name",
                Icons.label_outline,
              ),
              SizedBox(height: 1.5.h),
              _buildTextField(
                priceController,
                "Selling Price (₹)",
                Icons.sell_outlined,
                isNumber: true,
              ),
              SizedBox(height: 1.5.h),
              _buildTextField(
                costController,
                "Cost Price (₹)",
                Icons.account_balance_wallet_outlined,
                isNumber: true,
              ),
              SizedBox(height: 1.5.h),
              _buildTextField(
                stockController,
                "Initial Stock",
                Icons.inventory_2_outlined,
                isNumber: true,
              ),
            ],
          ),
        ),
        actionsPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:isDark ? colorScheme.surfaceBright : Colors.indigo,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () async {
              if (nameController.text.isEmpty || priceController.text.isEmpty) {
                return;
              }
              if (isEditing) {
                await DBProvider.db.updateProduct(
                  product['id'],
                  nameController.text,
                  double.parse(priceController.text),
                  double.parse(costController.text),
                  int.parse(stockController.text),
                );
              } else {
                await DBProvider.db.addProduct(
                  nameController.text,
                  double.tryParse(priceController.text) ?? 0.0,
                  double.tryParse(costController.text) ?? 0.0,
                  int.tryParse(stockController.text) ?? 0,
                );
              }
              _loadData();
              Navigator.pop(dialogCtx);
              _refreshData();
            },
            child: Text(
              "SAVE PRODUCT",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget to keep the dialog code clean
  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isNumber = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          borderSide: BorderSide(color: Colors.indigo, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  @override
  void dispose() {
    // Clean up memory
    nameController.dispose();
    priceController.dispose();
    stockController.dispose();
    costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Detect theme and pull color scheme
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
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Search products...",
                  hintStyle: TextStyle(
                    color: appBarTheme.foregroundColor?.withValues(alpha: 0.7),
                  ),
                  border: InputBorder.none,
                ),
                onChanged: (value) => _runFilter(value),
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
                  _runFilter("");
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshData,
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
                return Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: 4.w,
                    vertical: 0.8.h,
                  ),
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    // Adapt card color to theme
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
                                  p['name'],
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "Price: ${formatter.format(p['price'])}",
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
                              // Use subtler shades for stock badges in dark mode
                              color: p['stock'] < 5
                                  ? (isDark
                                        ? Colors.red.withValues(alpha: 0.15)
                                        : Colors.red[50])
                                  : (isDark
                                        ? Colors.green.withValues(alpha: 0.15)
                                        : Colors.green[50]),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "Stock: ${p['stock']}",
                              style: TextStyle(
                                color: p['stock'] < 5
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
                                p['price'],
                                p['cost'],
                                p['stock'] + 5,
                              );
                              _refreshData();
                            },
                            icon: Icon(
                              Icons.add_box_outlined,
                              color: isDark ? Colors.greenAccent : Colors.green,
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
                                      : Colors.indigo, // Dynamic Indigo
                                  size: 20.sp,
                                ),
                                onPressed: () =>
                                    _showProductDialog(context, product: p),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                  size: 20.sp,
                                ),
                                onPressed: () =>
                                    _confirmDelete(context, p['id'], p['name']),
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
