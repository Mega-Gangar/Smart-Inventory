import 'package:sizer/sizer.dart';
import 'package:flutter/material.dart';
import 'package:smart_inventory/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:smart_inventory/database/database_helper.dart';

// --- 1. BILLING MODULE ---
class BillingPage extends StatefulWidget {
  const BillingPage({super.key});
  @override
  BillingPageState createState() => BillingPageState();
}

class BillingPageState extends RefreshableState<BillingPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  // 1. New variables to hold state locally
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = []; // For Search
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProducts(); // Initial load
  }

  // 2. Optimized data fetcher (no flickering)
  Future<void> _fetchProducts() async {
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
    _fetchProducts(); // Silent background update
  }

  final Map<int, int> _itemCounters = {};
  List<Map<String, dynamic>> _cart = [];
  double _total = 0;

  void _updateCounter(int productId, int delta, int maxStock) {
    int inCart = _getQtyInCart(productId);
    int realAvailable = maxStock - inCart;
    setState(() {
      int current = _itemCounters[productId] ?? 0;
      int newValue = current + delta;

      if (newValue >= 0 && newValue <= realAvailable) {
        _itemCounters[productId] = newValue;
      } else if (newValue > realAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Total in cart selection cannot exceed $maxStock"),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.only(bottom: 132, left: 16, right: 16),
          ),
        );
      }
    });
  }

  void _addToCart(Map<String, dynamic> product, BuildContext context) {
    int id = product['id'];
    int qtyToAdd = _itemCounters[id] ?? 0;
    if (qtyToAdd <= 0) return;

    setState(() {
      // Check if item already exists in cart
      int existingIndex = _cart.indexWhere((element) => element['id'] == id);

      if (existingIndex != -1) {
        // Update existing row
        _cart[existingIndex]['qty'] += qtyToAdd;
      } else {
        // Add new row
        _cart.add({
          'id': id,
          'name': product['name'],
          'price': product['price'],
          'cost': product['cost'],
          'qty': qtyToAdd,
        });
      }
      _total += (product['price'] * qtyToAdd);
      _itemCounters[id] = 0; // Reset counter after adding
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Added $qtyToAdd x ${product['name']} to cart"),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.only(bottom: 132, left: 16, right: 16),
      ),
    );
  }

  void _showCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(3.h)),
      ),
      builder: (context) => StatefulBuilder(
        // StatefulBuilder allows deleting items from inside the modal
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.all(5.w),
          height: 60.h, // Takes up 60% of the screen
          child: Column(
            children: [
              Text(
                "Review Cart",
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
              ),
              Divider(),
              Expanded(
                child: _cart.isEmpty
                    ? Center(
                        child: Text(
                          "Cart is empty",
                          style: TextStyle(fontSize: 15.sp),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _cart.length,
                        itemBuilder: (context, i) {
                          final item = _cart[i];
                          return ListTile(
                            title: Text(
                              item['name'],
                              style: TextStyle(fontSize: 16.sp),
                            ),
                            subtitle: Text(
                              "${item['qty']} x ${formatter.format(item['price'])}",
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                                size: 20.sp,
                              ),
                              onPressed: () {
                                setState(() {
                                  _total -= (item['price'] * item['qty']);
                                  _cart.removeAt(i);
                                });
                                setModalState(() {}); // Refresh the modal list
                                if (_cart.isEmpty) Navigator.pop(context);
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _getQtyInCart(int productId) {
    int count = 0;
    for (var item in _cart) {
      if (item['id'] == productId) {
        count += (item['qty'] as int);
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                cursorColor: Colors.white,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Search products...",
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: (value) => _runFilter(value),
              )
            : const Text(
                "New Sale",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
        backgroundColor: Colors.indigo,
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
                  _runFilter(""); // Reset filter
                }
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            tooltip: "Logout from this account",
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Logout"),
                  content: const Text(
                    "Are you sure you want to log out? Any unsaved sale progress will be lost.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context), // Cancel
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () async {
                        try {
                          Navigator.pop(context); // Close the dialog
                          // 1. Sign out from Firebase Auth
                          await FirebaseAuth.instance.signOut();
                          // 2. Clear Google Sign-In session safely (v7.2.0 compatible)
                          final googleSignIn = GoogleSignIn.instance;
                          await googleSignIn.initialize();
                          await googleSignIn.signOut();
                          // 3. Navigate back to login screen
                          if (context.mounted) {
                            Navigator.of(
                              context,
                            ).popUntil((route) => route.isFirst);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error logging out: $e")),
                            );
                          }
                        }
                      },
                      child: const Text(
                        "Logout",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_isLoading == false && _products.isEmpty)
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "No products available. Add some in Stock.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : _filteredProducts.isEmpty
                ? const Center(child: Text("No matching products found."))
                : ListView.builder(
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, i) {
                      final item = _filteredProducts[i];
                      int id = item['id'];
                      int stock = item['stock'];
                      int currentCount = _itemCounters[id] ?? 0;
                      bool isOutOfStock = stock <= 0;

                      return Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: 4.w,
                          vertical: 0.8.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(3.w),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['name'],
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16.sp,
                                      ),
                                    ),
                                    SizedBox(height: 0.5.h),
                                    Text(
                                      "Price: ${formatter.format(item['price'])}",
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      "In Stock: $stock",
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        color: stock < 5
                                            ? Colors.red
                                            : Colors.green[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Modern Stepper
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () =>
                                        _updateCounter(id, -1, stock),
                                    icon: Icon(
                                      Icons.remove_circle_outline,
                                      color: Colors.redAccent,
                                      size: 23.sp,
                                    ),
                                  ),
                                  Text(
                                    "$currentCount",
                                    style: TextStyle(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed:
                                        (!isOutOfStock && currentCount < stock)
                                        ? () => _updateCounter(id, 1, stock)
                                        : null, // Disables if out of stock
                                    icon: Icon(
                                      Icons.add_circle_outline,
                                      color: isOutOfStock
                                          ? Colors.grey
                                          : Colors.green, // Visual feedback
                                      size: 23.sp,
                                    ),
                                  ),
                                ],
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isOutOfStock
                                      ? Colors.grey[300]
                                      : Colors.indigo,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 2.w,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: (currentCount > 0 && !isOutOfStock)
                                    ? () => _addToCart(item, context)
                                    : null,
                                child: Text(
                                  isOutOfStock ? "Sold Out" : "Add",
                                  style: TextStyle(fontSize: 15.sp),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Divider(thickness: 2),
          Container(
            padding: EdgeInsets.all(4.w),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: _showCartSheet, // Calls the function you created
                      child: Row(
                        children: [
                          Icon(
                            Icons.shopping_cart,
                            color: Colors.indigo,
                            size: 20.sp,
                          ),
                          SizedBox(width: 2.w),
                          Text(
                            "Items: ${_cart.length}",
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Text(
                      "Total: ${formatter.format(_total)}",
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: _cart.isEmpty
                        ? null
                        : () async {
                            await DBProvider.db.completeSale(_cart);
                            await _fetchProducts(); //updating product's stock realtime
                            setState(() {
                              _cart = [];
                              _total = 0;
                              _itemCounters.clear();
                              _runFilter(_searchController.text);
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Sale Successfully Processed"),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                duration: const Duration(seconds: 1),
                                margin: const EdgeInsets.only(
                                  bottom: 132,
                                  left: 16,
                                  right: 16,
                                ),
                              ),
                            );
                          },
                    child: Text(
                      "COMPLETE SALE",
                      style: TextStyle(fontSize: 16, color: Colors.indigo),
                    ),
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
