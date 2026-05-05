import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import 'package:smart_inventory/main.dart';

class ProfitBarChart extends StatefulWidget {
  final List<Map<String, dynamic>> sales;

  const ProfitBarChart({super.key, required this.sales});

  @override
  State<ProfitBarChart> createState() => _ProfitBarChartState();
}

class _ProfitBarChartState extends State<ProfitBarChart> {
  // Store processed data in state to avoid re-calculating on every build
  late Map<String, Map<String, double>> _dailyData;
  late List<String> _labels;
  late double _maxYValue;

  @override
  void initState() {
    super.initState();
    _processChartData();
  }

  // If the sales list updates (e.g., after a new sale), refresh the data
  @override
  void didUpdateWidget(covariant ProfitBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sales != oldWidget.sales) {
      _processChartData();
    }
  }

  void _processChartData() {
    Map<String, Map<String, double>> dailyData = {};
    final now = DateTime.now();

    // Initialize last 7 days
    for (int i = 6; i >= 0; i--) {
      String dateKey = DateFormat(
        'dd/MM',
      ).format(now.subtract(Duration(days: i)));
      dailyData[dateKey] = {'rev': 0.0, 'cost': 0.0};
    }

    // Process sales list
    for (var sale in widget.sales) {
      DateTime saleDate = DateTime.parse(sale['date']);
      String dateKey = DateFormat('dd/MM').format(saleDate);

      if (dailyData.containsKey(dateKey)) {
        double rev = (sale['total'] as num).toDouble();
        double cost = 0;
        if (sale['items'] != null) {
          List<dynamic> items = jsonDecode(sale['items']);
          for (var item in items) {
            cost +=
                ((item['cost'] as num?)?.toDouble() ?? 0.0) *
                ((item['qty'] as num?)?.toInt() ?? 0);
          }
        }
        dailyData[dateKey]!['rev'] = dailyData[dateKey]!['rev']! + rev;
        dailyData[dateKey]!['cost'] = dailyData[dateKey]!['cost']! + cost;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      key: ValueKey(isDark), // Crucial for forcing theme refresh
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
                    fontSize: 11.sp,
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
                  if (index < 0 || index >= _labels.length)
                    return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _labels[index],
                      style: TextStyle(
                        fontSize: 13.sp,
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
                  width: 12,
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
                  width: 12,
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
    );
  }
}
