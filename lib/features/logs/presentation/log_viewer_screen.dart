import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// نمایش لاگ‌های نیتیو اپ (معادل adb logcat) داخل خود برنامه.
class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  static const MethodChannel _channel = MethodChannel('com.v2ray.stk/logs');

  final TextEditingController _filterController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<String> _lines = <String>[];
  bool _loading = false;
  bool _onlyVpn = true;
  String? _error;

  static const List<String> _vpnKeywords = <String>[
    'SingBox',
    'libbox',
    'sing-box',
    'V2rayVpn',
    'BoxPlatform',
    'AndroidRuntime',
    'FATAL',
    'Exception',
    'Error',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _filterController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final String raw = await _channel.invokeMethod<String>('dump') ?? '';
      final List<String> lines = raw
          .split('\n')
          .map((String line) => line.trimRight())
          .where((String line) => line.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _lines = lines;
        _loading = false;
      });
      _jumpToEnd();
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message ?? e.code;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _clear() async {
    try {
      await _channel.invokeMethod<bool>('clear');
    } catch (_) {
      // نادیده گرفتن؛ پاک‌کردن بافر روی همه دستگاه‌ها مجاز نیست
    }
    await _load();
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  List<String> get _visibleLines {
    final String query = _filterController.text.trim().toLowerCase();
    return _lines.where((String line) {
      if (_onlyVpn) {
        final bool matchesVpn = _vpnKeywords.any(
          (String keyword) =>
              line.toLowerCase().contains(keyword.toLowerCase()),
        );
        if (!matchesVpn && !line.startsWith('=====')) {
          return false;
        }
      }
      if (query.isEmpty) return true;
      return line.toLowerCase().contains(query);
    }).toList();
  }

  Color _colorFor(String line, ColorScheme scheme) {
    final String upper = line.toUpperCase();
    if (upper.contains('FATAL') ||
        upper.contains(' E/') ||
        upper.contains('EXCEPTION') ||
        upper.contains('ERROR')) {
      return scheme.error;
    }
    if (upper.contains(' W/') || upper.contains('WARN')) {
      return Colors.orange;
    }
    if (upper.contains('SINGBOX') || upper.contains('LIBBOX')) {
      return scheme.primary;
    }
    return scheme.onSurface;
  }

  Future<void> _copyAll() async {
    await Clipboard.setData(ClipboardData(text: _visibleLines.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('لاگ در کلیپ‌بورد کپی شد')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<String> lines = _visibleLines;

    return Scaffold(
      appBar: AppBar(
        title: const Text('لاگ‌ها'),
        actions: <Widget>[
          IconButton(
            tooltip: 'کپی',
            onPressed: lines.isEmpty ? null : _copyAll,
            icon: const Icon(Icons.copy_all),
          ),
          IconButton(
            tooltip: 'بازخوانی',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'پاک‌کردن',
            onPressed: _loading ? null : _clear,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _filterController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search),
                hintText: 'جستجو در لاگ‌ها',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          SwitchListTile(
            dense: true,
            value: _onlyVpn,
            onChanged: (bool value) => setState(() => _onlyVpn = value),
            title: const Text('فقط لاگ‌های VPN و خطاها'),
            subtitle: Text('${lines.length} خط نمایش داده می‌شود'),
          ),
          const Divider(height: 1),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'خطا در خواندن لاگ: $_error',
                style: TextStyle(color: scheme.error),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : lines.isEmpty
                    ? const Center(child: Text('لاگی برای نمایش نیست'))
                    : Scrollbar(
                        controller: _scrollController,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(12),
                          itemCount: lines.length,
                          itemBuilder: (BuildContext context, int index) {
                            final String line = lines[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: SelectableText(
                                line,
                                textDirection: TextDirection.ltr,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11.5,
                                  color: _colorFor(line, scheme),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
