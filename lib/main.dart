import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dashboard.dart';
import 'firebase_options.dart';
import 'login.dart';
import 'billing.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const SmartBillingApp());
}

final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

class SmartBillingApp extends StatelessWidget {
  const SmartBillingApp({super.key});
  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(primarySwatch: Colors.indigo, useMaterial3: true),
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return const HomeScreen();
              }
              return const LoginPage();
            },
          ),
        );
      },
    );
  }
}

// --- DATABASE HELPER ---
class DBProvider {
  static final DBProvider db = DBProvider._();
  DBProvider._();

  static Database? _database;
  Future<Database> get database async => _database ??= await initDB();

  Future<Database> initDB() async {
    String path = join(await getDatabasesPath(), 'business.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE products(id INTEGER PRIMARY KEY, name TEXT, price REAL, cost REAL, stock INTEGER CHECK (stock >= 0))', // Added CHECK
        );
        await db.execute(
          'CREATE TABLE sales(id INTEGER PRIMARY KEY, total REAL, date TEXT, items TEXT)',
        );
      },
    );
  }

  Future<void> addProduct(
    String name,
    double price,
    double cost,
    int stock,
  ) async {
    final dbClient = await database;
    await dbClient.insert('products', {
      'name': name,
      'price': price,
      'cost': cost,
      'stock': stock,
    });
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    final dbClient = await database;
    return await dbClient.query('products');
  }

  Future<void> completeSale(List<Map<String, dynamic>> cartItems) async {
    final dbClient = await database;
    double total = cartItems.fold(
      0,
      (sum, item) => sum + (item['price'] * item['qty']),
    );
    String itemsJson = jsonEncode(cartItems);

    await dbClient.transaction((txn) async {
      // 1. Insert the Sale Record
      await txn.insert('sales', {
        'total': total,
        'date': DateTime.now().toString(),
        'items': itemsJson,
      });

      // 2. Update Stock for each item
      for (var item in cartItems) {
        await txn.rawUpdate(
          'UPDATE products SET stock = stock - ? WHERE id = ?',
          [item['qty'], item['id']],
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getSales({String? year}) async {
    final dbClient = await database;
    if (year != null) {
      return await dbClient.query(
        'sales',
        where: "strftime('%Y', date) = ?",
        whereArgs: [year],
        orderBy: 'id DESC',
      );
    }
    return await dbClient.query('sales', orderBy: 'id DESC');
  }

  Future<void> updateProduct(
    int id,
    String name,
    double price,
    double cost,
    int stock,
  ) async {
    final dbClient = await database;
    await dbClient.update(
      'products',
      {'name': name, 'price': price, 'cost': cost, 'stock': stock},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteProduct(int id) async {
    final dbClient = await database;
    await dbClient.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> returnSale(Map<String, dynamic> sale) async {
    final dbClient = await database;

    // 1. Decode the items to know what to restock
    List<dynamic> items = jsonDecode(sale['items']);

    // 2. Start a transaction to ensure both stock and sale update correctly
    await dbClient.transaction((txn) async {
      for (var item in items) {
        await txn.rawUpdate(
          'UPDATE products SET stock = stock + ? WHERE id = ?',
          [item['qty'], item['id']],
        );
      }
      // 3. Delete the sale record (or you could add a 'status' column instead)
      await txn.delete('sales', where: 'id = ?', whereArgs: [sale['id']]);
    });
  }
}

abstract class RefreshableState<T extends StatefulWidget> extends State<T> {
  void refreshData();
}

// --- MAIN UI SCREEN ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // 1. Use a list of GlobalKeys to talk to the pages
  final List<GlobalKey<RefreshableState>> _keys = [
    GlobalKey<RefreshableState>(), // Billing
    GlobalKey<RefreshableState>(), // Inventory
    GlobalKey<RefreshableState>(), // Analytics
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          BillingPage(key: _keys[0]),
          InventoryPage(key: _keys[1]),
          DashboardPage(key: _keys[2]),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          // 2. When tapping a tab, call the refresh method on that page
          _keys[index].currentState?.refreshData();
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: "Billing"),
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: "Stock"),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: "Analytics",
          ),
        ],
      ),
    );
  }
}

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

  void _showProductDialog(
    BuildContext context, {
    Map<String, dynamic>? product,
  }) {
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
        title: Text(isEditing ? "Update Product" : "Add New Product"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: "Product Name"),
              ),
              TextField(
                controller: priceController,
                decoration: InputDecoration(labelText: "Selling Price (₹)"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: costController,
                decoration: InputDecoration(labelText: "Cost Price (₹)"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: stockController,
                decoration: InputDecoration(labelText: "Stock Quantity"),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text("Cancel"),
          ),
          ElevatedButton(
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
              Navigator.pop(dialogCtx);
              _refreshData();
            },
            child: Text("Save"),
          ),
        ],
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
