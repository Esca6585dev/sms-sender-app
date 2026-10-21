package com.example.sms_sender_app

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SubscriptionManager
import android.view.WindowManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Small native bridge used by the Dart side (`DeviceBridge`):
/// SIM list, foreground service for long sends, keep-screen-on, device name.
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    private val stopReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            channel?.invokeMethod("stopRequested", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "deviceName" -> result.success("${Build.MANUFACTURER} ${Build.MODEL}".trim())
                    "sims" -> result.success(listSims())
                    "startSending" -> {
                        SendingService.start(
                            this,
                            call.argument<String>("title") ?: "SMS",
                            call.argument<String>("text") ?: ""
                        )
                        result.success(true)
                    }
                    "updateSending" -> {
                        SendingService.update(
                            this,
                            call.argument<String>("title") ?: "SMS",
                            call.argument<String>("text") ?: ""
                        )
                        result.success(true)
                    }
                    "stopSending" -> {
                        SendingService.stop(this)
                        result.success(true)
                    }
                    "keepScreenOn" -> {
                        val on = call.argument<Boolean>("on") ?: false
                        if (on) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        val filter = IntentFilter(SendingService.ACTION_STOP_REQUESTED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(stopReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(stopReceiver, filter)
        }
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(stopReceiver)
        } catch (_: IllegalArgumentException) {
        }
        channel?.setMethodCallHandler(null)
        channel = null
        super.onDestroy()
    }

    private fun listSims(): List<Map<String, Any?>> {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE)
            != PackageManager.PERMISSION_GRANTED
        ) {
            return emptyList()
        }
        val manager = getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
            ?: return emptyList()
        val infos = try {
            manager.activeSubscriptionInfoList ?: emptyList()
        } catch (_: SecurityException) {
            emptyList()
        }
        val defaultSms = SubscriptionManager.getDefaultSmsSubscriptionId()
        return infos.map { info ->
            mapOf(
                "subscriptionId" to info.subscriptionId,
                "slot" to info.simSlotIndex,
                "displayName" to (info.displayName?.toString() ?: ""),
                "carrier" to (info.carrierName?.toString() ?: ""),
                "number" to numberOf(info.subscriptionId, manager, info),
                "isDefaultSms" to (info.subscriptionId == defaultSms)
            )
        }
    }

    @Suppress("DEPRECATION")
    private fun numberOf(
        subscriptionId: Int,
        manager: SubscriptionManager,
        info: android.telephony.SubscriptionInfo
    ): String {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                manager.getPhoneNumber(subscriptionId)
            } else {
                info.number ?: ""
            }
        } catch (_: SecurityException) {
            ""
        }
    }

    companion object {
        const val CHANNEL = "elite_sms/device"
    }
}
