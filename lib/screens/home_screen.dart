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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  double _spent = 0;
  double? _limit;
  List<Expense> _expenses = [];
  bool _smsEnabled = false;
  bool _notifListenerEnabled = false;
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
    WidgetsBinding.instance.addObserver(this);
    _load();
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final smsGranted = await SmsService.instance.isSmsGranted();
    final notifListenerGranted =
        await SmsService.instance.isNotificationListenerGranted();
    if (mounted) {
      setState(() {
        _smsEnabled = smsGranted;
        _notifListenerEnabled = notifListenerGranted;
      });
    }
  }

  Future<void> _enableUpiNotifications() async {
    await SmsService.instance.openNotificationListenerSettings();
  }

  Future<void> _toggleSmsCapture(bool value) async {
    if (value) {
      final granted = await SmsService.instance.requestSmsPermission();
      if (mounted) {
        setState(() => _smsEnabled = granted);
      }
      if (granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bank SMS capture enabled!'),
            duration: Duration(seconds: 3),
          ),
        );
      } else if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('SMS permission required. Enable in app settings.'),
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

  void _showAutoCaptureDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt, color: Colors.teal, size: 28),
                  const SizedBox(width: 8),
                  const Text(
                    'Auto-Capture Settings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Option 1: UPI App Push Notifications (Google Pay, PhonePe, Paytm, CRED)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _notifListenerEnabled
                        ? Colors.teal.shade300
                        : Colors.orange.shade300,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: _notifListenerEnabled
                      ? Colors.teal.shade50
                      : Colors.orange.shade50,
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _notifListenerEnabled
                              ? Icons.check_circle
                              : Icons.warning_amber,
                          color: _notifListenerEnabled
                              ? Colors.teal
                              : Colors.orange.shade800,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'UPI Apps (GPay, PhonePe, Paytm, CRED)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (_notifListenerEnabled)
                          const Text(
                            'Active',
                            style: TextStyle(
                              color: Colors.teal,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        else
                          FilledButton(
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            onPressed: () {
                              _enableUpiNotifications();
                              Navigator.pop(ctx);
                            },
                            child: const Text('Enable'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _notifListenerEnabled
                          ? 'Catches payments instantly from Google Pay, PhonePe, Paytm & CRED notifications.'
                          : 'Tap "Enable" to grant Notification Access in Android Settings so Expensy can catch UPI transactions.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Option 2: Bank SMS Backup
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _smsEnabled
                        ? Colors.teal.shade300
                        : Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: _smsEnabled ? Colors.teal.shade50 : Colors.grey.shade50,
                ),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      _smsEnabled ? Icons.sms : Icons.sms_outlined,
                      color: _smsEnabled ? Colors.teal : Colors.grey.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bank SMS Backup',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Detects debit SMS sent by banks (SBI, HDFC, ICICI, etc.)',
                            style: TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _smsEnabled,
                      onChanged: (val) async {
                        await _toggleSmsCapture(val);
                        setModalState(() {});
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Samsung One UI / Device tip
              Container(
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blueGrey, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Samsung One UI Tip: Set Expensy battery usage to "Unrestricted" in App Info so background alerts are never delayed.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blueGrey.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _scanRecentSms() async {
    final hasPerm = await SmsService.instance.isSmsGranted();
    if (!hasPerm) {
      final granted = await SmsService.instance.requestSmsPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SMS permission is required to scan bank messages'),
            ),
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
                    'Found ${results.length} Bank Transactions',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                itemCount: results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = results[index];
                  final dateStr = item.date != null
                      ? '${item.date!.day}/${item.date!.month} ${item.date!.hour.toString().padLeft(2, '0')}:${item.date!.minute.toString().padLeft(2, '0')}'
                      : '';
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.teal,
                      child: Icon(Icons.receipt_long, color: Colors.white, size: 20),
                    ),
                    title: Text(
                      item.merchant,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      dateStr.isNotEmpty ? 'Debit · $dateStr' : 'Bank Debit',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '₹${item.amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
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
    final isAutoActive = _notifListenerEnabled || _smsEnabled;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: isAutoActive ? Colors.teal : Colors.orange.shade800,
            ),
            icon: Icon(
              isAutoActive ? Icons.bolt : Icons.flash_off,
              size: 18,
            ),
            label: Text(
              isAutoActive ? 'Auto ON' : 'Setup Auto',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: _showAutoCaptureDialog,
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
          if (!_notifListenerEnabled)
            Card(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              color: Colors.orange.shade50,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.orange.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.bolt, color: Colors.orange.shade800, size: 28),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enable UPI Auto-Capture',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Catch payments from Google Pay, PhonePe, Paytm',
                            style: TextStyle(fontSize: 11, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange.shade800,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: _showAutoCaptureDialog,
                      child: const Text('Setup', style: TextStyle(fontSize: 12)),
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
