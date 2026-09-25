import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../db/database_helper.dart';
import '../models/expense.dart';
import '../services/sms_service.dart';
import 'add_expense_screen.dart';
import 'summary_screen.dart';

String monthKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double _spent = 0;
  double? _limit;
  List<Expense> _expenses = [];
  bool _smsEnabled = false;
  bool _isScanning = false;

  DateTime get _monthStart {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  DateTime get _monthEnd {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 1);
  }

  @override
  void initState() {
    super.initState();
    _load();
    _checkSmsPermission();
  }

  Future<void> _checkSmsPermission() async {
    final granted = await SmsService.instance.isPermissionGranted();
    if (mounted) {
      setState(() => _smsEnabled = granted);
    }
  }

  Future<void> _toggleSmsCapture(bool value) async {
    if (value) {
      final granted = await SmsService.instance.requestPermission();
      if (mounted) {
        setState(() => _smsEnabled = granted);
      }
      if (granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SMS Auto-Capture enabled! Bank debits will alert automatically.'),
            duration: Duration(seconds: 3),
          ),
        );
      } else if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('SMS/Notification permission required. Enable in app settings.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        setState(() => _smsEnabled = false);
      }
    }
  }

  Future<void> _scanRecentSms() async {
    final hasPerm = await SmsService.instance.isPermissionGranted();
    if (!hasPerm) {
      final granted = await SmsService.instance.requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('SMS permission is required to scan bank messages')),
          );
        }
        return;
      }
      setState(() => _smsEnabled = true);
    }

    setState(() => _isScanning = true);
    final results = await SmsService.instance.scanRecentSms();
    setState(() => _isScanning = false);

    if (!mounted) return;

    if (results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No recent bank debit SMS found')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.mark_email_read, color: Colors.teal),
                  const SizedBox(width: 8),
                  Text(
                    'Recent Bank Debits (${results.length})',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                itemCount: results.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final item = results[i];
                  final dateStr = item.date != null
                      ? '${item.date!.day}/${item.date!.month} ${item.date!.hour.toString().padLeft(2, '0')}:${item.date!.minute.toString().padLeft(2, '0')}'
                      : '';
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.teal,
                      child: Icon(Icons.receipt_long, color: Colors.white, size: 20),
                    ),
                    title: Text(item.merchant, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(dateStr.isNotEmpty ? 'Debit · $dateStr' : 'Bank Debit'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '₹${item.amount.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final saved = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddExpenseScreen(
                                  prefillAmount: item.amount,
                                  prefillMerchant: item.merchant,
                                ),
                              ),
                            );
                            if (saved == true) _load();
                          },
                          child: const Text('Log'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    final db = DatabaseHelper.instance;
    final spent = await db.getTotalSpent(_monthStart, _monthEnd);
    final limit = await db.getMonthlyLimit(monthKey(DateTime.now()));
    final expenses = await db.getExpensesBetween(_monthStart, _monthEnd);
    setState(() {
      _spent = spent;
      _limit = limit;
      _expenses = expenses;
    });
  }

  Future<void> _setLimitDialog() async {
    final ctrl = TextEditingController(text: _limit?.toStringAsFixed(0) ?? '');
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Monthly Limit'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Limit (₹)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, double.tryParse(ctrl.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      await DatabaseHelper.instance.setMonthlyLimit(
        monthKey(DateTime.now()),
        result,
      );
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = (_limit ?? 0) - _spent;
    final overLimit = _limit != null && _spent > _limit!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        actions: [
          Row(
            children: [
              const Text('SMS Auto', style: TextStyle(fontSize: 12)),
              Switch(value: _smsEnabled, onChanged: _toggleSmsCapture),
            ],
          ),
          IconButton(
            icon: _isScanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            tooltip: 'Scan Bank SMS',
            onPressed: _isScanning ? null : _scanRecentSms,
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SummaryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _setLimitDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_smsEnabled)
            Card(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              color: Colors.teal.shade50,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.teal.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.flash_on, color: Colors.teal, size: 28),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enable Auto-Capture',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            'Auto-detect UPI & bank debit SMS when you pay',
                            style: TextStyle(fontSize: 11, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _toggleSmsCapture(true),
                      child: const Text('Enable', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
          Card(
            margin: const EdgeInsets.all(16),
            color: overLimit ? Colors.red.shade50 : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _limit == null
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('No monthly limit set'),
                        TextButton(
                          onPressed: _setLimitDialog,
                          child: const Text('Set Limit'),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Spent: ₹${_spent.toStringAsFixed(0)} / ₹${_limit!.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: (_spent / _limit!).clamp(0, 1),
                          color: overLimit ? Colors.red : Colors.green,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          overLimit
                              ? 'Over limit by ₹${(-remaining).toStringAsFixed(0)}'
                              : 'Remaining: ₹${remaining.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: overLimit
                                ? Colors.red
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          Expanded(
            child: _expenses.isEmpty
                ? const Center(child: Text('No expenses this month yet'))
                : ListView.builder(
                    itemCount: _expenses.length,
                    itemBuilder: (context, i) {
                      final e = _expenses[i];
                      return ListTile(
                        leading: Icon(
                          e.mode == 'UPI' ? Icons.qr_code : Icons.money,
                        ),
                        title: Text(e.merchant),
                        subtitle: Text(
                          '${e.category} · ${e.date.day}/${e.date.month}',
                        ),
                        trailing: Text(
                          '₹${e.amount.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final saved = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
          );
          if (saved == true) _load();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
