import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/vpn_bridge.dart';

class Server {
  const Server({required this.id, required this.name, required this.config});
  final String id, name, config;
}

class AppState {
  const AppState({this.locale = const Locale('en'), this.connected = false,
    this.tor = false, this.servers = const []});
  final Locale locale; final bool connected, tor; final List<Server> servers;
  AppState copyWith({Locale? locale, bool? connected, bool? tor, List<Server>? servers}) =>
      AppState(locale: locale ?? this.locale, connected: connected ?? this.connected,
          tor: tor ?? this.tor, servers: servers ?? this.servers);
}

class AppStateNotifier extends Notifier<AppState> {
  @override AppState build() => const AppState(servers: [Server(id: 'default', name: 'Default profile', config: '')]);
  Future<void> toggleConnection() async { final next = !state.connected; await VpnBridge.setTor(state.tor); await VpnBridge.setEnabled(next); state = state.copyWith(connected: next); }
  Future<void> toggleTor(bool enabled) async { state = state.copyWith(tor: enabled); if (state.connected) await VpnBridge.setTor(enabled); }
  void setLocale(Locale locale) => state = state.copyWith(locale: locale);
  void addServer(Server server) => state = state.copyWith(servers: [...state.servers, server]);
}

final appStateProvider = NotifierProvider<AppStateNotifier, AppState>(AppStateNotifier.new);
