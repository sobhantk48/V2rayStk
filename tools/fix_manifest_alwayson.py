import pathlib, re, shutil, sys

p = pathlib.Path("android/app/src/main/AndroidManifest.xml")
if not p.exists():
    print("!! AndroidManifest.xml پیدا نشد")
    sys.exit(1)

src = p.read_text(encoding="utf-8")
shutil.copy2(p, p.with_suffix(".xml.bak_alwayson"))
orig = src

# 1) حذف کامل attribute نامعتبر (هرجا باشد)
src, n_attr = re.subn(r'\s*android:supportsAlwaysOnVpn\s*=\s*"[^"]*"', "", src)

# 2) تزریق meta-data صحیح داخل سرویس VPN
META = ('            <meta-data\n'
        '                android:name="android.net.VpnService.SUPPORTS_ALWAYS_ON"\n'
        '                android:value="true" />\n')

n_meta = 0
if "android.net.VpnService.SUPPORTS_ALWAYS_ON" not in src:
    idx = src.find("V2rayVpnService")
    if idx == -1:
        print("!! سرویس V2rayVpnService در منیفست پیدا نشد")
    else:
        start = src.rfind("<service", 0, idx)
        close_tag = src.find("</service>", start)
        self_close = src.find("/>", start)
        # کدام پایان زودتر می‌آید؟
        if close_tag != -1 and (self_close == -1 or close_tag < self_close):
            src = src[:close_tag] + META + src[close_tag:]
            n_meta = 1
        elif self_close != -1:
            src = src[:self_close] + ">\n" + META + "        </service>" + src[self_close + 2:]
            n_meta = 1

p.write_text(src, encoding="utf-8")
print(f"attribute حذف‌شده: {n_attr} | meta-data افزوده‌شده: {n_meta}")
print("changed" if src != orig else "no-change")
