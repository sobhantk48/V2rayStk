import os

file_path = 'lib/features/sing_box/application/sing_box_config_generator.dart'

if os.path.exists(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # جایگزینی فراخوانی اشتباه با فراخوانی درست که uri و tag رو می‌گیره
    new_content = content.replace('return _buildTorOutbound(profile);', 'return _buildTorOutbound(uri, tag);')
    new_content = new_content.replace('_buildTorOutbound(profile)', '_buildTorOutbound(uri, tag)')

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)

    print("✅ _buildTorOutbound arguments fixed successfully!")
else:
    print("❌ File not found!")
