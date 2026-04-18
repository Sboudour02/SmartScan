package com.smartscan.smartscan_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Build
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.smartscan/security"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isRooted" -> result.success(checkRoot())
                    "isEmulator" -> result.success(checkEmulator())
                    else -> result.notImplemented()
                }
            }
    }

    /// Root Detection - comprehensive check
    private fun checkRoot(): Boolean {
        // Check 1: Known su binary paths
        val rootPaths = arrayOf(
            "/system/app/Superuser.apk",
            "/system/xbin/su",
            "/system/bin/su",
            "/sbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/data/local/su",
            "/su/bin/su",
            "/system/bin/failsafe/su",
            "/system/sd/xbin/su",
            "/data/adb/magisk",
            "/system/app/Magisk.apk",
        )

        for (path in rootPaths) {
            if (File(path).exists()) return true
        }

        // Check 2: Build tags
        val buildTags = Build.TAGS
        if (buildTags != null && buildTags.contains("test-keys")) return true

        // Check 3: Try executing 'which su'
        try {
            val process = Runtime.getRuntime().exec(arrayOf("which", "su"))
            val result = process.inputStream.bufferedReader().readText()
            if (result.isNotEmpty()) return true
        } catch (_: Exception) {}

        return false
    }

    /// Emulator Detection - comprehensive check
    private fun checkEmulator(): Boolean {
        // Check Build properties for emulator indicators
        val fingerprint = Build.FINGERPRINT.lowercase()
        val model = Build.MODEL.lowercase()
        val manufacturer = Build.MANUFACTURER.lowercase()
        val brand = Build.BRAND.lowercase()
        val device = Build.DEVICE.lowercase()
        val product = Build.PRODUCT.lowercase()
        val hardware = Build.HARDWARE.lowercase()

        if (fingerprint.contains("generic") ||
            fingerprint.contains("unknown") ||
            fingerprint.contains("emulator") ||
            fingerprint.contains("sdk_gphone")) return true

        if (model.contains("google_sdk") ||
            model.contains("emulator") ||
            model.contains("android sdk built for x86") ||
            model.contains("sdk_gphone")) return true

        if (manufacturer.contains("genymotion") ||
            manufacturer.contains("unknown")) return true

        if (brand.startsWith("generic") && device.startsWith("generic")) return true

        if (product.contains("sdk") ||
            product.contains("vbox") ||
            product.contains("emulator")) return true

        if (hardware.contains("goldfish") ||
            hardware.contains("ranchu") ||
            hardware.contains("vbox86")) return true

        // Check for QEMU
        try {
            val qemu = Build::class.java.getField("IS_EMULATOR")
            if (qemu.getBoolean(null)) return true
        } catch (_: Exception) {}

        return false
    }
}
