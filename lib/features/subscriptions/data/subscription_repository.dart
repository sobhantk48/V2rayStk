import '../domain/subscription.dart';

abstract class SubscriptionRepository {
  Future<List<Subscription>> getSubscriptions();
  Future<void> addSubscription(Subscription subscription);
  Future<void> deleteSubscription(String subscriptionId);
}
