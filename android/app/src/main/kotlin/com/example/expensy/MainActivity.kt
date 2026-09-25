package com.example.expensy

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.expensy/sms"
    private var pendingPayload: String? = null

    companion object {
        private var activeChannel: MethodChannel? = null

        fun notifySms(payload: String) {
            activeChannel?.invokeMethod("onSmsReceived", payload)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val payload = intent?.getStringExtra("payload")
        if (payload != null) {
            pendingPayload = payload
            activeChannel?.invokeMethod("onNotificationTapped", payload)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        activeChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getLaunchPayload" -> {
                    val p = pendingPayload
                    pendingPayload = null
                    result.success(p)
                }
                "readRecentSms" -> {
                    val list = readRecentBankSms()
                    result.success(list)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        activeChannel = null
        super.onDestroy()
    }

    private fun readRecentBankSms(): List<Map<String, Any>> {
        val smsList = mutableListOf<Map<String, Any>>()
        try {
            val cursor = contentResolver.query(
                Uri.parse("content://sms/inbox"),
                arrayOf("address", "body", "date"),
                null,
                null,
                "date DESC LIMIT 50"
            )
            cursor?.use {
                val addressIdx = it.getColumnIndex("address")
                val bodyIdx = it.getColumnIndex("body")
                val dateIdx = it.getColumnIndex("date")
                while (it.moveToNext()) {
                    val sender = it.getString(addressIdx) ?: ""
                    val body = it.getString(bodyIdx) ?: ""
                    val date = it.getLong(dateIdx)
                    smsList.add(
                        mapOf(
                            "sender" to sender,
                            "body" to body,
                            "date" to date
                        )
                    )
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return smsList
    }
}
