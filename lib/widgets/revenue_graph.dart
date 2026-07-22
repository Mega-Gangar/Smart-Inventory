import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:sizer/sizer.dart';
import 'package:smart_inventory/main.dart';
import 'package:smart_inventory/services/filters.dart';

class RevenueGraph extends StatefulWidget {
  final List<Map<String, dynamic>> sales;
  const RevenueGraph({super.key, required this.sales});

  @override
  State<RevenueGraph> createState() => _RevenueGraphState();
}

class _RevenueGraphState extends State<RevenueGraph> {
  GraphFilter _selectedFilter = GraphFilter.today;
  DateTimeRange? _customRange;

  /// Filters the raw sales list based on the selected dropdown filter / calendar range
  List<Map<String, dynamic>> _filterSales() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return widget.sales.where((sale) {
      final saleDate = DateTime.parse(sale['date'].toString());

      switch (_selectedFilter) {
        case GraphFilter.today:
          return !saleDate.isBefore(today);

        case GraphFilter.last7Days:
          final sevenDaysAgo = today.subtract(const Duration(days: 7));
          return saleDate.isAfter(sevenDaysAgo);

        case GraphFilter.last30Days:
          final thirtyDaysAgo = today.subtract(const Duration(days: 30));
          return saleDate.isAfter(thirtyDaysAgo);

        case GraphFilter.custom:
          if (_customRange == null) return true;
          // Set start of custom range to midnight and end of range to 23:59:59
          final start = DateTime(
            _customRange!.start.year,
            _customRange!.start.month,
            _customRange!.start.day,
          );
          final end = DateTime(
            _customRange!.end.year,
            _customRange!.end.month,
            _customRange!.end.day,
            23,
            59,
            59,
          );
          return saleDate.isAfter(start) && saleDate.isBefore(end);
      }
    }).toList();
  }

  /// Handles calendar selection when "Custom Range" is chosen
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
    final filteredSales = _filterSales();

    // 1. Sort Filtered Sales by Time (Earliest to Latest)
    filteredSales.sort((a, b) {
      return DateTime.parse(a['date'].toString())
          .compareTo(DateTime.parse(b['date'].toString()));
    });

    // 2. Generate Chart Spots
    List<FlSpot> spots = [];
    List<DateTime> spotDates = [];

    for (int i = 0; i < filteredSales.length; i++) {
      final saleDate = DateTime.parse(filteredSales[i]['date'].toString());
      final total = (filteredSales[i]['total'] as num).toDouble();

      spots.add(FlSpot(i.toDouble(), total));
      spotDates.add(saleDate);
    }

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
                      const DropdownMenuItem(
                        value: GraphFilter.last30Days,
                        child: Text("Last 30 Days"),
                      ),
                      DropdownMenuItem(
                        value: GraphFilter.custom,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _customRange == null
                                  ? "Custom Range"
                                  : "${DateFormat('dd/MM').format(_customRange!.start)} - ${DateFormat('dd/MM').format(_customRange!.end)}",
                            ),
                          ],
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
          child: spots.isEmpty
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
                  return spotIndexes.map((index) => TouchedSpotIndicatorData(
                    const FlLine(color: Colors.transparent),
                    const FlDotData(show: false),
                  )).toList();
                },
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (touchedSpot) => Colors.white,
                  getTooltipItems: (touchedBarSpots) {
                    return touchedBarSpots.map((barSpot) {
                      final int index = barSpot.x.toInt();
                      final String label = (index >= 0 && index < spotDates.length)
                          ? _getSpotLabel(spotDates[index])
                          : "";
                      return LineTooltipItem(
                        "$label\n${formatter.format(barSpot.y)}",
                        const TextStyle(
                          color: Colors.indigo,
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
                  spots: spots,
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
