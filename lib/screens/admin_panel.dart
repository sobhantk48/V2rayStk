import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/app_state.dart';

class AdminPanel extends ConsumerWidget {
  const AdminPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(appStateProvider).servers;
    return Scaffold(appBar: AppBar(title: const Text('Admin panel')), body: ListView(padding: const EdgeInsets.all(16), children: [
      Text('Profiles', style: Theme.of(context).textTheme.headlineSmall),
      ...servers.map((server) => ListTile(leading: const Icon(Icons.dns), title: Text(server.name), subtitle: Text(server.id))),
      FilledButton.icon(onPressed: () => ref.read(appStateProvider.notifier).addServer(const Server(id: 'new', name: 'New profile', config: '')), icon: const Icon(Icons.add), label: const Text('Add profile')),
    ]));
  }
}
