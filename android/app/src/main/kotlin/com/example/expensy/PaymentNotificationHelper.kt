package com.example.expensy

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.media.RingtoneManager
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONObject
import java.util.regex.Pattern

data class ParsedPayment(val amount: Double, val merchant: String)

object PaymentNotificationHelper {
    private const val TAG = "PaymentHelper"
    const val CHANNEL_ID = "expense_tracker_channel"

    private var lastAmount: Double? = null
    private var lastMerchant: String? = null
    private var lastTimestamp: Long = 0L

    @Synchronized
    fun isDuplicate(amount: Double, merchant: String): Boolean {
        val now = System.currentTimeMillis()
        val sameAmount = lastAmount != null && Math.abs(lastAmount!! - amount) < 0.01
        val sameMerchant = lastMerchant != null && (
            lastMerchant.equals(merchant, ignoreCase = true) ||
            merchant == "UPI Transfer" ||
            lastMerchant == "UPI Transfer"
        )
        if (sameAmount && sameMerchant && (now - lastTimestamp) < 20000L) {
            return true
        }
        lastAmount = amount
        lastMerchant = merchant
        lastTimestamp = now
        return false
    }

    fun parsePayment(text: String): ParsedPayment? {
        val lower = text.lowercase()

        val isDebit = lower.contains("debited") ||
                lower.contains("paid") ||
                lower.contains("payment") ||
                lower.contains("sent") ||
                lower.contains("spent") ||
                lower.contains("txn of") ||
                lower.contains("transferred to") ||
                lower.contains("transfer to")

        // Inward credit to user's account
        val isAccountCredited = (lower.contains("credited") && (
                lower.contains("to your account") ||
                lower.contains("in your account") ||
                lower.contains("to your a/c") ||
                lower.contains("to a/c") ||
                lower.contains("has been credited with") ||
                lower.contains("credited with inr") ||
                lower.contains("credited with rs")
        )) || lower.contains("received from") || lower.contains("received in your account")

        val isExcluded = (!lower.contains("debited") && isAccountCredited) ||
                lower.contains("refund") ||
                lower.contains("otp") ||
                lower.contains("verification code") ||
                lower.contains("due date") ||
                lower.contains("bill generated") ||
                lower.contains("statement")

        if (!isDebit || isExcluded) return null

        // Primary amount regex (₹ / Rs / INR)
        val amountRegex = Pattern.compile(
            "(?:₹|Rs\\.?|INR)\\s?([0-9,]+(?:\\.[0-9]{1,2})?)",
            Pattern.CASE_INSENSITIVE
        )
        // Fallback amount regex (debited by 350.0 / paid 100 / etc.)
        val fallbackAmountRegex = Pattern.compile(
            "(?:debited\\s+(?:by|with|for|of)|paid|payment of|sent|spent|txn of)\\s+(?:₹|Rs\\.?|INR)?\\s?([0-9,]+(?:\\.[0-9]{1,2})?)",
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

        // Extract merchant / recipient
        var merchant = "UPI Transfer"
        val toRegex = Pattern.compile(
            "\\b(?:transfer to|transferred to|paid to|towards|vpa|info/|at|to)\\s+([A-Za-z0-9@_.&\\-/ ]{2,40})",
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

    fun processPayment(
        context: Context,
        amount: Double,
        merchant: String,
        source: String,
        packageName: String
    ) {
        if (isDuplicate(amount, merchant)) {
            Log.d(TAG, "Skipping duplicate transaction: ₹$amount to $merchant")
            return
        }

        val payload = JSONObject().apply {
            put("amount", amount)
            put("merchant", merchant)
            put("source", source)
            put("package", packageName)
            put("timestamp", System.currentTimeMillis())
        }.toString()

        Log.i(TAG, "Logging detected transaction: ₹$amount to $merchant via $source ($packageName)")

        // 1. Notify running Flutter engine if app is foreground
        MainActivity.notifyPayment(payload)

        // 2. Display Heads-up Notification for user to tap & log
        showNotification(context, amount, merchant, payload)
    }

    private fun showNotification(context: Context, amount: Double, merchant: String, payload: String) {
        try {
            if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) {
                Log.w(TAG, "Notification permission not granted, skipping notification")
                return
            }

            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "Expense Tracker",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "UPI auto-capture alerts and budget warnings"
                    enableVibration(true)
                    enableLights(true)
                    lightColor = Color.parseColor("#008080")
                    vibrationPattern = longArrayOf(0, 250, 100, 250)
                    lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
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
            val defaultSoundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(smallIcon)
                .setContentTitle("UPI payment of ₹$amountFormatted")
                .setContentText("To $merchant · Tap to log this expense")
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_EVENT)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setSound(defaultSoundUri)
                .setVibrate(longArrayOf(0, 250, 100, 250))
                .setDefaults(NotificationCompat.DEFAULT_ALL)
                .setContentIntent(pendingIntent)
                .build()

            val notificationId = (System.currentTimeMillis() % 10000).toInt() + 10
            notificationManager.notify(notificationId, notification)
        } catch (e: Throwable) {
            Log.e(TAG, "Error displaying heads-up notification", e)
        }
    }
}
