import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/accounting_service.dart';
import 'add_entry_screen.dart';
import 'person_details_screen.dart';
import 'login_screen.dart';
import 'invoice_detail_screen.dart';
import '../models/stock_item.dart';
import '../models/accounting_entry.dart';
import '../models/transaction_model.dart';
import '../models/invoice_item_model.dart';
import '../models/sale_purchase_model.dart';
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
  int _selectedIndex = 2; // Default to 'home' tab (index 2 after reindex)
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _historySearchQuery = ''; // Added for History tab search
  String _salePurchaseFilter = 'All'; // All, Daily, Weekly, Monthly, Yearly
  
  // Invoice state
  AccountingEntry? _selectedCustomer;
  final TextEditingController _customerController = TextEditingController();
  final List<InvoiceItem> _invoiceItems = [];
  int _invoiceItemCounter = 0;
  int? _editingTransactionId; // Track if editing an existing invoice
  
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
        accountingService.loadSalePurchaseEntries();
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
            icon: Icon(Icons.point_of_sale_outlined),
            label: 'Sale/Buy',
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
    if (_selectedIndex == 4) { // Customers
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
    } else if (_selectedIndex == 0) { // Items
      return FloatingActionButton(
        onPressed: () => _showAddStockItemModal(),
        backgroundColor: Colors.blue[900],
        child: const Icon(Icons.add, color: Colors.white),
      );
    } else if (_selectedIndex == 1) { // Sale & Purchase
      return FloatingActionButton(
        onPressed: () => _showAddSalePurchaseModal(),
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
        return _buildSalePurchaseTab();
      case 2:
        return Consumer<AccountingService>(
          builder: (context, accountingService, child) {
            return Column(
              children: [
                AppBar(
                  title: const Text('Invo'),
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
      case 3:
        return _buildHistoryTab();
      case 4:
        return _buildCustomersTab();
      default:
        return const Center(child: Text('Unknown Tab'));
    }
  }

  Widget _buildCustomersTab() {
    return Consumer<AccountingService>(
      builder: (context, accountingService, child) {
        final filteredEntries = accountingService.entries.where((entry) {
          return entry.name != 'Walk-in Customer' && 
                 entry.name.toLowerCase().contains(_searchQuery);
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
                      // IconButton(
                      //   icon: const Icon(Icons.filter_list),
                      //   onPressed: () {}, // Filter placeholder
                      // ),
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
                  final advance = entry.debitAmount; // Given amount = advance

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
                          '₹${advance.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Advance',
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
                      // IconButton(
                      //   icon: const Icon(Icons.filter_list),
                      //   onPressed: () {}, 
                      // ),
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

  Widget _buildSalePurchaseTab() {
    return Consumer<AccountingService>(
      builder: (context, accountingService, child) {
        final entries = accountingService.salePurchaseEntries;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Sale & Purchase',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  PopupMenuButton<String>(
                    icon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _salePurchaseFilter,
                          style: TextStyle(color: Colors.blue[900], fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        Icon(Icons.filter_list, color: Colors.blue[900]),
                      ],
                    ),
                    onSelected: (value) {
                      setState(() => _salePurchaseFilter = value);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'All', child: Text('All')),
                      const PopupMenuItem(value: 'Daily', child: Text('Daily')),
                      const PopupMenuItem(value: 'Weekly', child: Text('Weekly')),
                      const PopupMenuItem(value: 'Monthly', child: Text('Monthly')),
                      const PopupMenuItem(value: 'Yearly', child: Text('Yearly')),
                    ],
                  ),
                ],
              ),
            ),
            // Filter entries based on selected period
            Builder(
              builder: (context) {
                final now = DateTime.now();
                final filteredEntries = entries.where((e) {
                  final entryDate = DateTime.tryParse(e.date) ?? DateTime.now();
                  switch (_salePurchaseFilter) {
                    case 'Daily':
                      return entryDate.year == now.year && entryDate.month == now.month && entryDate.day == now.day;
                    case 'Weekly':
                      final weekStart = now.subtract(Duration(days: now.weekday - 1));
                      final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
                      return entryDate.isAfter(weekStartDate.subtract(const Duration(seconds: 1)));
                    case 'Monthly':
                      return entryDate.year == now.year && entryDate.month == now.month;
                    case 'Yearly':
                      return entryDate.year == now.year;
                    default:
                      return true;
                  }
                }).toList();

                final totalSale = filteredEntries.fold<double>(0, (sum, e) => sum + e.salePrice);
                final totalPurchase = filteredEntries.fold<double>(0, (sum, e) => sum + e.purchasePrice);
                final totalProfit = filteredEntries.fold<double>(0, (sum, e) => sum + e.profit);

                return Expanded(
                  child: Column(
                    children: [
                      // Summary card
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Card(
                          color: Colors.blue.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    Text('Total Sale', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                    const SizedBox(height: 4),
                                    Text(
                                      '\u20b9${totalSale.toStringAsFixed(0)}',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                                    ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text('Total Purchase', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                    const SizedBox(height: 4),
                                    Text(
                                      '\u20b9${totalPurchase.toStringAsFixed(0)}',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange),
                                    ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text('Profit', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                    const SizedBox(height: 4),
                                    Text(
                                      '\u20b9${totalProfit.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: totalProfit >= 0 ? Colors.green : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: filteredEntries.isEmpty
                            ? Center(child: Text('No entries for ${_salePurchaseFilter == 'All' ? 'now' : 'this ${_salePurchaseFilter.toLowerCase()} period'}.', style: const TextStyle(fontSize: 16, color: Colors.grey)))
                            : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredEntries.length,
                      itemBuilder: (context, index) {
                        final entry = filteredEntries[index];
                        final isProfit = entry.profit >= 0;
                        return Dismissible(
                          key: Key(entry.id.toString()),
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) {
                            accountingService.deleteSalePurchaseEntry(entry.id!);
                          },
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        DateFormat('dd MMM yyyy').format(DateTime.tryParse(entry.date) ?? DateTime.now()),
                                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isProfit ? Colors.green.shade50 : Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '${isProfit ? '+' : ''}\u20b9${entry.profit.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isProfit ? Colors.green : Colors.red,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Sale Price', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                                            const SizedBox(height: 2),
                                            Text('\u20b9${entry.salePrice.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Purchase Price', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                                            const SizedBox(height: 2),
                                            Text('\u20b9${entry.purchasePrice.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('Profit', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                                          const SizedBox(height: 2),
                                          Text(
                                            '\u20b9${entry.profit.toStringAsFixed(0)}',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isProfit ? Colors.green : Colors.red),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
              ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showAddSalePurchaseModal() {
    final salePriceController = TextEditingController();
    final purchasePriceController = TextEditingController();

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
                    'Add Sale & Purchase',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: salePriceController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Sale Price',
                  prefixText: '\u20b9 ',
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
              const SizedBox(height: 16),
              TextField(
                controller: purchasePriceController,
                decoration: InputDecoration(
                  hintText: 'Purchase Price',
                  prefixText: '\u20b9 ',
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final salePrice = double.tryParse(salePriceController.text) ?? 0.0;
                    final purchasePrice = double.tryParse(purchasePriceController.text) ?? 0.0;

                    if (salePrice > 0 || purchasePrice > 0) {
                      final entry = SalePurchaseEntry(
                        itemName: DateFormat('dd MMM yyyy').format(DateTime.now()),
                        salePrice: salePrice,
                        purchasePrice: purchasePrice,
                        date: DateTime.now().toIso8601String(),
                      );

                      Provider.of<AccountingService>(context, listen: false).addSalePurchaseEntry(entry);
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
                  onChanged: (val) {
                    setState(() {
                      _customerController.text = val;
                      // Update filtered options logic is handled by autocomplete, 
                      // but we need setState to update button enabled state
                    });
                  },
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
                    // Sync our controller text to autocomplete's controller (handle empty too)
                    if (controller.text != _itemNameController.text) {
                      controller.text = _itemNameController.text;
                    }
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
                  setState(() {
                    _itemNameController.clear();
                    _qtyController.clear();
                    _rateController.clear();
                  });
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
              return Dismissible(
                key: Key(item.id),
                background: Container(
                  color: Colors.blue,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 20),
                  child: const Icon(Icons.edit, color: Colors.white),
                ),
                secondaryBackground: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.startToEnd) {
                    // Swipe right → Edit inline
                    _showEditItemDialog(index);
                  } else {
                    // Swipe left → Delete
                    setState(() {
                      _invoiceItems.removeAt(index);
                    });
                  }
                  return false; // We handle removal ourselves
                },
                child: Container(
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

  void _showEditItemDialog(int index) {
    final item = _invoiceItems[index];
    setState(() {
      _itemNameController.text = item.name;
      _qtyController.text = item.quantity.toStringAsFixed(0);
      _rateController.text = item.rate.toStringAsFixed(0);
      _selectedUnit = item.unit;
      _invoiceItems.removeAt(index);
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
    // Allow save if customer selected OR typed manually
    if ((_selectedCustomer == null && _customerController.text.isEmpty) || _invoiceItems.isEmpty) return;

    final accountingService = Provider.of<AccountingService>(context, listen: false);

    // If no customer selected but name typed, check if exists or use Guest
    int? targetEntryId;
    String customerName = _customerController.text.trim();

    if (_selectedCustomer != null) {
      targetEntryId = _selectedCustomer!.id;
      customerName = _selectedCustomer!.name;
    } else if (_customerController.text.isNotEmpty) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.userId;

      if (userId == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: User not logged in')));
        return;
      }

      try {
        // Check if exists
        final existing = accountingService.entries.firstWhere(
          (e) => e.name.toLowerCase() == customerName.toLowerCase(),
          orElse: () => AccountingEntry(userId: -1, name: '', phone: '', creditAmount: 0, debitAmount: 0, date: ''),
        );

        if (existing.userId != -1) {
          _selectedCustomer = existing;
          targetEntryId = existing.id;
        } else {
          // Use "Guest" entry ID
          targetEntryId = await accountingService.getGuestEntry(userId);
        }
      } catch (e) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error determining customer: $e')));
        }
        return;
      }
    }

    if (targetEntryId == null) return;

    final total = _invoiceItems.fold<double>(0, (sum, item) => sum + item.total);
    final roundedTotal = total.floorToDouble();
    
    // Determine description format. 
    // If Guest/Ad-hoc, include the name in description.
    String description;
    bool isGuest = _selectedCustomer == null || _selectedCustomer!.name == 'Walk-in Customer';
    
    if (isGuest) {
       // Use controller text for ad-hoc/guest name
       description = 'Invoice: ${_customerController.text.trim()} | ${_invoiceItems.map((i) => i.name).join(", ")}';
    } else {
       description = 'Invoice: ${_invoiceItems.map((i) => i.name).join(", ")}';
    }

    try {
      if (_editingTransactionId != null) {
        // UPDATE existing invoice
        final updatedTx = TransactionModel(
          id: _editingTransactionId,
          entryId: targetEntryId,
          amount: roundedTotal,
          date: DateTime.now().toIso8601String(),
          description: description,
          type: 'DEBIT',
        );
        await accountingService.updateTransaction(updatedTx);

        final invoiceItemModels = _invoiceItems.map((item) => InvoiceItemModel(
          transactionId: _editingTransactionId!,
          itemName: item.name,
          quantity: item.quantity,
          unit: item.unit,
          rate: item.rate,
          total: item.total,
        )).toList();
        await accountingService.updateInvoiceItems(_editingTransactionId!, invoiceItemModels);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invoice updated!')),
          );
          setState(() {
            _editingTransactionId = null;
            _invoiceItems.clear();
            _selectedCustomer = null;
            _customerController.clear();
          });
        }
      } else {
        // CREATE new invoice
        final transaction = TransactionModel(
          entryId: targetEntryId,
          amount: roundedTotal,
          date: DateTime.now().toIso8601String(),
          description: description,
          type: 'DEBIT',
        );

        final txId = await accountingService.addTransaction(transaction);

        final invoiceItemModels = _invoiceItems.map((item) => InvoiceItemModel(
          transactionId: txId,
          itemName: item.name,
          quantity: item.quantity,
          unit: item.unit,
          rate: item.rate,
          total: item.total,
        )).toList();
        await accountingService.saveInvoiceItems(txId, invoiceItemModels);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invoice saved to History!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving invoice: $e')),
        );
      }
    }
  }

  void _loadInvoiceForEditing(TransactionModel transaction, AccountingEntry customer, List<InvoiceItemModel> items) {
    setState(() {
      _selectedIndex = 2; // Switch to Home tab
      _editingTransactionId = transaction.id;
      _selectedCustomer = customer;
      
      // Parse ad-hoc name if Guest
      if (customer.name == 'Walk-in Customer') {
         final parts = transaction.description.split('|');
         if (parts.length > 1) {
            _customerController.text = parts[0].replaceFirst('Invoice:', '').trim();
         } else {
            _customerController.text = ''; 
         }
      } else {
         _customerController.text = customer.name;
      }
      
      _invoiceItems.clear();
      _invoiceItemCounter = 0;
      for (final item in items) {
        _invoiceItems.add(InvoiceItem(
          id: 'edit_${_invoiceItemCounter++}',
          name: item.itemName,
          quantity: item.quantity,
          unit: item.unit,
          rate: item.rate,
        ));
      }
    });
  }

  void _shareInvoice() async {
    if ((_selectedCustomer == null && _customerController.text.isEmpty) || _invoiceItems.isEmpty) return;

    try {
      final items = _invoiceItems.map((item) => {
        'name': item.name,
        'quantity': item.quantity,
        'unit': item.unit,
        'rate': item.rate,
        'total': item.total,
      }).toList();

      await BillGenerator.shareInvoice(
        customerName: _selectedCustomer?.name ?? _customerController.text,
        customerPhone: _selectedCustomer?.phone ?? '',
        customerAdvance: _selectedCustomer?.creditAmount ?? 0.0,
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
    if ((_selectedCustomer == null && _customerController.text.isEmpty) || _invoiceItems.isEmpty) return;

    try {
      final items = _invoiceItems.map((item) => {
        'name': item.name,
        'quantity': item.quantity,
        'unit': item.unit,
        'rate': item.rate,
        'total': item.total,
      }).toList();

      await BillGenerator.printInvoice(
        customerName: _selectedCustomer?.name ?? _customerController.text,
        customerPhone: _selectedCustomer?.phone ?? '',
        customerAdvance: _selectedCustomer?.creditAmount ?? 0.0,
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
    final subtotal = _invoiceItems.fold<double>(0, (sum, item) => sum + item.total);
    final roundedTotal = subtotal.floorToDouble();
    final roundOff = roundedTotal - subtotal; // negative value like -0.1
    final advance = _selectedCustomer?.debitAmount ?? 0.0;
    final balance = roundedTotal - advance;

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
          _buildCalculationRow('Subtotal', subtotal, color: Colors.grey[700]),
          if (roundOff != 0) ...[
            const SizedBox(height: 4),
            _buildCalculationRow('Round Off', roundOff, color: Colors.orange[800]),
          ],
          const SizedBox(height: 4),
          _buildCalculationRow('Total', roundedTotal, isBold: true, color: Colors.blue[900]),
          if (_selectedCustomer != null && _selectedCustomer!.debitAmount > 0) ...[
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
                  onPressed: _invoiceItems.isEmpty || (_selectedCustomer == null && _customerController.text.isEmpty)
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
                  onPressed: _invoiceItems.isEmpty || (_selectedCustomer == null && _customerController.text.isEmpty)
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
                  onPressed: _invoiceItems.isEmpty || (_selectedCustomer == null && _customerController.text.isEmpty)
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
          padding: const EdgeInsets.all(16),
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

              final allTransactions = (snapshot.data ?? [])
                  .where((tx) => tx.description.startsWith('Invoice:'))
                  .toList();
              
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
                  final dateFormatted = DateFormat('dd-MMM-yy').format(date);

                  final entry = Provider.of<AccountingService>(context, listen: false)
                      .entries
                      .firstWhere((e) => e.id == tx.entryId, orElse: () => AccountingEntry(userId: 0, name: 'Unknown', phone: '', creditAmount: 0, debitAmount: 0, date: ''));

                  String displayName = entry.name;
                  if (entry.name == 'Walk-in Customer') {
                     final parts = tx.description.split('|');
                     if (parts.length > 1) {
                        displayName = parts[0].replaceFirst('Invoice:', '').trim();
                     }
                  }

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Text(
                      '#${transactions.length - index}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(dateFormatted),
                    trailing: Text(
                      '\u20b9${tx.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDebit ? Colors.blue[900] : Colors.green,
                      ),
                    ),
                    onTap: () async {
                      final result = await Navigator.push<Map<String, dynamic>>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => InvoiceDetailScreen(
                            transaction: tx,
                            customer: entry,
                          ),
                        ),
                      );

                      if (result != null && result['action'] == 'edit') {
                        _loadInvoiceForEditing(
                          result['transaction'] as TransactionModel,
                          result['customer'] as AccountingEntry,
                          result['items'] as List<InvoiceItemModel>,
                        );
                      }
                    },
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
