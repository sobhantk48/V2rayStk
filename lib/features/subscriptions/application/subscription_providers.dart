import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_storage_service.dart';
import '../../profiles/application/profile_providers.dart';
import '../data/local_subscription_repository.dart';
import '../data/subscription_repository.dart';
import '../domain/subscription.dart';

final FutureProvider<SubscriptionRepository> subscriptionRepositoryProvider =
    FutureProvider<SubscriptionRepository>((Ref ref) async {
  final LocalStorageService storage =
      await ref.watch(localStorageProvider.future);
  return LocalSubscriptionRepository(storage);
});

final AsyncNotifierProvider<SubscriptionsNotifier, List<Subscription>>
    subscriptionsProvider =
    AsyncNotifierProvider<SubscriptionsNotifier, List<Subscription>>(
  SubscriptionsNotifier.new,
);

class SubscriptionsNotifier extends AsyncNotifier<List<Subscription>> {
  Future<SubscriptionRepository> get _repository async {
    return ref.read(subscriptionRepositoryProvider.future);
  }

  @override
  Future<List<Subscription>> build() async {
    final SubscriptionRepository repository = await _repository;
    return repository.getSubscriptions();
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final SubscriptionRepository repository = await _repository;
      return repository.getSubscriptions();
    });
  }

  Future<void> addSubscription({
    required String name,
    required String url,
  }) async {
    final SubscriptionRepository repository = await _repository;
    await repository.addSubscription(
      Subscription(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name.trim().isEmpty ? 'Subscription' : name.trim(),
        url: url.trim(),
        lastUpdatedAt: null,
        enabled: true,
      ),
    );
    await reload();
  }

  Future<void> deleteSubscription(String subscriptionId) async {
    final SubscriptionRepository repository = await _repository;
    await repository.deleteSubscription(subscriptionId);
    await reload();
  }
}
