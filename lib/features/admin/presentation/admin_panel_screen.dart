import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/strings.dart';
import '../data/admin_service.dart';
import '../domain/admin_settings.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  AdminSettings? _settings;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final AdminSettings settings = await AdminService.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
      _loading = false;
    });
  }

  Future<void> _update(AdminSettings next) async {
    setState(() => _settings = next);
    await AdminService.save(next);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final Strings strings = Strings.of(context);
    if (!AdminService.isUnlocked) {
      return Scaffold(
        appBar: AppBar(title: Text(strings.adminPanel)),
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/admin'),
            child: Text(strings.login),
          ),
        ),
      );
    }
    final AdminSettings? settings = _settings;
    if (_loading || settings == null) {
      return Scaffold(
        appBar: AppBar(title: Text(strings.adminPanel)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(strings.adminPanel),
          actions: <Widget>[
            IconButton(
              tooltip: strings.lockPanel,
              icon: const Icon(Icons.logout),
              onPressed: () {
                AdminService.lock();
                context.go('/settings');
              },
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(text: strings.tabGeneral),
              Tab(text: strings.tabNetwork),
              Tab(text: strings.tabSecurity),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            _generalTab(strings, settings),
            _networkTab(strings, settings),
            _securityTab(strings, settings),
          ],
        ),
      ),
    );
  }

  Widget _generalTab(Strings strings, AdminSettings s) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: <Widget>[
        _header(strings.sectionRouting),
        SwitchListTile(
          title: Text(strings.torRouting),
          subtitle: Text(strings.torRoutingHint),
          value: s.torEnabled,
          onChanged: (bool v) => _update(s.copyWith(torEnabled: v)),
        ),
        SwitchListTile(
          title: Text(strings.multiHop),
          subtitle: Text(strings.multiHopHint),
          value: s.multiHop,
          onChanged: (bool v) => _update(s.copyWith(multiHop: v)),
        ),
        SwitchListTile(
          title: Text(strings.dynamicRouting),
          value: s.dynamicRouting,
          onChanged: (bool v) => _update(s.copyWith(dynamicRouting: v)),
        ),
        SwitchListTile(
          title: Text(strings.autoServerSelection),
          value: s.autoServerSelection,
          onChanged: (bool v) => _update(s.copyWith(autoServerSelection: v)),
        ),
        const Divider(),
        _header(strings.sectionPerformance),
        SwitchListTile(
          title: Text(strings.liteMode),
          subtitle: Text(strings.liteModeHint),
          value: s.liteMode,
          onChanged: (bool v) => _update(s.copyWith(liteMode: v)),
        ),
        SwitchListTile(
          title: Text(strings.batteryOptimization),
          value: s.batteryOptimization,
          onChanged: (bool v) => _update(s.copyWith(batteryOptimization: v)),
        ),
        SwitchListTile(
          title: Text(strings.trafficCompression),
          value: s.trafficCompression,
          onChanged: (bool v) => _update(s.copyWith(trafficCompression: v)),
        ),
        SwitchListTile(
          title: Text(strings.lwo),
          subtitle: Text(strings.lwoHint),
          value: s.lwoEnabled,
          onChanged: (bool v) => _update(s.copyWith(lwoEnabled: v)),
        ),
        SwitchListTile(
          title: Text(strings.nordLynx),
          value: s.nordLynxEnabled,
          onChanged: (bool v) => _update(s.copyWith(nordLynxEnabled: v)),
        ),
        const Divider(),
        _header(strings.sectionUserPermissions),
        SwitchListTile(
          title: Text(strings.allowUserEdit),
          value: s.allowUserEdit,
          onChanged: (bool v) => _update(s.copyWith(allowUserEdit: v)),
        ),
        SwitchListTile(
          title: Text(strings.allowUserImport),
          value: s.allowUserImport,
          onChanged: (bool v) => _update(s.copyWith(allowUserImport: v)),
        ),
        SwitchListTile(
          title: Text(strings.allowUserGroups),
          value: s.allowUserGroups,
          onChanged: (bool v) => _update(s.copyWith(allowUserGroups: v)),
        ),
        SwitchListTile(
          title: Text(strings.hapticFeedback),
          value: s.hapticFeedback,
          onChanged: (bool v) => _update(s.copyWith(hapticFeedback: v)),
        ),
      ],
    );
  }

  Widget _networkTab(Strings strings, AdminSettings s) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: <Widget>[
        _header(strings.sectionDns),
        ListTile(
          title: Text(strings.dnsMode),
          subtitle: Text(s.dnsMode.toUpperCase()),
          trailing: DropdownButton<String>(
            value: s.dnsMode,
            onChanged: (String? v) {
              if (v != null) {
                _update(s.copyWith(dnsMode: v));
              }
            },
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(value: 'doh', child: Text('DoH')),
              DropdownMenuItem<String>(value: 'dot', child: Text('DoT')),
              DropdownMenuItem<String>(value: 'udp', child: Text('UDP')),
              DropdownMenuItem<String>(value: 'tcp', child: Text('TCP')),
            ],
          ),
        ),
        _textTile(
          title: strings.dnsServer,
          value: s.dnsServer,
          onSaved: (String v) => _update(s.copyWith(dnsServer: v)),
        ),
        SwitchListTile(
          title: Text(strings.splitDns),
          subtitle: Text(strings.splitDnsHint),
          value: s.splitDns,
          onChanged: (bool v) => _update(s.copyWith(splitDns: v)),
        ),
        const Divider(),
        _header(strings.sectionFragment),
        SwitchListTile(
          title: Text(strings.fragmentEnabled),
          value: s.fragmentEnabled,
          onChanged: (bool v) => _update(s.copyWith(fragmentEnabled: v)),
        ),
        _textTile(
          title: strings.fragmentPackets,
          value: s.fragmentPackets,
          enabled: s.fragmentEnabled,
          onSaved: (String v) => _update(s.copyWith(fragmentPackets: v)),
        ),
        _textTile(
          title: strings.fragmentLength,
          value: s.fragmentLength,
          enabled: s.fragmentEnabled,
          onSaved: (String v) => _update(s.copyWith(fragmentLength: v)),
        ),
        _textTile(
          title: strings.fragmentInterval,
          value: s.fragmentInterval,
          enabled: s.fragmentEnabled,
          onSaved: (String v) => _update(s.copyWith(fragmentInterval: v)),
        ),
        const Divider(),
        _header(strings.sectionTun),
        _textTile(
          title: strings.mtu,
          value: '${s.mtu}',
          keyboardType: TextInputType.number,
          onSaved: (String v) {
            final int? parsed = int.tryParse(v);
            if (parsed != null && parsed >= 576 && parsed <= 65535) {
              _update(s.copyWith(mtu: parsed));
            } else {
              _toast(strings.invalidValue);
            }
          },
        ),
        SwitchListTile(
          title: Text(strings.autoConnectOnNetworkChange),
          value: s.autoConnectOnNetworkChange,
          onChanged: (bool v) =>
              _update(s.copyWith(autoConnectOnNetworkChange: v)),
        ),
        SwitchListTile(
          title: Text(strings.alwaysOnVpn),
          value: s.alwaysOnVpn,
          onChanged: (bool v) => _update(s.copyWith(alwaysOnVpn: v)),
        ),
        const Divider(),
        _header(strings.sectionApi),
        SwitchListTile(
          title: Text(strings.clashApi),
          subtitle: Text(strings.clashApiHint),
          value: s.clashApiEnabled,
          onChanged: (bool v) => _update(s.copyWith(clashApiEnabled: v)),
        ),
        _textTile(
          title: strings.clashApiPort,
          value: '${s.clashApiPort}',
          enabled: s.clashApiEnabled,
          keyboardType: TextInputType.number,
          onSaved: (String v) {
            final int? parsed = int.tryParse(v);
            if (parsed != null && parsed > 1023 && parsed <= 65535) {
              _update(s.copyWith(clashApiPort: parsed));
            } else {
              _toast(strings.invalidValue);
            }
          },
        ),
        ListTile(
          title: Text(strings.logLevel),
          trailing: DropdownButton<String>(
            value: s.logLevel,
            onChanged: (String? v) {
              if (v != null) {
                _update(s.copyWith(logLevel: v));
              }
            },
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(value: 'trace', child: Text('trace')),
              DropdownMenuItem<String>(value: 'debug', child: Text('debug')),
              DropdownMenuItem<String>(value: 'info', child: Text('info')),
              DropdownMenuItem<String>(value: 'warn', child: Text('warn')),
              DropdownMenuItem<String>(value: 'error', child: Text('error')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _securityTab(Strings strings, AdminSettings s) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: <Widget>[
        _header(strings.sectionProtection),
        SwitchListTile(
          title: Text(strings.killSwitch),
          subtitle: Text(strings.killSwitchHint),
          value: s.killSwitch,
          onChanged: (bool v) => _update(s.copyWith(killSwitch: v)),
        ),
        SwitchListTile(
          title: Text(strings.anonymousMode),
          subtitle: Text(strings.anonymousModeHint),
          value: s.anonymousMode,
          onChanged: (bool v) => _update(s.copyWith(anonymousMode: v)),
        ),
        SwitchListTile(
          title: Text(strings.biometricLock),
          value: s.biometricLock,
          onChanged: (bool v) => _update(s.copyWith(biometricLock: v)),
        ),
        const Divider(),
        _header(strings.sectionFirewall),
        SwitchListTile(
          title: Text(strings.firewall),
          value: s.firewallEnabled,
          onChanged: (bool v) => _update(s.copyWith(firewallEnabled: v)),
        ),
        SwitchListTile(
          title: Text(strings.blockAds),
          value: s.blockAds,
          onChanged: s.firewallEnabled
              ? (bool v) => _update(s.copyWith(blockAds: v))
              : null,
        ),
        SwitchListTile(
          title: Text(strings.blockTrackers),
          value: s.blockTrackers,
          onChanged: s.firewallEnabled
              ? (bool v) => _update(s.copyWith(blockTrackers: v))
              : null,
        ),
        SwitchListTile(
          title: Text(strings.blockTorrent),
          value: s.blockTorrent,
          onChanged: s.firewallEnabled
              ? (bool v) => _update(s.copyWith(blockTorrent: v))
              : null,
        ),
        const Divider(),
        _header(strings.sectionPassword),
        ListTile(
          leading: const Icon(Icons.key_outlined),
          title: Text(strings.changePassword),
          subtitle: Text(strings.changePasswordHint),
          trailing: const Icon(Icons.chevron_right),
          onTap: _showChangePasswordDialog,
        ),
      ],
    );
  }

  Widget _header(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  Widget _textTile({
    required String title,
    required String value,
    required ValueChanged<String> onSaved,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return ListTile(
      enabled: enabled,
      title: Text(title),
      subtitle: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.edit_outlined),
      onTap: enabled
          ? () async {
              final String? result = await _promptText(
                title: title,
                initial: value,
                keyboardType: keyboardType,
              );
              if (result != null && result.trim().isNotEmpty) {
                onSaved(result.trim());
              }
            }
          : null,
    );
  }

  Future<String?> _promptText({
    required String title,
    required String initial,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final Strings strings = Strings.of(context);
    final TextEditingController controller =
        TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: keyboardType,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: Text(strings.save),
            ),
          ],
        );
      },
    ).whenComplete(controller.dispose);
  }

  Future<void> _showChangePasswordDialog() async {
    final Strings strings = Strings.of(context);
    final TextEditingController current = TextEditingController();
    final TextEditingController next = TextEditingController();
    final TextEditingController confirm = TextEditingController();

    final bool? done = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        String? error;
        return StatefulBuilder(
          builder: (BuildContext ctx, void Function(void Function()) setLocal) {
            return AlertDialog(
              title: Text(strings.changePassword),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: current,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: strings.currentPassword,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: next,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: strings.newPassword,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirm,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: strings.confirmPassword,
                        border: const OutlineInputBorder(),
                        errorText: error,
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(strings.cancel),
                ),
                FilledButton(
                  onPressed: () async {
                    if (next.text.length < 4) {
                      setLocal(() => error = strings.passwordTooShort);
                      return;
                    }
                    if (next.text != confirm.text) {
                      setLocal(() => error = strings.passwordMismatch);
                      return;
                    }
                    final bool ok = await AdminService.changePassword(
                      currentPassword: current.text,
                      newPassword: next.text,
                    );
                    if (!ok) {
                      setLocal(() => error = strings.wrongPassword);
                      return;
                    }
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(true);
                    }
                  },
                  child: Text(strings.save),
                ),
              ],
            );
          },
        );
      },
    );

    current.dispose();
    next.dispose();
    confirm.dispose();

    if (done == true && mounted) {
      await _load();
      if (mounted) {
        _toast(strings.passwordChanged);
      }
    }
  }
}
