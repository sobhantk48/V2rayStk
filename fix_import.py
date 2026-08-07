import os

file_path = 'lib/features/vpn/application/vpn_controller.dart'
import_stmt = "import 'package:v2ray_stk/features/profiles/domain/profile_type.dart';"

if os.path.exists(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    if import_stmt not in content:
        lines = content.split('\n')
        # پیدا کردن آخرین خط import برای تزریق تمیز
        last_import_idx = -1
        for i, line in enumerate(lines):
            if line.startswith('import '):
                last_import_idx = i
        
        if last_import_idx != -1:
            lines.insert(last_import_idx + 1, import_stmt)
        else:
            lines.insert(0, import_stmt)
            
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines))
        print("✅ Import for ProfileType added successfully!")
    else:
        print("⚡ Import already exists. No changes made.")
else:
    print(f"❌ File not found: {file_path}")
