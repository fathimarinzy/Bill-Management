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
  
  // Invoice state
  AccountingEntry? _selectedCustomer;
  final List<InvoiceItem> _invoiceItems = [];
  int _invoiceItemCounter = 0;

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
                        _buildInvoiceSection(accountingService),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
        );
      case 2:
        return const Center(child: Text('History - Coming Soon'));
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
      color: Colors.deepPurple.shade50,
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

  Widget _buildInvoiceSection(AccountingService accountingService) {
    final total = _invoiceItems.fold<double>(0, (sum, item) => sum + item.total);
    final advance = _selectedCustomer?.creditAmount ?? 0.0;
    final balance = total - advance;

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create Invoice',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Customer Dropdown
            DropdownButtonFormField<AccountingEntry>(
              value: _selectedCustomer,
              decoration: InputDecoration(
                labelText: 'Select Customer',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: accountingService.entries.map((entry) {
                return DropdownMenuItem(
                  value: entry,
                  child: Text(entry.name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCustomer = value;
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Add Item Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showAddInvoiceItemDialog(accountingService),
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Items List
            if (_invoiceItems.isNotEmpty) ...[
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _invoiceItems.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = _invoiceItems[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text('${item.quantity} ${item.unit} × ₹${item.rate.toStringAsFixed(2)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '₹${item.total.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _invoiceItems.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(thickness: 2),
              const SizedBox(height: 8),
            ],
            
            // Calculations
            _buildCalculationRow('Total', total),
            const SizedBox(height: 4),
            _buildCalculationRow('Advance', advance, color: Colors.green),
            const Divider(),
            _buildCalculationRow('Balance', balance, isBold: true, color: balance >= 0 ? Colors.blue[900] : Colors.red),
            const SizedBox(height: 16),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _invoiceItems.isEmpty || _selectedCustomer == null
                        ? null
                        : () => _saveInvoice(),
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[900],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _invoiceItems.isEmpty || _selectedCustomer == null
                        ? null
                        : () => _shareInvoice(),
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _invoiceItems.isEmpty || _selectedCustomer == null
                        ? null
                        : () => _printInvoice(),
                    icon: const Icon(Icons.print),
                    label: const Text('Print'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[900],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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

  void _showAddInvoiceItemDialog(AccountingService accountingService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.inventory_2),
              title: const Text('Select from Stock'),
              onTap: () {
                Navigator.pop(context);
                _showStockItemSelection(accountingService);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Manual Entry'),
              onTap: () {
                Navigator.pop(context);
                _showManualItemEntry();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showStockItemSelection(AccountingService accountingService) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Item from Stock'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: accountingService.stockItems.length,
              itemBuilder: (context, index) {
                final stockItem = accountingService.stockItems[index];
                return ListTile(
                  title: Text(stockItem.name),
                  subtitle: stockItem.rate != null 
                      ? Text('Rate: ₹${stockItem.rate}')
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    _showQuantityDialog(stockItem);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showQuantityDialog(StockItem stockItem) {
    final qtyController = TextEditingController(text: '1');
    final rateController = TextEditingController(
      text: stockItem.rate?.toString() ?? ''
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add ${stockItem.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyController,
              decoration: const InputDecoration(labelText: 'Quantity'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: rateController,
              decoration: const InputDecoration(labelText: 'Rate'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final qty = double.tryParse(qtyController.text) ?? 1;
              final rate = double.tryParse(rateController.text) ?? 0;
              
              setState(() {
                _invoiceItems.add(InvoiceItem(
                  id: 'item_${_invoiceItemCounter++}',
                  name: stockItem.name,
                  quantity: qty,
                  unit: 'Nos',
                  rate: rate,
                ));
              });
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showManualItemEntry() {
    final nameController = TextEditingController();
    final qtyController = TextEditingController();
    final unitController = TextEditingController(text: 'Nos');
    final rateController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual Item Entry'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Item Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: qtyController,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: unitController,
                decoration: const InputDecoration(labelText: 'Unit'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: rateController,
                decoration: const InputDecoration(labelText: 'Rate'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                final qty = double.tryParse(qtyController.text) ?? 1;
                final rate = double.tryParse(rateController.text) ?? 0;
                
                setState(() {
                  _invoiceItems.add(InvoiceItem(
                    id: 'item_${_invoiceItemCounter++}',
                    name: nameController.text,
                    quantity: qty,
                    unit: unitController.text,
                    rate: rate,
                  ));
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _saveInvoice() async {
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice saved successfully!')),
        );
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
}
