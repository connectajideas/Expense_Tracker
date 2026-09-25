import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/expense.dart';
import '../models/budget.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'expense_tracker.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE expenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount REAL NOT NULL,
            mode TEXT NOT NULL,
            merchant TEXT NOT NULL,
            category TEXT NOT NULL,
            date TEXT NOT NULL,
            source TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE budget (
            month TEXT PRIMARY KEY,
            limit_amount REAL NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE category_map (
            merchant_keyword TEXT PRIMARY KEY,
            category TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // ---------- Expenses ----------

  Future<int> insertExpense(Expense e) async {
    final db = await database;
    return db.insert('expenses', e.toMap());
  }

  Future<List<Expense>> getExpensesBetween(DateTime start, DateTime end) async {
    final db = await database;
    final rows = await db.query(
      'expenses',
      where: 'date >= ? AND date < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date DESC',
    );
    return rows.map((r) => Expense.fromMap(r)).toList();
  }

  Future<double> getTotalSpent(DateTime start, DateTime end) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM expenses WHERE date >= ? AND date < ?',
      [start.toIso8601String(), end.toIso8601String()],
    );
    return (result.first['total'] as num).toDouble();
  }

  Future<Map<String, double>> getTotalsByCategory(
      DateTime start, DateTime end) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''SELECT category, SUM(amount) as total FROM expenses
         WHERE date >= ? AND date < ? GROUP BY category ORDER BY total DESC''',
      [start.toIso8601String(), end.toIso8601String()],
    );
    return {
      for (final r in rows)
        r['category'] as String: (r['total'] as num).toDouble()
    };
  }

  Future<Map<String, double>> getTotalsByMode(
      DateTime start, DateTime end) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''SELECT mode, SUM(amount) as total FROM expenses
         WHERE date >= ? AND date < ? GROUP BY mode''',
      [start.toIso8601String(), end.toIso8601String()],
    );
    return {
      for (final r in rows) r['mode'] as String: (r['total'] as num).toDouble()
    };
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;
    return db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Budget ----------

  Future<void> setMonthlyLimit(String month, double limit) async {
    final db = await database;
    await db.insert('budget', Budget(month: month, limitAmount: limit).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<double?> getMonthlyLimit(String month) async {
    final db = await database;
    final rows =
        await db.query('budget', where: 'month = ?', whereArgs: [month]);
    if (rows.isEmpty) return null;
    return (rows.first['limit_amount'] as num).toDouble();
  }

  // ---------- Category auto-guess ----------

  Future<void> setCategoryKeyword(String keyword, String category) async {
    final db = await database;
    await db.insert(
      'category_map',
      {'merchant_keyword': keyword.toLowerCase(), 'category': category},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String> guessCategory(String merchant) async {
    final db = await database;
    final rows = await db.query('category_map');
    final lower = merchant.toLowerCase();
    for (final r in rows) {
      if (lower.contains(r['merchant_keyword'] as String)) {
        return r['category'] as String;
      }
    }
    return 'Uncategorized';
  }
}
