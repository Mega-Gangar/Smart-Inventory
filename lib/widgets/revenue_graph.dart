import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smart_inventory/main.dart';
import 'package:smart_inventory/services/filters.dart';

/// Lightweight container for pre-parsed sale data
class _ParsedSale {
  final DateTime date;
  final double total;

  const _ParsedSale({required this.date, required this.total});
}

class RevenueGraph extends StatefulWidget {
  final List<Map<String, dynamic>> sales;
  const RevenueGraph({super.key, required this.sales});

  @override
  State<RevenueGraph> createState() => _RevenueGraphState();
}

class _RevenueGraphState extends State<RevenueGraph> {
  GraphFilter _selectedFilter = GraphFilter.today;
  DateTimeRange? _customRange;

  List<FlSpot> _spots = [];
  List<DateTime> _spotDates = [];

  @override
  void initState() {
    super.initState();
    _processSalesData();
  }

  @override
  void didUpdateWidget(covariant RevenueGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sales != oldWidget.sales) {
      _processSalesData();
    }
  }

  /// Single-pass filtering, pre-parsed sorting, and spot generation
  void _processSalesData() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime? startDate;
    DateTime? endDate;

    switch (_selectedFilter) {
      case GraphFilter.today:
        startDate = today;
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;

      case GraphFilter.last7Days:
        startDate = today.subtract(const Duration(days: 6));
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
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
        }
        break;
    }

    final startBoundary = startDate?.subtract(const Duration(seconds: 1));
    final endBoundary = endDate?.add(const Duration(seconds: 1));

    // 1. Single pass: Parse date once & filter
    final List<_ParsedSale> validSales = [];

    for (var sale in widget.sales) {
      final rawDate = sale['date'];
      if (rawDate == null) continue;

      final DateTime? saleDate = rawDate is DateTime
          ? rawDate
          : DateTime.tryParse(rawDate.toString());

      if (saleDate == null) continue;

      // Filter boundary checks
      if (startBoundary != null && !saleDate.isAfter(startBoundary)) continue;
      if (endBoundary != null && !saleDate.isBefore(endBoundary)) continue;

      final double total = (sale['total'] as num?)?.toDouble() ?? 0.0;
      validSales.add(_ParsedSale(date: saleDate, total: total));
    }

    // 2. Fast sort using pre-parsed DateTime objects (microseconds comparison)
    validSales.sort((a, b) => a.date.compareTo(b.date));

    // 3. Generate chart spots and date references
    final List<FlSpot> spots = [];
    final List<DateTime> spotDates = [];

    for (int i = 0; i < validSales.length; i++) {
      spots.add(FlSpot(i.toDouble(), validSales[i].total));
      spotDates.add(validSales[i].date);
    }

    setState(() {
      _spots = spots;
      _spotDates = spotDates;
    });
  }

  /// Handles calendar selection when "Custom Range" is chosen
  Future<void> _selectCustomDateRange(BuildContext context) async {
    final pickedRange = await DatePickerHelper.selectCustomDateRange(
      context: context,
      currentRange: _customRange,
      maxDays: 7,
      primaryColor: Colors.indigo,
    );

    if (pickedRange != null) {
      setState(() {
        _customRange = pickedRange;
        _selectedFilter = GraphFilter.custom;
        _processSalesData();
      });
    }
  }

  /// Returns the subtitle label for tooltips based on the active filter
  String _getSpotLabel(DateTime date) {
    if (_selectedFilter == GraphFilter.today) {
      return DateFormat('hh:mm a').format(date);
    }
    return DateFormat('dd MMM').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // --- Filter Dropdown Header Row ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
                          _processSalesData();
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

        // --- Chart View ---
        Container(
          height: 200,
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
          child: _spots.isEmpty
              ? const Center(
            child: Text(
              "No sales data for this period",
              style: TextStyle(color: Colors.grey),
            ),
          )
              : LineChart(
            LineChartData(
              lineTouchData: LineTouchData(
                getTouchedSpotIndicator: (barData, spotIndexes) {
                  return spotIndexes
                      .map((index) => const TouchedSpotIndicatorData(
                    FlLine(color: Colors.transparent),
                    FlDotData(show: false),
                  ))
                      .toList();
                },
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (touchedSpot) =>
                  isDark ? const Color(0xFF2C2C2C) : Colors.white,
                  getTooltipItems: (touchedBarSpots) {
                    return touchedBarSpots.map((barSpot) {
                      final int index = barSpot.x.toInt();
                      final String label =
                      (index >= 0 && index < _spotDates.length)
                          ? _getSpotLabel(_spotDates[index])
                          : "";
                      return LineTooltipItem(
                        "$label\n${formatter.format(barSpot.y)}",
                        TextStyle(
                          color: isDark
                              ? Colors.indigoAccent
                              : Colors.indigo,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: _spots,
                  isCurved: true,
                  color: Colors.indigo,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.indigo.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}