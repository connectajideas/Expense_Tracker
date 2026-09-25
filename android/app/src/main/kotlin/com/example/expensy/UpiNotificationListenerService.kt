package com.example.expensy

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class UpiNotificationListenerService : NotificationListenerService() {
    companion object {
        private const val TAG = "UpiNotifListener"

        // Known UPI and banking app package identifiers
        private val UPI_PACKAGES = setOf(
            "com.google.android.apps.nbu.paisa.user", // Google Pay
            "com.phonepe.app",                       // PhonePe
            "net.one97.paytm",                       // Paytm
            "in.org.npci.upiapp",                    // BHIM UPI
            "com.dreamplug.androidapp",               // CRED
            "com.amazon.mShop.android.shopping",     // Amazon Pay
            "in.amazon.mShop.android.shopping",     // Amazon India
            "com.sbi.upi",                           // BHIM SBI Pay
            "com.csam.icici.bank.imobile",           // ICICI iMobile
            "com.snapwork.hdfc",                     // HDFC Bank MobileBanking
            "com.axis.mobile",                       // Axis Mobile
            "com.msf.kbank.mobile",                  // Kotak 811
            "com.bankofbaroda.mconnect",             // bob World
            "com.canarabank.mobility",               // Canara ai1
            "com.fss.pnbpsp"                         // PNB ONE
        )
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.i(TAG, "Expensy UPI NotificationListenerService connected and active!")
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.w(TAG, "Expensy UPI NotificationListenerService disconnected!")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        try {
            val packageName = sbn.packageName ?: return

            // CRITICAL: Skip our own notifications to avoid infinite trigger loops
            if (packageName == applicationContext.packageName) return

            val extras = sbn.notification?.extras ?: return
            val title = extras.getString(Notification.EXTRA_TITLE) ?: ""
            val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
            val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""
            val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString() ?: ""

            val combined = "$title $text $bigText $subText".trim()
            if (combined.isBlank()) return

            val isTargetApp = UPI_PACKAGES.contains(packageName)
            val lower = combined.lowercase()

            val hasDebitKeyword = lower.contains("paid") ||
                    lower.contains("debited") ||
                    lower.contains("payment") ||
                    lower.contains("sent") ||
                    lower.contains("spent") ||
                    lower.contains("txn of") ||
                    lower.contains("transferred to")

            // If it's a known UPI app, or any app posting a strong debit notification
            if (!isTargetApp && !hasDebitKeyword) return

            val parsed = PaymentNotificationHelper.parsePayment(combined) ?: return

            Log.i(TAG, "Detected payment in notification: ₹${parsed.amount} to '${parsed.merchant}' from $packageName")

            PaymentNotificationHelper.processPayment(
                context = applicationContext,
                amount = parsed.amount,
                merchant = parsed.merchant,
                source = "notification",
                packageName = packageName
            )
        } catch (e: Throwable) {
            Log.e(TAG, "Error handling posted notification", e)
        }
    }
}
