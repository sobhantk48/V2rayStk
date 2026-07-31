import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/profile.dart';
import 'latency_service.dart';

class LatencyState {
  const LatencyState({
    this.results = const <String, int?>{},
    this.errors = const <String, String>{},
    this.isTesting = false,
    this.done = 0,
    this.total = 0,
    this.lastRunAt,
  });

  final Map<String, int?> results;
  final Map<String, String> errors;
  final bool isTesting;
  final int done;
  final int total;
  final DateTime? lastRunAt;

  double get progress => total == 0 ? 0 : done / total;

  int? latencyFor(String profileId) => results[profileId];

  String? errorFor(String profileId) => errors[profileId];

  LatencyState copyWith({
    Map<String, int?>? results,
    Map<String, String>? errors,
    bool? isTesting,
    int? done,
    int? total,
    DateTime? lastRunAt,
  }) {
    return LatencyState(
      results: results ?? this.results,
      errors: errors ?? this.errors,
      isTesting: isTesting ?? this.isTesting,
      done: done ?? this.done,
      total: total ?? this.total,
      lastRunAt: lastRunAt ?? this.lastRunAt,
    );
  }
}

final Provider<LatencyService> latencyServiceProvider =
    Provider<LatencyService>((Ref ref) => const LatencyService());

final NotifierProvider<LatencyNotifier, LatencyState> latencyProvider =
    NotifierProvider<LatencyNotifier, LatencyState>(LatencyNotifier.new);

class LatencyNotifier extends Notifier<LatencyState> {
  @override
  LatencyState build() => const LatencyState();

  Future<List<LatencySample>> pingAll(List<Profile> profiles) async {
    if (state.isTesting || profiles.isEmpty) {
      return const <LatencySample>[];
    }

    final LatencyService service = ref.read(latencyServiceProvider);
    final Map<String, int?> results = <String, int?>{};
    final Map<String, String> errors = <String, String>{};

    state = LatencyState(
      isTesting: true,
      total: profiles.length,
      lastRunAt: state.lastRunAt,
    );

    final List<LatencySample> samples = await service.measureAll(
      profiles,
      onProgress: (LatencySample sample, int done, int total) {
        results[sample.profileId] = sample.latencyMs;
        if (sample.error != null) {
          errors[sample.profileId] = sample.error!;
        }
        state = state.copyWith(
          results: Map<String, int?>.from(results),
          errors: Map<String, String>.from(errors),
          done: done,
          total: total,
          isTesting: true,
        );
      },
    );

    state = state.copyWith(
      isTesting: false,
      done: profiles.length,
      total: profiles.length,
      lastRunAt: DateTime.now(),
    );
    return samples;
  }

  /// شناسهٔ سریع‌ترین پروفایل بر اساس آخرین تست.
  String? fastestProfileId() {
    String? best;
    int bestMs = 1 << 30;
    state.results.forEach((String id, int? value) {
      if (value != null && value < bestMs) {
        bestMs = value;
        best = id;
      }
    });
    return best;
  }

  void clear() {
    state = const LatencyState();
  }
}
