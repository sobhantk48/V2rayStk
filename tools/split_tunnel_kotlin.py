#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Split Tunneling — پچ سمت Kotlin (VpnPrefs / V2rayVpnService / MainActivity)"""
import os, re, shutil, sys, time

ROOT = os.getcwd()
K = "android/app/src/main/kotlin/com/example/v2ray_stk"
PREFS = os.path.join(ROOT, K, "vpn/VpnPrefs.kt")
SVC   = os.path.join(ROOT, K, "vpn/V2rayVpnService.kt")
MAIN  = os.path.join(ROOT, K, "MainActivity.kt")
BAK   = os.path.join(ROOT, ".trash_bak")
os.makedirs(BAK, exist_ok=True)
STAMP = time.strftime("%Y%m%d-%H%M%S")

def read(p):
    with open(p, encoding="utf-8") as f: return f.read()

def write(p, s):
    shutil.copy2(p, os.path.join(BAK, os.path.basename(p) + ".bak_split_" + STAMP))
    with open(p, "w", encoding="utf-8") as f: f.write(s)
    print("  ✔ نوشته شد:", os.path.relpath(p, ROOT))

for p in (PREFS, SVC, MAIN):
    if not os.path.exists(p):
        sys.exit("✘ پیدا نشد: " + p)

# ---------------------------------------------------------------- VpnPrefs.kt
s = read(PREFS)
if "KEY_SPLIT_MODE" in s:
    print("  • VpnPrefs: از قبل پچ شده")
else:
    s = s.replace(
        '    private const val KEY_ALWAYS_ON = "always_on"',
        '    private const val KEY_ALWAYS_ON = "always_on"\n'
        '    private const val KEY_SPLIT_MODE = "split_mode"\n'
        '    private const val KEY_SPLIT_APPS = "split_apps"\n\n'
        '    /** حالت‌های مجاز تونل تفکیکی */\n'
        '    const val SPLIT_OFF = "off"\n'
        '    const val SPLIT_EXCLUDE = "exclude"\n'
        '    const val SPLIT_INCLUDE = "include"',
        1)
    s = s.rstrip()
    assert s.endswith("}")
    s = s[:-1] + '''
    // ----------------------------------------------------- split tunneling

    /** ذخیره‌ی حالت و لیست پکیج‌ها؛ از سمت Flutter صدا زده می‌شود. */
    fun saveSplit(context: Context, mode: String, apps: Collection<String>) {
        val safeMode = when (mode) {
            SPLIT_EXCLUDE, SPLIT_INCLUDE -> mode
            else -> SPLIT_OFF
        }
        prefs(context).edit()
            .putString(KEY_SPLIT_MODE, safeMode)
            .putStringSet(KEY_SPLIT_APPS, apps.filter { it.isNotBlank() }.toSet())
            .apply()
    }

    fun splitMode(context: Context): String =
        prefs(context).getString(KEY_SPLIT_MODE, SPLIT_OFF) ?: SPLIT_OFF

    fun splitApps(context: Context): Set<String> =
        prefs(context).getStringSet(KEY_SPLIT_APPS, emptySet()) ?: emptySet()
}
'''
    write(PREFS, s)

# ------------------------------------------------------- V2rayVpnService.kt
s = read(SVC)
if "applySplitTunnel" in s:
    print("  • V2rayVpnService: از قبل پچ شده")
