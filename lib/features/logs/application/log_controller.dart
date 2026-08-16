import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// یک خط لاگ که از سمت نیتیو می‌آید
@immutable
class LogEntry {
  const LogEntry({
    required this.id,
    required this.time,
    required this.level,
    required this.tag,
    required this.message,
  });

  factory LogEntry.fromMap(Map<dynamic, dynamic> map) {
    final int millis = (map['time'] as num?)?.toInt() ?? 0;
    return LogEntry(
      id: (map['id'] as num?)?.toInt() ?? 0,
      time: DateTime.fromMillisecondsSinceEpoch(
        millis == 0 ? DateTime.now().millisecondsSinceEpoch : millis,
      ),
      level: (map['level'] as String?) ?? 'info',
      tag: (map['tag'] as String?) ?? 'core',
      message: (map['message'] as String?) ?? '',
    );
  }

  final int id;
  final DateTime time;
  final String level;
  final String tag;
  final String message;

  String get timeLabel {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }

  String get plainLine => '[$timeLabel] ${level.toUpperCase()} ($tag) $message';
}

@immutable
class LogState {
  const LogState({
    this.entries = const <LogEntry>[],
    this.query = '',
    this.levels = const <String>{},
    this.paused = false,
    this.autoScroll = true,
  });

  final List<LogEntry> entries;
  final String query;

  /// اگر خالی باشد یعنی همهٔ سطوح نمایش داده شوند
  final Set<String> levels;
  final bool paused;
  final bool autoScroll;

  List<LogEntry> get visible {
    final String q = query.trim().toLowerCase();
    return entries.where((LogEntry e) {
      if (levels.isNotEmpty && !levels.contains(e.level)) {
        return false;
      }
      if (q.isEmpty) {
        return true;
      }
      return e.message.toLowerCase().contains(q) ||
          e.tag.toLowerCase().contains(q);
    }).toList();
  }

  LogState copyWith({
    List<LogEntry>? entries,
    String? query,
    Set<String>? levels,
    bool? paused,
    bool? autoScroll,
  }) {
    return LogState(
      entries: entries ?? this.entries,
      query: query ?? this.query,
      levels: levels ?? this.levels,
      paused: paused ?? this.paused,
      autoScroll: autoScroll ?? this.autoScroll,
    );
  }
}

/// پل ارتباطی لاگ با سمت نیتیو
class LogPlatformService {
  static const String _storeChannel = 'com.v2ray.stk/log_store';
  static const String _logChannel = 'com.v2ray.stk/logs';

  static const MethodChannel _method = MethodChannel(_storeChannel);
  static const EventChannel _events = EventChannel(_logChannel);

  Stream<LogEntry> stream() {
    return _events.receiveBroadcastStream().where((dynamic e) => e is Map).map(
          (dynamic e) => LogEntry.fromMap(e as Map<dynamic, dynamic>),
        );
  }

  Future<List<LogEntry>> snapshot() async {
    try {
      final List<dynamic>? raw =
          await _method.invokeMethod<List<dynamic>>('getLogs');
      if (raw == null) {
        return <LogEntry>[];
      }
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map(LogEntry.fromMap)
          .toList();
    } on MissingPluginException {
      return <LogEntry>[];
    } on PlatformException {
      return <LogEntry>[];
    }
  }

  Future<void> clear() async {
    try {
      await _method.invokeMethod<void>('clearLogs');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}

final Provider<LogPlatformService> logPlatformServiceProvider =
    Provider<LogPlatformService>((Ref ref) => LogPlatformService());

class LogController extends StateNotifier<LogState> {
  LogController(this._service) : super(const LogState()) {
    _init();
  }

  static const int _maxLines = 3000;

  final LogPlatformService _service;
  StreamSubscription<LogEntry>? _sub;
  bool _nativeStreamAlive = true;

  Future<void> _init() async {
    final List<LogEntry> initial = await _service.snapshot();
    if (!mounted) {
      return;
    }
    // merge نه replace: ممکن است پیش از تکمیل این await،
    // لاگ‌هایی از سمت Dart (مثل VpnController) append شده باشند.
    if (initial.isNotEmpty) {
      state = state.copyWith(
        entries: _trim(<LogEntry>[...initial, ...state.entries]),
      );
    }

    _sub = _service.stream().listen(
      (LogEntry entry) {
        if (state.paused) {
          return;
        }
        state = state.copyWith(
          entries: _trim(<LogEntry>[...state.entries, entry]),
        );
      },
      onError: (Object error, StackTrace _) {
        // کانال لاگ نیتیو StreamHandler ندارد؛ خطا را می‌بلعیم
        // تا بافر داخلی سالم بماند و unhandled error ندهد.
        _nativeStreamAlive = false;
        if (kDebugMode) {
          debugPrint('LogController: native log stream unavailable ($error)');
        }
      },
      cancelOnError: true,
    );
  }

  /// آیا استریم لاگ نیتیو زنده است؟ در نبودش UI باید فقط بافر Dart را نشان دهد.
  bool get nativeStreamAlive => _nativeStreamAlive;

  /// افزودن یک خط لاگ از سمت Dart (مثلا خطاهای VpnController).
  /// مستقل از logcat کار می‌کند و در حالت paused هم ثبت می‌شود.
  void append({
    required String level,
    required String tag,
    required String message,
  }) {
    final LogEntry entry = LogEntry(
      id: DateTime.now().microsecondsSinceEpoch,
      time: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
    );
    state = state.copyWith(
      entries: _trim(<LogEntry>[...state.entries, entry]),
    );
  }

  List<LogEntry> _trim(List<LogEntry> list) {
    if (list.length <= _maxLines) {
      return list;
    }
    return list.sublist(list.length - _maxLines);
  }

  void setQuery(String value) => state = state.copyWith(query: value);

  void toggleLevel(String level) {
    final Set<String> next = <String>{...state.levels};
    if (!next.remove(level)) {
      next.add(level);
    }
    state = state.copyWith(levels: next);
  }

  void clearFilters() => state = state.copyWith(
        levels: <String>{},
        query: '',
      );

  void togglePause() => state = state.copyWith(paused: !state.paused);

  void toggleAutoScroll() =>
      state = state.copyWith(autoScroll: !state.autoScroll);

  Future<void> refresh() async {
    final List<LogEntry> list = await _service.snapshot();
    if (!mounted) {
      return;
    }
    if (list.isEmpty) {
      // کانال نیتیو چیزی نداد؛ بافر داخلی را پاک نمی‌کنیم.
      return;
    }
    // id لاگ‌های Dart از microsecondsSinceEpoch است و با idهای نیتیو تلاقی نمی‌کند.
    final Set<int> nativeIds = list.map((LogEntry e) => e.id).toSet();
    final List<LogEntry> merged = <LogEntry>[
      ...list,
      ...state.entries.where((LogEntry e) => !nativeIds.contains(e.id)),
    ]..sort((LogEntry a, LogEntry b) => a.time.compareTo(b.time));
    state = state.copyWith(entries: _trim(merged));
  }

  Future<void> clear() async {
    await _service.clear();
    if (!mounted) {
      return;
    }
    state = state.copyWith(entries: <LogEntry>[]);
  }

  String exportText() =>
      state.visible.map((LogEntry e) => e.plainLine).join('\n');

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final StateNotifierProvider<LogController, LogState> logControllerProvider =
    StateNotifierProvider<LogController, LogState>((Ref ref) {
  return LogController(ref.watch(logPlatformServiceProvider));
});
