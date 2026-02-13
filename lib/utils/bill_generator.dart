import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/accounting_entry.dart';
import '../models/item_detail.dart';

class BillGenerator {
  static Future<Uint8List> generateBill(AccountingEntry entry, List<ItemDetail> items) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text('INVOICE', style: pw.TextStyle(fontSize: 40, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('To:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(entry.name),
                      pw.Text(entry.phone),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 40),
              pw.Table.fromTextArray(
                context: context,
                headers: ['Item', 'Rate', 'Qty', 'Total'],
                data: items.map((item) => [
                  item.itemName,
                  item.rate.toStringAsFixed(2),
                  item.quantity.toStringAsFixed(2),
                  item.totalPrice.toStringAsFixed(2),
                ]).toList(),
                border: null,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellHeight: 30,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerRight,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                },
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('Total Amount: ', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                    items.fold(0.0, (sum, item) => sum + item.totalPrice).toStringAsFixed(2),
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Footer(
                title: pw.Text('Thank you for your business!'),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> printBill(AccountingEntry entry, List<ItemDetail> items) async {
    final pdfBytes = await generateBill(entry, items);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Bill_${entry.name}_${DateFormat('yyyyMMdd').format(DateTime.now())}',
    );
  }

  static Future<Uint8List> generateInvoice({
    required String customerName,
    required String customerPhone,
    required double customerAdvance,
    required List<Map<String, dynamic>> items,
  }) async {
    final pdf = pw.Document();
    final total = items.fold<double>(0, (sum, item) => sum + (item['total'] as double));
    final balance = total - customerAdvance;

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text('INVOICE', style: pw.TextStyle(fontSize: 40, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('To:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(customerName),
                      pw.Text(customerPhone),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 40),
              pw.TableHelper.fromTextArray(
                context: context,
                headers: ['Item', 'Qty', 'Unit', 'Rate', 'Total'],
                data: items.map((item) => [
                  item['name'],
                  item['quantity'].toStringAsFixed(2),
                  item['unit'],
                  item['rate'].toStringAsFixed(2),
                  item['total'].toStringAsFixed(2),
                ]).toList(),
                border: null,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellHeight: 30,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerRight,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                },
              ),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text('Total: ', style: pw.TextStyle(fontSize: 14)),
                          pw.SizedBox(width: 20),
                          pw.Text('₹${total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14)),
                        ],
                      ),
                      pw.SizedBox(height: 5),
                      pw.Row(
                        children: [
                          pw.Text('Advance: ', style: pw.TextStyle(fontSize: 14, color: PdfColors.green)),
                          pw.SizedBox(width: 20),
                          pw.Text('₹${customerAdvance.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, color: PdfColors.green)),
                        ],
                      ),
                      pw.Divider(),
                      pw.Row(
                        children: [
                          pw.Text('Balance: ', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(width: 20),
                          pw.Text(
                            '₹${balance.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: balance >= 0 ? PdfColors.blue : PdfColors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Footer(
                title: pw.Text('Thank you for your business!'),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> printInvoice({
    required String customerName,
    required String customerPhone,
    required double customerAdvance,
    required List<Map<String, dynamic>> items,
  }) async {
    final pdfBytes = await generateInvoice(
      customerName: customerName,
      customerPhone: customerPhone,
      customerAdvance: customerAdvance,
      items: items,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Invoice_${customerName}_${DateFormat('yyyyMMdd').format(DateTime.now())}',
    );
  }

  static Future<void> shareInvoice({
    required String customerName,
    required String customerPhone,
    required double customerAdvance,
    required List<Map<String, dynamic>> items,
  }) async {
    final pdfBytes = await generateInvoice(
      customerName: customerName,
      customerPhone: customerPhone,
      customerAdvance: customerAdvance,
      items: items,
    );
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Invoice_${customerName}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }
}
