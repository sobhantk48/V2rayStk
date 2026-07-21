import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile.dart';
import '../services/profile_service.dart';

final profilesProvider = FutureProvider.autoDispose<List<Profile>>((ref) async {
  return ProfileService.getAll();
});

final selectedProfileProvider = FutureProvider.autoDispose<Profile?>((ref) async {
  return ProfileService.getSelected();
});

final isAdminLoggedInProvider = StateProvider<bool>((ref) => false);

final connectionStatusProvider = StateProvider<bool>((ref) => false);
