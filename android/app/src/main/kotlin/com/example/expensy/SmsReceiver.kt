package com.example.expensy

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONObject
import java.util.regex.Pattern

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (Telephony.Sms.Intents.SMS_RECEIVED_ACTION != intent.action) return

        try {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            if (messages.isNullOrEmpty()) return

            // Group multi-part messages by sender to reconstruct full SMS
            val messagesBySender = messages.groupBy { it.displayOriginatingAddress ?: "" }

            for ((sender, partList) in messagesBySender) {
                val fullBody = partList.joinToString("") { it.displayMessageBody ?: "" }
                if (fullBody.isBlank()) continue

                val parsed = parseBankSms(fullBody) ?: continue

                val payload = JSONObject().apply {
                    put("amount", parsed.amount)
                    put("merchant", parsed.merchant)
                    put("sender", sender)
                    put("source", "sms")
                }.toString()

                // Notify active Flutter engine if app is currently open
                MainActivity.notifySms(payload)

                // Show notification so user can tap to log expense
                showNotification(context, parsed.amount, parsed.merchant, payload)
            }
        } catch (e: Throwable) {
            Log.e("SmsReceiver", "Error processing incoming SMS", e)
        }
    }

    private fun showNotification(context: Context, amount: Double, merchant: String, payload: String) {
        try {
            // If user disabled notifications, avoid calling notify
            if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) {
                Log.w("SmsReceiver", "Notification permission not granted, skipping notification")
                return
            }

            val channelId = "expense_tracker_channel"
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    channelId,
                    "Expense Tracker",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Budget and auto-capture alerts"
                    enableVibration(true)
                }
                notificationManager.createNotificationChannel(channel)
            }

            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("payload", payload)
            }

            val requestCode = (System.currentTimeMillis() % 100000).toInt()
            val pendingIntent = PendingIntent.getActivity(
                context,
                requestCode,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val amountFormatted = if (amount % 1.0 == 0.0) {
                amount.toInt().toString()
            } else {
                String.format("%.2f", amount)
            }

            val iconId = context.applicationInfo.icon
            val smallIcon = if (iconId != 0) iconId else android.R.drawable.ic_dialog_info

            val notification = NotificationCompat.Builder(context, channelId)
                .setSmallIcon(smallIcon)
                .setContentTitle("UPI payment of ₹$amountFormatted")
                .setContentText("To $merchant · Tap to log this expense")
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setDefaults(NotificationCompat.DEFAULT_ALL)
                .setContentIntent(pendingIntent)
                .build()

            val notificationId = (System.currentTimeMillis() % 10000).toInt() + 10
            notificationManager.notify(notificationId, notification)
        } catch (e: Throwable) {
            Log.e("SmsReceiver", "Error displaying notification", e)
        }
    }

    data class ParsedPayment(val amount: Double, val merchant: String)

    companion object {
        fun parseBankSms(text: String): ParsedPayment? {
            val lower = text.lowercase()

            val isDebit = lower.contains("debited") ||
                    lower.contains("paid") ||
                    lower.contains("payment") ||
                    lower.contains("sent") ||
                    lower.contains("spent") ||
                    lower.contains("txn of") ||
                    lower.contains("transfer to")

            val isCredit = lower.contains("credited") ||
                    lower.contains("received from") ||
                    lower.contains("received in your account") ||
                    lower.contains("credited to")

            val isExcluded = isCredit ||
                    lower.contains("refund") ||
                    lower.contains("otp") ||
                    lower.contains("verification code") ||
                    lower.contains("due date") ||
                    lower.contains("bill generated") ||
                    lower.contains("statement")

            if (!isDebit || isExcluded) return null

            // Primary amount regex with currency code/symbol
            val amountRegex = Pattern.compile(
                "(?:₹|Rs\\.?|INR)\\s?([0-9,]+(?:\\.[0-9]{1,2})?)",
                Pattern.CASE_INSENSITIVE
            )
            // Fallback amount regex without currency code (e.g. SBI 'debited by 350.0')
            val fallbackAmountRegex = Pattern.compile(
                "(?:debited\\s+(?:by|with|for|of)|paid|sent|spent|txn of)\\s+(?:₹|Rs\\.?|INR)?\\s?([0-9,]+(?:\\.[0-9]{1,2})?)",
                Pattern.CASE_INSENSITIVE
            )

            var amount: Double? = null
            val amountMatcher = amountRegex.matcher(text)
            if (amountMatcher.find()) {
                amount = amountMatcher.group(1)?.replace(",", "")?.toDoubleOrNull()
            }
            if (amount == null) {
                val fallbackMatcher = fallbackAmountRegex.matcher(text)
                if (fallbackMatcher.find()) {
                    amount = fallbackMatcher.group(1)?.replace(",", "")?.toDoubleOrNull()
                }
            }

            if (amount == null || amount <= 0.0) return null

            var merchant = "UPI Transfer"
            val toRegex = Pattern.compile(
                "\\b(?:transfer to|paid to|towards|vpa|info/|at|to)\\s+([A-Za-z0-9@_.&\\-/ ]{2,40})",
                Pattern.CASE_INSENSITIVE
            )
            val forRegex = Pattern.compile(
                "\\bfor\\s+([A-Za-z0-9@_.&\\-/ ]{2,40})",
                Pattern.CASE_INSENSITIVE
            )

            var candidateMatcher = toRegex.matcher(text)
            var found = candidateMatcher.find()
            if (!found) {
                candidateMatcher = forRegex.matcher(text)
                found = candidateMatcher.find()
            }

            if (found) {
                var candidate = candidateMatcher.group(1)?.trim() ?: ""
                val candLower = candidate.lowercase()
                val isAmountLike = candLower.startsWith("rs") ||
                        candLower.startsWith("inr") ||
                        candLower.startsWith("₹") ||
                        candLower.matches(Regex("^\\d.*"))

                if (candLower.isNotEmpty() &&
                    !isAmountLike &&
                    !candLower.startsWith("your") &&
                    !candLower.startsWith("a/c") &&
                    !candLower.startsWith("acct") &&
                    !candLower.startsWith("account")
                ) {
                    candidate = candidate.replaceFirst(Regex("^(?i)(?:UPI/)+(?:P2M/|P2P/)?"), "").trim()
                    candidate = candidate.replace(Regex("(?i)\\s+\\b(on|ref|avl|bal|avail|balance|txn|trans)\\b.*"), "").trim()
                    candidate = candidate.replace(Regex("[.,/]+$"), "").trim()
                    if (candidate.isNotEmpty()) {
                        merchant = candidate
                    }
                }
            }

            return ParsedPayment(amount, merchant)
        }
    }
}
