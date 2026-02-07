// --- DATABASE HELPER ---
import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/material.dart';

abstract class RefreshableState<T extends StatefulWidget> extends State<T> {
  void refreshData();
}
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
