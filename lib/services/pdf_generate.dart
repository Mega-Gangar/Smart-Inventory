import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PdfHelper {
  // Static formatter using standard characters to avoid font errors
  static final pdfFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs. ',
  );
  static Future<void> generateAndPrintReceipt(Map<String, dynamic> sale) async {
    final prefs = await SharedPreferences.getInstance();
    String company = prefs.getString('company_name') ?? "Smart Billing";
    String gstin = prefs.getString('gstin_number') ?? "";
    final pdf = pw.Document();
    final List<dynamic> items = jsonDecode(sale['items'] ?? '[]');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(child: pw.Text(company, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
                if (gstin.isNotEmpty) pw.Center(child: pw.Text("GSTIN: $gstin")),
                pw.Center(child: pw.Text("Receipt No: #${sale['id'] ?? 'N/A' }")),
                pw.Center(child: pw.Text("Date: ${sale['date'].toString().split('.')[0]}")),
                pw.Divider(thickness: 1),

                pw.Table(
                  children: [
                    pw.TableRow(children: [
                      pw.Text("Item", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text("Qty", textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text("Price", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text("Total", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    ]),
                    pw.TableRow(children: [pw.SizedBox(height: 4), pw.SizedBox(), pw.SizedBox()]), // Row spacing
                    ...items.map((item) {
            final double lineTotal = (item['qty'] as num).toDouble() * (item['price'] as num).toDouble();
                      return pw.TableRow(children: [

                      pw.Text(item['name'], style: pw.TextStyle(fontSize: 9)),
                      pw.Text("${item['qty']}", textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9)),
                      pw.Text("${item['price']}", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9)),
                      pw.Text(lineTotal.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8)),
                    ]);}),
                  ],
                ),

                pw.Divider(thickness: 1),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("TOTAL", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    // Added your /- suffix here
                    pw.Text("${pdfFormatter.format(sale['total'])}/-", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Center(child: pw.Text("Thank you for your business!", style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic))),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Receipt_${sale['id']}.pdf',
    );
  }
  static Future<Uint8List> generateReceiptBytes(Map<String, dynamic> sale) async {
    final prefs = await SharedPreferences.getInstance();
    String company = prefs.getString('company_name') ?? "Smart Billing";
    String gstin = prefs.getString('gstin_number') ?? "";
    final List<dynamic> items = jsonDecode(sale['items'] ?? '[]');
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(child: pw.Text(company, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
                if (gstin.isNotEmpty) pw.Center(child: pw.Text("GSTIN: $gstin")),
                pw.Center(child: pw.Text("Receipt No: #${sale['id']}")),
                pw.Center(child: pw.Text("Date: ${sale['date'].toString().split('.')[0]}")),
                pw.Divider(thickness: 1),

                pw.Table(
                  children: [
                    pw.TableRow(children: [
                      pw.Text("Item", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text("Qty", textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text("Price", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text("Total", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    ]),
                    pw.TableRow(children: [pw.SizedBox(height: 4), pw.SizedBox(), pw.SizedBox()]), // Row spacing
                    ...items.map((item) {
                      final double lineTotal = (item['qty'] as num).toDouble() * (item['price'] as num).toDouble();
                      return pw.TableRow(children: [

                        pw.Text(item['name'], style: pw.TextStyle(fontSize: 9)),
                        pw.Text("${item['qty']}", textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9)),
                        pw.Text("${item['price']}", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9)),
                        pw.Text(lineTotal.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8)),
                      ]);}),
                  ],
                ),

                pw.Divider(thickness: 1),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("TOTAL", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    // Added your /- suffix here
                    pw.Text("${pdfFormatter.format(sale['total'])}/-", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Center(child: pw.Text("Thank you for your business!", style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic))),
              ],
            ),
          );
        },
      ),
    );
    return pdf.save();
  }
}