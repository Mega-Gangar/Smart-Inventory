import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:smart_inventory/database/database_helper.dart';
import 'package:smart_inventory/main.dart'; // Global formatter & RefreshableState
import 'package:smart_inventory/services/qr_upi.dart';

// --- BILLING MODULE ---
class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  BillingPageState createState() => BillingPageState();
}

class BillingPageState extends RefreshableState<BillingPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  final Map<int, int> _itemCounters = {};
  final List<Map<String, dynamic>> _cart = [];

  double _total = 0.0;
  bool _isLoading = true;
  bool _isSearching = false;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  /// Fetches products from database without screen flickering
  Future<void> _fetchProducts() async {
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

  /// Filters in-memory product list safely
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
    _fetchProducts();
  }

  int _getQtyInCart(int productId) {
    int count = 0;
    for (var item in _cart) {
      if (item['id'] == productId) {
        count += (item['qty'] as num?)?.toInt() ?? 0;
      }
    }
    return count;
  }

  void _updateCounter(int productId, int delta, int maxStock) {
    final int inCart = _getQtyInCart(productId);
    final int realAvailable = maxStock - inCart;
    final int current = _itemCounters[productId] ?? 0;
    final int newValue = current + delta;

    if (newValue >= 0 && newValue <= realAvailable) {
      setState(() {
        _itemCounters[productId] = newValue;
      });
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
  }

  void _addToCart(Map<String, dynamic> product, BuildContext context) {
    final int id = (product['id'] as num?)?.toInt() ?? 0;
    final double price = (product['price'] as num?)?.toDouble() ?? 0.0;
    final double cost = (product['cost'] as num?)?.toDouble() ?? 0.0;
    final String name = product['name']?.toString() ?? '';
    final int qtyToAdd = _itemCounters[id] ?? 0;

    if (qtyToAdd <= 0) return;

    setState(() {
      final int existingIndex =
      _cart.indexWhere((element) => element['id'] == id);

      if (existingIndex != -1) {
        final currentQty = (_cart[existingIndex]['qty'] as num?)?.toInt() ?? 0;
        _cart[existingIndex]['qty'] = currentQty + qtyToAdd;
      } else {
        _cart.add({
          'id': id,
          'name': name,
          'price': price,
          'cost': cost,
          'qty': qtyToAdd,
        });
      }

      _total += (price * qtyToAdd);
      _itemCounters[id] = 0; // Reset counter after adding
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Added $qtyToAdd x $name to cart"),
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(2.5.h)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final colorScheme = Theme.of(context).colorScheme;
          return Container(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
            constraints: BoxConstraints(maxHeight: 70.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Sheet Drag Handle
                Container(
                  width: 12.w,
                  height: 0.4.h,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                SizedBox(height: 1.5.h),

                // 2. Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.shopping_bag_outlined,
                          color: isDark ? Colors.white : Colors.indigo,
                          size: 20.sp,
                        ),
                        SizedBox(width: 2.w),
                        Text(
                          "Review Cart (${_cart.length})",
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (_cart.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _cart.clear();
                            _total = 0.0;
                            _itemCounters.clear();
                          });
                          setModalState(() {});
                          if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                        },
                        icon: Icon(
                          Icons.delete_sweep_outlined,
                          color: Colors.redAccent,
                          size: 18.sp,
                        ),
                        label: Text(
                          "Clear",
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 16.5.sp,
                          ),
                        ),
                      ),
                  ],
                ),
                Divider(
                  thickness: 1,
                  color: isDark ? Colors.white10 : Colors.grey[200],
                ),

                // 3. Cart Items List / Empty State
                Expanded(
                  child: _cart.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.remove_shopping_cart_outlined,
                          size: 42.sp,
                          color: isDark
                              ? Colors.grey[600]
                              : Colors.grey[400],
                        ),
                        SizedBox(height: 1.5.h),
                        Text(
                          "Your cart is empty",
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                      : ListView.separated(
                    itemCount: _cart.length,
                    separatorBuilder: (_, _) => SizedBox(height: 1.h),
                    itemBuilder: (context, i) {
                      final item = _cart[i];
                      final int _ = (item['id'] as num?)?.toInt() ?? 0;
                      final String name = item['name']?.toString() ?? '';
                      final double price =
                          (item['price'] as num?)?.toDouble() ?? 0.0;
                      final int qty = (item['qty'] as num?)?.toInt() ?? 0;
                      final double itemTotal = price * qty;

                      return Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 3.w,
                          vertical: 1.2.h,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? Colors.white10
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Item Info & Unit Pricing
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 15.5.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 0.4.h),
                                  Text(
                                    "${formatter.format(price)} x $qty = ${formatter.format(itemTotal)}",
                                    style: TextStyle(
                                      fontSize: 14.8.sp,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // In-Cart Stepper (+ / - / delete)
                            Row(
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    setState(() {
                                      if (qty > 1) {
                                        _cart[i]['qty'] = qty - 1;
                                        _total -= price;
                                      } else {
                                        _cart.removeAt(i);
                                        _total -= price;
                                      }
                                      if (_total < 0) _total = 0.0;
                                    });
                                    setModalState(() {});
                                    if (_cart.isEmpty && sheetCtx.mounted) {
                                      Navigator.pop(sheetCtx);
                                    }
                                  },
                                  child: Padding(
                                    padding: EdgeInsets.all(1.w),
                                    child: Icon(
                                      qty == 1
                                          ? Icons.delete_outline
                                          : Icons.remove_circle_outline,
                                      color: Colors.redAccent,
                                      size: 21.sp,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 2.w,
                                  ),
                                  child: Text(
                                    "$qty",
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    setState(() {
                                      _cart[i]['qty'] = qty + 1;
                                      _total += price;
                                    });
                                    setModalState(() {});
                                  },
                                  child: Padding(
                                    padding: EdgeInsets.all(1.w),
                                    child: Icon(
                                      Icons.add_circle_outline,
                                      color: isDark
                                          ? Colors.greenAccent
                                          : Colors.green,
                                      size: 21.sp,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // 4. Cart Summary Footer Bar
                if (_cart.isNotEmpty) ...[
                  Divider(
                    thickness: 1,
                    color: isDark ? Colors.white10 : Colors.grey[200],
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 0.5.h, bottom: 0.5.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Subtotal",
                              style: TextStyle(
                                fontSize: 17.sp,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                            Text(
                              formatter.format(_total),
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.greenAccent[400]
                                    : Colors.indigo,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            isDark ?  colorScheme.surfaceBright : Colors.indigo,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: 5.w,
                              vertical: 1.2.h,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                          },
                          icon: const Icon(Icons.check_circle_outline),
                          label: Text(
                            "Done",
                            style: TextStyle(
                              fontSize: 17.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
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
          "New Sale",
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
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                ? Center(
              child: Text(
                "No products available. Add some in Stock.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.sp,
                  color: isDark ? Colors.white70 : Colors.grey[600],
                ),
              ),
            )
                : _filteredProducts.isEmpty
                ? const Center(
              child: Text("No matching products found."),
            )
                : ListView.builder(
              itemCount: _filteredProducts.length,
              itemBuilder: (context, i) {
                final item = _filteredProducts[i];
                final int id =
                    (item['id'] as num?)?.toInt() ?? 0;
                final int stock =
                    (item['stock'] as num?)?.toInt() ?? 0;
                final double price =
                    (item['price'] as num?)?.toDouble() ?? 0.0;
                final int currentCount =
                    _itemCounters[id] ?? 0;
                final bool isOutOfStock = stock <= 0;

                return Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: 4.w,
                    vertical: 0.8.h,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.2 : 0.04,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(3.w),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name']?.toString() ?? '',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.sp,
                                ),
                              ),
                              SizedBox(height: 0.5.h),
                              Text(
                                "Price: ${formatter.format(price)}",
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.grey[600],
                                ),
                              ),
                              Text(
                                "In Stock: $stock",
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: stock < 5
                                      ? Colors.redAccent
                                      : (isDark
                                      ? Colors.greenAccent[400]
                                      : Colors.green[700]),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Stepper
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => _updateCounter(
                                id,
                                -1,
                                stock,
                              ),
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
                              onPressed: (!isOutOfStock &&
                                  currentCount < stock)
                                  ? () => _updateCounter(
                                id,
                                1,
                                stock,
                              )
                                  : null,
                              icon: Icon(
                                Icons.add_circle_outline,
                                color: isOutOfStock
                                    ? Colors.grey
                                    : (isDark
                                    ? Colors.greenAccent
                                    : Colors.green),
                                size: 23.sp,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isOutOfStock
                                ? (isDark
                                ? Colors.grey[800]
                                : Colors.grey[300])
                                : Colors.indigo,
                            foregroundColor: isOutOfStock
                                ? Colors.grey[500]
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          onPressed: (currentCount > 0 &&
                              !isOutOfStock)
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

          // Checkout Section
          Divider(
            thickness: 1,
            color: isDark ? Colors.white10 : Colors.grey[300],
          ),
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: _showCartSheet,
                      child: Row(
                        children: [
                          Icon(
                            Icons.shopping_cart,
                            color: isDark ? Colors.white : colorScheme.primary,
                            size: 20.sp,
                          ),
                          SizedBox(width: 2.w),
                          Text(
                            "Items: ${_cart.length}",
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.indigo,
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
                        color: isDark ? Colors.white : Colors.indigo,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      isDark ? colorScheme.surfaceBright : Colors.indigo,
                      foregroundColor:
                      isDark ? Colors.white : colorScheme.onPrimary,
                      disabledBackgroundColor:
                      isDark ? Colors.grey[800] : Colors.grey[300],
                      disabledForegroundColor:
                      isDark ? Colors.grey[600] : Colors.grey[500],
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _cart.isEmpty
                        ? null
                        : () async {
                      final double finalAmount = _total;
                      final bool? isPaid = await QrUpi.showUPIDialog(
                        context,
                        finalAmount,
                      );

                      if (isPaid == true) {
                        await DBProvider.db.completeSale(_cart);
                        await _fetchProducts();

                        if (!mounted) return;
                        setState(() {
                          _cart.clear();
                          _total = 0.0;
                          _itemCounters.clear();
                        });

                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Sale Successfully Completed"),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    child: const Text(
                      "COMPLETE SALE",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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