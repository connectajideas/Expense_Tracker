class Expense {
  final int? id;
  final double amount;
  final String mode; // 'UPI' or 'Cash'
  final String merchant;
  final String category;
  final DateTime date;
  final String source; // 'auto' or 'manual'

  Expense({
    this.id,
    required this.amount,
    required this.mode,
    required this.merchant,
    required this.category,
    required this.date,
    required this.source,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'amount': amount,
        'mode': mode,
        'merchant': merchant,
        'category': category,
        'date': date.toIso8601String(),
        'source': source,
      };

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
        id: map['id'] as int?,
        amount: (map['amount'] as num).toDouble(),
        mode: map['mode'] as String,
        merchant: map['merchant'] as String,
        category: map['category'] as String,
        date: DateTime.parse(map['date'] as String),
        source: map['source'] as String,
      );
}
