/// Parsed payment data model
class ParsedUpiPayment {
  final double amount;
  final String merchant;
  final DateTime? date;

  ParsedUpiPayment(this.amount, this.merchant, {this.date});
}

final _amountRegex = RegExp(
  r'(?:₹|Rs\.?|INR)\s?([\d,]+(?:\.\d{1,2})?)',
  caseSensitive: false,
);

final _fallbackAmountRegex = RegExp(
  r'(?:debited\s+(?:by|with|for|of)|paid|sent|spent|txn of)\s+(?:₹|Rs\.?|INR)?\s?([\d,]+(?:\.\d{1,2})?)',
  caseSensitive: false,
);

final _toMerchantRegex = RegExp(
  r'\b(?:transfer to|paid to|towards|vpa|info\/|at|to)\s+([A-Za-z0-9@_.&\-\/ ]{2,40})',
  caseSensitive: false,
);

final _forMerchantRegex = RegExp(
  r'\bfor\s+([A-Za-z0-9@_.&\-\/ ]{2,40})',
  caseSensitive: false,
);

/// Parses bank debit SMS text or notification text.
/// Returns null if the text does not look like a payment/debit event.
ParsedUpiPayment? parseUpiNotification(String title, String content) {
  return parseTransactionText('$title $content');
}

ParsedUpiPayment? parseTransactionText(String text, {DateTime? date}) {
  final lower = text.toLowerCase();

  // Must have debit/spending indicators
  final isDebit = lower.contains('debited') ||
      lower.contains('paid') ||
      lower.contains('payment') ||
      lower.contains('sent') ||
      lower.contains('spent') ||
      lower.contains('txn of') ||
      lower.contains('transfer to');

  // Inward credit to user's account (only exclude if it's not a debit)
  final isAccountCredited = (lower.contains('credited') && (
          lower.contains('to your account') ||
          lower.contains('in your account') ||
          lower.contains('to your a/c') ||
          lower.contains('to a/c') ||
          lower.contains('has been credited with') ||
          lower.contains('credited with inr') ||
          lower.contains('credited with rs')
      )) || lower.contains('received from') || lower.contains('received in your account');

  final isExcluded = (!lower.contains('debited') && isAccountCredited) ||
      lower.contains('refund') ||
      lower.contains('otp') ||
      lower.contains('verification code') ||
      lower.contains('due date') ||
      lower.contains('bill generated') ||
      lower.contains('statement');

  if (!isDebit || isExcluded) return null;

  // Extract amount
  var match = _amountRegex.firstMatch(text);
  match ??= _fallbackAmountRegex.firstMatch(text);
  if (match == null) return null;

  final amount = double.tryParse(match.group(1)!.replaceAll(',', ''));
  if (amount == null || amount <= 0) return null;

  // Extract merchant / recipient
  String merchant = 'UPI Transfer';
  var toMatch = _toMerchantRegex.firstMatch(text);
  toMatch ??= _forMerchantRegex.firstMatch(text);

  if (toMatch != null) {
    final candidate = toMatch.group(1)!.trim();
    final candLower = candidate.toLowerCase();
    final isAmountLike = candLower.startsWith('rs') ||
        candLower.startsWith('inr') ||
        candLower.startsWith('₹') ||
        RegExp(r'^\d').hasMatch(candLower);

    if (candLower.isNotEmpty &&
        !isAmountLike &&
        !candLower.startsWith('your') &&
        !candLower.startsWith('a/c') &&
        !candLower.startsWith('acct') &&
        !candLower.startsWith('account')) {
      // Strip common prefixes like UPI/P2M/ or UPI/P2P/ or UPI/
      var cleaned = candidate.replaceFirst(RegExp(r'^(?:UPI\/)+(?:P2M\/|P2P\/)?', caseSensitive: false), '').trim();
      // Remove trailing delimiters like dot, comma, or trailing words like "on 25-09", "Ref No", "Avail Bal"
      cleaned = cleaned.replaceAll(RegExp(r'[\.\,\/]+$', caseSensitive: false), '').trim();
      cleaned = cleaned.replaceAll(RegExp(r'\s+\b(on|ref|avl|bal|avail|balance|txn|trans)\b.*', caseSensitive: false), '').trim();
      if (cleaned.isNotEmpty) {
        merchant = cleaned;
      }
    }
  }

  return ParsedUpiPayment(amount, merchant, date: date);
}
