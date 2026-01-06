import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:smart_inventory/main.dart';
class PdfHelper {
  static final formatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
  );
  static Future<void> generateAndPrintReceipt(Map<String, dynamic> sale) async {
    final pdf = pw.Document();
    final List<dynamic> items = jsonDecode(sale['items'] ?? '[]');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // Receipt style format
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text("SMART BILLING", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
              pw.Center(child: pw.Text("Receipt No: #${sale['id']}")),
              pw.Center(child: pw.Text("Date: ${sale['date'].toString().split('.')[0]}")),
              pw.Divider(),
              pw.Table(
                children: [
                  pw.TableRow(children: [
                    pw.Text("Item", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text("Qty", textAlign: pw.TextAlign.center),
                    pw.Text("Price", textAlign: pw.TextAlign.right),
                  ]),
                  ...items.map((item) => pw.TableRow(children: [
                    pw.Text(item['name']),
                    pw.Text("${item['qty']}", textAlign: pw.TextAlign.center),
                    pw.Text("${item['price']}", textAlign: pw.TextAlign.right),
                  ])),
                ],
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("TOTAL", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  pw.Text("Rs. ${(sale['total'])}/-", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Center(child: pw.Text("Thank you for your business!", style: pw.TextStyle(fontStyle: pw.FontStyle.italic))),
            ],
          );
        },
      ),
    );

    // This opens the Native Print/Save Preview dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Receipt_${sale['id']}.pdf',
    );
  }
}