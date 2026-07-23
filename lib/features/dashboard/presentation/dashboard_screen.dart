import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../profiles/application/profile_providers.dart';
import '../../profiles/domain/profile.dart';
import '../../vpn/application/vpn_controller.dart';
import '../../vpn/domain/vpn_status.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final VpnStatus status = ref.watch(vpnControllerProvider);
    final AsyncValue<List<Profile>> profilesAsync = ref.watch(profilesProvider);

    return AppScaffold(
      title: 'Dashboard',
      currentIndex: 0,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: <Widget>[
                  const Icon(Icons.shield_outlined, size: 56),
                  const SizedBox(height: 12),
                  Text(
                    _statusLabel(status),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(_activeProfileLabel(profilesAsync)),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      final VpnController controller =
                          ref.read(vpnControllerProvider.notifier);
                      if (status == VpnStatus.connected) {
                        await controller.disconnect();
                      } else {
                        await controller.connect();
                      }
                    },
                    child: Text(
                      status == VpnStatus.connected ? 'Disconnect' : 'Connect',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(VpnStatus status) {
    switch (status) {
      case VpnStatus.connected:
        return 'Connected';
      case VpnStatus.connecting:
        return 'Connecting';
      case VpnStatus.disconnected:
        return 'Disconnected';
    }
  }

  String _activeProfileLabel(AsyncValue<List<Profile>> profilesAsync) {
    return profilesAsync.maybeWhen(
      data: (List<Profile> profiles) {
        final Profile? active = profiles.cast<Profile?>().firstWhere(
              (Profile? profile) => profile?.isActive == true,
              orElse: () => null,
            );
        if (active == null) {
          return 'Active profile: none';
        }
        return 'Active profile: ${active.name}';
      },
      orElse: () => 'Active profile: loading...',
    );
  }
}
