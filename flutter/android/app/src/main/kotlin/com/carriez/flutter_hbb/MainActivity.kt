package com.carriez.flutter_hbb

/**
 * Handle events from flutter.
 *
 * SubnetDesk Helper on Android is an outgoing controller only. This activity
 * never starts a hosting service, screen projection, input service or
 * floating window, and exposes no channel method that could do so.
 */

import ffi.FFI

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import java.io.File
import java.util.concurrent.Executors
import android.content.ClipboardManager
import android.os.Bundle
import android.os.Build
import android.util.Log
import android.view.WindowManager
import android.media.MediaCodecInfo
import android.media.MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface
import android.media.MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar
import android.media.MediaCodecList
import android.media.MediaFormat
import android.util.DisplayMetrics
import androidx.annotation.RequiresApi
import org.json.JSONArray
import org.json.JSONObject
import com.hjq.permissions.XXPermissions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread


class MainActivity : FlutterActivity() {
    companion object {
        var flutterMethodChannel: MethodChannel? = null
        private var _rdClipboardManager: RdClipboardManager? = null
        val rdClipboardManager: RdClipboardManager?
            get() = _rdClipboardManager;
    }

    private val channelTag = "mChannel"
    private val logTag = "mMainActivity"
    private var shareChannel: MethodChannel? = null
    private val shareExecutor = Executors.newSingleThreadExecutor()
    private val sharedFiles = mutableListOf<String>()
    private val shareErrors = mutableListOf<String>()

