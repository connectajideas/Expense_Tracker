import '../db/database_helper.dart';
import '../screens/home_screen.dart' show monthKey;
import 'app_notifications.dart';

class BudgetService {
  static Future<void> checkAndAlert() async {
    final db = DatabaseHelper.instance;
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);
    final limit = await db.getMonthlyLimit(monthKey(now));
    if (limit == null) return;
    final spent = await db.getTotalSpent(monthStart, monthEnd);
    if (spent > limit) {
      await AppNotifications.show(
        title: 'Monthly budget exceeded',
        body:
            'You have spent ₹${spent.toStringAsFixed(0)} of your ₹${limit.toStringAsFixed(0)} limit.',
        id: 1,
      );
    }
  }
}
