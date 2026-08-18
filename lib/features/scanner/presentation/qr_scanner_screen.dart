import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../l10n/strings.dart';

/// اسکنر QR برای واردات کانفیگ.
/// با Navigator.pop مقدار متنی خوانده‌شده (trim شده) را برمی‌گرداند.
///
/// مدیریت چرخه‌ی حیات دوربین:
///  - رفتن به پس‌زمینه  -> stop()
///  - بازگشت به پیش‌زمینه -> start()
///  - خروج از صفحه       -> stop() سپس dispose()
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
  );

  bool _handled = false;
  bool _torchOn = false;
  bool _running = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // در mobile_scanner 5.x با controller دستی، شروع دوربین بر عهده‌ی ماست.
    _startCamera();
  }

  Future<void> _startCamera() async {
    if (_disposed || _running) {
      return;
    }
    _running = true;
    try {
      await _controller.start();
    } catch (_) {
      _running = false;
    }
  }

  Future<void> _stopCamera() async {
    if (!_running) {
      return;
    }
    _running = false;
    try {
      await _controller.stop();
    } catch (_) {
      // اگر قبلاً متوقف شده باشد، بی‌صدا رد می‌شویم.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_disposed) {
      return;
    }
    switch (state) {
      case AppLifecycleState.resumed:
        _startCamera();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _stopCamera();
        break;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    // ترتیب مهم است: اول توقف دوربین، بعد آزادسازی کنترلر.
    _controller.stop().catchError((Object _) {}).whenComplete(() {
      _controller.dispose();
    });
    super.dispose();
  }

  Future<void> _finish(String? value) async {
    await _stopCamera();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(value);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || _disposed || !mounted) {
      return;
    }
    for (final Barcode barcode in capture.barcodes) {
      final String? raw = barcode.rawValue;
      if (raw != null && raw.trim().isNotEmpty) {
        _handled = true;
        _finish(raw.trim());
        return;
      }
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      if (mounted) {
        setState(() => _torchOn = !_torchOn);
      }
    } catch (_) {
      // بعضی دستگاه‌ها فلاش ندارند؛ بی‌صدا رد می‌شویم.
    }
  }

  @override
  Widget build(BuildContext context) {
    final Strings strings = Strings.of(context);
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        // با دکمه‌ی بازگشت سیستم هم دوربین بسته شود.
        _stopCamera();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(strings.scanQr),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _finish(null),
          ),
          actions: <Widget>[
            IconButton(
              tooltip: strings.torch,
              icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
              onPressed: _toggleTorch,
            ),
            IconButton(
              tooltip: strings.switchCamera,
              icon: const Icon(Icons.cameraswitch_outlined),
              onPressed: () => _controller.switchCamera(),
            ),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (
                BuildContext context,
                MobileScannerException error,
              ) {
                return _ScannerError(
                  message:
                      error.errorCode == MobileScannerErrorCode.permissionDenied
                          ? strings.cameraPermissionDenied
                          : strings.cameraError,
                );
              },
            ),
            IgnorePointer(
              child: Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white70, width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 40,
              child: Text(
                strings.scanQrHint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white54,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
