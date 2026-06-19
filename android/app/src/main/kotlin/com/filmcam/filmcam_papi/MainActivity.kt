package com.filmcam.filmcam_papi

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.filmcam/camera_metadata"
    private var metadataReader: Camera2MetadataReader? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val cameraId = call.argument<String>("cameraId") ?: "0"
                    metadataReader = Camera2MetadataReader(this)
                    val ok = metadataReader!!.start(cameraId)
                    result.success(ok)
                }
                "getLatest" -> {
                    val r = metadataReader
                    if (r != null) {
                        result.success(mapOf(
                            "aperture" to r.latestAperture,
                            "exposureTime" to r.latestExposureTime,
                            "iso" to r.latestIso,
                            "focusDistance" to r.latestFocusDistance.toDouble(),
                            "isRunning" to r.isRunning,
                            "sessionType" to r.sessionType
                        ))
                    } else {
                        result.success(mapOf(
                            "aperture" to -1.0,
                            "exposureTime" to -1L,
                            "iso" to -1,
                            "focusDistance" to -1.0,
                            "isRunning" to false,
                            "sessionType" to "none"
                        ))
                    }
                }
                "measureDistance" -> {
                    try {
                        val cameraId = call.argument<String>("cameraId") ?: "0"
                        val reader = Camera2MetadataReader(this)
                        val fd = reader.measureDistance(cameraId)
                        result.success(fd.toDouble())
                    } catch (e: Exception) {
                        result.success(-1.0)
                    }
                }
                "getStaticAperture" -> {
                    try {
                        val cameraId = call.argument<String>("cameraId") ?: "0"
                        val mgr = getSystemService(android.content.Context.CAMERA_SERVICE) as android.hardware.camera2.CameraManager
                        val ch = mgr.getCameraCharacteristics(cameraId)
                        val ap = ch.get(android.hardware.camera2.CameraCharacteristics.LENS_INFO_AVAILABLE_APERTURES)
                        result.success(ap?.getOrNull(0)?.toDouble() ?: -1.0)
                    } catch (e: Exception) {
                        result.success(-1.0)
                    }
                }
                "dispose" -> {
                    metadataReader?.cleanup()
                    metadataReader = null
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        metadataReader?.cleanup()
        super.onDestroy()
    }
}
