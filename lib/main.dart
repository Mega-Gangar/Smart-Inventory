import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
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
      version: 2, // Incremented version
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE products(id INTEGER PRIMARY KEY, name TEXT, price REAL, cost REAL, stock INTEGER)',
        );
        // Added 'items' column
        await db.execute(
          'CREATE TABLE sales(id INTEGER PRIMARY KEY, total REAL, date TEXT, items TEXT)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE sales ADD COLUMN items TEXT');
        }
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

    // Convert list of items to a string to store in DB
    String itemsJson = jsonEncode(cartItems);

    await dbClient.insert('sales', {
      'total': total,
      'date': DateTime.now().toString(),
      'items': itemsJson, // Save the items here
    });

    for (var item in cartItems) {
      await dbClient.rawUpdate(
        'UPDATE products SET stock = stock - ? WHERE id = ?',
        [item['qty'], item['id']],
      );
    }
  }

  Future<List<Map<String, dynamic>>> getSales() async {
    final dbClient = await database;
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

// --- MAIN UI SCREEN ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final profitLabel = "\t\t\tProfit\nAnalytics";
  // FIXED: These now point to the correct Widget classes
  final List<Widget> _pages = [BillingPage(), InventoryPage(), DashboardPage()];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: "Billing"),
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: "Stock"),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: profitLabel,
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

class _InventoryPageState extends State<InventoryPage> {
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
                SnackBar(content: Text("$name deleted successfully")),
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Inventory Management"),
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _refreshData),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductDialog(context),
        child: Icon(Icons.add),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
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
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  // --- TRIGGER DELETION ON LONG PRESS ---
                  onLongPress: () =>
                      _confirmDelete(context, p['id'], p['name']),
                  leading: CircleAvatar(
                    backgroundColor: p['stock'] < 5
                        ? Colors.red
                        : Colors.indigo,
                    child: Text(
                      "${p['stock']}",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    p['name'],
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(formatter.format(p['price'])),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
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
                        child: Text(
                          "+5",
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.indigo),
                        onPressed: () =>
                            _showProductDialog(context, product: p),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}