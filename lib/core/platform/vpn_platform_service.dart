import 'package:flutter/services.dart';

import '../constants/app_constants.dart';

class VpnPlatformService {
  VpnPlatformService()
      : _channel = const MethodChannel(AppConstants.vpnChannelName);

  final MethodChannel _channel;

  Future<String> getStatus() async {
    final String? result = await _channel.invokeMethod<String>('getStatus');
    return result ?? 'disconnected';
  }

  Future<void> connect() async {
    await _channel.invokeMethod<void>('connect');
  }

  Future<void> disconnect() async {
    await _channel.invokeMethod<void>('disconnect');
  }
}
