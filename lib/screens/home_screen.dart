import 'package:sizer/sizer.dart';
import 'package:flutter/material.dart';
import 'package:smart_inventory/auth/login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_inventory/screens/billing.dart';
import 'package:smart_inventory/screens/dashboard.dart';
import 'package:smart_inventory/screens/inventory.dart';
import 'package:smart_inventory/database/database_helper.dart';

class SmartBillingApp extends StatelessWidget {
  const SmartBillingApp({super.key});
  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(primarySwatch: Colors.indigo, useMaterial3: true),
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return const HomeScreen();
              }
              return const LoginPage();
            },
          ),
        );
      },
    );
  }
}


// --- MAIN UI SCREEN ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // 1. Use a list of GlobalKeys to talk to the pages
  final List<GlobalKey<RefreshableState>> _keys = [
    GlobalKey<RefreshableState>(), // Billing
    GlobalKey<RefreshableState>(), // Inventory
    GlobalKey<RefreshableState>(), // Analytics
  ];

  @override
  Widget build(BuildContext context) {
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
        decoration: const BoxDecoration(color: Colors.indigo),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            indicatorColor: Colors.white.withValues(
              alpha: 0.2,
            ), // The color of the "pill"
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                );
              }
              return TextStyle(fontSize: 13.sp, color: Colors.white60);
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return IconThemeData(size: 22.sp, color: Colors.white);
              }
              return IconThemeData(size: 20.sp, color: Colors.white60);
            }),
          ),
          child: NavigationBar(
            height: 9.h,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
              _keys[index].currentState?.refreshData();
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Billing',
              ),
              NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: 'Stock',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart),
                label: 'Analytics',
              ),
            ],
          ),
        ),
      ),
    );
  }
}