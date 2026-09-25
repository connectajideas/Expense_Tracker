import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/expense.dart';

enum SummaryRange { week, month }

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  SummaryRange _range = SummaryRange.week;
  int _offset = 0; // 0 = current period, -1 = previous, etc.

  double _total = 0;
  Map<String, double> _byCategory = {};
  Map<String, double> _byMode = {};
  List<Expense> _expenses = [];

  (DateTime, DateTime) get _bounds {
    final now = DateTime.now();
    if (_range == SummaryRange.week) {
      final weekday = now.weekday; // 1 = Mon
      final thisMonday = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: weekday - 1));
      final start = thisMonday.add(Duration(days: 7 * _offset));
      return (start, start.add(const Duration(days: 7)));
    } else {
      final start = DateTime(now.year, now.month + _offset, 1);
      final end = DateTime(now.year, now.month + _offset + 1, 1);
      return (start, end);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final (start, end) = _bounds;
    final db = DatabaseHelper.instance;
    final total = await db.getTotalSpent(start, end);
    final byCat = await db.getTotalsByCategory(start, end);
    final byMode = await db.getTotalsByMode(start, end);
    final expenses = await db.getExpensesBetween(start, end);
    setState(() {
      _total = total;
      _byCategory = byCat;
      _byMode = byMode;
      _expenses = expenses;
    });
  }

  String get _periodLabel {
    final (start, end) = _bounds;
    if (_range == SummaryRange.week) {
      final endInclusive = end.subtract(const Duration(days: 1));
      return '${start.day}/${start.month} - ${endInclusive.day}/${endInclusive.month}';
    }
    return '${start.month}/${start.year}';
  }

  @override
  Widget build(BuildContext context) {
    final maxCat = _byCategory.values.isEmpty
        ? 1.0
        : _byCategory.values.reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(title: const Text('Summary')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<SummaryRange>(
              segments: const [
                ButtonSegment(value: SummaryRange.week, label: Text('Weekly')),
                ButtonSegment(
                  value: SummaryRange.month,
                  label: Text('Monthly'),
                ),
              ],
              selected: {_range},
              onSelectionChanged: (s) {
                setState(() {
                  _range = s.first;
                  _offset = 0;
                });
                _load();
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() => _offset -= 1);
                  _load();
                },
              ),
              Text(
                _periodLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _offset >= 0
                    ? null
                    : () {
                        setState(() => _offset += 1);
                        _load();
                      },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Total: ₹${_total.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (_byMode.isNotEmpty) ...[
                  const Text(
                    'By Mode',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: _byMode.entries
                        .map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Text(
                              '${e.key}: ₹${e.value.toStringAsFixed(0)}',
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_byCategory.isNotEmpty) ...[
                  const Text(
                    'By Category',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ..._byCategory.entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${e.key}  ₹${e.value.toStringAsFixed(0)}'),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: e.value / maxCat,
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'Transactions',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (_expenses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('No expenses'),
                  ),
                ..._expenses.map(
                  (e) => ListTile(
                    leading: Icon(
                      e.mode == 'UPI' ? Icons.qr_code : Icons.money,
                    ),
                    title: Text(e.merchant),
                    subtitle: Text(
                      '${e.category} · ${e.date.day}/${e.date.month}',
                    ),
                    trailing: Text('₹${e.amount.toStringAsFixed(0)}'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
