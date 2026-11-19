import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import 'package:smart_inventory/screens/setting_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printing/printing.dart';
import 'package:smart_inventory/screens/smart_analytics_ui.dart';
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
                  icon: Icon(Icons.close, size: 18.sp),
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
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ...items.map(
                        (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        item['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15.sp,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        "${item['qty']} x ${formatter.format(item['price'])}",
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: colorScheme.onSurfaceVariant,
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
                      padding: EdgeInsets.symmetric(vertical: 1.5.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => PdfHelper.generateAndPrintReceipt(sale),
                    icon: Icon(
                      Icons.picture_as_pdf,
                      color: Colors.white,
                      size: 16.sp,
                    ),
                    label: Text(
                      "PRINT",
                      style: TextStyle(color: Colors.white, fontSize: 14.sp),
                    ),
                  ),
                ),
                SizedBox(width: 4.w),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? Colors.green[600]
                          : Colors.green[800],
                      padding: EdgeInsets.symmetric(vertical: 1.5.h),
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
                    icon: Icon(Icons.share, color: Colors.white, size: 16.sp),
                    label: Text(
                      "SHARE",
                      style: TextStyle(color: Colors.white, fontSize: 14.sp),
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
      color: colorScheme.primary,
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Revenue Card
            Card(
              margin: EdgeInsets.all(4.w),
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
                        fontSize: 15.sp,
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
                        size: 22.sp,
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
              padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 2.h),
              child: TextField(
                controller: _searchController,
                style: TextStyle(fontSize: 15.sp),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search, size: 18.sp),
                  hintText: "Search Sale ID...",
                  hintStyle: TextStyle(fontSize: 16.sp),
                  filled: true,
                  fillColor: isDark
                      ? colorScheme.surfaceContainer
                      : Colors.grey[100],
                  contentPadding: EdgeInsets.symmetric(vertical: 1.3.h),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15.0),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear, size: 17.sp),
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
                padding: EdgeInsets.symmetric(horizontal: 4.w),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? colorScheme.surfaceContainer : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: EdgeInsets.fromLTRB(5.w, 2.5.h, 5.w, 1.h),
        contentPadding: EdgeInsets.fromLTRB(5.w, 0.5.h, 5.w, 1.5.h),
        actionsPadding: EdgeInsets.fromLTRB(4.w, 0.5.h, 4.w, 2.h),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.assignment_return_rounded,
                color: Colors.red.shade600,
                size: 18.sp,
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Text(
                "Confirm Refund?",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20.sp,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Process a return for Sale #${sale['id']}?",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 17.sp,
                color: colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 1.2.h),
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.red.withValues(alpha: 0.35)
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.withValues(alpha: isDark ? 0.35 : 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14.sp,
                    color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                  ),
                  SizedBox(width: 2.5.w),
                  Expanded(
                    child: Text(
                      "Items will be restored to inventory and this sale's revenue will be deducted.",
                      style: TextStyle(
                        fontSize: 13.5.sp,
                        height: 1.35,
                        color: isDark ? Colors.red.shade200 : Colors.red.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.white70 : Colors.grey.shade700,
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              "CANCEL",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14.5.sp,
              ),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
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
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 2.5.w),
                      Expanded(
                        child: Text(
                          "Sale #${sale['id']} returned and stock updated.",
                          style: TextStyle(fontSize: 11.5.sp, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.green.shade700,
                  behavior: SnackBarBehavior.floating,
                  margin: EdgeInsets.all(3.w),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            icon: Icon(Icons.check_rounded, size: 14.sp),
            label: Text(
              "CONFIRM RETURN",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15.sp,
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

    return SingleChildScrollView(
      padding: EdgeInsets.all(4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 0,
            color: isDark ? colorScheme.surfaceContainer : Colors.grey[50],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: ProfitBarChart(sales: _sales),
          ),
          Divider(height: 3.5.h, thickness: 1),
          ProfitBreakdownWidget(sales: _sales),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final appBarTheme = Theme.of(context).appBarTheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "Profit & Analytics",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 20.sp,
            ),
          ),
          backgroundColor: appBarTheme.backgroundColor,
          iconTheme: appBarTheme.iconTheme,
          actions: [
            IconButton(
              icon: Icon(Icons.auto_graph_rounded, size: 20.sp),
              tooltip: 'Smart Restock & Analytics',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SmartRestockAnalyticsPage(),
                  ),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.settings, color: Colors.white, size: 22.sp),
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
            indicatorColor: isDark ? colorScheme.secondary : Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            labelStyle: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
            unselectedLabelStyle: TextStyle(fontSize: 14.sp),
            unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
            tabs: [
              Tab(
                icon: Icon(Icons.show_chart, size: 18.sp),
                text: "Sales Summary",
              ),
              Tab(
                icon: Icon(Icons.currency_rupee, size: 18.sp),
                text: "Profits/Losses",
              ),
            ],
          ),
        ),
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
