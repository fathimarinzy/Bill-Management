import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/accounting_entry.dart';
import '../models/invoice_item_model.dart';
import '../services/accounting_service.dart';
import '../utils/bill_generator.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final TransactionModel transaction;
  final AccountingEntry customer;

  const InvoiceDetailScreen({
    super.key,
    required this.transaction,
    required this.customer,
  });

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  List<InvoiceItemModel> _items = [];
  bool _isLoading = true;
  bool _isEditing = false;

  // Edit controllers
  final List<TextEditingController> _nameControllers = [];
  final List<TextEditingController> _qtyControllers = [];
  final List<TextEditingController> _rateControllers = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    for (var c in _nameControllers) { c.dispose(); }
    for (var c in _qtyControllers) { c.dispose(); }
    for (var c in _rateControllers) { c.dispose(); }
    super.dispose();
  }

  Future<void> _loadItems() async {
    final service = Provider.of<AccountingService>(context, listen: false);
    final items = await service.getInvoiceItems(widget.transaction.id!);
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }




  Future<void> _saveEdits() async {
    final service = Provider.of<AccountingService>(context, listen: false);

    final updatedItems = <InvoiceItemModel>[];
    double newTotal = 0;

    for (int i = 0; i < _items.length; i++) {
      final name = _nameControllers[i].text;
      final qty = double.tryParse(_qtyControllers[i].text) ?? _items[i].quantity;
      final rate = double.tryParse(_rateControllers[i].text) ?? _items[i].rate;
      final total = qty * rate;
      newTotal += total;

      updatedItems.add(InvoiceItemModel(
        transactionId: widget.transaction.id!,
        itemName: name,
        quantity: qty,
        unit: _items[i].unit,
        rate: rate,
        total: total,
      ));
    }

    await service.updateInvoiceItems(widget.transaction.id!, updatedItems);

    // Update transaction amount
    final updatedTx = TransactionModel(
      id: widget.transaction.id,
      entryId: widget.transaction.entryId,
      amount: newTotal,
      date: widget.transaction.date,
      description: (){
        if (widget.customer.name == 'Walk-in Customer') {
           final parts = widget.transaction.description.split('|');
           if (parts.length > 1) {
              return '${parts[0]} | ${updatedItems.map((i) => i.itemName).join(", ")}';
           }
        }
        return 'Invoice: ${updatedItems.map((i) => i.itemName).join(", ")}';
      }(),
      type: widget.transaction.type,
    );
    await service.updateTransaction(updatedTx);

    await _loadItems();
    setState(() => _isEditing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice updated!')),
      );
    }
  }

  void _shareInvoice() async {
    try {
      final items = _items.map((item) => {
        'name': item.itemName,
        'quantity': item.quantity,
        'unit': item.unit,
        'rate': item.rate,
        'total': item.total,
      }).toList();

      await BillGenerator.shareInvoice(
        customerName: (){
          if (widget.customer.name == 'Walk-in Customer') {
            final parts = widget.transaction.description.split('|');
            if (parts.length > 1) {
              return parts[0].replaceFirst('Invoice:', '').trim();
            }
          }
          return widget.customer.name;
        }(),
        customerPhone: widget.customer.phone,
        customerAdvance: widget.customer.debitAmount,
        items: items,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing invoice: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(widget.transaction.date) ?? DateTime.now();
    final dateString = DateFormat('dd-MMM-yy').format(date);
    final total = _items.fold<double>(0, (sum, item) => sum + item.total);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text((){
          if (widget.customer.name == 'Walk-in Customer') {
            final parts = widget.transaction.description.split('|');
            if (parts.length > 1) {
              return parts[0].replaceFirst('Invoice:', '').trim();
            }
          }
          return widget.customer.name;
        }()),
        actions: [
          if (!_isEditing) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _items.isNotEmpty ? () {
                Navigator.pop(context, {
                  'action': 'edit',
                  'transaction': widget.transaction,
                  'customer': widget.customer,
                  'items': _items,
                });
              } : null,
            ),
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _items.isNotEmpty ? _shareInvoice : null,
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveEdits,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _isEditing = false),
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(
                  child: Text(
                    'No items found for this invoice.\n(Invoices created before this update won\'t have items)',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : Column(
                  children: [
                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      color: Colors.blue[800],
                      child: const Row(
                        children: [
                          SizedBox(width: 30, child: Text('S.No', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                          SizedBox(width: 8),
                          Expanded(flex: 3, child: Text('Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          Expanded(flex: 2, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          Expanded(flex: 2, child: Text('Rate', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          Expanded(flex: 2, child: Text('Amount', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),

                    // Items List
                    Expanded(
                      child: ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];

                          if (_isEditing) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                              child: Row(
                                children: [
                                  SizedBox(width: 30, child: Text('${index + 1}.', style: const TextStyle(fontSize: 14))),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 3,
                                    child: TextField(
                                      controller: _nameControllers[index],
                                      style: const TextStyle(fontSize: 14),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: _qtyControllers[index],
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 14),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: _rateControllers[index],
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(fontSize: 14),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                        border: OutlineInputBorder(),
                                        prefixText: '\u20b9',
                                      ),
                                    ),
                                  ),
                                  const Expanded(flex: 2, child: SizedBox()),
                                ],
                              ),
                            );
                          }

                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                            ),
                            child: Row(
                              children: [
                                SizedBox(width: 30, child: Text('${index + 1}.', style: const TextStyle(fontSize: 14))),
                                const SizedBox(width: 8),
                                Expanded(flex: 3, child: Text(item.itemName, style: const TextStyle(fontSize: 14))),
                                Expanded(flex: 2, child: Text(item.quantity.toStringAsFixed(0), textAlign: TextAlign.center, style: const TextStyle(fontSize: 14))),
                                Expanded(flex: 2, child: Text('\u20b9${item.rate.toStringAsFixed(0)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 14))),
                                Expanded(flex: 2, child: Text('\u20b9${item.total.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Footer
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: Colors.grey.shade300, width: 2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            dateString,
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                          Row(
                            children: [
                              Text(
                                'Total',
                                style: TextStyle(
                                  color: Colors.blue[900],
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                '\u20b9${total.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: Colors.blue[900],
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
