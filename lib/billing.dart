import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sizer/sizer.dart';
import 'main.dart';

// --- 1. BILLING MODULE ---
class BillingPage extends StatefulWidget {
  const BillingPage({super.key});
  @override
  _BillingPageState createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  Map<int, int> _itemCounters = {};
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
    int qty = _itemCounters[product['id']] ?? 0;
    if (qty <= 0 && (product['stock'] ?? 0) > 0) {
      qty = 1;
    } else if (qty <= 0) {
      return;
    }
    setState(() {
      _cart.add({
        'id': id,
        'name': product['name'],
        'price': product['price'],
        'cost': product['cost'],
        'qty': qty,
      });
      _total += (product['price'] * qty);
      _itemCounters[id] = 0;
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Added $qty x ${product['name']} to cart"),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.only(bottom: 132, left: 16, right: 16),
      ),
    );
  }

  void _showCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(3.h))),
      builder: (context) => StatefulBuilder( // StatefulBuilder allows deleting items from inside the modal
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.all(5.w),
          height: 60.h, // Takes up 60% of the screen
          child: Column(
            children: [
              Text("Review Cart", style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
              Divider(),
              Expanded(
                child: _cart.isEmpty
                    ? Center(child: Text("Cart is empty", style: TextStyle(fontSize: 15.sp)))
                    : ListView.builder(
                  itemCount: _cart.length,
                  itemBuilder: (context, i) {
                    final item = _cart[i];
                    return ListTile(
                      title: Text(item['name'], style: TextStyle(fontSize: 16.sp)),
                      subtitle: Text("${item['qty']} x ${formatter.format(item['price'])}"),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.red, size: 20.sp),
                        onPressed: () {
                          setState(() {
                            _total -= (item['price'] * item['qty']);
                            _cart.removeAt(i);
                          });
                          setModalState(() {}); // Refresh the modal list
                          if(_cart.isEmpty) Navigator.pop(context);
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
    return Scaffold(
      appBar: AppBar(
        title: Text("New Sale"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
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
                          Navigator.pop(context);
                          // 1. Sign out from Firebase Auth
                          await FirebaseAuth.instance.signOut();
                          // 2. Clear Google Sign-In session (Important if you used Google login)
                          // This prevents the app from auto-selecting the same Google account next time
                          final googleSignIn = GoogleSignIn();
                          if (await googleSignIn.isSignedIn()) {
                            await googleSignIn.signOut();
                          }
                          // It pops everything until it reaches the initial route (the StreamBuilder)
                          if (context.mounted) {
                            Navigator.of(
                              context,
                            ).popUntil((route) => route.isFirst);
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Error in logging out")),
                          );
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
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: DBProvider.db.getProducts(),
              builder: (ctx, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, i) {
                    var item = snapshot.data![i];
                    int id = item['id'];
                    int stock = item['stock'];
                    String itemName = item['name'];
                    int currentCount = _itemCounters[id] ?? 0;

                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        title: Text(
                          item['name'],
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "Price: ${formatter.format(item['price'])} | \nStock: $stock",
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.remove_circle,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => _updateCounter(id, -1, stock),
                            ),
                            Text(
                              "$currentCount",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle,
                                color: Colors.green,
                              ),
                              onPressed: (_itemCounters[id] ?? 0) < stock
                                  ? () => _updateCounter(id, 1, stock)
                                  : () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).hideCurrentSnackBar();
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "Only $stock units of $itemName available in stock!",
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          duration: const Duration(seconds: 2),
                                          margin: const EdgeInsets.only(
                                            bottom: 132,
                                            left: 16,
                                            right: 16,
                                          ),
                                        ),
                                      );
                                    },
                            ),
                            ElevatedButton(
                              onPressed: currentCount > 0
                                  ? () => _addToCart(item, context)
                                  : null,
                              child: Text("Add"),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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

                    // --- REPLACE YOUR OLD "Cart Items" TEXT WITH THIS ---
                    InkWell(
                      onTap: _showCartSheet, // Calls the function you created
                      child: Row(
                        children: [
                          Icon(Icons.shopping_cart, color: Colors.indigo, size: 20.sp),
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
                            setState(() {
                              _cart = [];
                              _total = 0;
                              _itemCounters.clear();
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Sale Successfully Processed"),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                duration: const Duration(seconds: 2),
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
                      style: TextStyle(fontSize: 16),
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
