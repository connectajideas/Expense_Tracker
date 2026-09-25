import 'package:flutter_test/flutter_test.dart';
import 'package:expensy/services/upi_parser.dart';

void main() {
  group('Bank Debit SMS Parser Tests', () {
    test('HDFC Bank UPI debit SMS', () {
      const sms = 'Dear Customer, Rs 180.00 has been debited from account **4321 to VPA swiggy@icici on 25-09-26. Your UPI transaction ref is 426819283741.';
      final parsed = parseTransactionText(sms);
      expect(parsed, isNotNull);
      expect(parsed!.amount, 180.0);
      expect(parsed.merchant.toLowerCase(), contains('swiggy'));
    });

    test('SBI UPI debit SMS', () {
      const sms = 'Dear UPI user A/C 9876 debited by 350.0 on 25Sep26 transfer to Zomato Ref No 426819283741.';
      final parsed = parseTransactionText(sms);
      expect(parsed, isNotNull);
      expect(parsed!.amount, 350.0);
      expect(parsed.merchant.toLowerCase(), contains('zomato'));
    });

    test('ICICI Bank debit SMS', () {
      const sms = 'Dear Customer, your A/C ending 5678 has been debited with INR 499.00 on 25-Sep-26 towards Amazon. Avail Bal: INR 12,345.00';
      final parsed = parseTransactionText(sms);
      expect(parsed, isNotNull);
      expect(parsed!.amount, 499.0);
      expect(parsed.merchant.toLowerCase(), contains('amazon'));
    });

    test('Axis Bank UPI debit SMS', () {
      const sms = 'INR 420.00 debited from A/c no. XX1234 on 25-09-26 21:04:12 for UPI/P2M/Uber India. Avail Bal: INR 8,450.00';
      final parsed = parseTransactionText(sms);
      expect(parsed, isNotNull);
      expect(parsed!.amount, 420.0);
      expect(parsed.merchant.toLowerCase(), contains('uber'));
    });

    test('Paytm UPI debit SMS', () {
      const sms = 'Paid Rs.120 to Sharma General Store via Paytm UPI. Txn ID: 123456.';
      final parsed = parseTransactionText(sms);
      expect(parsed, isNotNull);
      expect(parsed!.amount, 120.0);
      expect(parsed.merchant.toLowerCase(), contains('sharma'));
    });

    test('Debit SMS containing received by merchant', () {
      const sms = 'Payment of Rs 150.00 to Chai Point received by merchant via UPI. Avail Bal: Rs 4,500.';
      final parsed = parseTransactionText(sms);
      expect(parsed, isNotNull);
      expect(parsed!.amount, 150.0);
      expect(parsed.merchant.toLowerCase(), contains('chai point'));
    });

    test('Debit SMS mentioning credited to merchant', () {
      const sms = 'Rs 250.00 debited from A/c XX1234 on 25-09-26 towards UPI. Credited to Dominos.';
      final parsed = parseTransactionText(sms);
      expect(parsed, isNotNull);
      expect(parsed!.amount, 250.0);
      expect(parsed.merchant.toLowerCase(), contains('dominos'));
    });

    test('SBI debit for format', () {
      const sms = 'Your a/c no. XX1234 debited for Rs.250.00 on 25-09-26 by transfer to Dominos.';
      final parsed = parseTransactionText(sms);
      expect(parsed, isNotNull);
      expect(parsed!.amount, 250.0);
      expect(parsed.merchant.toLowerCase(), contains('dominos'));
    });

    test('Ignore OTP SMS', () {
      const sms = 'Your OTP for transaction of INR 500.00 at Swiggy is 987654. Do not share with anyone.';
      final parsed = parseTransactionText(sms);
      expect(parsed, isNull);
    });

    test('Ignore Credit / Salary SMS', () {
      const sms = 'Dear Customer, your A/C ending 1234 has been credited with INR 50,000.00 on 25-Sep-26 by Salary. Avail Bal: INR 52,000.00';
      final parsed = parseTransactionText(sms);
      expect(parsed, isNull);
    });

    test('Ignore Refund SMS', () {
      const sms = 'Refund of INR 150.00 received from Swiggy to your A/c ending 1234.';
      final parsed = parseTransactionText(sms);
      expect(parsed, isNull);
    });
  });

  group('UPI App Push Notification Parser Tests', () {
    test('Google Pay: Paid ₹150.00 to Chai Point', () {
      final parsed = parseUpiNotification('Paid ₹150.00 to Chai Point', 'Completed');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 150.0);
      expect(parsed.merchant.toLowerCase(), contains('chai point'));
    });

    test('PhonePe: Paid ₹200 to Starbucks', () {
      final parsed = parseUpiNotification('Paid ₹200 to Starbucks', '₹200 debited from A/c XX1234');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 200.0);
      expect(parsed.merchant.toLowerCase(), contains('starbucks'));
    });

    test('Paytm: Paid ₹75 to Sharma Groceries', () {
      final parsed = parseUpiNotification('Paid ₹75 to Sharma Groceries', 'Payment successful');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 75.0);
      expect(parsed.merchant.toLowerCase(), contains('sharma'));
    });

    test('CRED: Paid ₹1,200 to Cult Fit', () {
      final parsed = parseUpiNotification('Paid ₹1,200 to Cult Fit', 'UPI transaction completed');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 1200.0);
      expect(parsed.merchant.toLowerCase(), contains('cult fit'));
    });
  });
}
