import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import 'package:smart_inventory/main.dart'; // Contains 'formatter'
import 'package:smart_inventory/services/filters.dart';

// --- Shared Helper Utilities ---
DateTime? _parseSaleDate(dynamic rawDate) {
  if (rawDate == null) return null;
  if (rawDate is DateTime) return rawDate;
  return DateTime.tryParse(rawDate.toString());
}

double _calculateSaleCost(dynamic itemsRaw) {
  if (itemsRaw == null) return 0.0;
  try {
    final List<dynamic> items =
    itemsRaw is String ? jsonDecode(itemsRaw) : itemsRaw;
    double totalCost = 0.0;
    for (var item in items) {
      final price = (item['cost'] as num?)?.toDouble() ?? 0.0;
      final qty = (item['qty'] as num?)?.toInt() ?? 0;
      totalCost += price * qty;
    }
    return totalCost;
  } catch (_) {
    return 0.0;
  }
}

// PROFIT BAR CHART WIDGET
class ProfitBarChart extends StatefulWidget {
  final List<Map<String, dynamic>> sales;

  const ProfitBarChart({super.key, required this.sales});

  @override
  State<ProfitBarChart> createState() => _ProfitBarChartState();
}

class _ProfitBarChartState extends State<ProfitBarChart> {
  GraphFilter _selectedFilter = GraphFilter.last7Days;
  DateTimeRange? _customRange;

  Map<String, Map<String, double>> _dailyData = {};
  List<String> _labels = [];
  double _maxYValue = 100;

  @override
  void initState() {
    super.initState();
    _processChartData();
  }

