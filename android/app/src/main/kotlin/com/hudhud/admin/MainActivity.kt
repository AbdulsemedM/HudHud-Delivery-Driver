package com.hudhud.admin

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val configChannel = "hudhud_delivery_driver/config"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, configChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getGoogleMapsApiKey" -> result.success(BuildConfig.GOOGLE_MAPS_API_KEY)
                    // Deliberately a different key from the one above: the Maps
                    // SDK key carries an Android application restriction, and
                    // Google does not apply those to the maps.googleapis.com
                    // web services, so sending it to Places/Geocoding/Directions
                    // earns a REQUEST_DENIED. See android/app/build.gradle.
                    "getGoogleMapsWebKey" -> {
                        val web = BuildConfig.GOOGLE_MAPS_WEB_KEY ?: ""
                        result.success(
                            if (web.isNotEmpty()) web else BuildConfig.GOOGLE_MAPS_API_KEY
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
