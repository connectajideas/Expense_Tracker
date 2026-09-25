import 'package:flutter_test/flutter_test.dart';
import 'package:expensy/models/expense.dart';
import 'package:expensy/screens/home_screen.dart';

void main() {
  test('Month key helper test', () {
    final d = DateTime(2026, 9, 25);
    expect(monthKey(d), '2026-09');
  });

  test('Expense model serialization test', () {
    final e = Expense(
      amount: 150.0,
      category: 'Food',
      merchant: 'Swiggy',
      date: DateTime(2026, 9, 25),
      mode: 'UPI',
      source: 'auto',
    );
    final map = e.toMap();
    expect(map['amount'], 150.0);
    expect(map['merchant'], 'Swiggy');
    expect(map['mode'], 'UPI');
    expect(map['source'], 'auto');

    final fromMap = Expense.fromMap(map);
    expect(fromMap.amount, 150.0);
    expect(fromMap.merchant, 'Swiggy');
    expect(fromMap.source, 'auto');
  });
}