  @override
  void didUpdateWidget(covariant ProfitBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sales != oldWidget.sales) {
      _processChartData();
    }
  }

  void _processChartData() {
    final Map<String, Map<String, double>> dailyData = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime startDate;
    DateTime endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (_selectedFilter) {
      case GraphFilter.today:
        startDate = today;
        break;

      case GraphFilter.last7Days:
        startDate = today.subtract(const Duration(days: 6));
        break;

      case GraphFilter.custom:
        if (_customRange != null) {
          startDate = DateTime(
            _customRange!.start.year,
            _customRange!.start.month,
            _customRange!.start.day,
          );

          final userEndDate = DateTime(
            _customRange!.end.year,
            _customRange!.end.month,
            _customRange!.end.day,
            23,
            59,
            59,
          );

          final maxAllowedEndDate = startDate.add(const Duration(days: 6));
          endDate = userEndDate.isAfter(maxAllowedEndDate)
              ? DateTime(
            maxAllowedEndDate.year,
            maxAllowedEndDate.month,
            maxAllowedEndDate.day,
            23,
            59,
            59,
          )
              : userEndDate;
        } else {
          startDate = today.subtract(const Duration(days: 6));
        }
        break;
    }

    int totalDays = endDate.difference(startDate).inDays + 1;
    if (totalDays <= 0) totalDays = 1;

    // Populate chart buckets
    if (_selectedFilter == GraphFilter.today) {
      for (int i = 0; i < 24; i += 4) {
        String key = "${i.toString().padLeft(2, '0')}:00";
        dailyData[key] = {'rev': 0.0, 'cost': 0.0};
      }
    } else {
      for (int i = 0; i < totalDays; i++) {
        DateTime d = startDate.add(Duration(days: i));
        String dateKey = DateFormat('dd/MM').format(d);
        dailyData[dateKey] = {'rev': 0.0, 'cost': 0.0};
      }
    }

    double maxVal = 0.0;
    final startBoundary = startDate.subtract(const Duration(seconds: 1));
    final endBoundary = endDate.add(const Duration(seconds: 1));

    // Aggregate sales data
    for (var sale in widget.sales) {
      final saleDate = _parseSaleDate(sale['date']);
      if (saleDate == null) continue;

      if (saleDate.isAfter(startBoundary) && saleDate.isBefore(endBoundary)) {
        final String key = _selectedFilter == GraphFilter.today
            ? "${((saleDate.hour ~/ 4) * 4).toString().padLeft(2, '0')}:00"
            : DateFormat('dd/MM').format(saleDate);

        final bucket = dailyData[key];
        if (bucket != null) {
          final double rev = (sale['total'] as num?)?.toDouble() ?? 0.0;
          final double cost = _calculateSaleCost(sale['items']);

          bucket['rev'] = bucket['rev']! + rev;
          bucket['cost'] = bucket['cost']! + cost;

          if (bucket['rev']! > maxVal) maxVal = bucket['rev']!;
          if (bucket['cost']! > maxVal) maxVal = bucket['cost']!;
        }
      }
    }

    setState(() {
      _dailyData = dailyData;
      _labels = dailyData.keys.toList();
      _maxYValue = maxVal == 0 ? 100 : maxVal * 1.35;
    });
  }

  Future<void> _selectCustomDateRange(BuildContext context) async {
    final range = await DatePickerHelper.selectCustomDateRange(
      context: context,
      currentRange: _customRange,
      maxDays: 7,
    );

    if (range != null) {
      setState(() {
        _customRange = range;
        _selectedFilter = GraphFilter.custom;
        _processChartData();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    final double barWidth =
    _labels.length > 20 ? 4 : (_labels.length > 10 ? 7 : 12);
    final int labelStep = _labels.length > 15 ? (_labels.length ~/ 5) : 1;

    final Color revColor = isDark ? Colors.greenAccent : Colors.green;
    final Color trackColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey[100]!;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Weekly Performance",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17.sp,
                  color: colorScheme.onSurface,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<GraphFilter>(
                    value: _selectedFilter,
                    isDense: true,
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    onChanged: (GraphFilter? newValue) {
                      if (newValue == GraphFilter.custom) {
                        _selectCustomDateRange(context);
                      } else if (newValue != null) {
                        setState(() {
                          _selectedFilter = newValue;
                          _processChartData();
                        });
                      }
                    },
                    items: [
                      const DropdownMenuItem(
                        value: GraphFilter.today,
                        child: Text("Today"),
                      ),
                      const DropdownMenuItem(
                        value: GraphFilter.last7Days,
                        child: Text("Last 7 Days"),
                      ),
                      DropdownMenuItem(
                        value: GraphFilter.custom,
                        child: Text(
                          _customRange == null
                              ? "Custom Range"
                              : "${DateFormat('dd/MM').format(_customRange!.start)} - ${DateFormat('dd/MM').format(_customRange!.end)}",
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // --- Bar Chart View ---
        SizedBox(
          height: 250,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _maxYValue,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) =>
                    isDark ? const Color(0xFF333333) : Colors.grey.shade900,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        "${rodIndex == 0 ? "Revenue" : "Cost"}\n${formatter.format(rod.toY)}",
                        TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.7.sp,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index < 0 || index >= _labels.length) {
                          return const SizedBox();
                        }
                        if (index % labelStep != 0 &&
                            index != _labels.length - 1) {
                          return const SizedBox();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _labels[index],
                            style: TextStyle(
                              fontSize: 13.7.sp,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(_labels.length, (index) {
                  final data = _dailyData[_labels[index]]!;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: data['rev']!,
                        color: revColor,
                        width: barWidth,
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: _maxYValue,
                          color: trackColor,
                        ),
                      ),
                      BarChartRodData(
                        toY: data['cost']!,
                        color: Colors.orange,
                        width: barWidth,
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: _maxYValue,
                          color: trackColor,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 2. PROFIT BREAKDOWN WIDGET
// ==========================================
class ProfitBreakdownWidget extends StatefulWidget {
  final List<Map<String, dynamic>> sales;

  const ProfitBreakdownWidget({super.key, required this.sales});

  @override
  State<ProfitBreakdownWidget> createState() => _ProfitBreakdownWidgetState();
}

class _ProfitBreakdownWidgetState extends State<ProfitBreakdownWidget> {
  BreakdownFilter _selectedFilter = BreakdownFilter.thisMonth;
  DateTimeRange? _customRange;

  double _periodRevenue = 0.0;
  double _periodCost = 0.0;
  double _todayNet = 0.0;

  @override
  void initState() {
    super.initState();
    _recalculateMetrics();
  }

  @override
  void didUpdateWidget(covariant ProfitBreakdownWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sales != oldWidget.sales) {
      _recalculateMetrics();
    }
  }

  /// Single-pass calculation for both period metrics and today's net profit
  void _recalculateMetrics() {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (_selectedFilter) {
      case BreakdownFilter.thisMonth:
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;

      case BreakdownFilter.lastMonth:
        startDate = DateTime(now.year, now.month - 1, 1);
        endDate = DateTime(now.year, now.month, 0, 23, 59, 59);
        break;

      case BreakdownFilter.thisYear:
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year, 12, 31, 23, 59, 59);
        break;

      case BreakdownFilter.custom:
        if (_customRange != null) {
          startDate = DateTime(
            _customRange!.start.year,
            _customRange!.start.month,
            _customRange!.start.day,
          );
          endDate = DateTime(
            _customRange!.end.year,
            _customRange!.end.month,
            _customRange!.end.day,
            23,
            59,
            59,
          );
        } else {
          startDate = DateTime(now.year, now.month, 1);
        }
        break;
    }

    double revAcc = 0.0;
    double costAcc = 0.0;
    double tRev = 0.0;
    double tCost = 0.0;

    final startBoundary = startDate.subtract(const Duration(seconds: 1));
    final endBoundary = endDate.add(const Duration(seconds: 1));

    for (var sale in widget.sales) {
      final saleDate = _parseSaleDate(sale['date']);
      if (saleDate == null) continue;

      final double saleRev = (sale['total'] as num?)?.toDouble() ?? 0.0;
      final double saleCost = _calculateSaleCost(sale['items']);

      // 1. Period metrics check
      if (saleDate.isAfter(startBoundary) && saleDate.isBefore(endBoundary)) {
        revAcc += saleRev;
        costAcc += saleCost;
      }

      // 2. Today's net check
      if (saleDate.year == now.year &&
          saleDate.month == now.month &&
          saleDate.day == now.day) {
        tRev += saleRev;
        tCost += saleCost;
      }
    }

    setState(() {
      _periodRevenue = revAcc;
      _periodCost = costAcc;
      _todayNet = tRev - tCost;
    });
  }

  Future<void> _selectCustomDateRange(BuildContext context) async {
    final range = await DatePickerHelper.selectCustomDateRange(
      context: context,
      currentRange: _customRange,
      maxDays: 31, // Custom breakdown range can support longer ranges
    );

    if (range != null) {
      setState(() {
        _customRange = range;
        _selectedFilter = BreakdownFilter.custom;
        _recalculateMetrics();
      });
    }
  }

  String _getFilterLabel() {
    switch (_selectedFilter) {
      case BreakdownFilter.thisMonth:
        return "This Month's";
      case BreakdownFilter.lastMonth:
        final lastMonthDate = DateTime(DateTime.now().year, DateTime.now().month - 1, 1);
        return "${DateFormat('MMM').format(lastMonthDate)}'s";
      case BreakdownFilter.thisYear:
        return "This Year's";
      case BreakdownFilter.custom:
        if (_customRange != null) {
          return "${DateFormat('dd/MM').format(_customRange!.start)} - ${DateFormat('dd/MM').format(_customRange!.end)}";
        }
        return "Custom Range";
    }
  }

  Widget _buildPeriodTile(String label, double amount, {Color? customColor}) {
    final bool isLoss = amount < 0;
    final Color textColor = customColor ?? (isLoss ? Colors.red : Colors.green);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15.5.sp,
            ),
          ),
          Text(
            formatter.format(amount),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16.5.sp,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final double periodNet = _periodRevenue - _periodCost;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Profit Breakdown",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17.sp,
                  color: colorScheme.onSurface,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<BreakdownFilter>(
                    value: _selectedFilter,
                    isDense: true,
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    onChanged: (BreakdownFilter? newValue) {
                      if (newValue == BreakdownFilter.custom) {
                        _selectCustomDateRange(context);
                      } else if (newValue != null) {
                        setState(() {
                          _selectedFilter = newValue;
                          _recalculateMetrics();
                        });
                      }
                    },
                    items: [
                      const DropdownMenuItem(
                        value: BreakdownFilter.thisMonth,
                        child: Text("This Month"),
                      ),
                      const DropdownMenuItem(
                        value: BreakdownFilter.lastMonth,
                        child: Text("Last Month"),
                      ),
                      const DropdownMenuItem(
                        value: BreakdownFilter.thisYear,
                        child: Text("This Year"),
                      ),
                      DropdownMenuItem(
                        value: BreakdownFilter.custom,
                        child: Text(_customRange == null
                            ? "Custom Range"
                            : "${DateFormat('dd/MM').format(_customRange!.start)} - ${DateFormat('dd/MM').format(_customRange!.end)}"),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // --- Today's Metrics Tile ---
          _buildPeriodTile(
            _todayNet < 0 ? "Today's Loss" : "Today's Profit",
            _todayNet,
          ),

          // --- Filtered Period Revenue Tile ---
          _buildPeriodTile(
            "${_getFilterLabel()} Revenue",
            _periodRevenue,
            customColor: Colors.blue.shade700,
          ),

          // --- Filtered Period Cost Tile ---
          _buildPeriodTile(
            "${_getFilterLabel()} Cost",
            _periodCost,
            customColor: Colors.orange.shade800,
          ),

          // --- Filtered Period Net Profit/Loss Tile ---
          _buildPeriodTile(
            periodNet < 0
                ? "${_getFilterLabel()} Loss"
                : "${_getFilterLabel()} Profit",
            periodNet,
          ),
        ],
      ),
    );
  }
}