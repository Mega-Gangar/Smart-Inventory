import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
    setState(() {
      int current = _itemCounters[productId] ?? 0;
      int newValue = current + delta;
      if (newValue >= 0 && newValue <= maxStock) {
        _itemCounters[productId] = newValue;
      }
    });
  }

  void _addToCart(Map<String, dynamic> product, BuildContext context) {
    int qty = _itemCounters[product['id']] ?? 0;
    if (qty <= 0) return;

    setState(() {
      _cart.add({
        'id': product['id'],
        'name': product['name'],
        'price': product['price'],
        'cost': product['cost'],
        'qty': qty,
      });
      _total += (product['price'] * qty);
      _itemCounters[product['id']] = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Added $qty x ${product['name']} to cart")),
    );
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
                  content: const Text("Are you sure you want to log out? Any unsaved sale progress will be lost."),
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
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Error logging out: $e")),
                          );
                        }
                      },
                      child: const Text("Logout", style: TextStyle(color: Colors.red)),
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
                    int currentCount = _itemCounters[id] ?? 0;

                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        title: Text(
                          item['name'],
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "Price: ${formatter.format(item['price'])} | Stock: $stock",
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
                              icon: Icon(Icons.add_circle, color: Colors.green),
                              onPressed: () => _updateCounter(id, 1, stock),
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
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Cart Items: ${_cart.length}",
                      style: TextStyle(fontSize: 16),
                    ),
                    Text(
                      "Total: ${formatter.format(_total)}",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
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