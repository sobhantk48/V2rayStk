import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/platform/log_service.dart';

class NativeLogScreen extends StatefulWidget {
  const NativeLogScreen({super.key});

  @override
  State<NativeLogScreen> createState() => _NativeLogScreenState();
}

class _NativeLogScreenState extends State<NativeLogScreen> {
  List<String> _lines = [];
  bool _onlyVpn = true;
  bool _loading = false;
  bool _autoScroll = true;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final lines = await NativeLogService.dump(onlyVpn: _onlyVpn);
    if (!mounted) return;
    setState(() {
      _lines = lines;
      _loading = false;
    });
    if (_autoScroll) _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _clear() async {
    await NativeLogService.clear();
    await _load();
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: _lines.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('لاگ‌ها کپی شد')),
    );
  }

  Color _lineColor(String line) {
    final l = line.toLowerCase();
    if (l.contains('error') || l.contains('e/')) {
      return Colors.red.shade300;
    }
    if (l.contains('warn') || l.contains('w/')) {
      return Colors.orange.shade300;
    }
    if (l.contains('info') || l.contains('i/')) {
      return Colors.lightBlue.shade300;
    }
    return Colors.grey.shade300;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Native Logs', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // فیلتر VPN
          Row(
            children: [
              const Text('فقط VPN',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              Switch(
                value: _onlyVpn,
                onChanged: (v) {
                  setState(() => _onlyVpn = v);
                  _load();
                },
                activeThumbColor: Colors.greenAccent,
              ),
            ],
          ),
          // Auto scroll
          IconButton(
            icon: Icon(
              Icons.vertical_align_bottom,
              color: _autoScroll ? Colors.greenAccent : Colors.white54,
            ),
            tooltip: 'Auto Scroll',
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
          IconButton(
            icon: const Icon(Icons.copy, color: Colors.white70),
            tooltip: 'کپی همه',
            onPressed: _copy,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'پاک کردن',
            onPressed: _clear,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'بازخوانی',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.greenAccent))
          : _lines.isEmpty
              ? const Center(
                  child: Text('لاگی یافت نشد',
                      style: TextStyle(color: Colors.white54)),
                )
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(8),
                  itemCount: _lines.length,
                  itemBuilder: (ctx, i) {
                    final line = _lines[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Text(
                        line,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: _lineColor(line),
                          height: 1.4,
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: _load,
        backgroundColor: const Color(0xFF21262D),
        child: const Icon(Icons.refresh, color: Colors.greenAccent),
      ),
    );
  }
}
