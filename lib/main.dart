import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_inventory/services/theme_provider.dart';
import 'firebase_options.dart';
import 'package:smart_inventory/screens/home_screen.dart';

final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const SmartBillingApp(),
    ),
  );
}
