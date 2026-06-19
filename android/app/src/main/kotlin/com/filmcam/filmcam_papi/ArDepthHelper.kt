package com.filmcam.filmcam_papi

import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLSurface
import android.opengl.GLES20
import android.os.Handler
import android.os.HandlerThread
import com.google.ar.core.ArCoreApk
import com.google.ar.core.Config
import com.google.ar.core.Frame
import com.google.ar.core.Session
import java.nio.ByteBuffer
import java.nio.ByteOrder

class ArDepthHelper(private val context: Context) {
    private var session: Session? = null
    private var handlerThread: HandlerThread? = null
    private var handler: Handler? = null
    private var eglDisplay: EGLDisplay? = null
    private var eglContext: EGLContext? = null
    private var eglSurface: EGLSurface? = null

    private val depthTimeoutMs = 3000L

    fun isArCoreSupported(): Boolean {
        return try {
            when (ArCoreApk.getInstance().checkAvailability(context)) {
                ArCoreApk.Availability.SUPPORTED_INSTALLED -> true
                ArCoreApk.Availability.SUPPORTED_APK_TOO_OLD -> {
                    ArCoreApk.getInstance().requestInstall(null, true)
                    false
                }
                else -> false
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun getBackCameraId(): String? {
        return try {
            val mgr = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            for (id in mgr.cameraIdList) {
                val ch = mgr.getCameraCharacteristics(id)
                if (ch.get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_BACK) {
                    return id
                }
            }
            null
        } catch (_: Exception) { null }
    }

    fun measureDepth(): Double? {
        cleanup()
        try {
            handlerThread = HandlerThread("arcore-depth").apply { start() }
            handler = Handler(handlerThread!!.looper)

            val cameraId = getBackCameraId() ?: return null

            // Init minimal EGL context (required by ARCore Session)
            if (!initEgl()) return null

            val session = Session(context)
            this.session = session

            val config = Config(session)
            config.depthMode = Config.DepthMode.AUTOMATIC
            config.focusMode = Config.FocusMode.FIXED
            config.updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
            session.configure(config)

            // ARCore needs a GL texture to render camera frames into
            val texId = IntArray(1)
            GLES20.glGenTextures(1, texId, 0)
            session.setCameraTextureName(texId[0])

            // Run update loop until depth data is available
            val deadline = System.currentTimeMillis() + depthTimeoutMs
            var depthValue: Double? = null

            while (System.currentTimeMillis() < deadline) {
                try {
                    val frame = session.update()
                    depthValue = readCenterDepth(frame)
                    if (depthValue != null && depthValue > 0) break
                } catch (_: Exception) {
                    // session.update() may throw early; keep trying
                }
                Thread.sleep(100)
            }

            GLES20.glDeleteTextures(1, texId, 0)
            return depthValue
        } catch (e: Exception) {
            return null
        } finally {
            cleanup()
        }
    }

    private fun readCenterDepth(frame: Frame): Double? {
        return try {
            val depthImage = frame.acquireDepthImage() ?: return null
            val buffer = depthImage.planes[0].buffer
            val width = depthImage.width
            val height = depthImage.height
            val pixelStride = depthImage.planes[0].pixelStride
            val rowStride = depthImage.planes[0].rowStride

            // Read center pixel
            val cx = width / 2
            val cy = height / 2
            val offset = cy * rowStride + cx * pixelStride

            // DEPTH16: each pixel is 2 bytes, value in mm
            val bb = ByteBuffer.allocate(2).order(ByteOrder.nativeOrder())
            bb.put(0, buffer.get(offset))
            bb.put(1, buffer.get(offset + 1))
            val depthMm = bb.getShort(0).toInt() and 0xFFFF

            depthImage.close()

            // Reasonable range: 1cm to 10m
            if (depthMm in 10..10000) depthMm / 1000.0 else null
        } catch (_: Exception) { null }
    }

    private fun initEgl(): Boolean {
        return try {
            val display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
            if (display == EGL14.EGL_NO_DISPLAY) return false

            val version = IntArray(2)
            if (!EGL14.eglInitialize(display, version, 0, version, 1)) return false
            eglDisplay = display

            val configAttr = intArrayOf(
                EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                EGL14.EGL_SURFACE_TYPE, EGL14.EGL_PBUFFER_BIT,
                EGL14.EGL_BLUE_SIZE, 8,
                EGL14.EGL_GREEN_SIZE, 8,
                EGL14.EGL_RED_SIZE, 8,
                EGL14.EGL_DEPTH_SIZE, 16,
                EGL14.EGL_NONE
            )
            val configs = arrayOfNulls<EGLConfig>(1)
            val numConfigs = IntArray(1)
            if (!EGL14.eglChooseConfig(display, configAttr, 0, configs, 0, 1, numConfigs, 0)) {
                return false
            }
            if (numConfigs[0] == 0) return false

            val ctxAttr = intArrayOf(
                EGL14.EGL_CONTEXT_CLIENT_VERSION, 2,
                EGL14.EGL_NONE
            )
            val ctx = EGL14.eglCreateContext(display, configs[0]!!, EGL14.EGL_NO_CONTEXT, ctxAttr, 0)
            if (ctx == EGL14.EGL_NO_CONTEXT) return false
            eglContext = ctx

            val surfAttr = intArrayOf(
                EGL14.EGL_WIDTH, 1,
                EGL14.EGL_HEIGHT, 1,
                EGL14.EGL_NONE
            )
            val surf = EGL14.eglCreatePbufferSurface(display, configs[0]!!, surfAttr, 0)
            if (surf == EGL14.EGL_NO_SURFACE) return false
            eglSurface = surf

            EGL14.eglMakeCurrent(display, surf, surf, ctx)
            true
        } catch (_: Exception) { false }
    }

    private fun cleanupEgl() {
        val dpy = eglDisplay ?: run { eglContext = null; eglSurface = null; return }
        try { EGL14.eglMakeCurrent(dpy, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT) } catch (_: Exception) {}
        try { val s = eglSurface; if (s != null) EGL14.eglDestroySurface(dpy, s) } catch (_: Exception) {}
        try { val c = eglContext; if (c != null) EGL14.eglDestroyContext(dpy, c) } catch (_: Exception) {}
        try { EGL14.eglTerminate(dpy) } catch (_: Exception) {}
        eglDisplay = null
        eglContext = null
        eglSurface = null
    }

    fun cleanup() {
        try { session?.close() } catch (_: Exception) {}
        session = null
        cleanupEgl()
        try { handlerThread?.quitSafely() } catch (_: Exception) {}
        handlerThread = null
        handler = null
    }
}
