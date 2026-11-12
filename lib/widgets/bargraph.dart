import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import 'package:smart_inventory/main.dart'; // Contains 'formatter'
import 'package:smart_inventory/services/filters.dart';


class ProfitBarChart extends StatefulWidget {
  final List<Map<String, dynamic>> sales;

  const ProfitBarChart({super.key, required this.sales});

  @override
  State<ProfitBarChart> createState() => _ProfitBarChartState();
}

class _ProfitBarChartState extends State<ProfitBarChart> {
  GraphFilter _selectedFilter = GraphFilter.last7Days;
  DateTimeRange? _customRange;

  late Map<String, Map<String, double>> _dailyData;
  late List<String> _labels;
  late double _maxYValue;

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

  /// Processes sales into revenue & cost data buckets according to the selected filter
  void _processChartData() {
    Map<String, Map<String, double>> dailyData = {};
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
      case GraphFilter.last30Days:
        startDate = today.subtract(const Duration(days: 29));
        break;
      case GraphFilter.custom:
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
          startDate = today.subtract(const Duration(days: 6));
        }
        break;
    }

    int totalDays = endDate.difference(startDate).inDays + 1;
    if (totalDays <= 0) totalDays = 1;

    // Populate chart buckets
    if (_selectedFilter == GraphFilter.today) {
      // 4-hour time slots for Today's view (00:00, 04:00, 08:00, 12:00, 16:00, 20:00)
      for (int i = 0; i < 24; i += 4) {
        String key = "${i.toString().padLeft(2, '0')}:00";
        dailyData[key] = {'rev': 0.0, 'cost': 0.0};
      }
    } else {
      // Daily buckets for range views
      for (int i = 0; i < totalDays; i++) {
        DateTime d = startDate.add(Duration(days: i));
        String dateKey = DateFormat('dd/MM').format(d);
        dailyData[dateKey] = {'rev': 0.0, 'cost': 0.0};
      }
    }

    // Filter and process sales list
    for (var sale in widget.sales) {
      DateTime saleDate = DateTime.parse(sale['date'].toString());

      if (saleDate.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
          saleDate.isBefore(endDate.add(const Duration(seconds: 1)))) {
        String key;
        if (_selectedFilter == GraphFilter.today) {
          int slotHour = (saleDate.hour ~/ 4) * 4;
          key = "${slotHour.toString().padLeft(2, '0')}:00";
        } else {
          key = DateFormat('dd/MM').format(saleDate);
        }

        if (dailyData.containsKey(key)) {
          double rev = (sale['total'] as num).toDouble();
          double cost = 0;
          if (sale['items'] != null) {
            List<dynamic> items = jsonDecode(sale['items']);
            for (var item in items) {
              cost += ((item['cost'] as num?)?.toDouble() ?? 0.0) *
                  ((item['qty'] as num?)?.toInt() ?? 0);
            }
          }
          dailyData[key]!['rev'] = dailyData[key]!['rev']! + rev;
          dailyData[key]!['cost'] = dailyData[key]!['cost']! + cost;
        }
      }
    }

    setState(() {
      _dailyData = dailyData;
      _labels = dailyData.keys.toList();
      _maxYValue = _calculateMaxY(dailyData);
    });
  }

  double _calculateMaxY(Map<String, Map<String, double>> data) {
    double highestVal = 0;
    for (var d in data.values) {
      if (d['rev']! > highestVal) highestVal = d['rev']!;
      if (d['cost']! > highestVal) highestVal = d['cost']!;
    }
    return highestVal == 0 ? 100 : highestVal * 1.4;
  }

  /// Displays native calendar date range picker for "Custom Range"
  Future<void> _selectCustomDateRange(BuildContext context) async {
    final now = DateTime.now();
    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _customRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Colors.indigo,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedRange != null) {
      setState(() {
        _customRange = pickedRange;
        _selectedFilter = GraphFilter.custom;
        _processChartData();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    // Dynamically adjust bar width and label spacing depending on array density
    final double barWidth =
    _labels.length > 20 ? 4 : (_labels.length > 10 ? 7 : 12);
    final int labelStep = _labels.length > 15 ? (_labels.length ~/ 5) : 1;

    return Column(
      children: [
        // --- Filter Dropdown Header Row ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0,vertical: 14.0),
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
        Container(
          key: ValueKey(isDark),
          height: 250,
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
                      // Skip crowded labels when date range is large
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
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
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
                      color: isDark ? Colors.greenAccent : Colors.green,
                      width: barWidth,
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: _maxYValue,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey[100],
                      ),
                    ),
                    BarChartRodData(
                      toY: data['cost']!,
                      color: Colors.orange,
                      width: barWidth,
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: _maxYValue,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey[100],
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}
//Profit BreakDown Section
class ProfitBreakdownWidget extends StatefulWidget {
  final List<Map<String, dynamic>> sales;

  const ProfitBreakdownWidget({super.key, required this.sales});

  @override
  State<ProfitBreakdownWidget> createState() => _PeriodBreakdownWidgetState();
}

class _PeriodBreakdownWidgetState extends State<ProfitBreakdownWidget> {
  BreakdownFilter _selectedFilter = BreakdownFilter.thisMonth;
  DateTimeRange? _customRange;

  /// Calculates revenue, cost, and net profit based on the selected period filter
  Map<String, double> _calculateMetrics() {
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

    double revenue = 0.0;
    double cost = 0.0;

    for (var sale in widget.sales) {
      DateTime saleDate = DateTime.parse(sale['date'].toString());

      if (saleDate.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
          saleDate.isBefore(endDate.add(const Duration(seconds: 1)))) {
        double saleRev = (sale['total'] as num).toDouble();
        double saleCost = 0.0;

        if (sale['items'] != null) {
          List<dynamic> items = jsonDecode(sale['items']);
          for (var item in items) {
            saleCost += ((item['cost'] as num?)?.toDouble() ?? 0.0) *
                ((item['qty'] as num?)?.toInt() ?? 0);
          }
        }

        revenue += saleRev;
        cost += saleCost;
      }
    }

    return {
      'revenue': revenue,
      'cost': cost,
      'net': revenue - cost,
    };
  }

  /// Calculates Today's net profit specifically
  double _calculateTodayNet() {
    final now = DateTime.now();
    double todayRev = 0.0;
    double todayCost = 0.0;

    for (var sale in widget.sales) {
      DateTime saleDate = DateTime.parse(sale['date'].toString());
      if (saleDate.year == now.year &&
          saleDate.month == now.month &&
          saleDate.day == now.day) {
        todayRev += (sale['total'] as num).toDouble();

        if (sale['items'] != null) {
          List<dynamic> items = jsonDecode(sale['items']);
          for (var item in items) {
            todayCost += ((item['cost'] as num?)?.toDouble() ?? 0.0) *
                ((item['qty'] as num?)?.toInt() ?? 0);
          }
        }
      }
    }
    return todayRev - todayCost;
  }

  /// Opens the native date range calendar picker for custom filter
  Future<void> _selectCustomDateRange(BuildContext context) async {
    final now = DateTime.now();
    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _customRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: now,
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Colors.indigo,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedRange != null) {
      setState(() {
        _customRange = pickedRange;
        _selectedFilter = BreakdownFilter.custom;
      });
    }
  }

  String _getFilterLabel() {
    switch (_selectedFilter) {
      case BreakdownFilter.thisMonth:
        return "This Month's";
      case BreakdownFilter.lastMonth:
        return "${DateFormat('MMM').format(DateTime(DateTime.now().year, DateTime.now().month - 1, 1))}'s";
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
    final metrics = _calculateMetrics();
    final double periodRevenue = metrics['revenue']!;
    final double periodCost = metrics['cost']!;
    final double selectedPeriodNet = metrics['net']!;
    final double todayNet = _calculateTodayNet();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          // --- Filter Dropdown Row ---
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
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
            todayNet < 0 ? "Today's Loss" : "Today's Profit",
            todayNet,
          ),

          // --- Filtered Period Revenue Tile ---
          _buildPeriodTile(
            "${_getFilterLabel()} Revenue",
            periodRevenue,
            customColor: Colors.blue.shade700,
          ),

          // --- Filtered Period Cost Tile ---
          _buildPeriodTile(
            "${_getFilterLabel()} Cost",
            periodCost,
            customColor: Colors.orange.shade800,
          ),

          // --- Filtered Period Net Profit/Loss Tile ---
          _buildPeriodTile(
            selectedPeriodNet < 0
                ? "${_getFilterLabel()} Loss"
                : "${_getFilterLabel()} Profit",
            selectedPeriodNet,
          ),
        ],
      ),
    );
  }
}