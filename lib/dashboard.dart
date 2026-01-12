import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'pdf_generate.dart';
import 'revenue_graph.dart';
import 'main.dart';
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  // Change to StatefulWidget
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isGraphVisible = false;
  final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
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
      builder: (ctx) =>
          Container(
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
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
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
                            (item) =>
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(item['name']),
                              subtitle: Text(
                                "${item['qty']} x ${formatter.format(
                                    item['price'])}",
                              ),
                              trailing: Text(
                                formatter.format(item['qty'] * item['price']),
                              ),
                            ),
                      )
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
                        onPressed: () =>
                            PdfHelper.generateAndPrintReceipt(sale),
                        icon: Icon(Icons.picture_as_pdf, color: Colors.white),
                        label: Text(
                            "PRINT", style: TextStyle(color: Colors.white)),
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
                        label: Text(
                            "SHARE", style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }
  //Edit documents details for printing
  Future<void> _saveBusinessDetails(String name, String gstin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('company_name', name);
    await prefs.setString('gstin_number', gstin);
  }
  void _showBusinessDetailsDialog() async {
    final prefs = await SharedPreferences.getInstance();

    // Pre-fill controllers with existing data if available
    TextEditingController nameController = TextEditingController(text: prefs.getString('company_name') ?? "Smart Billing");
    TextEditingController gstinController = TextEditingController(text: prefs.getString('gstin_number') ?? "");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Billing Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Company Name",
                hintText: "Enter company name for billing",
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: gstinController,
              decoration: const InputDecoration(
                labelText: "GSTIN Number",
                hintText: "Enter GSTIN number",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () async {
              await _saveBusinessDetails(nameController.text, gstinController.text);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Billing details saved!")),
              );
            },
            child: const Text("SAVE"),
          ),
        ],
      ),
    );
  }

  Widget _saleSummary() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DBProvider.db.getSales(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No sales recorded yet."));
        }

        List<Map<String, dynamic>> sales = snapshot.data!;
        double revenue = sales.fold(
            0, (sum, item) => sum + (item['total'] as num).toDouble());

        return RefreshIndicator(
          onRefresh: () async => setState(() {}), // Pull to refresh the DB data
          child: Column(
            children: [
              // --- REVENUE CARD & GRAPH ---
              Card(
                margin: const EdgeInsets.all(16),
                color: Colors.indigo[50],
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                child: Column(
                  children: [
                    ListTile(
                      title: const Text("Total Revenue"),
                      subtitle: Text(
                        formatter.format(revenue),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                      trailing: IconButton(
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
                    ),
                    if (_isGraphVisible) RevenueGraph(sales: sales),
                  ],
                ),
              ),

              // --- INSTRUCTION TEXT ---
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Tap a Sale ID to see details & print",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              ),

              // --- RECENT SALES LIST ---
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: sales.length,
                  separatorBuilder: (context, index) =>
                  const Divider(height: 1),
                  itemBuilder: (context, i) {
                    // Reversing the list to show newest sales at the top
                    final sale = sales.reversed.toList()[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      title: GestureDetector(
                        onTap: () => _showSaleDetails(context, sale),
                        onLongPress: () => _confirmRefund(context, sale),
                        child: Text(
                          "Sale #${sale['id']}",
                          style: const TextStyle(
                            color: Colors.indigo,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      subtitle: Text(sale['date'].toString().split('.')[0]),
                      trailing: Text(
                        formatter.format(sale['total']),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmRefund(BuildContext context, Map<String, dynamic> sale) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Refund?"),
        content: Text("Do you want to return Sale #${sale['id']}? This will add the items back to stock and remove the revenue."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await DBProvider.db.returnSale(sale);
              Navigator.pop(ctx);
              setState(() {}); // Refresh UI
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Sale returned successfully!")),
              );
            },
            child: const Text("CONFIRM RETURN", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  //Profit and Losses Tab
  Widget _buildProfitSummaryTab() {
    return FutureBuilder(
      // Now only waiting for Sales data
      future: DBProvider.db.getSales(),
      builder: (context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        List<Map<String, dynamic>> sales = snapshot.data!;

        double totalRevenue = 0;
        double totalCost = 0;

        // Calculate based on sales only
        for (var sale in sales) {
          totalRevenue += (sale['total'] as num).toDouble();
          if (sale['items'] != null) {
            List<dynamic> items = jsonDecode(sale['items']);
            for (var item in items) {
              double cost = (item['cost'] as num?)?.toDouble() ?? 0.0;
              int qty = (item['qty'] as num?)?.toInt() ?? 0;
              totalCost += (cost * qty);
            }
          }
        }

        double grossProfit = totalRevenue - totalCost;
        //Condition for loss
        bool isLoss = grossProfit < 0;
        String mainTitle = isLoss ? "Total Loss" : "Total Profit";
        Color mainColor = isLoss ? Colors.red : Colors.teal;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCard("Total Revenue", totalRevenue, Colors.green),
              _buildSummaryCard("Total Cost Price", totalCost, Colors.orange),
              const Divider(height: 30, thickness: 2),
              _buildSummaryCard(mainTitle, grossProfit, mainColor, isMain: true),

              const SizedBox(height: 20),
              const Text("Profit Breakdown", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildPeriodBreakdown(sales),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color color, {bool isMain = false}) {
    return Card(
      elevation: isMain ? 4 : 1,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(title, style: TextStyle(fontSize: isMain ? 18 : 16, fontWeight: isMain ? FontWeight.bold : FontWeight.normal)),
        trailing: Text(
          formatter.format(amount),
          style: TextStyle(fontSize: isMain ? 20 : 16, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }

  Widget _buildPeriodBreakdown(List<Map<String, dynamic>> sales) {
    DateTime now = DateTime.now();
    double dailyRevenue = 0, dailyCost = 0;
    double monthlyRevenue = 0, monthlyCost = 0;

    for (var sale in sales) {
      DateTime saleDate = DateTime.parse(sale['date']);
      double saleRev = (sale['total'] as num).toDouble();
      double saleCost = 0;

      if (sale['items'] != null) {
        List<dynamic> items = jsonDecode(sale['items']);
        for (var item in items) {
          saleCost += ((item['cost'] as num?)?.toDouble() ?? 0.0) * ((item['qty'] as num?)?.toInt() ?? 0);
        }
      }

      if (saleDate.year == now.year && saleDate.month == now.month && saleDate.day == now.day) {
        dailyRevenue += saleRev;
        dailyCost += saleCost;
      }
      if (saleDate.year == now.year && saleDate.month == now.month) {
        monthlyRevenue += saleRev;
        monthlyCost += saleCost;
      }
    }

    double todayNet = dailyRevenue - dailyCost;
    double monthNet = monthlyRevenue - monthlyCost;

    return Column(
      children: [
        _buildPeriodTile(
            todayNet < 0 ? "Today's Loss" : "Today's Profit",
            todayNet
        ),
        _buildPeriodTile(
            monthNet < 0 ? "Month's Loss" : "Month's Profit",
            monthNet
        ),
      ],
    );
  }

  Widget _buildPeriodTile(String label, double amount) {
    return ListTile(
      title: Text(label),
      trailing: Text(
        formatter.format(amount),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: amount >= 0 ? Colors.teal : Colors.red,
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: Text("Profit & Analytics"),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_document),
              tooltip: 'Edit Printing Format',
              onPressed: () => _showBusinessDetailsDialog(),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(icon: Icon(Icons.show_chart), text: "Sales Summary"),
              Tab(icon: Icon(Icons.currency_rupee), text: "Profits/Losses"),
            ],
          ),),
        body: TabBarView(
          children: [
            _saleSummary(),
            _buildProfitSummaryTab()
          ],
        ),
      ),
    );
  }
<<<<<<< HEAD
}
=======
}
>>>>>>> 3ee39e5adff40df8bc03c942f88ffb82e9219112
