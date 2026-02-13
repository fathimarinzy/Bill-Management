import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('account_manager.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path, 
      version: 5, 
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE accounting_entries ADD COLUMN advanceAmount REAL DEFAULT 0.0');
    }
    if (oldVersion < 3) {
      // Version 3 logic (old stock_items) - retained for history but v4 will overwrite
      await db.execute('''
        CREATE TABLE IF NOT EXISTS stock_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          salePrice REAL,
          purchasePrice REAL,
          stockQuantity REAL DEFAULT 0.0,
          unit TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 4) {
      // Breaking change for v4: Drop old table and create new one with rate/quantity
      await db.execute('DROP TABLE IF EXISTS stock_items');
      await db.execute('''
        CREATE TABLE stock_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          rate REAL,
          quantity REAL DEFAULT 0.0
        )
      ''');
    }
    if (oldVersion < 5) {
      // Version 5: Add transactions table
      await db.execute('''
        CREATE TABLE transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          entryId INTEGER NOT NULL,
          amount REAL NOT NULL,
          date TEXT NOT NULL,
          description TEXT,
          type TEXT NOT NULL,
          FOREIGN KEY (entryId) REFERENCES accounting_entries (id) ON DELETE CASCADE
        )
      ''');
    }
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';
    const integerType = 'INTEGER NOT NULL';
    const textNullable = 'TEXT';
    const realNullable = 'REAL';
    
    // Users Table
    await db.execute('''
CREATE TABLE users ( 
  id $idType, 
  username $textType,
  email $textType,
  password $textType
  )
''');

    // Accounting Entries Table
    await db.execute('''
CREATE TABLE accounting_entries ( 
  id $idType, 
  userId $integerType,
  name $textType,
  phone $textType,
  advanceAmount $realType DEFAULT 0.0,
  creditAmount $realType,
  debitAmount $realType,
  date $textType,
  imagePath $textNullable,
  FOREIGN KEY (userId) REFERENCES users (id) ON DELETE CASCADE
  )
''');

    // Item Details Table
    await db.execute('''
CREATE TABLE item_details (
  id $idType,
  entryId $integerType,
  itemName $textType,
  rate $realType,
  quantity $realType,
  totalPrice $realType,
  dateAdded $textType,
  FOREIGN KEY (entryId) REFERENCES accounting_entries (id) ON DELETE CASCADE
  )
''');

    // Stock Items Table
    await db.execute('''
CREATE TABLE stock_items (
  id $idType,
  name $textType,
  rate $realNullable,
  quantity $realType DEFAULT 0.0
  )
''');

    // Transactions Table
    await db.execute('''
CREATE TABLE transactions (
  id $idType,
  entryId $integerType,
  amount $realType,
  date $textType,
  description $textNullable,
  type $textType,
  FOREIGN KEY (entryId) REFERENCES accounting_entries (id) ON DELETE CASCADE
  )
''');
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
