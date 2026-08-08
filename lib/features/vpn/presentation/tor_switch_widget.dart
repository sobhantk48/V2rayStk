import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tor_provider.dart';

// این همون دکمه ماست که تبدیلش کردیم به یه ویجت مستقل
class TorSwitchWidget extends ConsumerWidget {
  const TorSwitchWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // خوندن وضعیت فعلی دکمه (روشن/خاموش)
    final isTorOn = ref.watch(torToggleProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // ظاهر دکمه
      child: SwitchListTile(
        title: const Text(
          "Tor Network",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text(
          "اتصال از طریق پل‌های ضدفیلتر",
          style: TextStyle(fontSize: 12),
        ),
        value: isTorOn,
        activeColor: Colors.deepPurpleAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        onChanged: (value) {
          // وقتی کاربر دکمه رو میزنه، دستورات روشن/خاموش شدن اجرا میشه
          ref.read(torToggleProvider.notifier).toggleTor(value);
        },
      ),
    );
  }
}
