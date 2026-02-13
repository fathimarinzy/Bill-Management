import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/accounting_service.dart';
import 'add_entry_screen.dart';
import 'person_details_screen.dart';
import 'login_screen.dart';
import '../models/stock_item.dart';
import '../models/accounting_entry.dart';
import '../models/transaction_model.dart';
import '../utils/bill_generator.dart';

class InvoiceItem {
  final String id;
  String name;
  double quantity;
  String unit;
  double rate;
  
  InvoiceItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.rate,
  });
  
  double get total => quantity * rate;
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 3; // Default to 'Customers' tab as per screenshot
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _historySearchQuery = ''; // Added for History tab search
  
  // Invoice state
  AccountingEntry? _selectedCustomer;
  final TextEditingController _customerController = TextEditingController();
  final List<InvoiceItem> _invoiceItems = [];
  int _invoiceItemCounter = 0;
  
  // Inline Item Entry Controllers
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  final FocusNode _qtyFocusNode = FocusNode();
  final FocusNode _rateFocusNode = FocusNode();
  String _selectedUnit = 'Nos';
  final List<String> _units = ['Nos', 'Pck', 'Bdl', 'Kg', 'Gm', 'Ltr', 'Box'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.userId != null) {
        final accountingService = Provider.of<AccountingService>(context, listen: false);
        accountingService.loadEntries(authService.userId!);
        accountingService.loadStockItems();
      }
    });
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customerController.dispose();
    _itemNameController.dispose();
    _qtyController.dispose();
    _rateController.dispose();
    _qtyFocusNode.dispose();
    _rateFocusNode.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _buildBody(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Items',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            label: 'Customers',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue[900],
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
      ),
      floatingActionButton: _getFAB(),
    );
  }

  Widget? _getFAB() {
    if (_selectedIndex == 3) {
      return FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const AddEntryScreen(),
          );
        },
        backgroundColor: Colors.blue[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.person_add, color: Colors.white),
      );
    } else if (_selectedIndex == 0) {
      return FloatingActionButton(
        onPressed: () => _showAddStockItemModal(),
        backgroundColor: Colors.blue[900],
        child: const Icon(Icons.add, color: Colors.white),
      );
    }
    return null;
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildItemsTab();
      case 1:
        return Consumer<AccountingService>(
          builder: (context, accountingService, child) {
            return Column(
              children: [
                AppBar(
                  title: const Text('Home'),
                  actions: [
                     IconButton(
                      icon: const Icon(Icons.logout),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Logout'),
                            content: const Text('Are you sure you want to logout?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Logout', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        
                        if (confirm == true && context.mounted) {
                          Provider.of<AuthService>(context, listen: false).logout();
                          Navigator.pushReplacement(
                            context, 
                            MaterialPageRoute(builder: (_) => const LoginScreen())
                          );
                        }
                      },
                    ),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildSummaryCard(accountingService),
                        _buildInvoiceContent(accountingService),
                      ],
                    ),
                  ),
                ),
                _buildInvoiceFooter(accountingService),
              ],
            );
          }
        );
      case 2:
        return _buildHistoryTab();
      case 3:
        return _buildCustomersTab();
      default:
        return const Center(child: Text('Unknown Tab'));
    }
  }

  Widget _buildCustomersTab() {
    return Consumer<AccountingService>(
      builder: (context, accountingService, child) {
        final filteredEntries = accountingService.entries.where((entry) {
          return entry.name.toLowerCase().contains(_searchQuery);
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Customers',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.filter_list),
                        onPressed: () {}, // Filter placeholder
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search Customers',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: filteredEntries.length,
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 70, endIndent: 16),
                itemBuilder: (context, index) {
                  final entry = filteredEntries[index];
                  final balance = entry.creditAmount - entry.debitAmount;
                  final isPositive = balance >= 0;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: entry.imagePath != null
                        ? CircleAvatar(backgroundImage: FileImage(File(entry.imagePath!)))
                        : CircleAvatar(
                            backgroundColor: Colors.grey[200],
                            child: Text(
                              entry.name[0].toUpperCase(),
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                            ),
                          ),
                    title: Text(
                      entry.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${balance.abs().toStringAsFixed(2)}',
                          style: TextStyle(
                            color: isPositive ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          isPositive ? 'Advance' : 'Due',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PersonDetailsScreen(entry: entry),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(AccountingService service) {
    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSummaryItem('Total Credit', service.totalCredit, Colors.green),
            _buildSummaryItem('Total Debit', service.totalDebit, Colors.red),
            _buildSummaryItem('Balance', service.balance, Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          amount.toStringAsFixed(2),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildItemsTab() {
    return Consumer<AccountingService>(
      builder: (context, accountingService, child) {
        final filteredItems = accountingService.stockItems.where((item) {
          return item.name.toLowerCase().contains(_searchQuery);
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Products',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.filter_list),
                        onPressed: () {}, 
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search Items',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filteredItems.isEmpty
                  ? const Center(child: Text('No items found', style: TextStyle(fontSize: 16, color: Colors.grey)))
                  : ListView.separated(
                      itemCount: filteredItems.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: item.rate != null
                              ? Text('Rate: ₹${item.rate}', style: const TextStyle(color: Colors.grey))
                              : null,
                          trailing: Text(
                            '${item.quantity} (Kg/Count)',
                            style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  void _showAddStockItemModal() {
    final nameController = TextEditingController();
    final rateController = TextEditingController();
    final quantityController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Add New Item',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'Item Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: rateController,
                      decoration: InputDecoration(
                        hintText: 'Rate',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: quantityController,
                      decoration: InputDecoration(
                        hintText: 'Quantity',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (nameController.text.isNotEmpty) {
                      final rate = double.tryParse(rateController.text);
                      final quantity = double.tryParse(quantityController.text) ?? 0.0;
                      
                      final newItem = StockItem(
                        name: nameController.text,
                        rate: rate,
                        quantity: quantity,
                      );

                      Provider.of<AccountingService>(context, listen: false).addStockItem(newItem);
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[900],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Save', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceContent(AccountingService accountingService) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Customer Selection (Autocomplete)
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Autocomplete<AccountingEntry>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<AccountingEntry>.empty();
                }
                return accountingService.entries.where((entry) {
                  return entry.name.toLowerCase().contains(textEditingValue.text.toLowerCase());
                });
              },
              displayStringForOption: (AccountingEntry option) => option.name,
              onSelected: (AccountingEntry selection) {
                setState(() {
                  _selectedCustomer = selection;
                  _customerController.text = selection.name;
                });
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                if (_customerController.text != controller.text) {
                   controller.text = _customerController.text;
                }
                
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: 'Select Customer',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    suffixIcon: _selectedCustomer != null 
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _selectedCustomer = null;
                              _customerController.clear();
                              controller.clear();
                            });
                          },
                        )
                      : null,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          
          // Inline Item Entry
          Row(
            children: [
              const SizedBox(width: 8),
              Expanded(
                child: Autocomplete<StockItem>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                     if (textEditingValue.text.isEmpty) {
                       return const Iterable<StockItem>.empty();
                     }
                     return accountingService.stockItems.where((item) {
                       return item.name.toLowerCase().contains(textEditingValue.text.toLowerCase());
                     });
                  },
                  displayStringForOption: (StockItem option) => option.name,
                  onSelected: (StockItem selection) {
                    _itemNameController.text = selection.name;
                    _rateController.text = selection.rate?.toString() ?? '';
                    // Auto-focus Qty field logic
                    _qtyFocusNode.requestFocus();
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: (val) => _itemNameController.text = val,
                      decoration: const InputDecoration(
                        hintText: 'Item Description',
                        border: UnderlineInputBorder(),
                      ),
                    );
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.grey), 
                onPressed: () {
                  _itemNameController.clear();
                  _qtyController.clear();
                  _rateController.clear();
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
               const SizedBox(width: 24), // Indent to align with description
               Expanded(
                 flex: 2,
                 child: TextField(
                   controller: _qtyController,
                   focusNode: _qtyFocusNode,
                   keyboardType: TextInputType.number,
                   decoration: const InputDecoration(
                     hintText: 'Qty',
                     contentPadding: EdgeInsets.symmetric(horizontal: 8),
                   ),
                   onSubmitted: (_) => _rateFocusNode.requestFocus(),
                 ),
               ),
               const SizedBox(width: 8),
               Expanded(
                 flex: 2,
                 child: DropdownButtonFormField<String>(
                   value: _selectedUnit,
                   items: _units.map((unit) => DropdownMenuItem(
                     value: unit, 
                     child: Text(unit, style: const TextStyle(fontSize: 14)),
                   )).toList(),
                   onChanged: (val) {
                     setState(() => _selectedUnit = val!);
                   },
                   decoration: const InputDecoration(
                     contentPadding: EdgeInsets.symmetric(horizontal: 8),
                     border: InputBorder.none,
                   ),
                 ),
               ),
               const SizedBox(width: 8),
               Expanded(
                 flex: 3,
                 child: TextField(
                   controller: _rateController,
                   focusNode: _rateFocusNode,
                   keyboardType: TextInputType.number,
                   decoration: const InputDecoration(
                     hintText: 'Rate',
                     prefixText: '₹ ',
                     contentPadding: EdgeInsets.symmetric(horizontal: 8),
                   ),
                   onSubmitted: (_) => _addInlineItem(),
                 ),
               ),
               IconButton(
                 onPressed: () => _addInlineItem(),
                 icon: const Icon(Icons.add_circle, color: Colors.blue, size: 28),
               ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Items List Heading
          Container(
             padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
             decoration: BoxDecoration(
               color: Colors.grey.shade100,
               borderRadius: BorderRadius.circular(8),
             ),
             child: Row(
               children: const [
                 SizedBox(width: 20, child: Text('#', style: TextStyle(color: Colors.grey))),
                 Expanded(flex: 3, child: Text('Item', style: TextStyle(color: Colors.grey))),
                 Expanded(flex: 2, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))),
                 Expanded(flex: 2, child: Text('Rate', textAlign: TextAlign.right, style: TextStyle(color: Colors.grey))),
                 Expanded(flex: 2, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(color: Colors.grey))),
               ],
             ),
          ),
          
          // Items List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _invoiceItems.length,
            itemBuilder: (context, index) {
              final item = _invoiceItems[index];
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                decoration: BoxDecoration(
                  color: index % 2 == 0 ? Colors.blue.withAlpha(13) : Colors.white,
                ),
                child: Row(
                  children: [
                    SizedBox(width: 20, child: Text('${index + 1}')),
                    Expanded(flex: 3, child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                    Expanded(
                      flex: 2, 
                      child: Text(
                        '${item.quantity.toStringAsFixed(0)} ${item.unit}', 
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Expanded(flex: 2, child: Text('₹${item.rate.toStringAsFixed(0)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
                    Expanded(
                      flex: 2, 
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('₹${item.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _addInlineItem() {
    if (_itemNameController.text.isEmpty) return;
    
    final qty = double.tryParse(_qtyController.text) ?? 1.0;
    final rate = double.tryParse(_rateController.text) ?? 0.0;
    
    setState(() {
      _invoiceItems.add(InvoiceItem(
        id: 'item_${_invoiceItemCounter++}',
        name: _itemNameController.text,
        quantity: qty,
        unit: _selectedUnit,
        rate: rate,
      ));
      
      // Clear fields for next item
      _itemNameController.clear();
      _qtyController.clear();
      _rateController.clear();
      _selectedUnit = 'Nos';
    });
  }

  Widget _buildCalculationRow(String label, double amount, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }

  // Dialog methods removed in favor of inline entry

  void _saveInvoice() async {
    if (_selectedCustomer == null || _invoiceItems.isEmpty) return;

    final total = _invoiceItems.fold<double>(0, (sum, item) => sum + item.total);

    try {
      // 1. Save Transaction to DB
      final transaction = TransactionModel(
        entryId: _selectedCustomer!.id!,
        amount: total,
        date: DateTime.now().toIso8601String(),
        description: 'Invoice: ${_invoiceItems.map((i) => i.name).join(", ")}',
        type: 'DEBIT', // Customer owes money
      );

      await Provider.of<AccountingService>(context, listen: false)
          .addTransaction(transaction);

      // 2. Generate/Print PDF (Optional based on user workflow, keeping it for now)
      // 2. Generate/Print PDF (Optional based on user workflow, keeping it for now)
      // final items = ... (Removed unused variable)

      // Note: We might not want to auto-print on save, but for now enabling it as per previous code
      // await BillGenerator.printInvoice(...) 
      // User said "save the invoice in history tab", not necessarily print.
      // So I'll comment out the print/share logic here to keep it fast, 
      // or maybe just keep it separate. The buttons are separate (Save, Share, Print).
      // So Save should just Save.

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice saved to History!')),
        );
        
        // Form details are NOT cleared, allowing user to Share/Print the saved invoice.
        // User explicitly can clear manually or by starting new invoice if we add a button.
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving invoice: $e')),
        );
      }
    }
  }

  void _shareInvoice() async {
    if (_selectedCustomer == null || _invoiceItems.isEmpty) return;

    try {
      final items = _invoiceItems.map((item) => {
        'name': item.name,
        'quantity': item.quantity,
        'unit': item.unit,
        'rate': item.rate,
        'total': item.total,
      }).toList();

      await BillGenerator.shareInvoice(
        customerName: _selectedCustomer!.name,
        customerPhone: _selectedCustomer!.phone,
        customerAdvance: _selectedCustomer!.creditAmount,
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

  void _printInvoice() async {
    if (_selectedCustomer == null || _invoiceItems.isEmpty) return;

    try {
      final items = _invoiceItems.map((item) => {
        'name': item.name,
        'quantity': item.quantity,
        'unit': item.unit,
        'rate': item.rate,
        'total': item.total,
      }).toList();

      await BillGenerator.printInvoice(
        customerName: _selectedCustomer!.name,
        customerPhone: _selectedCustomer!.phone,
        customerAdvance: _selectedCustomer!.creditAmount,
        items: items,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing invoice: $e')),
        );
      }
      }
    }

  Widget _buildInvoiceFooter(AccountingService accountingService) {
    final total = _invoiceItems.fold<double>(0, (sum, item) => sum + item.total);
    final advance = _selectedCustomer?.creditAmount ?? 0.0;
    final balance = total - advance;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(51), // 51 is 20% opacity of 255
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, -3), 
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildCalculationRow('Total', total, isBold: true, color: Colors.blue[900]),
          if (_selectedCustomer != null && _selectedCustomer!.creditAmount > 0) ...[
             const SizedBox(height: 8),
             _buildCalculationRow('Advance', advance, color: Colors.green),
             const Divider(height: 16),
             _buildCalculationRow('Balance', balance, isBold: true, color: balance >= 0 ? Colors.blue[900] : Colors.red),
          ],
          
          const SizedBox(height: 20),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _invoiceItems.isEmpty || _selectedCustomer == null
                      ? null
                      : () => _saveInvoice(),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[900],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _invoiceItems.isEmpty || _selectedCustomer == null
                      ? null
                      : () => _shareInvoice(),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[900],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _invoiceItems.isEmpty || _selectedCustomer == null
                      ? null
                      : () => _printInvoice(),
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Print'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue[900],
                    side: BorderSide(color: Colors.blue.shade900),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return Column(
      children: [
        // Custom App Bar for History/Invoices
        Container(
          padding: const EdgeInsets.only(top: 50, left: 16, right: 16, bottom: 16),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Invoices', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.sort)), // Sort icon placeholder
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (val) {
                  setState(() {
                    _historySearchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search Invoices',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: FutureBuilder<List<TransactionModel>>(
            future: Provider.of<AccountingService>(context, listen: false).getAllTransactions(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final allTransactions = snapshot.data ?? [];
              
              // Filter based on search query
              final transactions = allTransactions.where((tx) {
                if (_historySearchQuery.isEmpty) return true;
                
                final entry = Provider.of<AccountingService>(context, listen: false)
                      .entries
                      .firstWhere((e) => e.id == tx.entryId, orElse: () => AccountingEntry(userId: 0, name: '', phone: '', creditAmount: 0, debitAmount: 0, date: ''));
                
                return entry.name.toLowerCase().contains(_historySearchQuery.toLowerCase()) ||
                       tx.description.toLowerCase().contains(_historySearchQuery.toLowerCase()) ||
                       tx.amount.toString().contains(_historySearchQuery);
              }).toList();

              if (transactions.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'No Invoices/Estimates saved',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: transactions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final tx = transactions[index];
                  final isDebit = tx.type == 'DEBIT';
                  final date = DateTime.tryParse(tx.date) ?? DateTime.now();
                  final dateString = '${date.day}/${date.month}/${date.year}';
                  
                  final entry = Provider.of<AccountingService>(context, listen: false)
                      .entries
                      .firstWhere((e) => e.id == tx.entryId, orElse: () => AccountingEntry(userId: 0, name: 'Unknown', phone: '', creditAmount: 0, debitAmount: 0, date: ''));

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: isDebit ? Colors.blue.shade50 : Colors.green.shade50,
                      child: Icon(
                        isDebit ? Icons.description_outlined : Icons.attach_money,
                        color: isDebit ? Colors.blue : Colors.green,
                      ),
                    ),
                    title: Text(entry.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('$dateString • ${tx.description}'),
                    trailing: Text(
                      '₹${tx.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDebit ? Colors.black : Colors.green,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
