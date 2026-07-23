package com.v2raystk.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor
import androidx.core.app.NotificationCompat

class V2rayVpnService : VpnService() {
    private var tunnel: ParcelFileDescriptor? = null
    private lateinit var tor: TorManager
    override fun onCreate() { super.onCreate(); tor = TorManager(this); createChannel() }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(7, NotificationCompat.Builder(this, CHANNEL).setSmallIcon(android.R.drawable.ic_lock_lock).setContentTitle("V2ray Stk").setContentText("VPN is active").setOngoing(true).setContentIntent(PendingIntent.getActivity(this, 0, packageManager.getLaunchIntentForPackage(packageName), PendingIntent.FLAG_IMMUTABLE)).build())
        if (tunnel == null) {
            tunnel = Builder().setSession("V2ray Stk").addAddress("172.19.0.1", 30).addRoute("0.0.0.0", 0).addDnsServer("1.1.1.1").establish()
            val fd = tunnel?.fd ?: return START_NOT_STICKY
            if (torEnabled) tor.start()
            LibboxBridge.start(filesDir.resolve("active.json").takeIf { it.exists() }?.readText() ?: "{}", fd)
        }
        return START_STICKY
    }
    override fun onDestroy() { LibboxBridge.stop(); tor.stop(); tunnel?.close(); tunnel = null; super.onDestroy() }
    private fun createChannel() { (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(NotificationChannel(CHANNEL, "VPN", NotificationManager.IMPORTANCE_LOW)) }
    companion object { private const val CHANNEL = "vpn"; @Volatile var torEnabled = false; fun stats(): Map<String, Long> { val values = runCatching { LibboxBridge.traffic() }.getOrDefault(longArrayOf(0, 0)); return mapOf("upload" to values[0], "download" to values[1]) } }
}
