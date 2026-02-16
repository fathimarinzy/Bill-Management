import 'package:flutter/material.dart';
import '../models/accounting_entry.dart';
import '../models/item_detail.dart';
import '../models/stock_item.dart';
import '../models/transaction_model.dart';
import '../models/sale_purchase_model.dart';
import '../models/invoice_item_model.dart';
import 'database_helper.dart';

class AccountingService with ChangeNotifier {
  List<AccountingEntry> _entries = [];
  double _totalCredit = 0.0;
  double _totalDebit = 0.0;

  List<AccountingEntry> get entries => _entries;
  double get totalCredit => _totalCredit;
  double get totalDebit => _totalDebit;
  double get balance => _totalCredit - _totalDebit;

  Future<void> loadEntries(int userId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'accounting_entries',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'date DESC', // Latest first
    );

    _entries = maps.map((e) => AccountingEntry.fromMap(e)).toList();
    _calculateTotals();
    notifyListeners();
  }

  void _calculateTotals() {
    _totalCredit = 0.0;
    _totalDebit = 0.0;
    for (var entry in _entries) {
      _totalCredit += entry.creditAmount;
      _totalDebit += entry.debitAmount;
    }
  }

  Future<int> addEntry(AccountingEntry entry) async {
    final db = await DatabaseHelper.instance.database;
    final id = await db.insert('accounting_entries', entry.toMap());
    await loadEntries(entry.userId);
    return id;
  }

  Future<int> getGuestEntry(int userId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'accounting_entries',
      where: 'userId = ? AND name = ?',
      whereArgs: [userId, 'Walk-in Customer'],
    );

    if (maps.isNotEmpty) {
      return maps.first['id'] as int;
    } else {
      final entry = AccountingEntry(
        userId: userId,
        name: 'Walk-in Customer',
        phone: '',
        creditAmount: 0,
        debitAmount: 0,
        date: DateTime.now().toIso8601String(),
      );
      return await addEntry(entry);
    }
  }

  Future<void> updateEntry(AccountingEntry entry) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'accounting_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
    await loadEntries(entry.userId);
  }

  Future<void> deleteEntry(int id, int userId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'accounting_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
    await loadEntries(userId);
  }

  // Item Details Logic
  List<ItemDetail> _items = [];
  List<ItemDetail> get items => _items;

  Future<void> loadItems(int entryId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'item_details',
      where: 'entryId = ?',
      whereArgs: [entryId],
      orderBy: 'dateAdded DESC',
    );

    _items = maps.map((e) => ItemDetail.fromMap(e)).toList();
    notifyListeners();
  }

  Future<void> addItem(ItemDetail item) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('item_details', item.toMap());
    await loadItems(item.entryId);
  }

  Future<void> updateItem(ItemDetail item) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'item_details',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
    await loadItems(item.entryId);
  }

  Future<void> deleteItem(int id, int entryId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'item_details',
      where: 'id = ?',
      whereArgs: [id],
    );
    await loadItems(entryId);
  }

  // Stock Items Logic
  List<StockItem> _stockItems = [];
  List<StockItem> get stockItems => _stockItems;

  Future<void> loadStockItems() async {
    try {
      final db = await DatabaseHelper.instance.database;
      debugPrint('Loading stock items...');
      final maps = await db.query('stock_items', orderBy: 'id DESC');
      debugPrint('Loaded ${maps.length} items from DB');
      _stockItems = maps.map((e) => StockItem.fromMap(e)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading stock items: $e');
    }
  }

  Future<void> addStockItem(StockItem item) async {
    try {
      final db = await DatabaseHelper.instance.database;
      debugPrint('Adding stock item: ${item.toMap()}');
      final id = await db.insert('stock_items', item.toMap());
      debugPrint('Added stock item with ID: $id');
      await loadStockItems();
    } catch (e) {
      debugPrint('Error adding stock item: $e');
    }
  }

  Future<void> updateStockItem(StockItem item) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'stock_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
    await loadStockItems();
  }

  Future<void> deleteStockItem(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'stock_items',
      where: 'id = ?',
      whereArgs: [id],
    );
    await loadStockItems();
  }

  // Transaction Logic
  List<TransactionModel> _transactions = [];
  List<TransactionModel> get transactions => _transactions;

  Future<void> loadTransactions(int entryId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'transactions',
      where: 'entryId = ?',
      whereArgs: [entryId],
      orderBy: 'date DESC',
    );

    _transactions = maps.map((e) => TransactionModel.fromMap(e)).toList();
    notifyListeners();
  }

  Future<List<TransactionModel>> getAllTransactions() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'transactions',
      orderBy: 'date DESC',
    );
    return maps.map((e) => TransactionModel.fromMap(e)).toList();
  }

  Future<int> addTransaction(TransactionModel transaction) async {
    final db = await DatabaseHelper.instance.database;
    final txId = await db.insert('transactions', transaction.toMap());

    // Update parent entry totals
    final entry = _entries.firstWhere((e) => e.id == transaction.entryId);
    double newCredit = entry.creditAmount;
    double newDebit = entry.debitAmount;

    if (transaction.type == 'CREDIT') {
      newCredit += transaction.amount;
    } else {
      newDebit += transaction.amount;
    }

    final updatedEntry = AccountingEntry(
      id: entry.id,
      userId: entry.userId,
      name: entry.name,
      phone: entry.phone,
      advanceAmount: entry.advanceAmount,
      creditAmount: newCredit,
      debitAmount: newDebit,
      date: entry.date,
      imagePath: entry.imagePath,
    );

    await updateEntry(updatedEntry);
    await loadTransactions(transaction.entryId);
    return txId;
  }

  Future<void> deleteTransaction(TransactionModel transaction) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [transaction.id],
    );

    // Update parent entry totals (reverse)
    final entry = _entries.firstWhere((e) => e.id == transaction.entryId);
    double newCredit = entry.creditAmount;
    double newDebit = entry.debitAmount;

    if (transaction.type == 'CREDIT') {
      newCredit -= transaction.amount;
    } else {
      newDebit -= transaction.amount;
    }

    final updatedEntry = AccountingEntry(
      id: entry.id,
      userId: entry.userId,
      name: entry.name,
      phone: entry.phone,
      advanceAmount: entry.advanceAmount,
      creditAmount: newCredit,
      debitAmount: newDebit,
      date: entry.date,
      imagePath: entry.imagePath,
    );

    await updateEntry(updatedEntry);
    await loadTransactions(transaction.entryId);
  }

  // Sale & Purchase Logic
  List<SalePurchaseEntry> _salePurchaseEntries = [];
  List<SalePurchaseEntry> get salePurchaseEntries => _salePurchaseEntries;

  Future<void> loadSalePurchaseEntries() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('sale_purchase_entries', orderBy: 'id DESC');
    _salePurchaseEntries = maps.map((e) => SalePurchaseEntry.fromMap(e)).toList();
    notifyListeners();
  }

  Future<void> addSalePurchaseEntry(SalePurchaseEntry entry) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('sale_purchase_entries', entry.toMap());
    await loadSalePurchaseEntries();
  }

  Future<void> updateSalePurchaseEntry(SalePurchaseEntry entry) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'sale_purchase_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
    await loadSalePurchaseEntries();
  }

  Future<void> deleteSalePurchaseEntry(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'sale_purchase_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
    await loadSalePurchaseEntries();
  }

  // Invoice Items Logic
  Future<void> saveInvoiceItems(int transactionId, List<InvoiceItemModel> items) async {
    final db = await DatabaseHelper.instance.database;
    for (var item in items) {
      final itemWithTxId = InvoiceItemModel(
        transactionId: transactionId,
        itemName: item.itemName,
        quantity: item.quantity,
        unit: item.unit,
        rate: item.rate,
        total: item.total,
      );
      await db.insert('invoice_items', itemWithTxId.toMap());
    }
  }

  Future<List<InvoiceItemModel>> getInvoiceItems(int transactionId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'invoice_items',
      where: 'transactionId = ?',
      whereArgs: [transactionId],
    );
    return maps.map((e) => InvoiceItemModel.fromMap(e)).toList();
  }

  Future<void> updateInvoiceItems(int transactionId, List<InvoiceItemModel> items) async {
    final db = await DatabaseHelper.instance.database;
    // Delete old items
    await db.delete('invoice_items', where: 'transactionId = ?', whereArgs: [transactionId]);
    // Insert new items
    await saveInvoiceItems(transactionId, items);
  }

  Future<void> updateTransaction(TransactionModel transaction) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
    notifyListeners();
  }
}
