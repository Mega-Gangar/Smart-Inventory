import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
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

        case GraphFilter.custom:
          if (_customRange == null) return true;
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

  Widget _buildFilterChip(String label, GraphFilter filterValue, IconData icon) {
    final isSelected = _selectedFilter == filterValue;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChoiceChip(
      label: Text(label),
      avatar: Icon(
        icon,
        size: 16.sp,
        color: isSelected ? colorScheme.primary : (isDark ? Colors.white70 : Colors.grey[700]),
      ),
      selected: isSelected,
      selectedColor: colorScheme.primary.withValues(alpha: 0.15),
      backgroundColor: Theme.of(context).cardColor,
      labelStyle: TextStyle(
        fontSize: 15.sp,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? colorScheme.primary : (isDark ? Colors.white70 : Colors.grey[800]),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : (isDark ? Colors.white12 : Colors.grey.shade300),
        ),
      ),
      onSelected: (selected) async {
        if (selected) {
          if (filterValue == GraphFilter.custom) {
            await _selectCustomDateRange(context);
          } else {
            setState(() {
              _selectedFilter = filterValue;
            });
          }
        }
      },
    );
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
      // Validate that the selected range does not exceed 7 days
      final int differenceInDays = pickedRange.end.difference(pickedRange.start).inDays;

      if (differenceInDays > 7) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Custom range cannot exceed a maximum of 7 days.",style: TextStyle(color: Colors.white),),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return; // Reject selection and keep previous state
      }

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          padding: EdgeInsets.symmetric(horizontal: 1.w, vertical: 0.5.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip("Today", GraphFilter.today, Icons.today_rounded),
                    SizedBox(width: 2.w),
                    _buildFilterChip("Last 7 Days", GraphFilter.last7Days, Icons.date_range_rounded),
                    SizedBox(width: 2.w),
                    _buildFilterChip("Custom", GraphFilter.custom, Icons.tune_rounded),
                  ],
                ),
              ),

              // Active Custom Range Subtitle Indicator
              if (_selectedFilter == GraphFilter.custom && _customRange != null) ...[
                SizedBox(height: 0.6.h),
                Text(
                  "Range: ${DateFormat('dd MMM').format(_customRange!.start)} - ${DateFormat('dd MMM').format(_customRange!.end)}",
                  style: TextStyle(
                    fontSize: 13.5.sp,
                    color: isDark ? Colors.white60 : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
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
