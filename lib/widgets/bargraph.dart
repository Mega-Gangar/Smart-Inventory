import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smart_inventory/main.dart';

class ProfitBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> sales;

  const ProfitBarChart({super.key, required this.sales});

  @override
  Widget build(BuildContext context) {
    // 1. Group data by date (Last 7 Days)
    Map<String, Map<String, double>> dailyData = {};
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      String dateKey = DateFormat(
        'dd/MM',
      ).format(now.subtract(Duration(days: i)));
      dailyData[dateKey] = {'rev': 0.0, 'cost': 0.0};
    }

    for (var sale in sales) {
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

    List<String> labels = dailyData.keys.toList();

    return Container(
      height: 250,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _calculateMaxY(dailyData),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => Colors.grey.shade900,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                String type = rodIndex == 0 ? "Revenue" : "Cost";
                return BarTooltipItem(
                  "$type\n${formatter.format(rod.toY)}",
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      labels[value.toInt()],
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(labels.length, (index) {
            final data = dailyData[labels[index]]!;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: data['rev']!,
                  color: Colors.green,
                  width: 12,
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: _calculateMaxY(dailyData), // Limits the visual "track"
                    color: Colors.grey[200],
                  ),
                ),
                BarChartRodData(
                  toY: data['cost']!,
                  color: Colors.orange,
                  width: 12,
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: _calculateMaxY(dailyData), // Limits the visual "track"
                    color: Colors.grey[200],
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  double _calculateMaxY(Map<String, Map<String, double>> data) {
    double highestVal = 0;
    for (var d in data.values) {
      if (d['rev']! > highestVal) highestVal = d['rev']!;
      if (d['cost']! > highestVal) highestVal = d['cost']!;
    }
    // Add 20% extra space at the top so tooltips have room
    return highestVal == 0 ? 100 : highestVal * 1.4;
  }
}
