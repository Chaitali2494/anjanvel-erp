import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

class ExcelExportService {
  /// Export bookings to Excel
  static Future<void> exportBookings(List<Map<String, dynamic>> bookings) async {
    final excel = Excel.createExcel();
    final sheet = excel['Bookings'];

    // Headers
    final headers = [
      'Booking No', 'Guest Name', 'Phone', 'Package', 'Check-in',
      'Check-out', 'Adults', 'Children', 'Total (₹)', 'Paid (₹)',
      'Balance (₹)', 'Status', 'Payment Status', 'Source', 'Created'
    ];

    for (var i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        ..value = TextCellValue(headers[i])
        ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#2E7D32'));
    }

    // Data rows
    for (var i = 0; i < bookings.length; i++) {
      final b = bookings[i];
      final row = i + 1;
      final values = [
        b['booking_number'] ?? '',
        b['guest_name'] ?? '',
        b['guest_phone'] ?? '',
        b['package_name'] ?? '',
        b['check_in_date'] ?? '',
        b['check_out_date'] ?? '',
        b['num_adults'] ?? 0,
        b['num_children'] ?? 0,
        b['total_amount'] ?? 0,
        b['paid_amount'] ?? 0,
        b['balance_amount'] ?? 0,
        b['status'] ?? '',
        b['payment_status'] ?? '',
        b['source'] ?? '',
        b['created_at'] ?? '',
      ];

      for (var j = 0; j < values.length; j++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: row))
          .value = TextCellValue(values[j].toString());
      }
    }

    await _saveAndShare(excel, 'bookings_${DateFormat('yyyy-MM-dd').format(DateTime.now())}');
  }

  /// Export inventory to Excel
  static Future<void> exportInventory(List<Map<String, dynamic>> items) async {
    final excel = Excel.createExcel();
    final sheet = excel['Inventory'];

    final headers = ['SKU', 'Name', 'Category', 'Unit', 'Current Stock', 'Min Stock', 'Unit Cost', 'Status'];
    for (var i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        .value = TextCellValue(headers[i]);
    }

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final isLow = (item['current_stock'] as num) <= (item['min_stock'] as num);
      final row = i + 1;
      final values = [
        item['sku'] ?? '',
        item['name'] ?? '',
        item['category'] ?? '',
        item['unit'] ?? '',
        item['current_stock'] ?? 0,
        item['min_stock'] ?? 0,
        item['unit_cost'] ?? 0,
        isLow ? 'LOW STOCK' : 'OK',
      ];

      for (var j = 0; j < values.length; j++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: row));
        cell.value = TextCellValue(values[j].toString());
        if (isLow) {
          cell.cellStyle = CellStyle(backgroundColorHex: ExcelColor.fromHexString('#FFCDD2'));
        }
      }
    }

    await _saveAndShare(excel, 'inventory_${DateFormat('yyyy-MM-dd').format(DateTime.now())}');
  }

  static Future<void> _saveAndShare(Excel excel, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename.xlsx');
    await file.writeAsBytes(excel.encode()!);
    await Share.shareXFiles([XFile(file.path)], text: 'Anjanvel ERP Export');
  }
}
