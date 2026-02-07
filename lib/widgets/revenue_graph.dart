import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:smart_inventory/main.dart';
class RevenueGraph extends StatelessWidget {
  final List<Map<String, dynamic>> sales;
  const RevenueGraph({super.key, required this.sales});

  @override
  Widget build(BuildContext context) {
    if (sales.isEmpty) {
      return SizedBox(
        height: 25.h,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_graph, color: Colors.grey, size: 40.sp),
            SizedBox(height: 1.h),
            Text("No sales data for this period", style: TextStyle(color: Colors.grey, fontSize: 11.sp)),
          ],
        ),
      );
    }

    // 1. Get Today's Date (Midnight)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterdayDate = now.subtract(Duration(days: 1));
    final todayLabel=DateFormat('dd MMM').format(today);
    final yesterdayLabel = DateFormat('dd MMM').format(yesterdayDate);

    // 2. Separate Sales
    double previousTotal = 0;
    List<Map<String, dynamic>> todaySales = [];

    for (var sale in sales) {
      // Parse the SQLite String date back to a DateTime object
      DateTime saleDate = DateTime.parse(sale['date'].toString());

      if (saleDate.isBefore(today)) {
        previousTotal += (sale['total'] as num).toDouble();
      } else {
        todaySales.add(sale);
      }
    }

    // 3. Sort Today's Sales by Time (Earliest to Latest)
    todaySales.sort((a, b) => a['date'].compareTo(b['date']));

    //4. Create Spots
    List<FlSpot> spots = [];
    double runningTotal = previousTotal; // Start with yesterday's closing total

// Add the starting point (Yesterday's total)
    spots.add(FlSpot(0, runningTotal));

// Add Today's Sales with Cumulative Logic
    int startIdx = todaySales.length > 9 ? todaySales.length - 9 : 0;
    for (int i = startIdx; i < todaySales.length; i++) {
      // Cumulative: Add current sale to the running total
      runningTotal += (todaySales[i]['total'] as num).toDouble();

      spots.add(FlSpot(
        spots.length.toDouble(),
        runningTotal, // Plot the new total, not just the single sale amount
      ));
    }

    return Container(
      height: 25.h,
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            getTouchedSpotIndicator: (barData, spotIndexes) {
              return spotIndexes.map((index) => TouchedSpotIndicatorData(
                FlLine(color: Colors.transparent),
                FlDotData(show: false),
              )).toList();
            },
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => Colors.white,
              getTooltipItems: (touchedBarSpots) {
                return touchedBarSpots.map((barSpot) {
                  String label = barSpot.x == 0
                      ? yesterdayLabel
                      : todayLabel;
                  return LineTooltipItem(
                    "$label\n${formatter.format(barSpot.y)}",
                    const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold),
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
    );
  }
}