import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:sizer/sizer.dart';
import 'package:smart_inventory/database/database_helper.dart';
import 'package:smart_inventory/screens/setting_screen.dart';
import 'package:smart_inventory/services/pdf_generate.dart';
import 'package:smart_inventory/widgets/bargraph.dart';
import 'package:smart_inventory/widgets/revenue_graph.dart';

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
  double _totalRevenue = 0.0; // Cached total revenue

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

  /// Efficiently filters sales list
  void _filterSales() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isNotEmpty) {
        _filteredSales = _sales.where((sale) {
          final id = sale['id']?.toString().toLowerCase() ?? '';
          return id.contains(query);
        }).toList();
      } else {
        _filteredSales = List.from(_sales);
      }
    });
  }

  /// Fetches sales (sorted directly by SQLite database) and calculates cached revenue
  Future<void> _fetchSales() async {
    // Option 2: Delegated sorting to SQLite query directly
    final data = await DBProvider.db.getSales();

    // Calculate total revenue once
    double revenueAcc = 0.0;
    for (var sale in data) {
      revenueAcc += (sale['total'] as num?)?.toDouble() ?? 0.0;
    }

    if (mounted) {
      setState(() {
        _sales = data;
        _totalRevenue = revenueAcc;
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
      try {
        items = sale['items'] is String
            ? jsonDecode(sale['items'])
            : sale['items'];
      } catch (_) {
        items = [];
      }
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
                        (item) {
                      final double qty =
                          (item['qty'] as num?)?.toDouble() ?? 0.0;
                      final double price =
                          (item['price'] as num?)?.toDouble() ?? 0.0;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          item['name']?.toString() ?? 'Item',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          "${qty.toInt()} x ${formatter.format(price)}",
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: Text(
                          formatter.format(qty * price),
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      );
                    },
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
                  formatter.format(sale['total'] ?? 0),
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
                      backgroundColor:
                      isDark ? Colors.green[600] : Colors.green[800],
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
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        _searchController.clear();
        await _fetchSales();
      },
      color: colorScheme.primary,
      child: CustomScrollView(
        slivers: [
          // 1. Revenue Card Header
          SliverToBoxAdapter(
            child: Card(
              margin: const EdgeInsets.all(16),
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
                      formatter.format(_totalRevenue),
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
          ),

          // 2. Search Bar Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: "Search Sale ID...",
                  filled: true,
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
          ),

          // 3. Lazy List or Empty State
          if (_filteredSales.isEmpty && _searchController.text.isNotEmpty)
            SliverToBoxAdapter(
              child: _emptyState("No matching sales found."),
            )
          else if (_filteredSales.isEmpty && _sales.isNotEmpty)
            SliverToBoxAdapter(
              child: _emptyState("No sales to display."),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.separated(
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
                      formatter.format(sale['total'] ?? 0),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

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
      builder: (ctx) {
        bool isProcessing = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              contentPadding: EdgeInsets.fromLTRB(20.sp, 24.sp, 20.sp, 12.sp),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.assignment_return_rounded,
                      color: Colors.red,
                      size: 32,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    "Confirm Refund?",
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    "Do you want to return Sale #${sale['id']}?\nThis will restore items back to stock and adjust revenue.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.5.sp,
                      color: colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
              actionsPadding: EdgeInsets.fromLTRB(16.sp, 0, 16.sp, 16.sp),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                TextButton(
                  onPressed: isProcessing ? null : () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.sp,
                      vertical: 10.sp,
                    ),
                  ),
                  child: Text(
                    "CANCEL",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      horizontal: 18.sp,
                      vertical: 10.sp,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isProcessing
                      ? null
                      : () async {
                    setDialogState(() => isProcessing = true);
                    try {
                      await DBProvider.db.returnSale(sale);

                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);

                      _fetchSales();

                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  color: Colors.white),
                              const SizedBox(width: 10),
                              Text(
                                  "Sale #${sale['id']} returned successfully!"),
                            ],
                          ),
                          backgroundColor: Colors.green[700],
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    } catch (e) {
                      setDialogState(() => isProcessing = false);
                    }
                  },
                  child: isProcessing
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    "CONFIRM RETURN",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildProfitSummaryTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading && _sales.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
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
          const Divider(height: 30, thickness: 1),
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
                  MaterialPageRoute(
                    builder: (context) => const SettingsPage(),
                  ),
                );
              },
            ),
          ],
          bottom: TabBar(
            indicatorColor: isDark ? colorScheme.secondary : Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
            tabs: const [
              Tab(icon: Icon(Icons.show_chart), text: "Sales Summary"),
              Tab(icon: Icon(Icons.currency_rupee), text: "Profits/Losses"),
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