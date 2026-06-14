import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class PdfService {
  /// Generate invoice PDF for a booking
  static Future<File> generateInvoice(Map<String, dynamic> booking) async {
    final pdf = pw.Document();
    final now = DateTime.now();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('ANJANVEL AGRO TOURISM RESORT',
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('Anjanvel Village, Maharashtra, India'),
                    pw.Text('GST: 27XXXXXXXXXXXZX'),
                    pw.Text('Phone: +91 9876543210'),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('INVOICE',
                        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('2E7D32'))),
                    pw.SizedBox(height: 8),
                    pw.Text('Invoice #: ${booking['booking_number']}'),
                    pw.Text('Date: ${DateFormat('d MMM yyyy').format(now)}'),
                  ],
                ),
              ],
            ),
            pw.Divider(),
            pw.SizedBox(height: 16),

            // Guest Info
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BILL TO:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.SizedBox(height: 4),
                      pw.Text(booking['guest_name'] ?? '', style: const pw.TextStyle(fontSize: 14)),
                      if (booking['guest_phone'] != null) pw.Text(booking['guest_phone']),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BOOKING DETAILS:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.SizedBox(height: 4),
                      pw.Text('Check-in: ${booking['check_in_date']}'),
                      if (booking['check_out_date'] != null)
                        pw.Text('Check-out: ${booking['check_out_date']}'),
                      pw.Text('Package: ${booking['package_name'] ?? 'Custom'}'),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 24),

            // Items Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF2E7D32)),
                  children: [
                    _tableHeader('Description'),
                    _tableHeader('Qty'),
                    _tableHeader('Rate'),
                    _tableHeader('Amount'),
                  ],
                ),
                pw.TableRow(children: [
                  _tableCell(booking['package_name'] ?? 'Accommodation & Services'),
                  _tableCell('${(booking['num_adults'] ?? 1)} adults, ${(booking['num_children'] ?? 0)} children'),
                  _tableCell('₹${booking['base_amount'] ?? 0}'),
                  _tableCell('₹${booking['base_amount'] ?? 0}'),
                ]),
                if ((booking['addon_amount'] ?? 0) > 0)
                  pw.TableRow(children: [
                    _tableCell('Add-ons & Extras'),
                    _tableCell('1'),
                    _tableCell('₹${booking['addon_amount']}'),
                    _tableCell('₹${booking['addon_amount']}'),
                  ]),
              ],
            ),
            pw.SizedBox(height: 16),

            // Totals
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.SizedBox(
                  width: 250,
                  child: pw.Column(
                    children: [
                      _totalRow('Subtotal', '₹${booking['base_amount'] ?? 0}'),
                      if ((booking['discount_amount'] ?? 0) > 0)
                        _totalRow('Discount', '-₹${booking['discount_amount']}'),
                      _totalRow('GST', '₹${booking['tax_amount'] ?? 0}'),
                      pw.Divider(),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                          pw.Text('₹${booking['total_amount'] ?? 0}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColor.fromHex('2E7D32'))),
                        ],
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Paid', style: const pw.TextStyle(color: PdfColors.green)),
                          pw.Text('-₹${booking['paid_amount'] ?? 0}', style: const pw.TextStyle(color: PdfColors.green)),
                        ],
                      ),
                      pw.Divider(),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('BALANCE DUE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.Text('₹${booking['balance_amount'] ?? 0}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.Spacer(),

            // Footer
            pw.Divider(),
            pw.Center(
              child: pw.Text(
                'Thank you for staying at Anjanvel! We look forward to hosting you again. 🌿',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/invoice_${booking['booking_number']}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
    );
  }

  static pw.Widget _tableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
    );
  }

  static pw.Widget _totalRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
        pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
      ],
    );
  }

  /// Print invoice
  static Future<void> printInvoice(Map<String, dynamic> booking) async {
    final file = await generateInvoice(booking);
    await Printing.layoutPdf(onLayout: (_) async => file.readAsBytesSync());
  }
}
