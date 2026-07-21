import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../theme/app_theme.dart';
import '../../models/profile.dart';
import '../../services/profile_service.dart';

class AddEditProfilePage extends StatefulWidget {
  final Profile? profile;
  const AddEditProfilePage({super.key, this.profile});

  @override
  State<AddEditProfilePage> createState() => _AddEditProfilePageState();
}

class _AddEditProfilePageState extends State<AddEditProfilePage> {
  final _nameCtrl = TextEditingController();
  final _configCtrl = TextEditingController();
  final _remarkCtrl = TextEditingController();
  bool _loading = false;

  bool get isEdit => widget.profile != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _nameCtrl.text = widget.profile!.name;
      _configCtrl.text = widget.profile!.config;
      _remarkCtrl.text = widget.profile!.remark ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _configCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final config = _configCtrl.text.trim();

    if (name.isEmpty || config.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نام و کانفیگ الزامی است'), backgroundColor: AppTheme.danger),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      if (isEdit) {
        final updated = widget.profile!.copyWith(
          name: name,
          config: config,
          remark: _remarkCtrl.text.trim().isEmpty ? null : _remarkCtrl.text.trim(),
        );
        await ProfileService.update(updated);
      } else {
        await ProfileService.add(
          name,
          config,
          remark: _remarkCtrl.text.trim().isEmpty ? null : _remarkCtrl.text.trim(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('profile_saved'.tr()), backgroundColor: AppTheme.success),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'edit_profile'.tr() : 'add_profile'.tr()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'profile_name'.tr(),
                prefixIcon: const Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _configCtrl,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: 'config'.tr(),
                alignLabelWithHint: true,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 80),
                  child: Icon(Icons.code),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _remarkCtrl,
              decoration: const InputDecoration(
                labelText: 'Remark (اختیاری)',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text('save'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
