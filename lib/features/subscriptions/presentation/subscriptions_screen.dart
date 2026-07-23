import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../application/subscription_providers.dart';
import '../domain/subscription.dart';

class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Subscription>> subscriptionsAsync =
        ref.watch(subscriptionsProvider);

    return AppScaffold(
      title: 'Subscriptions',
      currentIndex: 2,
      body: Column(
        children: <Widget>[
          _AddSubscriptionCard(
            onSubmit: ({
              required String name,
              required String url,
            }) async {
              await ref.read(subscriptionsProvider.notifier).addSubscription(
                    name: name,
                    url: url,
                  );
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: subscriptionsAsync.when(
              data: (List<Subscription> subscriptions) {
                if (subscriptions.isEmpty) {
                  return const Center(
                    child: Text('No subscriptions added yet.'),
                  );
                }

                return ListView.separated(
                  itemCount: subscriptions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (BuildContext context, int index) {
                    final Subscription item = subscriptions[index];
                    return Card(
                      child: ListTile(
                        title: Text(item.name),
                        subtitle: Text(item.url),
                        trailing: IconButton(
                          onPressed: () async {
                            await ref
                                .read(subscriptionsProvider.notifier)
                                .deleteSubscription(item.id);
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    );
                  },
                );
              },
              error: (Object error, StackTrace stackTrace) {
                return Center(
                  child: Text('Failed to load subscriptions: $error'),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddSubscriptionCard extends StatefulWidget {
  const _AddSubscriptionCard({
    required this.onSubmit,
  });

  final Future<void> Function({
    required String name,
    required String url,
  }) onSubmit;

  @override
  State<_AddSubscriptionCard> createState() => _AddSubscriptionCardState();
}

class _AddSubscriptionCardState extends State<_AddSubscriptionCard> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String url = _urlController.text.trim();
    if (url.isEmpty) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    await widget.onSubmit(
      name: _nameController.text.trim(),
      url: url,
    );

    if (mounted) {
      _nameController.clear();
      _urlController.clear();
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Subscription Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Subscription URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: Text(_isSubmitting ? 'Saving...' : 'Add'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
