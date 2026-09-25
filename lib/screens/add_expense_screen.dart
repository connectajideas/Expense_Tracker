import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/expense.dart';
import '../services/budget_service.dart';

const kCategories = [
  'Food',
  'Travel',
  'Shopping',
  'Bills',
  'Entertainment',
  'Health',
  'Other',
  'Uncategorized',
];

class AddExpenseScreen extends StatefulWidget {
  final Expense? existing;
  final double? prefillAmount;
  final String? prefillMerchant;
  const AddExpenseScreen({
    super.key,
    this.existing,
    this.prefillAmount,
    this.prefillMerchant,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _merchantCtrl = TextEditingController();
  String _mode = 'Cash';
  String _category = 'Uncategorized';
  DateTime _date = DateTime.now();
  bool _isAuto = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _amountCtrl.text = e.amount.toString();
      _merchantCtrl.text = e.merchant;
      _mode = e.mode;
      _category = e.category;
      _date = e.date;
    } else {
      if (widget.prefillAmount != null) {
        _amountCtrl.text = widget.prefillAmount!.toStringAsFixed(2);
      }
      if (widget.prefillMerchant != null) {
        _merchantCtrl.text = widget.prefillMerchant!;
        _mode = 'UPI';
        _isAuto = true;
        _onMerchantChanged(widget.prefillMerchant!);
      }
    }
  }

  Future<void> _onMerchantChanged(String value) async {
    if (widget.existing != null || value.trim().isEmpty) return;
    final guess = await DatabaseHelper.instance.guessCategory(value);
    if (guess != 'Uncategorized' && mounted) {
      setState(() => _category = guess);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final expense = Expense(
      id: widget.existing?.id,
      amount: double.parse(_amountCtrl.text),
      mode: _mode,
      merchant: _merchantCtrl.text.trim().isEmpty
          ? '-'
          : _merchantCtrl.text.trim(),
      category: _category,
      date: _date,
      source: _isAuto ? 'auto' : 'manual',
    );
    await DatabaseHelper.instance.insertExpense(expense);
    await BudgetService.checkAndAlert();
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add Expense' : 'Edit Expense'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Amount (₹)'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Amount required';
                  if (double.tryParse(v) == null) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _merchantCtrl,
                decoration: const InputDecoration(labelText: 'Merchant / Note'),
                onChanged: _onMerchantChanged,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _mode,
                decoration: const InputDecoration(labelText: 'Payment Mode'),
                items: const [
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                ],
                onChanged: (v) => setState(() => _mode = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: kCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Date: ${_date.day}/${_date.month}/${_date.year}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _save, child: const Text('Save')),
            ],
          ),
        ),
      ),
    );
  }
}
