package com.example.v2ray_stk

import android.app.Activity
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import com.example.v2ray_stk.log.LogChannel
import com.example.v2ray_stk.vpn.CommandClientBridge
import com.example.v2ray_stk.vpn.StatsProvider
import com.example.v2ray_stk.vpn.V2rayVpnService
import com.example.v2ray_stk.vpn.VpnState
import com.example.v2ray_stk.vpn.VpnStatus
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.example.v2ray_stk.vpn.VpnPrefs
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.net.InetSocketAddress
import java.net.Socket

class MainActivity : FlutterFragmentActivity() {

    private val channelName = "com.v2ray.stk/vpn"
    private val eventChannelName = "com.v2ray.stk/vpn_status"
    private val vpnPrepareRequestCode = 0x0f2c

    // fallback پینگ: هندشیک TCP روی پورت 80
    private val latencyHost = "www.gstatic.com"
    private val latencyPort = 80
    private val latencyTimeoutMs = 4000

    private var pendingConfig: String? = null
    private var pendingTorEnabled: Boolean = false
    private var pendingKillSwitch: Boolean = false
    private var pendingAlwaysOnVpn: Boolean = false
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        LogChannel.register(flutterEngine)
        com.example.v2ray_stk.vpn.LogChannel.register(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getStatus" -> result.success(VpnState.status)

                    "connect" -> {
                        StatsProvider.reset()
                        pendingTorEnabled =
                            call.argument<Boolean>("torEnabled") ?: false
                        pendingKillSwitch =
                            call.argument<Boolean>("killSwitch") ?: false
                        pendingAlwaysOnVpn =
                            call.argument<Boolean>("alwaysOnVpn") ?: false
                        prepareAndConnect(
                            call.argument<String>("config") ?: "",
                            pendingTorEnabled,
                            pendingKillSwitch,
                            pendingAlwaysOnVpn,
                        )
                        result.success(null)
                    }

                    "disconnect" -> {
                        StatsProvider.stop()
                        StatsProvider.reset()
                        disconnect()
                        result.success(null)
                    }

                    "getStats" -> result.success(buildStatsMap())

                    "testLatency" -> measureLatency(result)

                    "getInstalledApps" -> loadInstalledApps(
                        call.argument<Boolean>("withIcons") ?: true,
                        result,
                    )

                    "setSplitTunnel" -> {
                        val mode = call.argument<String>("mode") ?: "off"
                        val apps = call.argument<List<String>>("apps") ?: emptyList()
                        runCatching { VpnPrefs.saveSplit(this, mode, apps) }
                        result.success(true)
                    }

                    "getSplitTunnel" -> result.success(
                        mapOf(
                            "mode" to VpnPrefs.splitMode(this),
                            "apps" to VpnPrefs.splitApps(this).toList(),
                        )
                    )

                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    VpnState.setListener { status ->
                        runOnUiThread { eventSink?.success(status) }
                    }
                    events?.success(VpnState.status)
                }

