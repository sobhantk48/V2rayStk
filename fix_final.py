import os

controller_file = "lib/features/vpn/application/vpn_controller.dart"
generator_file = "lib/features/sing_box/application/sing_box_config_generator.dart"

# 1. Fix vpn_controller.dart
with open(controller_file, "r", encoding="utf-8") as f:
    c_content = f.read()

if "profile_type.dart" not in c_content:
    c_content = "import '../../profiles/domain/profile_type.dart';\n" + c_content
    with open(controller_file, "w", encoding="utf-8") as f:
        f.write(c_content)
    print("✅ Fixed vpn_controller.dart (Added import)")
else:
    print("⚡ vpn_controller.dart is already fine!")

# 2. Fix sing_box_config_generator.dart
with open(generator_file, "r", encoding="utf-8") as f:
    g_content = f.read()

if "case ProfileType.socks:" not in g_content:
    g_content = g_content.replace(
        "default:", 
        "case ProfileType.socks:\n        return _buildTorOutbound(profile);\n      default:"
    )
    with open(generator_file, "w", encoding="utf-8") as f:
        f.write(g_content)
    print("✅ Fixed sing_box_config_generator.dart (Added SOCKS case)")
else:
    print("⚡ sing_box_config_generator.dart is already fine!")
