import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:smart_inventory/main.dart';
import 'package:smart_inventory/database/database_helper.dart';
// --- 2. INVENTORY MODULE ---
class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});
  @override
  _InventoryPageState createState() => _InventoryPageState();
}

class _InventoryPageState extends RefreshableState<InventoryPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
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
        _isLoading = false;
      });
    }
  }

  @override
  void refreshData() {
    _loadData(); // Updates the list silently
  }

  // Use this for internal updates (like after adding a product)
  void _refreshUI() {
    _loadData();
  }

  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController stockController = TextEditingController();
  final TextEditingController costController = TextEditingController();
  Key _refreshKey = UniqueKey();

  void _refreshData() {
    setState(() {
      _refreshKey = UniqueKey();
    });
  }

  // --- NEW: DELETION CONFIRMATION DIALOG ---
  void _confirmDelete(BuildContext context, int id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Delete Product?"),
        content: Text(
          "Are you sure you want to remove '$name' from inventory?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("CANCEL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await DBProvider.db.deleteProduct(id);
              Navigator.pop(ctx);
              _refreshData();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("$name deleted successfully"),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Text("DELETE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showProductDialog(BuildContext context, {Map<String, dynamic>? product}) {
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

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(isEditing ? Icons.edit : Icons.add_business, color: Colors.indigo),
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
              _buildTextField(nameController, "Product Name", Icons.label_outline),
              SizedBox(height: 1.5.h),
              _buildTextField(priceController, "Selling Price (₹)", Icons.sell_outlined, isNumber: true),
              SizedBox(height: 1.5.h),
              _buildTextField(costController, "Cost Price (₹)", Icons.account_balance_wallet_outlined, isNumber: true),
              SizedBox(height: 1.5.h),
              _buildTextField(stockController, "Initial Stock", Icons.inventory_2_outlined, isNumber: true),
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
              backgroundColor: Colors.indigo,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () async {
              if (nameController.text.isEmpty || priceController.text.isEmpty) return;

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
            child: Text("SAVE PRODUCT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

// Helper widget to keep the dialog code clean
  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.indigo, size: 20),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Inventory Management",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductDialog(context),
        backgroundColor: Colors.indigo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3.h)),
        child: Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading && _products.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<Map<String, dynamic>>>(
        key: _refreshKey,
        future: DBProvider.db.getProducts(),
        builder: (ctx, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.isEmpty) {
            return Center(child: Text("Stock is empty. Add products."));
          }
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (itemCtx, i) {
              var p = snapshot.data![i];
              return Container(
                margin: EdgeInsets.symmetric(
                  horizontal: 4.w,
                  vertical: 0.8.h,
                ),
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
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
                                style: TextStyle(color: Colors.grey),
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
                            color: p['stock'] < 5
                                ? Colors.red[50]
                                : Colors.green[50],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "Stock: ${p['stock']}",
                            style: TextStyle(
                              color: p['stock'] < 5
                                  ? Colors.red
                                  : Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Divider(height: 2.h), // Separates info from actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment
                          .spaceBetween, // Pushes buttons to opposite sides
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
                            color: Colors.green,
                            size: 16.sp,
                          ),
                          label: Text(
                            "Refill +5",
                            style: TextStyle(
                              color: Colors.green,
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
                                color: Colors.indigo,
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
                              onPressed: () => _confirmDelete(
                                context,
                                p['id'],
                                p['name'],
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
          );
        },
      ),
    );
  }
}