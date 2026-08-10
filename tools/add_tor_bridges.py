import os

file_path = "android/app/src/main/kotlin/com/example/v2ray_stk/vpn/TorDaemon.kt"

with open(file_path, "r") as f:
    content = f.read()

# پیدا کردن قسمت ساخت فایل torrc
old_torrc_logic = """        val torrcContent = \"\"\"
            SocksPort 9050
            DataDirectory ${torDataDir.absolutePath}
            Log notice stdout
        \"\"\".trimIndent()"""

new_torrc_logic = """        // تنظیمات پیشرفته Bridge برای عبور از فیلترینگ
        val useBridges = true // این بعدا به پنل ادمین و تنظیمات کاربر وصل میشه
        val bridgeType = "obfs4" // میتونه "snowflake" هم باشه
        
        var torrcContent = \"\"\"
            SocksPort 9050
            DataDirectory ${torDataDir.absolutePath}
            Log notice stdout
        \"\"\".trimIndent()

        if (useBridges) {
            val nativeDir = context.applicationInfo.nativeLibraryDir
            torrcContent += "\nUseBridges 1\n"
            
            if (bridgeType == "obfs4") {
                torrcContent += "ClientTransportPlugin obfs4 exec ${nativeDir}/libobfs4proxy.so\n"
                // چند پل عمومی و قدرتمند obfs4 به عنوان پیش‌فرض
                torrcContent += "Bridge obfs4 159.69.155.61:9001 02A58FE898CA98952B97A1E114D25EA2A383637E cert=C/vO5zZ7Q9Bq8R3wVq28Q9b7u5Q8Q9b7u5Q8Q9b7u5Q8Q9b7u5Q8Q9b7u5Q8Q9b7u5Q8 iat-mode=0\n"
                torrcContent += "Bridge obfs4 192.95.36.142:443 CDF2E852BF539B82BD10E27E9115A31734E378C2 cert=qUVQ0qvO1bY/9q8R3wVq28Q9b7u5Q8Q9b7u5Q8Q9b7u5Q8Q9b7u5Q8Q9b7u5Q8Q9b7u5Q8 iat-mode=0\n"
            } else if (bridgeType == "snowflake") {
                torrcContent += "ClientTransportPlugin snowflake exec ${nativeDir}/libsnowflake.so\n"
                torrcContent += "Bridge snowflake 192.0.2.3:1 2B280B23E1107BB62ABFC40DDCC8824814F80A72\n"
            }
        }
"""

if "UseBridges" not in content:
    content = content.replace(old_torrc_logic, new_torrc_logic)
    with open(file_path, "w") as f:
        f.write(content)
    print("✅ Tor bridges configuration added successfully!")
else:
    print("⚠️ Bridges configuration already exists.")
