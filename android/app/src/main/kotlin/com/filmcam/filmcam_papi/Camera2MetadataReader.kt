package com.filmcam.filmcam_papi

import android.content.Context
import android.graphics.SurfaceTexture
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CaptureRequest
import android.hardware.camera2.CaptureResult
import android.hardware.camera2.TotalCaptureResult
import android.os.Handler
import android.os.HandlerThread
import android.view.Surface
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class Camera2MetadataReader(private val context: Context) {
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private val handlerThread = HandlerThread("cam2-meta").apply { start() }
    private val handler = Handler(handlerThread.looper)

    @Volatile var latestAperture: Double = -1.0
    @Volatile var latestExposureTime: Long = -1L
    @Volatile var latestIso: Int = -1
    @Volatile var latestFocusDistance: Float = -1f
    @Volatile var isRunning: Boolean = false
    @Volatile var sessionType: String = "none"

    private val stateCb = object : CameraDevice.StateCallback() {
        override fun onOpened(camera: CameraDevice) {
            cameraDevice = camera
            createSession(camera)
        }
        override fun onDisconnected(camera: CameraDevice) {
            camera.close(); cameraDevice = null; isRunning = false
        }
        override fun onError(camera: CameraDevice, e: Int) {
            camera.close(); cameraDevice = null; isRunning = false
        }
    }

    private val captureCb = object : CameraCaptureSession.CaptureCallback() {
        override fun onCaptureCompleted(session: CameraCaptureSession, req: CaptureRequest, res: TotalCaptureResult) {
            res.get(CaptureResult.LENS_APERTURE)?.let { latestAperture = it.toDouble() }
            res.get(CaptureResult.SENSOR_EXPOSURE_TIME)?.let { latestExposureTime = it }
            res.get(CaptureResult.SENSOR_SENSITIVITY)?.let { latestIso = it }
            res.get(CaptureResult.LENS_FOCUS_DISTANCE)?.let { latestFocusDistance = it }
        }
    }

    fun start(cameraId: String): Boolean {
        if (isRunning) return true
        try {
            val manager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            manager.openCamera(cameraId, stateCb, handler)
            sessionType = "TEMPLATE_PREVIEW"
            isRunning = true
            return true
        } catch (e: Exception) {
            sessionType = "static_fallback"
            readStatic(cameraId)
            return false
        }
    }

    /** Open Camera2, run AF until locked, read LENS_FOCUS_DISTANCE, close. Blocks up to 3s. */
    fun measureDistance(cameraId: String): Float {
        val latch = CountDownLatch(1)
        var result = -1f
        try {
            val mgr = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            mgr.openCamera(cameraId, object : CameraDevice.StateCallback() {
                override fun onOpened(cam: CameraDevice) {
                    try {
                        val tex = SurfaceTexture(0).apply { setDefaultBufferSize(320, 240) }
                        val surface = Surface(tex)
                        cam.createCaptureSession(listOf(surface), object : CameraCaptureSession.StateCallback() {
                            override fun onConfigured(ses: CameraCaptureSession) {
                                val req = cam.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW).apply {
                                    addTarget(surface)
                                    set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
                                    set(CaptureRequest.CONTROL_AF_TRIGGER, CaptureRequest.CONTROL_AF_TRIGGER_START)
                                }.build()
                                ses.setRepeatingRequest(req, object : CameraCaptureSession.CaptureCallback() {
                                    override fun onCaptureCompleted(ses: CameraCaptureSession, req: CaptureRequest, res: TotalCaptureResult) {
                                        val afState = res.get(CaptureResult.CONTROL_AF_STATE)
                                        if (afState != null && (
                                            afState == CaptureResult.CONTROL_AF_STATE_FOCUSED_LOCKED ||
                                            afState == CaptureResult.CONTROL_AF_STATE_PASSIVE_FOCUSED ||
                                            afState == CaptureResult.CONTROL_AF_STATE_NOT_FOCUSED_LOCKED)) {
                                            val fd = res.get(CaptureResult.LENS_FOCUS_DISTANCE)
                                            if (fd != null && fd > 0f) result = fd
                                            latch.countDown()
                                        }
                                    }
                                }, handler)
                            }
                            override fun onConfigureFailed(ses: CameraCaptureSession) { latch.countDown() }
                        }, handler)
                    } catch (_: Exception) { latch.countDown() }
                }
                override fun onDisconnected(cam: CameraDevice) { cam.close(); latch.countDown() }
                override fun onError(cam: CameraDevice, e: Int) { cam.close(); latch.countDown() }
            }, handler)
            latch.await(3, TimeUnit.SECONDS)
            // If AF never locked, still return whatever focus distance we got from last frame
        } catch (_: Exception) {}
        return result
    }

    private fun createSession(camera: CameraDevice) {
        try {
            val tex = SurfaceTexture(0).apply { setDefaultBufferSize(64, 48) }
            val surface = Surface(tex)
            val templates = listOf(
                CameraDevice.TEMPLATE_PREVIEW,
                CameraDevice.TEMPLATE_RECORD,
                CameraDevice.TEMPLATE_VIDEO_SNAPSHOT,
                CameraDevice.TEMPLATE_ZERO_SHUTTER_LAG
            )
            for (template in templates) {
                try {
                    val req = camera.createCaptureRequest(template).apply {
                        addTarget(surface)
                    }
                    camera.createCaptureSession(listOf(surface), object : CameraCaptureSession.StateCallback() {
                        override fun onConfigured(ses: CameraCaptureSession) {
                            captureSession = ses
                            ses.setRepeatingRequest(req.build(), captureCb, handler)
                        }
                        override fun onConfigureFailed(ses: CameraCaptureSession) {}
                    }, handler)
                    sessionType = when (template) {
                        CameraDevice.TEMPLATE_PREVIEW -> "PREVIEW"
                        CameraDevice.TEMPLATE_RECORD -> "RECORD"
                        CameraDevice.TEMPLATE_VIDEO_SNAPSHOT -> "SNAPSHOT"
                        CameraDevice.TEMPLATE_ZERO_SHUTTER_LAG -> "ZSL"
                        else -> "OTHER"
                    }
                    return
                } catch (_: Exception) {}
            }
        } catch (_: Exception) {}
    }

    private fun readStatic(cameraId: String) {
        try {
            val mgr = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val ch = mgr.getCameraCharacteristics(cameraId)
            ch.get(CameraCharacteristics.LENS_INFO_AVAILABLE_APERTURES)?.let {
                if (it.isNotEmpty()) latestAperture = it[0].toDouble()
            }
        } catch (_: Exception) {}
    }

    fun cleanup() {
        try { captureSession?.close() } catch (_: Exception) {}
        try { cameraDevice?.close() } catch (_: Exception) {}
        captureSession = null
        cameraDevice = null
        isRunning = false
        sessionType = "none"
    }
}
