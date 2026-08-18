import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profiles/application/profile_providers.dart';
import '../../profiles/domain/profile.dart';

/// انتخاب پروفایل‌های میانی زنجیرهٔ Multi-Hop.
///
/// ترتیب انتخاب مهم است: اولین مورد نزدیک‌ترین پله به سرور نهایی است.
class MultiHopPicker extends ConsumerWidget {
  const MultiHopPicker({
    super.key,
    required this.selectedIds,
    required this.onChanged,
  });

  final List<String> selectedIds;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Profile>> profiles = ref.watch(profilesProvider);

    return profiles.when(
      loading: () => const ListTile(
        leading: Icon(Icons.route),
        title: Text('سرورهای میانی'),
        subtitle: Text('در حال خواندن پروفایل‌ها...'),
      ),
      error: (Object e, StackTrace _) => ListTile(
        leading: const Icon(Icons.error_outline),
        title: const Text('سرورهای میانی'),
        subtitle: Text('خطا در خواندن پروفایل‌ها: $e'),
      ),
      data: (List<Profile> all) {
        final List<Profile> chosen = <Profile>[];
        for (final String id in selectedIds) {
          for (final Profile p in all) {
            if (p.id == id) {
              chosen.add(p);
              break;
            }
          }
        }

        final String subtitle = chosen.isEmpty
            ? 'انتخاب نشده - اتصال تک‌مرحله‌ای است'
            : chosen.map((Profile p) => p.name).join('  <-  ');

        return ListTile(
          leading: const Icon(Icons.route),
          title: const Text('سرورهای میانی (هاپ‌ها)'),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final List<String>? result = await showDialog<List<String>>(
              context: context,
              builder: (BuildContext ctx) => _HopDialog(
                all: all,
                initial: selectedIds,
              ),
            );
            if (result != null) {
              onChanged(result);
            }
          },
        );
      },
    );
  }
}

class _HopDialog extends StatefulWidget {
  const _HopDialog({required this.all, required this.initial});

  final List<Profile> all;
  final List<String> initial;

  @override
  State<_HopDialog> createState() => _HopDialogState();
}

class _HopDialogState extends State<_HopDialog> {
  late List<String> _picked;

  @override
  void initState() {
    super.initState();
    _picked = List<String>.from(widget.initial);
  }

  void _toggle(String id, bool value) {
    setState(() {
      if (value) {
        if (!_picked.contains(id)) {
          _picked.add(id);
        }
      } else {
        _picked.remove(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('انتخاب هاپ‌ها'),
      content: SizedBox(
        width: double.maxFinite,
        child: widget.all.isEmpty
            ? const Text('هیچ پروفایلی ذخیره نشده است.')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: widget.all.length,
                itemBuilder: (BuildContext ctx, int index) {
                  final Profile p = widget.all[index];
                  final int order = _picked.indexOf(p.id);
                  return CheckboxListTile(
                    dense: true,
                    value: order >= 0,
                    title: Text(p.name),
                    subtitle: Text(
                      order >= 0
                          ? 'پله ${order + 1} - ${p.server}:${p.port}'
                          : '${p.server}:${p.port}',
                    ),
                    onChanged: (bool? v) => _toggle(p.id, v ?? false),
                  );
                },
              ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('انصراف'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(<String>[]),
          child: const Text('پاک کردن'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_picked),
          child: const Text('تایید'),
        ),
      ],
    );
  }
}