else:
    old = """        // ترافیک خود اپ (و پروسه tor) از تونل خارج می‌ماند تا حلقه ایجاد نشود
        runCatching { builder.addDisallowedApplication(packageName) }

        return builder.establish()
    }"""
    new = """        // ترافیک خود اپ (و پروسه tor) از تونل خارج می‌ماند تا حلقه ایجاد نشود
        runCatching { builder.addDisallowedApplication(packageName) }

        applySplitTunnel(builder)

        return builder.establish()
    }

    /**
     * Split Tunneling — اعمال لیست اپ‌ها روی VpnService.Builder
     *
     * exclude: اپ‌های انتخاب‌شده از تونل خارج می‌مانند (بقیه داخل تونل)
     * include: فقط اپ‌های انتخاب‌شده داخل تونل می‌روند (بقیه مستقیم)
     *
     * نکته: اندروید اجازه نمی‌دهد هر دو متد addAllowed/addDisallowed با هم استفاده شوند،
     * و چون پکیج خودمان بالاتر با addDisallowedApplication ثبت شده، در حالت include
     * ابتدا Builder از نو ساخته نمی‌شود بلکه پکیج خودمان از لیست allowed کنار گذاشته می‌شود.
     */
    private fun applySplitTunnel(builder: Builder) {
        val mode = runCatching { VpnPrefs.splitMode(this) }.getOrDefault(VpnPrefs.SPLIT_OFF)
        val apps = runCatching { VpnPrefs.splitApps(this) }.getOrDefault(emptySet())

        if (mode == VpnPrefs.SPLIT_OFF || apps.isEmpty()) {
            Log.d(TAG, "Split Tunneling غیرفعال (mode=$mode apps=${apps.size})")
            return
        }

        var applied = 0
        when (mode) {
            VpnPrefs.SPLIT_EXCLUDE -> {
                for (pkg in apps) {
                    if (pkg == packageName) continue
                    runCatching { builder.addDisallowedApplication(pkg) }
                        .onSuccess { applied++ }
                        .onFailure { Log.w(TAG, "exclude ناموفق برای $pkg: ${it.message}") }
                }
                Log.i(TAG, "Split Tunneling [exclude] روی $applied اپ اعمال شد")
            }

            VpnPrefs.SPLIT_INCLUDE -> {
                for (pkg in apps) {
                    if (pkg == packageName) continue
                    runCatching { builder.addAllowedApplication(pkg) }
                        .onSuccess { applied++ }
                        .onFailure { Log.w(TAG, "include ناموفق برای $pkg: ${it.message}") }
                }
                if (applied == 0) {
                    Log.w(TAG, "هیچ اپی برای include اعمال نشد — تونل عملاً خالی می‌ماند")
                }
                Log.i(TAG, "Split Tunneling [include] روی $applied اپ اعمال شد")
            }
        }
    }"""
    if old not in s:
        sys.exit("✘ بلوک establishTun پیدا نشد — فایل تغییر کرده است")
    s = s.replace(old, new, 1)
    write(SVC, s)

# ------------------------------------------------------------ MainActivity.kt
s = read(MAIN)
if "getInstalledApps" in s:
    print("  • MainActivity: از قبل پچ شده")
else:
    # ایمپورت‌ها
    s = s.replace(
        "import android.net.VpnService",
        "import android.content.pm.ApplicationInfo\n"
        "import android.content.pm.PackageManager\n"
        "import android.graphics.Bitmap\n"
        "import android.graphics.Canvas\n"
        "import android.graphics.drawable.BitmapDrawable\n"
        "import android.graphics.drawable.Drawable\n"
        "import android.net.VpnService",
        1)
    s = s.replace(
        "import java.io.IOException",
        "import com.example.v2ray_stk.vpn.VpnPrefs\n"
        "import java.io.ByteArrayOutputStream\n"
        "import java.io.IOException",
        1)
    # متدهای کانال
    s = s.replace(
        '                    "testLatency" -> measureLatency(result)',
        '                    "testLatency" -> measureLatency(result)\n\n'
        '                    "getInstalledApps" -> loadInstalledApps(\n'
        '                        call.argument<Boolean>("withIcons") ?: true,\n'
        '                        result,\n'
        '                    )\n\n'
        '                    "setSplitTunnel" -> {\n'
        '                        val mode = call.argument<String>("mode") ?: "off"\n'
        '                        val apps = call.argument<List<String>>("apps") ?: emptyList()\n'
        '                        runCatching { VpnPrefs.saveSplit(this, mode, apps) }\n'
        '                        result.success(true)\n'
        '                    }\n\n'
        '                    "getSplitTunnel" -> result.success(\n'
        '                        mapOf(\n'
        '                            "mode" to VpnPrefs.splitMode(this),\n'
        '                            "apps" to VpnPrefs.splitApps(this).toList(),\n'
        '                        )\n'
        '                    )',
        1)
    # بدنه‌ی متدها قبل از onActivityResult
    anchor = "    override fun onActivityResult("
    body = '''    // -------------------------------------------------- split tunneling

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

'''
    if anchor not in s:
        sys.exit("✘ onActivityResult پیدا نشد")
    s = s.replace(anchor, body + anchor, 1)
    write(MAIN, s)

print("\n✅ پچ Kotlin تمام شد.")
