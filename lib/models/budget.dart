class Budget {
  final String month;
  final double limitAmount;

  Budget({required this.month, required this.limitAmount});

  Map<String, dynamic> toMap() => {
        'month': month,
        'limit_amount': limitAmount,
      };

  factory Budget.fromMap(Map<String, dynamic> map) => Budget(
        month: map['month'] as String,
        limitAmount: (map['limit_amount'] as num).toDouble(),
      );
}
