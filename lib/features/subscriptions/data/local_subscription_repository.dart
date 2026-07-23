import '../../../core/storage/local_storage_service.dart';
import '../domain/subscription.dart';
import 'subscription_repository.dart';

class LocalSubscriptionRepository implements SubscriptionRepository {
  LocalSubscriptionRepository(this._storage);

  final LocalStorageService _storage;

  @override
  Future<List<Subscription>> getSubscriptions() {
    return _storage.loadSubscriptions();
  }

  @override
  Future<void> addSubscription(Subscription subscription) async {
    final List<Subscription> subscriptions = await _storage.loadSubscriptions();
    final List<Subscription> updated = <Subscription>[
      ...subscriptions,
      subscription,
    ];
    await _storage.saveSubscriptions(updated);
  }

  @override
  Future<void> deleteSubscription(String subscriptionId) async {
    final List<Subscription> subscriptions = await _storage.loadSubscriptions();
    final List<Subscription> updated = subscriptions
        .where((Subscription item) => item.id != subscriptionId)
        .toList();
    await _storage.saveSubscriptions(updated);
  }
}
