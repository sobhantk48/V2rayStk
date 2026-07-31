import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// آمار لحظه‌ای ترافیک از Clash API هسته sing-box.
class TrafficSample {
  const TrafficSample({required this.uploadSpeed, required this.downloadSpeed});

  /// بایت بر ثانیه
  final int uploadSpeed;
  final int downloadSpeed;

  static const zero = TrafficSample(uploadSpeed: 0, downloadSpeed: 0);
}

/// مجموع مصرف از ابتدای اتصال.
class TotalTraffic {
  const TotalTraffic({required this.uploadTotal, required this.downloadTotal});

  final int uploadTotal;
  final int downloadTotal;

  static const zero = TotalTraffic(uploadTotal: 0, downloadTotal: 0);
}

/// خواندن آمار هسته از طریق external_controller.
///
/// هسته روی 127.0.0.1:9090 گوش می‌دهد، پس این ترافیک هرگز از TUN رد نمی‌شود
/// و حلقه‌ی روتینگ ایجاد نمی‌کند.
class ClashApiClient {
  ClashApiClient({
    this.host = '127.0.0.1',
    this.port = 9090,
    this.secret = '',
  });

  final String host;
  final int port;
  final String secret;

  WebSocket? _socket;
  StreamController<TrafficSample>? _controller;
  Timer? _retryTimer;
  bool _disposed = false;

  Map<String, String> get _headers =>
      secret.isEmpty ? const {} : {'Authorization': 'Bearer $secret'};

  /// جریان پیوسته سرعت آپلود/دانلود. در صورت قطع، خودش دوباره وصل می‌شود.
  Stream<TrafficSample> watchTraffic() {
    _controller ??= StreamController<TrafficSample>.broadcast(
      onListen: _connect,
      onCancel: _teardown,
    );
    return _controller!.stream;
  }

  Future<void> _connect() async {
    if (_disposed) return;
    try {
      final socket = await WebSocket.connect(
        'ws://$host:$port/traffic',
        headers: _headers,
      );
      _socket = socket;
      socket.listen(
        (dynamic raw) {
          final decoded = jsonDecode(raw as String) as Map<String, dynamic>;
          _controller?.add(
            TrafficSample(
              uploadSpeed: (decoded['up'] as num?)?.toInt() ?? 0,
              downloadSpeed: (decoded['down'] as num?)?.toInt() ?? 0,
            ),
          );
        },
        onError: (Object _) => _scheduleRetry(),
        onDone: _scheduleRetry,
        cancelOnError: true,
      );
    } on Object {
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    _socket = null;
    if (_disposed || _controller == null || !_controller!.hasListener) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 2), _connect);
  }

  /// مجموع مصرف تجمعی. برای per-proxy stats هم همین endpoint داده می‌دهد.
  Future<TotalTraffic> fetchTotals() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final request =
          await client.getUrl(Uri.parse('http://$host:$port/connections'));
      _headers.forEach(request.headers.set);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) return TotalTraffic.zero;
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      return TotalTraffic(
        uploadTotal: (decoded['uploadTotal'] as num?)?.toInt() ?? 0,
        downloadTotal: (decoded['downloadTotal'] as num?)?.toInt() ?? 0,
      );
    } on Object {
      return TotalTraffic.zero;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _teardown() async {
    _retryTimer?.cancel();
    _retryTimer = null;
    await _socket?.close();
    _socket = null;
  }

  Future<void> dispose() async {
    _disposed = true;
    await _teardown();
    await _controller?.close();
    _controller = null;
  }
}
