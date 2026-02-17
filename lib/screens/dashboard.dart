import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:smart_inventory/widgets/revenue_graph.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_inventory/services/pdf_generate.dart';
import 'package:smart_inventory/database/database_helper.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends RefreshableState<DashboardPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _filteredSales = [];
  final _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isGraphVisible = false;
  final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  @override
  void initState() {
    super.initState();
    _fetchSales();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _filterSales();
  }

  void _filterSales() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isNotEmpty) {
        _filteredSales = _sales.where((sale) {
          final id = sale['id']?.toString().toLowerCase() ?? '';
          return id.contains(query);
        }).toList()
          ..sort((a, b) => (a['id'] ?? 0).compareTo(b['id'] ?? 0));
      } else {
        _filteredSales = List.from(_sales);
      }
    });
  }

  Future<void> _fetchSales() async {
    final data = await DBProvider.db.getSales();
    if (mounted) {
      setState(() {
        _sales = data;
        _isLoading = false;
      });
      _filterSales();
    }
  }

  @override
  void refreshData() {
    _fetchSales();
  }

  void _showSaleDetails(BuildContext context, Map<String, dynamic> sale) {
    List<dynamic> items = [];
    if (sale['items'] != null) {
      items = jsonDecode(sale['items']);
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: EdgeInsets.all(5.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Sale #${sale['id']}",
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
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
                  ...items.map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        item['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15.sp,
                        ),
                      ),
                      subtitle: Text(
                        "${item['qty']} x ${formatter.format(item['price'])}",
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.black87,
                        ),
                      ),
                      trailing: Text(
                        formatter.format(item['qty'] * item['price']),
                        style: TextStyle(
                          fontSize: 15.sp,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "TOTAL AMOUNT:",
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  formatter.format(sale['total']),
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            SizedBox(height: 3.h),
            Row(
              children: [
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
                SizedBox(width: 4.w),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () async {
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

  Future<void> _saveBusinessDetails(String name, String gstin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('company_name', name);
    await prefs.setString('gstin_number', gstin);
  }

  void _showBusinessDetailsDialog() async {
    final prefs = await SharedPreferences.getInstance();
    TextEditingController nameController = TextEditingController(
      text: prefs.getString('company_name') ?? "",
    );
    TextEditingController gstinController = TextEditingController(
      text: prefs.getString('gstin_number') ?? "",
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.business_center, color: Colors.indigo),
            SizedBox(width: 10),
            Text(
              "Billing Profile",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.sp),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Information provided here will appear on your generated PDF receipts.",
                style: TextStyle(fontSize: 15.sp, color: Colors.grey[600]),
              ),
              SizedBox(height: 2.5.h),
              _buildDialogField(
                controller: nameController,
                label: "Company Name",
                hint: "e.g. My Awesome Store",
                icon: Icons.store_mall_directory_outlined,
              ),
              SizedBox(height: 2.h),
              _buildDialogField(
                controller: gstinController,
                label: "GSTIN Number",
                hint: "e.g. 22AAAAA0000A1Z5",
                icon: Icons.receipt_long_outlined,
              ),
            ],
          ),
        ),
        actionsPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CANCEL", style: TextStyle(color: Colors.grey[700])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: EdgeInsets.symmetric(horizontal: 25, vertical: 12),
            ),
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Company Name cannot be empty!"),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }
              await _saveBusinessDetails(
                nameController.text,
                gstinController.text,
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Billing details updated!"),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text(
              "SAVE DETAILS",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(fontSize: 15.sp),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.indigo),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.indigo, width: 2),
        ),
      ),
    );
  }

  Widget _saleSummary() {
    if (_isLoading && _sales.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_sales.isEmpty) {
      return Center(
        child: Text(
          "No sales recorded yet.",
          style: TextStyle(
            fontSize: 16.sp,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
    double revenue = _sales.fold(
      0,
      (sum, item) => sum + (item['total'] as num).toDouble(),
    );
    return RefreshIndicator(
      onRefresh: () async {
        _searchController.clear();
        await _fetchSales();
      },
      color: Colors.indigo,
      child: SingleChildScrollView(
        child: Column(
          children: [
            Card(
              margin: const EdgeInsets.all(16),
              color: Colors.indigo[50],
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: const Text(
                      "Total Revenue",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                    subtitle: Text(
                      formatter.format(revenue),
                      style: TextStyle(
                        fontSize: 22.sp,
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
                      onPressed: () =>
                          setState(() => _isGraphVisible = !_isGraphVisible),
                    ),
                  ),
                  if (_isGraphVisible) RevenueGraph(sales: _sales),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: "Search Sale ID...",
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(vertical: 10.0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15.0),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                ),
              ),
            ),
            if (_filteredSales.isEmpty && _searchController.text.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                child: Center(
                  child: Text(
                    "No matching sales found.",
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              )
            else if (_filteredSales.isEmpty && _sales.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                child: Center(
                  child: Text(
                    "No sales to display.",
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filteredSales.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final sale = _filteredSales[i];
                  return ListTile(
                    title: GestureDetector(
                      onTap: () => _showSaleDetails(context, sale),
                      onLongPress: () => _confirmRefund(context, sale),
                      child: Text(
                        "Sale #${sale['id']}",
                        style: TextStyle(
                          color: Colors.indigo,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.bold,
                          fontSize: 17.sp,
                        ),
                      ),
                    ),
                    subtitle: Text(
                      sale['date'].toString().split('.')[0],
                      style: TextStyle(fontSize: 15.sp),
                    ),
                    trailing: Text(
                      formatter.format(sale['total']),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _confirmRefund(BuildContext context, Map<String, dynamic> sale) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Refund?"),
        content: Text(
          "Do you want to return Sale #${sale['id']}? This will add the items back to stock and remove the revenue.",
        ),
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
              _fetchSales();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Sale returned successfully!")),
              );
            },
            child: const Text(
              "CONFIRM RETURN",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfitSummaryTab() {
    if (_isLoading && _sales.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    double totalRevenue = 0;
    double totalCost = 0;
    for (var sale in _sales) {
      totalRevenue += (sale['total'] as num).toDouble();
      if (sale['items'] != null) {
        List<dynamic> items = jsonDecode(sale['items']);
        for (var item in items) {
          totalCost += ((item['cost'] as num?)?.toDouble() ?? 0.0) *
              ((item['qty'] as num?)?.toInt() ?? 0);
        }
      }
    }
    double grossProfit = totalRevenue - totalCost;
    bool isLoss = grossProfit < 0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard("Total Revenue", totalRevenue, Colors.green),
          _buildSummaryCard("Total Cost Price", totalCost, Colors.orange),
          const Divider(height: 30, thickness: 2),
          _buildSummaryCard(
            isLoss ? "Total Loss" : "Total Profit",
            grossProfit,
            isLoss ? Colors.red : Colors.teal,
            isMain: true,
          ),
          SizedBox(height: 2.h),
          Text(
            "Profit Breakdown",
            style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 1.5.h),
          _buildPeriodBreakdown(_sales),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    double amount,
    Color color, {
    bool isMain = false,
  }) {
    return Card(
      elevation: isMain ? 4 : 2,
      shadowColor: color.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: EdgeInsets.symmetric(vertical: 1.h),
      child: Padding(
        padding: EdgeInsets.all(3.w),
        child: ListTile(
          title: Text(
            title,
            style: TextStyle(
              fontSize: isMain ? 17.sp : 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isMain)
                Icon(
                  amount >= 0 ? Icons.trending_up : Icons.trending_down,
                  color: color,
                  size: 20.sp,
                ),
              SizedBox(width: 5),
              Text(
                formatter.format(amount),
                style: TextStyle(
                  fontSize: isMain ? 18.sp : 16.sp,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
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
          saleCost += ((item['cost'] as num?)?.toDouble() ?? 0.0) *
              ((item['qty'] as num?)?.toInt() ?? 0);
        }
      }
      if (saleDate.year == now.year &&
          saleDate.month == now.month &&
          saleDate.day == now.day) {
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
          todayNet,
        ),
        _buildPeriodTile(
          monthNet < 0 ? "Month's Loss" : "Month's Profit",
          monthNet,
        ),
      ],
    );
  }

  Widget _buildPeriodTile(String label, double amount) {
    return ListTile(
      title: Text(
        label,
        style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
      ),
      trailing: Text(
        formatter.format(amount),
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.bold,
          color: amount >= 0 ? Colors.teal : Colors.red,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "Profit & Analytics",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: Colors.indigo,
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_document, color: Colors.white),
              tooltip: 'Edit Printing Format',
              onPressed: () => _showBusinessDetailsDialog(),
            ),
          ],
          bottom: TabBar(
            indicatorColor: Colors.indigo,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey[400],
            tabs: [
              Tab(icon: Icon(Icons.show_chart), text: "Sales Summary"),
              Tab(icon: Icon(Icons.currency_rupee), text: "Profits/Losses"),
            ],
          ),
        ),
        body: TabBarView(children: [_saleSummary(), _buildProfitSummaryTab()]),
      ),
    );
  }
}