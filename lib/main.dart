import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_inventory/services/theme_provider.dart';
import 'package:smart_inventory/screens/home_screen.dart';

final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const SmartBillingApp(),
    ),
  );
}
