package com.example.expensy

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log

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

                val parsed = PaymentNotificationHelper.parsePayment(fullBody) ?: continue

                PaymentNotificationHelper.processPayment(
                    context = context,
                    amount = parsed.amount,
                    merchant = parsed.merchant,
                    source = "sms",
                    packageName = sender
                )
            }
        } catch (e: Throwable) {
            Log.e("SmsReceiver", "Error processing incoming SMS", e)
        }
    }
}
