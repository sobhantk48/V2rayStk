import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../state/app_state.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider); final text = Strings.of(state.locale);
    return Directionality(textDirection: text.fa ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(appBar: AppBar(title: Text(text.appName), actions: [
        IconButton(icon: const Icon(Icons.admin_panel_settings), onPressed: () => Navigator.pushNamed(context, '/admin'))]),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
            Icon(state.connected ? Icons.shield : Icons.shield_outlined, size: 72, color: state.connected ? Colors.green : Colors.indigo),
            const SizedBox(height: 12), Text(state.connected ? text.connected : text.disconnected, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20), FilledButton.icon(onPressed: () => ref.read(appStateProvider.notifier).toggleConnection(), icon: Icon(state.connected ? Icons.stop : Icons.play_arrow), label: Text(state.connected ? text.disconnect : text.connect)),
          ]))),
          SwitchListTile(title: Text(text.tor), value: state.tor, onChanged: (value) => ref.read(appStateProvider.notifier).toggleTor(value)),
          ListTile(title: Text(text.servers), subtitle: Text(state.servers.map((server) => server.name).join(', '))),
          ListTile(title: Text(text.language), trailing: DropdownButton<Locale>(value: state.locale, items: const [DropdownMenuItem(value: Locale('en'), child: Text('English')), DropdownMenuItem(value: Locale('fa'), child: Text('فارسی'))], onChanged: (value) { if (value != null) ref.read(appStateProvider.notifier).setLocale(value); })),
        ])));
  }
}