                override fun onCancel(arguments: Any?) {
                    VpnState.setListener(null)
                    eventSink = null
                }
            })
    }

    // ------------------------------------------------------------------ stats

    /**
     * کلیدها عیناً همان چیزی هستند که VpnStats.fromMap در فلاتر انتظار دارد.
     * ترافیک از CommandClientBridge می‌آید، ping/location از StatsProvider.
     */
    private fun buildStatsMap(): Map<String, Any?> {
        val live = CommandClientBridge.hasData

        // هسته دارد داده می‌دهد یعنی تانل بالاست: ترد ping/geo را روشن کن (idempotent)
        if (live) StatsProvider.start()

        val ping = StatsProvider.lastPingMs()

        return mapOf(
            "downloadBps" to if (live) CommandClientBridge.downlink else 0L,
            "uploadBps" to if (live) CommandClientBridge.uplink else 0L,
            "totalDownload" to CommandClientBridge.downlinkTotal,
            "totalUpload" to CommandClientBridge.uplinkTotal,
            "memory" to CommandClientBridge.memory,
            "goroutines" to CommandClientBridge.goroutines,
            "connectionsIn" to CommandClientBridge.connectionsIn,
            "connectionsOut" to CommandClientBridge.connectionsOut,
            "location" to StatsProvider.lastLocation(),
            "ping" to if (ping >= 0L) ping else null
        )
    }

    // ---------------------------------------------------------------- latency

    private fun measureLatency(result: MethodChannel.Result) {
        Thread {
            val cached = StatsProvider.lastPingMs()
            val value = if (cached >= 0L) cached.toInt() else tcpHandshakeMillis()
            mainHandler.post { result.success(value) }
        }.apply { isDaemon = true }.start()
    }

    /** زمان هندشیک TCP بر حسب میلی‌ثانیه؛ در صورت خطا -1 */
    private fun tcpHandshakeMillis(): Int {
        var socket: Socket? = null
        return try {
            val started = System.nanoTime()
            socket = Socket()
            socket.connect(InetSocketAddress(latencyHost, latencyPort), latencyTimeoutMs)
            ((System.nanoTime() - started) / 1_000_000L).toInt()
        } catch (t: Throwable) {
            -1
        } finally {
            try {
                socket?.close()
            } catch (_: IOException) {
            }
        }
    }

    // ------------------------------------------------------------------- vpn

    private fun prepareAndConnect(
        config: String,
        torEnabled: Boolean,
        killSwitch: Boolean,
        alwaysOnVpn: Boolean,
    ) {
        val prepareIntent = VpnService.prepare(this)
        if (prepareIntent != null) {
            pendingConfig = config
            pendingTorEnabled = torEnabled
            pendingKillSwitch = killSwitch
            pendingAlwaysOnVpn = alwaysOnVpn
            startActivityForResult(prepareIntent, vpnPrepareRequestCode)
        } else {
            startVpnService(config, torEnabled, killSwitch, alwaysOnVpn)
        }
    }

    private fun startVpnService(
        config: String,
        torEnabled: Boolean,
        killSwitch: Boolean,
        alwaysOnVpn: Boolean,
    ) {
        val intent = Intent(this, V2rayVpnService::class.java).apply {
            action = V2rayVpnService.ACTION_CONNECT
            putExtra(V2rayVpnService.EXTRA_CONFIG, config)
            putExtra(V2rayVpnService.EXTRA_TOR_ENABLED, torEnabled)
            putExtra(V2rayVpnService.EXTRA_KILL_SWITCH, killSwitch)
            putExtra(V2rayVpnService.EXTRA_ALWAYS_ON, alwaysOnVpn)
        }
        if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
    }

    private fun disconnect() {
        startService(Intent(this, V2rayVpnService::class.java).apply {
            action = V2rayVpnService.ACTION_DISCONNECT
        })
    }

    // -------------------------------------------------- split tunneling

    /**
     * لیست اپ‌های نصب‌شده‌ای که مجوز INTERNET دارند.
     * آیکون به‌صورت PNG/Base64-free (ByteArray) به فلاتر می‌رود تا مستقیم در Image.memory بنشیند.
     */
    private fun loadInstalledApps(withIcons: Boolean, result: MethodChannel.Result) {
        Thread {
            val out = ArrayList<Map<String, Any?>>()
            try {
                val pm = packageManager
                val flags = PackageManager.GET_META_DATA
                val apps: List<ApplicationInfo> = pm.getInstalledApplications(flags)
                for (info in apps) {
                    val pkg = info.packageName ?: continue
                    if (pkg == packageName) continue
                    val hasNet = pm.checkPermission(
                        android.Manifest.permission.INTERNET, pkg
                    ) == PackageManager.PERMISSION_GRANTED
                    if (!hasNet) continue

                    val label = runCatching { pm.getApplicationLabel(info).toString() }
                        .getOrDefault(pkg)
                    val isSystem = (info.flags and ApplicationInfo.FLAG_SYSTEM) != 0

                    var iconBytes: ByteArray? = null
                    if (withIcons) {
                        iconBytes = runCatching {
                            drawableToPng(pm.getApplicationIcon(info))
                        }.getOrNull()
                    }

                    out.add(
                        mapOf(
                            "packageName" to pkg,
                            "name" to label,
                            "isSystem" to isSystem,
                            "icon" to iconBytes,
                        )
                    )
                }
                out.sortWith(compareBy({ it["isSystem"] as Boolean }, {
                    (it["name"] as String).lowercase()
                }))
            } catch (t: Throwable) {
                mainHandler.post {
                    result.error("APP_LIST_FAILED", t.message, null)
                }
                return@Thread
            }
            mainHandler.post { result.success(out) }
        }.apply { isDaemon = true }.start()
    }

    /** تبدیل Drawable آیکون اپ به بایت‌های PNG با ابعاد حداکثر 96px */
    private fun drawableToPng(drawable: Drawable): ByteArray? {
        val size = 96
        val bitmap: Bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
            Bitmap.createScaledBitmap(drawable.bitmap, size, size, true)
        } else {
            val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            drawable.setBounds(0, 0, size, size)
            drawable.draw(canvas)
            bmp
        }
        val stream = ByteArrayOutputStream()
        return if (bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)) {
            stream.toByteArray()
        } else {
            null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == vpnPrepareRequestCode) {
            if (resultCode == Activity.RESULT_OK) {
                startVpnService(pendingConfig ?: "", pendingTorEnabled, pendingKillSwitch, pendingAlwaysOnVpn)
            } else {
                VpnState.update(VpnStatus.DISCONNECTED)
            }
            pendingConfig = null
            pendingTorEnabled = false
            pendingKillSwitch = false
            pendingAlwaysOnVpn = false
        }
    }
}
