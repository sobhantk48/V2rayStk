import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/log_controller.dart';

class LogScreen extends ConsumerStatefulWidget {
  const LogScreen({super.key});

  @override
  ConsumerState<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends ConsumerState<LogScreen> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _search = TextEditingController();

  static const List<String> _levels = <String>[
    'fatal',
    'error',
    'warn',
    'info',
    'debug',
    'trace',
  ];

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  bool get _fa => Localizations.localeOf(context).languageCode == 'fa';

  String _t(String fa, String en) => _fa ? fa : en;

  void _scrollToEnd() {
    if (!_scroll.hasClients) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Color _levelColor(String level, ColorScheme scheme) {
    switch (level) {
      case 'fatal':
        return const Color(0xFFB00020);
      case 'error':
        return scheme.error;
      case 'warn':
        return const Color(0xFFE8A33D);
      case 'debug':
        return const Color(0xFF7E57C2);
      case 'trace':
        return scheme.outline;
      default:
        return scheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final LogState state = ref.watch(logControllerProvider);
    final LogController controller = ref.read(logControllerProvider.notifier);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<LogEntry> visible = state.visible;

    if (state.autoScroll && !state.paused) {
      _scrollToEnd();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('لاگ‌ها', 'Logs')),
        actions: <Widget>[
          IconButton(
            tooltip: state.paused
                ? _t('ادامه', 'Resume')
                : _t('توقف موقت', 'Pause'),
            icon: Icon(state.paused ? Icons.play_arrow : Icons.pause),
            onPressed: controller.togglePause,
          ),
          IconButton(
            tooltip: _t('اسکرول خودکار', 'Auto scroll'),
            icon: Icon(
              state.autoScroll
                  ? Icons.vertical_align_bottom
                  : Icons.vertical_align_center,
            ),
            onPressed: controller.toggleAutoScroll,
          ),
          IconButton(
            tooltip: _t('کپی', 'Copy'),
            icon: const Icon(Icons.copy_all),
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: controller.exportText()),
              );
              if (!context.mounted) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_t('در کلیپ‌بورد کپی شد', 'Copied')),
                ),
              );
            },
          ),
          IconButton(
            tooltip: _t('پاک کردن', 'Clear'),
            icon: const Icon(Icons.delete_outline),
            onPressed: controller.clear,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _search,
              onChanged: controller.setQuery,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                hintText: _t('جستجو در لاگ‌ها', 'Search logs'),
                border: const OutlineInputBorder(),
                suffixIcon: state.query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          controller.setQuery('');
                        },
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: <Widget>[
                for (final String level in _levels)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: FilterChip(
                      label: Text(level.toUpperCase()),
                      selected: state.levels.contains(level),
                      onSelected: (_) => controller.toggleLevel(level),
                      selectedColor: _levelColor(level, scheme).withValues(
                        alpha: 0.2,
                      ),
                    ),
                  ),
                if (state.levels.isNotEmpty || state.query.isNotEmpty)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: ActionChip(
                      avatar: const Icon(Icons.filter_alt_off, size: 18),
                      label: Text(_t('حذف فیلترها', 'Reset')),
                      onPressed: () {
                        _search.clear();
                        controller.clearFilters();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: <Widget>[
                Text(
                  '${visible.length} / ${state.entries.length}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const Spacer(),
                if (state.paused)
                  Text(
                    _t('متوقف شده', 'Paused'),
                    style: TextStyle(color: scheme.error),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _t(
                          'لاگی وجود ندارد. یک‌بار اتصال را امتحان کن تا لاگ هسته اینجا بیاید.',
                          'No logs yet. Try connecting to see core logs here.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: visible.length,
                    itemBuilder: (BuildContext context, int index) {
                      final LogEntry e = visible[index];
                      final Color color = _levelColor(e.level, scheme);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              width: 3,
                              height: 16,
                              margin: const EdgeInsetsDirectional.only(
                                end: 8,
                                top: 2,
                              ),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            Expanded(
                              child: SelectableText.rich(
                                TextSpan(
                                  children: <InlineSpan>[
                                    TextSpan(
                                      text: '${e.timeLabel} ',
                                      style: TextStyle(
                                        color: scheme.outline,
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                      ),
                                    ),
                                    TextSpan(
                                      text: '${e.level.toUpperCase()} ',
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                      ),
                                    ),
                                    TextSpan(
                                      text: e.message,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                textDirection: TextDirection.ltr,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
