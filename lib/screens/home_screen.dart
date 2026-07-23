import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:smart_inventory/screens/billing.dart';
import 'package:smart_inventory/screens/dashboard.dart';
import 'package:smart_inventory/screens/inventory.dart';

import '../database/database_helper.dart';
import '../services/theme_provider.dart';

class SmartBillingApp extends StatelessWidget {
  const SmartBillingApp({super.key});

  // Cached Theme Data structures to avoid re-allocation on rebuilds
  static final ThemeData _lightTheme = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: Colors.indigo,
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.indigo,
      elevation: 0,
      foregroundColor: Colors.white,
    ),
    cardColor: const Color(0xFFF5F5F5),
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Colors.white.withValues(alpha: 0.2),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: Colors.indigo);
        }
        return const IconThemeData(color: Colors.black54);
      }),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    ),
  );

  static final ThemeData _darkTheme = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: Colors.indigo,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF121212),
    cardColor: const Color(0xFF1E1E1E),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E1E),
      elevation: 0,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.4),
        fontSize: 14,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF1E1E1E),
      indicatorColor: Colors.indigo.withValues(alpha: 0.3),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: Colors.white);
        }
        return const IconThemeData(color: Colors.white54);
      }),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType) {
        // Listen strictly to themeMode updates rather than the whole Provider state
        final themeMode = context.select<ThemeProvider, ThemeMode>(
              (provider) => provider.themeMode,
        );

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Smart Billing System',
          themeMode: themeMode,
          theme: _lightTheme,
          darkTheme: _darkTheme,
          home: const HomeScreen(),
        );
      },
    );
  }
}

// --- MAIN UI SCREEN ---
class HomeScreen extends StatefulWidget {
  final int initialIndex;
  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentIndex;

  // GlobalKeys to talk to individual tab pages
  final List<GlobalKey<RefreshableState>> _keys = [
    GlobalKey<RefreshableState>(), // Billing
    GlobalKey<RefreshableState>(), // Inventory
    GlobalKey<RefreshableState>(), // Analytics
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          BillingPage(key: _keys[0]),
          InventoryPage(key: _keys[1]),
          DashboardPage(key: _keys[2]),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.indigo,
        ),
        child: NavigationBar(
          height: 9.h,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            if (_currentIndex != index) {
              setState(() => _currentIndex = index);
              _keys[index].currentState?.refreshData();
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined, color: Colors.white60),
              selectedIcon: Icon(Icons.receipt_long, color: Colors.white),
              label: 'Billing',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined, color: Colors.white60),
              selectedIcon: Icon(Icons.inventory_2, color: Colors.white),
              label: 'Stock',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined, color: Colors.white60),
              selectedIcon: Icon(Icons.bar_chart, color: Colors.white),
              label: 'Analytics',
            ),
          ],
        ),
      ),
    );
  }
}