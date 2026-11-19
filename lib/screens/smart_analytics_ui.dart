import 'dart:convert';
import 'package:sizer/sizer.dart';
import '../database/database_sync.dart';
import 'package:material_ui/material_ui.dart';
import '../services/smart_restock_model.dart';

// 1. The public StatefulWidget definition
class SmartRestockAnalyticsPage extends StatefulWidget {
  const SmartRestockAnalyticsPage({super.key});

  @override
  State<SmartRestockAnalyticsPage> createState() => _SmartRestockAnalyticsPageState();
}

// 2. The corresponding State class
class _SmartRestockAnalyticsPageState extends State<SmartRestockAnalyticsPage> {
  late Future<SmartRestockResponse?> _analysisFuture;

  // Track the currently selected filter option
  String _selectedFilter = "All";

  @override
  void initState() {
    super.initState();
    _loadAnalysisData();
  }

  void _loadAnalysisData() {
    setState(() {
      _analysisFuture = DatabaseSyncService.uploadDatabaseToPython().then((jsonString) {
        if (jsonString == null) return null;
        final Map<String, dynamic> jsonData = jsonDecode(jsonString);
        return SmartRestockResponse.fromJson(jsonData);
      });
    });
  }

// Helper method to show Cross-Selling Aggregate Percentages Modal & List 100% Matches
  void _showCrossSellingSummaryModal(BuildContext context, List<AssociationRule> rules) {
    if (rules.isEmpty) return;

    // Calculate aggregate metrics safely
    double avgConfidence = rules.fold(0.0, (sum, r) => sum + r.confidence) / rules.length;
    double avgLift = rules.fold(0.0, (sum, r) => sum + r.lift) / rules.length;

    // Filter all 100% confidence match pairs
    List<AssociationRule> perfectMatches = rules.where((r) => r.confidence >= 1.0).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows modal to expand nicely if there are many items
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: EdgeInsets.all(6.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Modal Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Cross-Selling Aggregate Insights",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  SizedBox(height: 1.h),

                  // Summary Metrics
                  _buildSummaryRow(Icons.rule_rounded, "Total Mined Rules", "${rules.length} active patterns"),
                  SizedBox(height: 1.5.h),
                  _buildSummaryRow(Icons.star_rounded, "100% Match Combos", "${perfectMatches.length} pairs found"),
                  SizedBox(height: 1.5.h),
                  _buildSummaryRow(Icons.analytics_rounded, "Average Confidence", "${(avgConfidence * 100).toStringAsFixed(1)}%"),
                  SizedBox(height: 1.5.h),
                  _buildSummaryRow(Icons.trending_up_rounded, "Average Lift Score", avgLift.toStringAsFixed(2)),

                  SizedBox(height: 2.5.h),
                  Text(
                    "All 100% Match Pairs (${perfectMatches.length})",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, color: Colors.amber.shade900),
                  ),
                  SizedBox(height: 1.h),

                  // Scrollable List of All 100% Match Pairs
                  Expanded(
                    child: perfectMatches.isEmpty
                        ? Center(
                      child: Text(
                        "No 100% confidence pairs available.",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12.sp),
                      ),
                    )
                        : ListView.builder(
                      controller: scrollController,
                      itemCount: perfectMatches.length,
                      itemBuilder: (context, index) {
                        final rule = perfectMatches[index];
                        return Container(
                          margin: EdgeInsets.only(bottom: 1.h),
                          padding: EdgeInsets.all(3.w),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.star_rounded, color: Colors.amber.shade800, size: 20.sp),
                              SizedBox(width: 3.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${rule.antecedents.join(', ')} ➔ ${rule.consequents.join(', ')}",
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
                                    ),
                                    SizedBox(height: 0.3.h),
                                    Text(
                                      "Confidence: 100%  •  Lift: ${rule.lift}",
                                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5.sp),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
      },
    );
  }

