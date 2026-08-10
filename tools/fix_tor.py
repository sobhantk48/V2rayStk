import os

path = 'lib/features/sing_box/application/sing_box_config_generator.dart'

try:
    with open(path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    # پیدا کردن خطوطی که تابع توشون تعریف شده
    starts = []
    for i, line in enumerate(lines):
        if '_buildTorOutbound' in line and '{' in line:
            starts.append(i)

    if len(starts) > 1:
        print(f"Found {len(starts)} declarations. Removing the duplicate starting at line {starts[1]+1}...")
        
        start_idx = starts[1]
        brace_count = 0
        end_idx = start_idx
        
        # پیدا کردن انتهای بلوک تابع تکراری
        for i in range(start_idx, len(lines)):
            brace_count += lines[i].count('{')
            brace_count -= lines[i].count('}')
            if brace_count == 0:
                end_idx = i
                break
        
        # حذف بلوک تکراری
        del lines[start_idx:end_idx+1]
        
        with open(path, 'w', encoding='utf-8') as f:
            f.writelines(lines)
        print("✅ با موفقیت تابع تکراری حذف شد!")
    else:
        print("⚠️ تابع تکراری پیدا نشد یا فقط یدونه هست.")
except Exception as e:
    print(f"❌ خطا: {e}")
