import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import 'package:smart_inventory/screens/setting_screen.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:smart_inventory/widgets/bargraph.dart';
import 'package:smart_inventory/widgets/revenue_graph.dart';
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
        }).toList()..sort((a, b) => (a['id'] ?? 0).compareTo(b['id'] ?? 0));
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

    // Identify current theme state
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // Ensure the background of the sheet matches the theme
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
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
                    color: isDark ? Colors.white : Colors.indigo,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (items.isEmpty)
                    Text(
                      "No item details recorded.",
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ...items.map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        item['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15.sp,
                          color: colorScheme.onSurface, // Adaptive text
                        ),
                      ),
                      subtitle: Text(
                        "${item['qty']} x ${formatter.format(item['price'])}",
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: colorScheme
                              .onSurfaceVariant, // Muted adaptive text
                        ),
                      ),
                      trailing: Text(
                        formatter.format(item['qty'] * item['price']),
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "TOTAL AMOUNT:",
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
                Text(
                  formatter.format(sale['total']),
                  style: TextStyle(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
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
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => PdfHelper.generateAndPrintReceipt(sale),
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                    label: const Text(
                      "PRINT",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                SizedBox(width: 4.w),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      // Green is a good "action" color, but we ensure it pops in both modes
                      backgroundColor: isDark
                          ? Colors.green[600]
                          : Colors.green[800],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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
                    icon: const Icon(Icons.share, color: Colors.white),
                    label: const Text(
                      "SHARE",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _saleSummary() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading && _sales.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_sales.isEmpty) {
      return Center(
        child: Text(
          "No sales recorded yet.",
          style: TextStyle(
            fontSize: 16.sp,
            // Adaptive muted text
            color: colorScheme.onSurfaceVariant,
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
      // Use primary color for the refresh spinner
      color: colorScheme.primary,
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Revenue Card
            Card(
              margin: const EdgeInsets.all(16),
              // Use a subtle indigo tinted background for both modes
              color: isDark
                  ? Colors.indigo.withValues(alpha: 0.15)
                  : Colors.indigo[50],
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      "Total Revenue",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.indigo,
                      ),
                    ),
                    subtitle: Text(
                      formatter.format(revenue),
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.indigo,
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

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: "Search Sale ID...",
                  filled: true,
                  // Use adaptive background for the search field
                  fillColor: isDark
                      ? colorScheme.surfaceContainer
                      : Colors.grey[100],
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

            // Conditional Display
            if (_filteredSales.isEmpty && _searchController.text.isNotEmpty)
              _emptyState("No matching sales found.")
            else if (_filteredSales.isEmpty && _sales.isNotEmpty)
              _emptyState("No sales to display.")
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
                          // Keep indigo for links/actions
                          color: isDark ? Colors.white : Colors.indigo,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.bold,
                          fontSize: 17.sp,
                        ),
                      ),
                    ),
                    subtitle: Text(
                      sale['date'].toString().split('.')[0],
                      style: TextStyle(
                        fontSize: 15.sp,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Text(
                      formatter.format(sale['total']),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                        color: colorScheme.onSurface,
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

  // Helper for empty states
  Widget _emptyState(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16.sp,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  void _confirmRefund(BuildContext context, Map<String, dynamic> sale) {
    // Define theme variables locally for this function
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Confirm Refund?",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        content: Text(
          "Do you want to return Sale #${sale['id']}? This will add the items back to stock and remove the revenue.",
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "CANCEL",
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              // Use semantic error color for the refund action
              backgroundColor: Colors.red,
              foregroundColor: colorScheme.onError,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              await DBProvider.db.returnSale(sale);

              if (!context.mounted) return;

              Navigator.pop(ctx);
              _fetchSales(); // Refresh your sales history

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text("Sale returned successfully!"),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
            child: Text(
              "CONFIRM RETURN",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.indigo,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfitSummaryTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

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
          totalCost +=
              ((item['cost'] as num?)?.toDouble() ?? 0.0) *
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
          Text(
            "Weekly Performance",
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface, // Adaptive heading
            ),
          ),
          const SizedBox(height: 10),
          // Adapted Graph Container
          Card(
            elevation: 0,
            // Use surfaceContainer for a subtle lift in Dark Mode
            color: isDark ? colorScheme.surfaceContainer : Colors.grey[50],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: ProfitBarChart(sales: _sales),
          ),
          const SizedBox(height: 20),
          _buildSummaryCard(
            "Total Revenue",
            totalRevenue,
            isDark ? Colors.greenAccent[400]! : Colors.green,
          ),
          _buildSummaryCard(
            "Total Cost Price",
            totalCost,
            isDark ? Colors.orangeAccent[200]! : Colors.orange,
          ),
          const Divider(height: 30, thickness: 1),
          _buildSummaryCard(
            isLoss ? "Total Loss" : "Total Profit",
            grossProfit.abs(), // Use absolute value for display
            isLoss
                ? (isDark ? Colors.redAccent[200]! : Colors.red)
                : (isDark ? Colors.tealAccent[400]! : Colors.teal),
            isMain: true,
          ),
          SizedBox(height: 2.h),
          Text(
            "Profit Breakdown",
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
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
      shadowColor: color.withValues(alpha: 0.2),
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
          saleCost +=
              ((item['cost'] as num?)?.toDouble() ?? 0.0) *
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
    // Detect theme brightness and color scheme
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final appBarTheme = Theme.of(context).appBarTheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "Profit & Analytics",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: appBarTheme.backgroundColor,
          iconTheme: appBarTheme.iconTheme,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              tooltip: 'Settings',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
            ),
          ],
          bottom: TabBar(
            // Use a bright indicator that pops against the indigo app bar
            indicatorColor: isDark ? colorScheme.secondary : Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            // Lighter grey for unselected tabs in both modes for readability
            unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
            tabs: const [
              Tab(icon: Icon(Icons.show_chart), text: "Sales Summary"),
              Tab(icon: Icon(Icons.currency_rupee), text: "Profits/Losses"),
            ],
          ),
        ),
        // Ensure the background of the TabBarView matches the theme
        body: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: TabBarView(
            children: [_saleSummary(), _buildProfitSummaryTab()],
          ),
        ),
      ),
    );
  }
}
