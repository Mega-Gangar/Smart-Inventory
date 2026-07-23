import 'package:flutter/material.dart';

enum GraphFilter { today, last7Days, custom }
enum BreakdownFilter { thisMonth, lastMonth, thisYear, custom }

class DatePickerHelper {
  static Future<DateTimeRange?> selectCustomDateRange({
    required BuildContext context,
    DateTimeRange? currentRange,
    int maxDays = 7,
    DateTime? firstDate,
    DateTime? lastDate,
    Color primaryColor = Colors.indigo,
    bool showCapSnackBar = true,
  }) async {
    final now = DateTime.now();
    final effectiveFirstDate = firstDate ?? DateTime(2020);
    final effectiveLastDate = lastDate ?? now;

    // e.g., 7 days inclusive = start at (now - 6 days) through today
    final defaultInitialRange = DateTimeRange(
      start: now.subtract(Duration(days: maxDays - 1)),
      end: now,
    );

    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: effectiveFirstDate,
      lastDate: effectiveLastDate,
      initialDateRange: currentRange ?? defaultInitialRange,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: Theme.of(ctx).colorScheme.copyWith(
              primary: primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedRange == null) return null;

    DateTimeRange finalRange = pickedRange;
    final maxAllowedDurationDays = maxDays - 1;

    // Check if selected range exceeds maxDays limit
    if (pickedRange.duration.inDays > maxAllowedDurationDays) {
      finalRange = DateTimeRange(
        start: pickedRange.start,
        end: pickedRange.start.add(Duration(days: maxAllowedDurationDays)),
      );

      if (showCapSnackBar && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Date range capped to a maximum of $maxDays days."),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }

    return finalRange;
  }
}