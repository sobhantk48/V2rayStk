import 'dart:async';

import 'package:flutter/services.dart';

/// Bridge between Flutter and Android VpnService (Platform Channel).
class VpnBridge {
  VpnBridge._();
  static final VpnBridge instance = VpnBridge._();

  static const MethodChannel _method =
      MethodChannel('com.v2raystk.v2ray_stk/vpn');
  static const EventChannel _events =
      EventChannel('com.v2raystk.v2ray_stk/vpn_events');

  Stream<VpnEvent>? _statusStream;

  /// Ask Android for VPN permission dialog if needed.
  Future<bool> prepare() async {
    final ok = await _method.invokeMethod<bool>('prepare');
    return ok ?? false;
  }

  /// Start VPN skeleton with raw config string (sing-box JSON later).
  Future<void> startVpn({String config = ''}) async {
    await _method.invokeMethod<void>('startVpn', <String, dynamic>{
      'config': config,
    });
  }

  Future<void> stopVpn() async {
    await _method.invokeMethod<void>('stopVpn');
  }

  Future<String> getStatus() async {
    final status = await _method.invokeMethod<String>('getStatus');
    return status ?? 'disconnected';
  }

  Future<VpnEvent> getStats() async {
    final raw = await _method.invokeMethod<Map<dynamic, dynamic>>('getStats');
    return VpnEvent.fromMap(raw ?? const <dynamic, dynamic>{});
  }

  /// Live status stream from native side.
  Stream<VpnEvent> get statusStream {
    return _statusStream ??= _events
        .receiveBroadcastStream()
        .map((dynamic event) {
          if (event is Map) {
            return VpnEvent.fromMap(event);
          }
          return const VpnEvent(status: VpnStatus.disconnected);
        })
        .asBroadcastStream();
  }
}

enum VpnStatus {
  disconnected,
  connecting,
  connected,
  error,
}

class VpnEvent {
  final VpnStatus status;
  final int upload;
  final int download;
  final String? message;

  const VpnEvent({
    required this.status,
    this.upload = 0,
    this.download = 0,
    this.message,
  });

  factory VpnEvent.fromMap(Map<dynamic, dynamic> map) {
    final raw = (map['status'] ?? 'disconnected').toString().toLowerCase();
    final status = switch (raw) {
      'connected' => VpnStatus.connected,
      'connecting' => VpnStatus.connecting,
      'error' => VpnStatus.error,
      _ => VpnStatus.disconnected,
    };

    return VpnEvent(
      status: status,
      upload: _asInt(map['upload']),
      download: _asInt(map['download']),
      message: map['message']?.toString(),
    );
  }

  bool get isConnected => status == VpnStatus.connected;
  bool get isConnecting => status == VpnStatus.connecting;

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