  Widget _buildSummaryRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, size: 21.sp, color: Colors.indigo),
        SizedBox(width: 3.w),
        Expanded(
          child: Text(title, style: TextStyle(fontSize: 15.sp, color: Colors.grey.shade700)),
        ),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? colorScheme.surface : Colors.grey.shade50,
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          title: Text(
            "Smart Restock & Analytics",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: TabBar(
            indicatorColor: isDark ? colorScheme.secondary : Colors.white,
            indicatorWeight: 3.h > 10 ? 3 : 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
            tabs: [
              Tab(icon: Icon(Icons.inventory_2_rounded, size: 20.sp), text: "Restock Forecasts"),
              Tab(icon: Icon(Icons.hub_rounded, size: 20.sp), text: "Cross-Selling"),
            ],
          ),
        ),
        body: FutureBuilder<SmartRestockResponse?>(
          future: _analysisFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError || snapshot.data == null) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(24.w > 100 ? 24.0 : 16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline_rounded, size: 36.sp, color: colorScheme.error),
                      SizedBox(height: 2.h),
                      Text(
                        "Unable to load analytics data",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19.sp, color: colorScheme.onSurface),
                      ),
                      SizedBox(height: 1.h),
                      FilledButton.icon(
                        onPressed: _loadAnalysisData,
                        style: FilledButton.styleFrom(
                          backgroundColor: isDark ? colorScheme.surfaceBright : Colors.indigo,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text("Retry Connection"),
                      ),
                    ],
                  ),
                ),
              );
            }

            final data = snapshot.data!;

            final filteredPredictions = data.predictions.where((item) {
              if (_selectedFilter == "Needs Reorder") {
                return item.needsReorder;
              } else if (_selectedFilter == "Optimal") {
                return !item.needsReorder;
              }
              return true;
            }).toList();

            return TabBarView(
              children: [
                // Tab 1: Restock Forecasts
                Column(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
                      color: isDark ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.3) : Colors.white,
                      child: Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  FilterChip(
                                    label: Text("All (${data.predictions.length})", style: TextStyle(fontSize: 15.sp)),
                                    selected: _selectedFilter == "All",
                                    onSelected: (selected) => setState(() => _selectedFilter = "All"),
                                  ),
                                  SizedBox(width: 2.w),
                                  FilterChip(
                                    label: Text("Needs Reorder (${data.predictions.where((i) => i.needsReorder).length})", style: TextStyle(fontSize: 15.sp)),
                                    selected: _selectedFilter == "Needs Reorder",
                                    selectedColor: Colors.red.shade100,
                                    labelStyle: TextStyle(
                                      color: _selectedFilter == "Needs Reorder" ? Colors.red.shade900 : null,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    onSelected: (selected) => setState(() => _selectedFilter = "Needs Reorder"),
                                  ),
                                  SizedBox(width: 2.w),
                                  FilterChip(
                                    label: Text("Optimal", style: TextStyle(fontSize: 15.sp)),
                                    selected: _selectedFilter == "Optimal",
                                    selectedColor: Colors.green.shade100,
                                    labelStyle: TextStyle(
                                      color: _selectedFilter == "Optimal" ? Colors.green.shade900 : null,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    onSelected: (selected) => setState(() => _selectedFilter = "Optimal"),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 1),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          _loadAnalysisData();
                          await _analysisFuture;
                        },
                        child: filteredPredictions.isEmpty
                            ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: 20.h),
                            const Center(child: Text("No items match this filter criteria.")),
                          ],
                        )
                            : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.all(4.w),
                          itemCount: filteredPredictions.length,
                          itemBuilder: (context, index) {
                            final item = filteredPredictions[index];
                            final isReorder = item.needsReorder;
                            final statusColor = isReorder ? Colors.red.shade700 : Colors.green.shade700;
                            final statusBg = isReorder ? Colors.red.shade50 : Colors.green.shade50;

                            return Container(
                              margin: EdgeInsets.only(bottom: 1.5.h),
                              decoration: BoxDecoration(
                                color: isDark ? colorScheme.surfaceContainer : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isReorder ? Colors.red.shade200 : colorScheme.outlineVariant.withValues(alpha: 0.5),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(4.w),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(2.5.w),
                                      decoration: BoxDecoration(
                                        color: statusBg,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        isReorder ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                                        color: statusColor,
                                        size: 20.sp,
                                      ),
                                    ),
                                    SizedBox(width: 3.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.productName,
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17.sp),
                                          ),
                                          SizedBox(height: 0.5.h),
                                          Text(
                                            "Current Stock: ${item.currentStock} units  •  Velocity: ~${item.dailyVelocity}/day",
                                            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.2.sp),
                                          ),
                                          SizedBox(height: 0.3.h),
                                          Text(
                                            "Estimated Stockout: ${item.daysRemaining} days remaining",
                                            style: TextStyle(
                                              color: item.daysRemaining <= 3 ? Colors.red.shade700 : colorScheme.onSurfaceVariant,
                                              fontSize: 12.9.sp,
                                              fontWeight: item.daysRemaining <= 3 ? FontWeight.w600 : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.5.h),
                                          decoration: BoxDecoration(
                                            color: statusBg,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            item.status,
                                            style: TextStyle(color: statusColor, fontSize: 13.sp, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        if (isReorder) ...[
                                          SizedBox(height: 1.h),
                                          Text(
                                            "Order +${item.recommendedOrderQty}",
                                            style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 15.sp),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                // Tab 2: Cross-Selling (Apriori Rules) wrapped in a Stack to support FloatingActionButton
                Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: () async {
                        _loadAnalysisData();
                        await _analysisFuture;
                      },
                      child: data.associationRules.isEmpty
                          ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(height: 25.h),
                          const Center(child: Text("No strong association patterns mined yet.")),
                        ],
                      )
                          : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(4.w, 4.w, 4.w, 10.h), // Extra bottom padding for FAB clearance
                        itemCount: data.associationRules.length,
                        itemBuilder: (context, index) {
                          final rule = data.associationRules[index];
                          return Container(
                            margin: EdgeInsets.only(bottom: 1.5.h),
                            decoration: BoxDecoration(
                              color: isDark ? colorScheme.surfaceContainer : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(4.w),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(3.w),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.link_rounded, color: colorScheme.primary, size: 20.sp),
                                  ),
                                  SizedBox(width: 3.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "If buying: ${rule.antecedents.join(', ')}",
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp),
                                        ),
                                        SizedBox(height: 0.3.h),
                                        Text(
                                          "Also buys: ${rule.consequents.join(', ')}",
                                          style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 14.5.sp),
                                        ),
                                        SizedBox(height: 0.8.h),
                                        Row(
                                          children: [
                                            Text(
                                              "Confidence: ${(rule.confidence * 100).toStringAsFixed(0)}%",
                                              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.5.sp),
                                            ),
                                            SizedBox(width: 3.w),
                                            Text(
                                              "Lift: ${rule.lift}",
                                              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.5.sp),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Floating Aggregate Summary Button on Bottom Right
                    Positioned(
                      bottom: 2.h,
                      right: 4.w,
                      child: FloatingActionButton.extended(
                        onPressed: () => _showCrossSellingSummaryModal(context, data.associationRules),
                        backgroundColor: isDark ?  colorScheme.surfaceBright : Colors.indigo,
                        foregroundColor: Colors.white,
                        icon: const Icon(Icons.insights_rounded),
                        label: const Text("Summary Stats"),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}