import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'pdfGenerate.dart';
import 'revenueGraph.dart';

void main() => runApp(SmartBillingApp());

final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

class SmartBillingApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: HomeScreen(),
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
          'CREATE TABLE products(id INTEGER PRIMARY KEY, name TEXT, price REAL, stock INTEGER)',
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

  Future<void> addProduct(String name, double price, int stock) async {
    final dbClient = await database;
    await dbClient.insert('products', {
      'name': name,
      'price': price,
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
    int stock,
  ) async {
    final dbClient = await database;
    await dbClient.update(
      'products',
      {'name': name, 'price': price, 'stock': stock},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteProduct(int id) async {
    final dbClient = await database;
    await dbClient.delete('products', where: 'id = ?', whereArgs: [id]);
  }
}

// --- MAIN UI SCREEN ---
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
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
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Profit"),
        ],
      ),
    );
  }
}

// --- 1. BILLING MODULE ---
class BillingPage extends StatefulWidget {
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
      appBar: AppBar(title: Text("New Sale")),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: DBProvider.db.getProducts(),
              builder: (ctx, snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());
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

// --- 2. INVENTORY MODULE ---
class InventoryPage extends StatefulWidget {
  @override
  _InventoryPageState createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController stockController = TextEditingController();
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
    } else {
      nameController.clear();
      priceController.clear();
      stockController.clear();
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
                decoration: InputDecoration(labelText: "Price (₹)"),
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
              if (nameController.text.isEmpty || priceController.text.isEmpty)
                return;
              if (isEditing) {
                await DBProvider.db.updateProduct(
                  product!['id'],
                  nameController.text,
                  double.parse(priceController.text),
                  int.parse(stockController.text),
                );
              } else {
                await DBProvider.db.addProduct(
                  nameController.text,
                  double.tryParse(priceController.text) ?? 0.0,
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
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());
          if (snapshot.data!.isEmpty)
            return Center(child: Text("Stock is empty. Add products."));

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
                  subtitle: Text("${formatter.format(p['price'])}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () async {
                          await DBProvider.db.updateProduct(
                            p['id'],
                            p['name'],
                            p['price'],
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

// --- 3. DASHBOARD MODULE (UPDATED) ---
class DashboardPage extends StatefulWidget {
  // Change to StatefulWidget
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isGraphVisible = false;

  void _showSaleDetails(BuildContext context, Map<String, dynamic> sale) {
    List<dynamic> items = [];
    if (sale['items'] != null) {
      items = jsonDecode(sale['items']);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows sheet to take more space
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Sale #${sale['id']} Details",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            Divider(),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (items.isEmpty) Text("No item details recorded."),
                  ...items
                      .map(
                        (item) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item['name']),
                          subtitle: Text(
                            "${item['qty']} x ${formatter.format(item['price'])}",
                          ),
                          trailing: Text(
                            formatter.format(item['qty'] * item['price']),
                          ),
                        ),
                      )
                      .toList(),
                ],
              ),
            ),
            Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Total Paid:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  formatter.format(sale['total']),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            // --- PRINT BUTTON ---
            Row(
              children: [
                // 1.Print Button
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => PdfHelper.generateAndPrintReceipt(sale),
                    icon: Icon(Icons.picture_as_pdf, color: Colors.white),
                    label: Text("PRINT", style: TextStyle(color: Colors.white)),
                  ),
                ),
                SizedBox(width: 10), // Space between buttons
                // 2. New Share Button
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () async {
                      // Re-use PDF generation logic to get the bytes
                      final pdfBytes = await PdfHelper.generateReceiptBytes(
                        sale,
                      );
                      await Printing.sharePdf(
                        bytes: pdfBytes,
                        filename: 'Receipt_${sale['id']}.pdf',
                      );
                    },
                    icon: Icon(Icons.share, color: Colors.white),
                    label: Text("SHARE", style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Business Analytics")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DBProvider.db.getSales(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());
          List<Map<String, dynamic>> sales = snapshot.data!;
          double revenue = snapshot.data!.fold(
            0,
            (sum, item) => sum + item['total'],
          );

          return Column(
            children: [
              Card(
                margin: EdgeInsets.all(16),
                color: Colors.indigo[50],
                child: Column(
                  children: [
                    ListTile(
                      title: Text("Total Revenue"),
                      subtitle: Text(
                        formatter.format(revenue),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(
                              _isGraphVisible
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: Colors.indigo,
                              size: 30,
                            ),
                            onPressed: () {
                              setState(() {
                                _isGraphVisible = !_isGraphVisible;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    if (_isGraphVisible) RevenueGraph(sales: sales),
                  ],
                )
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  "Tap a Sale ID to see details & print",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, i) {
                    final sale = snapshot.data![i];
                    return ListTile(
                      title: GestureDetector(
                        onTap: () => _showSaleDetails(context, sale),
                        child: Text(
                          "Sale #${sale['id']}",
                          style: TextStyle(
                            color: Colors.indigo,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      subtitle: Text(sale['date'].toString().split('.')[0]),
                      trailing: Text(
                        formatter.format(sale['total']),
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