    private var isAudioStart = false
    private val audioRecordHandle = AudioRecordHandle(this, { false }, { isAudioStart })

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelTag
        )
        initFlutterChannel(flutterMethodChannel!!)
        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "subnetdesk/share")
        synchronized(sharedFiles) {
            sharedFiles.addAll(getSharedPreferences("share-inbox", Context.MODE_PRIVATE)
                .getStringSet("pending", emptySet())?.filter { File(it).isFile } ?: emptyList())
        }
        shareChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "pending" -> synchronized(sharedFiles) {
                    result.success(mapOf("files" to sharedFiles.toList(), "errors" to shareErrors.toList()))
                    shareErrors.clear()
                }
                "acknowledge" -> synchronized(sharedFiles) {
                    val paths = call.arguments as? List<*> ?: emptyList<Any>()
                    sharedFiles.removeAll { paths.contains(it) }
                    saveShareInbox()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        thread {
            try {
                setCodecInfo()
            } catch (e: Exception) {
                Log.e("MainActivity", "Failed to setCodecInfo: ${e.message}", e)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) receiveSharedFiles(intent)
        if (_rdClipboardManager == null) {
            _rdClipboardManager = RdClipboardManager(getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager)
            FFI.setClipboardManager(_rdClipboardManager!!)
        }
    }

    override fun onDestroy() {
        Log.e(logTag, "onDestroy")
        super.onDestroy()
        shareExecutor.shutdown()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        receiveSharedFiles(intent)
    }

    @Suppress("DEPRECATION")
    private fun receiveSharedFiles(sharedIntent: Intent?) {
        if (sharedIntent == null) return
        if (sharedIntent?.action != Intent.ACTION_SEND && sharedIntent?.action != Intent.ACTION_SEND_MULTIPLE) return
        val uris = mutableListOf<Uri>()
        if (sharedIntent.action == Intent.ACTION_SEND_MULTIPLE) {
            uris.addAll(sharedIntent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM) ?: emptyList())
        } else {
            sharedIntent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)?.let { uris.add(it) }
        }
        sharedIntent.clipData?.let { clips ->
            for (index in 0 until clips.itemCount) clips.getItemAt(index).uri?.let { uris.add(it) }
        }
        if (uris.isEmpty()) return
        shareExecutor.execute {
            if (uris.distinct().size > 100) synchronized(sharedFiles) {
                shareErrors.add("Only the first 100 files were imported. Share the remaining files separately.")
            }
            for (uri in uris.distinct().take(100)) {
                var destination: File? = null
                try {
                    require(uri.scheme == "content") { "Only shared content files are supported" }
                    val folder = File(getExternalFilesDir(null) ?: filesDir, "Transfers/Shared")
                    check(folder.isDirectory || folder.mkdirs()) { "Cannot create transfer folder" }
                    var displayName = "shared-file"
                    contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                        if (cursor.moveToFirst()) displayName = cursor.getString(0) ?: displayName
                    }
                    val safeName = displayName.substringAfterLast('/').substringAfterLast('\\')
                        .replace(Regex("[\\x00-\\x1f]"), "_").take(180).trim('.').ifBlank { "shared-file" }
                    var file = File(folder, safeName)
                    var index = 1
                    while (file.exists()) file = File(folder, "${index++}-$safeName")
                    destination = file
                    val input = contentResolver.openInputStream(uri) ?: error("Shared file is unavailable")
                    input.use { source -> file.outputStream().use { target -> source.copyTo(target) } }
                    synchronized(sharedFiles) { sharedFiles.add(file.absolutePath); saveShareInbox() }
                } catch (error: Exception) {
                    destination?.let { if (it.exists() && !it.delete()) Log.w(logTag, "Cannot remove incomplete shared file") }
                    Log.e(logTag, "Cannot import shared file", error)
                    synchronized(sharedFiles) { shareErrors.add("Unable to import a shared file. Please share it again.") }
                }
            }
            runOnUiThread { if (!isDestroyed) shareChannel?.invokeMethod("changed", null) }
        }
    }

    private fun saveShareInbox() {
        getSharedPreferences("share-inbox", Context.MODE_PRIVATE).edit()
            .putStringSet("pending", sharedFiles.toSet()).apply()
    }

    private fun initFlutterChannel(flutterMethodChannel: MethodChannel) {
        flutterMethodChannel.setMethodCallHandler { call, result ->
            // make sure result will be invoked, otherwise flutter will await forever
            when (call.method) {
                "check_permission" -> {
                    if (call.arguments is String) {
                        result.success(XXPermissions.isGranted(context, call.arguments as String))
                    } else {
                        result.success(false)
                    }
                }
                "request_permission" -> {
                    if (call.arguments is String) {
                        requestPermission(context, call.arguments as String)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                START_ACTION -> {
                    if (call.arguments is String) {
                        startAction(context, call.arguments as String)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "enable_soft_keyboard" -> {
                    // https://blog.csdn.net/hanye2020/article/details/105553780
                    if (call.arguments as Boolean) {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM)
                    } else {
                        window.addFlags(WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM)
                    }
                    result.success(true)

                }
                "try_sync_clipboard" -> {
                    rdClipboardManager?.syncClipboard(true)
                    result.success(true)
                }
                GET_VALUE -> {
                    if (call.arguments is String) {
                        if (call.arguments == KEY_IS_SUPPORT_VOICE_CALL) {
                            result.success(isSupportVoiceCall())
                        } else {
                            result.error("-1", "No such key", null)
                        }
                    } else {
                        result.success(null)
                    }
                }
                "on_voice_call_started" -> {
                    onVoiceCallStarted()
                }
                "on_voice_call_closed" -> {
                    onVoiceCallClosed()
                }
                "has_remembered_lan_password", "forget_remembered_lan_password" -> {
                    val fingerprint = call.arguments as? String
                    if (fingerprint == null) {
                        result.error("credential_store", "Invalid device fingerprint", null)
                    } else {
                        thread {
                            try {
                                val answer = if (call.method == "has_remembered_lan_password") {
                                    LanCredentialStore.has(applicationContext, fingerprint)
                                } else {
                                    LanCredentialStore.forget(applicationContext, fingerprint)
                                    true
                                }
                                runOnUiThread { result.success(answer) }
                            } catch (_: Exception) {
                                // No exception text, fingerprint, username or password in logs.
                                runOnUiThread { result.error("credential_store", "Encrypted credential store unavailable", null) }
                            }
                        }
                    }
                }
                else -> {
                    result.error("-1", "No such method", null)
                }
            }
        }
    }

    private fun setCodecInfo() {
        val codecList = MediaCodecList(MediaCodecList.REGULAR_CODECS)
        val codecs = codecList.codecInfos
        val codecArray = JSONArray()

        val windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val wh = getScreenSize(windowManager)
        var w = wh.first
        var h = wh.second
        val align = 64
        w = (w + align - 1) / align * align
        h = (h + align - 1) / align * align
        codecs.forEach { codec ->
            val codecObject = JSONObject()
            codecObject.put("name", codec.name)
            codecObject.put("is_encoder", codec.isEncoder)
            var hw: Boolean? = null;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                hw = codec.isHardwareAccelerated
            } else {
                // https://chromium.googlesource.com/external/webrtc/+/HEAD/sdk/android/src/java/org/webrtc/MediaCodecUtils.java#29
                // https://chromium.googlesource.com/external/webrtc/+/master/sdk/android/api/org/webrtc/HardwareVideoEncoderFactory.java#229
                if (listOf("OMX.google.", "OMX.SEC.", "c2.android").any { codec.name.startsWith(it, true) }) {
                    hw = false
                } else if (listOf("c2.qti", "OMX.qcom.video", "OMX.Exynos", "OMX.hisi", "OMX.MTK", "OMX.Intel", "OMX.Nvidia").any { codec.name.startsWith(it, true) }) {
                    hw = true
                }
            }
            if (hw != true) {
                return@forEach
            }
            codecObject.put("hw", hw)
            var mime_type = ""
            codec.supportedTypes.forEach { type ->
                if (listOf("video/avc", "video/hevc").contains(type)) { // "video/x-vnd.on2.vp8", "video/x-vnd.on2.vp9", "video/av01"
                    mime_type = type;
                }
            }
            if (mime_type.isNotEmpty()) {
                codecObject.put("mime_type", mime_type)
                val caps = codec.getCapabilitiesForType(mime_type)
                if (codec.isEncoder) {
                    // Encoder's max_height and max_width are interchangeable
                    if (!caps.videoCapabilities.isSizeSupported(w,h) && !caps.videoCapabilities.isSizeSupported(h,w)) {
                        return@forEach
                    }
                }
                codecObject.put("min_width", caps.videoCapabilities.supportedWidths.lower)
                codecObject.put("max_width", caps.videoCapabilities.supportedWidths.upper)
                codecObject.put("min_height", caps.videoCapabilities.supportedHeights.lower)
                codecObject.put("max_height", caps.videoCapabilities.supportedHeights.upper)
                val surface = caps.colorFormats.contains(COLOR_FormatSurface);
                codecObject.put("surface", surface)
                val nv12 = caps.colorFormats.contains(COLOR_FormatYUV420SemiPlanar)
                codecObject.put("nv12", nv12)
                if (!(nv12 || surface)) {
                    return@forEach
                }
                codecObject.put("min_bitrate", caps.videoCapabilities.bitrateRange.lower / 1000)
                codecObject.put("max_bitrate", caps.videoCapabilities.bitrateRange.upper / 1000)
                if (!codec.isEncoder) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        codecObject.put("low_latency", caps.isFeatureSupported(MediaCodecInfo.CodecCapabilities.FEATURE_LowLatency))
                    }
                }
                if (!codec.isEncoder) {
                    return@forEach
                }
                codecArray.put(codecObject)
            }
        }
        val result = JSONObject()
        result.put("version", Build.VERSION.SDK_INT)
        result.put("w", w)
        result.put("h", h)
        result.put("codecs", codecArray)
        FFI.setCodecInfo(result.toString())
    }

    private fun onVoiceCallStarted() {
        isAudioStart = true
        val ok = audioRecordHandle.onVoiceCallStarted(null)
        if (!ok) {
            // Rarely happens, So we just add log and msgbox here.
            Log.e(logTag, "onVoiceCallStarted fail")
            flutterMethodChannel?.invokeMethod("msgbox", mapOf(
                "type" to "custom-nook-nocancel-hasclose-error",
                "title" to "Voice call",
                "text" to "Failed to start voice call."))
        } else {
            Log.d(logTag, "onVoiceCallStarted success")
        }
    }

    private fun onVoiceCallClosed() {
        isAudioStart = false
        val ok = audioRecordHandle.onVoiceCallClosed(null)
        if (!ok) {
            // Rarely happens, So we just add log and msgbox here.
            Log.e(logTag, "onVoiceCallClosed fail")
            flutterMethodChannel?.invokeMethod("msgbox", mapOf(
                "type" to "custom-nook-nocancel-hasclose-error",
                "title" to "Voice call",
                "text" to "Failed to stop voice call."))
        } else {
            Log.d(logTag, "onVoiceCallClosed success")
        }
    }
}
