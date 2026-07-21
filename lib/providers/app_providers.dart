import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile.dart';
import '../services/profile_service.dart';
import '../services/vpn_bridge.dart';
import 'vpn_provider.dart';

final profilesProvider = FutureProvider.autoDispose<List<Profile>>((ref) async {
  return ProfileService.getAll();
});

final selectedProfileProvider = FutureProvider.autoDispose<Profile?>((ref) async {
  return ProfileService.getSelected();
});

final isAdminLoggedInProvider = StateProvider<bool>((ref) => false);

/// Kept for backward-compat; UI should prefer [vpnEventProvider].
final connectionStatusProvider = StateProvider<bool>((ref) => false);

/// Convenience: true when native reports connected.
final isVpnConnectedProvider = Provider<bool>((ref) {
  final event = ref.watch(vpnEventProvider).valueOrNull;
  return event?.status == VpnStatus.connected;
});
