import os

# 1. Fix vpn_controller.dart missing import
vpn_ctrl_path = 'lib/features/vpn/application/vpn_controller.dart'
with open(vpn_ctrl_path, 'r', encoding='utf-8') as f:
    vpn_ctrl_content = f.read()

import_statement = "import '../../profiles/domain/profile_type.dart';"
if import_statement not in vpn_ctrl_content:
    # Add import near the top
    lines = vpn_ctrl_content.split('\n')
    for i, line in enumerate(lines):
        if line.startswith('import '):
            lines.insert(i, import_statement)
            break
    with open(vpn_ctrl_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))
    print("✅ Fixed import in vpn_controller.dart")


# 2. Fix sing_box_config_generator.dart switch case
gen_path = 'lib/features/sing_box/application/sing_box_config_generator.dart'
with open(gen_path, 'r', encoding='utf-8') as f:
    gen_content = f.read()

# Look for the switch statement and add the socks case if missing
if 'case ProfileType.socks:' not in gen_content:
    old_switch = "switch (profile.type) {"
    new_switch = """switch (profile.type) {
      case ProfileType.socks:
        return _buildTorOutbound(profile);"""
    
    gen_content = gen_content.replace(old_switch, new_switch)
    with open(gen_path, 'w', encoding='utf-8') as f:
        f.write(gen_content)
    print("✅ Added ProfileType.socks to sing_box_config_generator.dart")

print("🎉 All done! Now run your build again.")
