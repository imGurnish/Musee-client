import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import '../bloc/admin_logs_cubit.dart';
import '../bloc/admin_logs_state.dart';
import '../../data/models/log_entry_model.dart';

class AdminLogsPage extends StatelessWidget {
  const AdminLogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminLogsCubit>(
      create: (context) => GetIt.I<AdminLogsCubit>()..startStreaming(),
      child: const _AdminLogsView(),
    );
  }
}

class _AdminLogsView extends StatefulWidget {
  const _AdminLogsView();

  @override
  State<_AdminLogsView> createState() => _AdminLogsViewState();
}

class _AdminLogsViewState extends State<_AdminLogsView> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _autoScroll = true;
  bool _showJumpToBottom = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final isAtBottom = maxScroll - currentScroll <= 60;

    if (isAtBottom && !_autoScroll) {
      setState(() {
        _autoScroll = true;
        _showJumpToBottom = false;
      });
    } else if (!isAtBottom && _autoScroll) {
      setState(() {
        _autoScroll = false;
        _showJumpToBottom = true;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      setState(() {
        _autoScroll = true;
        _showJumpToBottom = false;
      });
    }
  }

  Color _getLevelColor(String level) {
    switch (level.toUpperCase()) {
      case 'ERROR':
        return Colors.red.shade600;
      case 'WARN':
        return Colors.amber.shade700;
      case 'DEBUG':
        return Colors.purple.shade400;
      case 'INFO':
      default:
        return Colors.blue.shade500;
    }
  }

  Color _getStatusColor(AdminLogsStatus status) {
    switch (status) {
      case AdminLogsStatus.connected:
        return Colors.green;
      case AdminLogsStatus.connecting:
        return Colors.amber;
      case AdminLogsStatus.error:
        return Colors.red;
      case AdminLogsStatus.disconnected:
        return Colors.grey;
    }
  }

  String _getStatusText(AdminLogsStatus status) {
    switch (status) {
      case AdminLogsStatus.connected:
        return 'Streaming Live';
      case AdminLogsStatus.connecting:
        return 'Connecting...';
      case AdminLogsStatus.error:
        return 'Connection Error';
      case AdminLogsStatus.disconnected:
        return 'Disconnected';
    }
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _exportLogs(BuildContext context, List<LogEntry> logs) {
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No logs to export')),
      );
      return;
    }

    final buffer = StringBuffer();
    for (final log in logs) {
      final timeStr = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(log.timestamp);
      buffer.writeln('[$timeStr] [${log.level}] ${log.message}');
    }

    // Share/copy file output
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All logs copied as text (ready to export/save)'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 850;

    return BlocConsumer<AdminLogsCubit, AdminLogsState>(
      listener: (context, state) {
        if (_autoScroll && state.logs.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        }
      },
      builder: (context, state) {
        final filtered = state.filteredLogs;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Server Logs',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final color = _getStatusColor(state.status);
                        return Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                            boxShadow: state.status == AdminLogsStatus.connected ||
                                    state.status == AdminLogsStatus.connecting
                                ? [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.6),
                                      blurRadius: 4 * _pulseController.value,
                                      spreadRadius: 2 * _pulseController.value,
                                    )
                                  ]
                                : null,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getStatusText(state.status),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _getStatusColor(state.status),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Clear view display',
                icon: const Icon(Icons.delete_sweep_rounded),
                onPressed: () => context.read<AdminLogsCubit>().clearDisplay(),
              ),
              IconButton(
                tooltip: 'Export logs text',
                icon: const Icon(Icons.download_rounded),
                onPressed: () => _exportLogs(context, filtered),
              ),
              IconButton(
                tooltip: state.status == AdminLogsStatus.connected
                    ? 'Pause stream'
                    : 'Resume stream',
                icon: Icon(
                  state.status == AdminLogsStatus.connected
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_filled_rounded,
                ),
                onPressed: () {
                  final cubit = context.read<AdminLogsCubit>();
                  if (state.status == AdminLogsStatus.connected) {
                    cubit.stopStreaming();
                  } else {
                    cubit.startStreaming();
                  }
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Filter Toolbar
              _buildToolbar(context, state, isDark),
              
              // Console logs list + Detail split pane
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logs list console
                    Expanded(
                      flex: 2,
                      child: Stack(
                        children: [
                          _buildConsoleList(context, filtered, state, isDark),
                          // Floating Jump To Bottom
                          if (_showJumpToBottom)
                            Positioned(
                              bottom: 16,
                              right: 16,
                              child: FloatingActionButton.small(
                                tooltip: 'Scroll to bottom',
                                onPressed: _scrollToBottom,
                                child: const Icon(Icons.arrow_downward_rounded),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Details Panel (Wide Screen)
                    if (isWide && state.selectedLog != null)
                      Container(
                        width: 320,
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: theme.colorScheme.outline.withValues(alpha: 0.15),
                            ),
                          ),
                        ),
                        child: _buildDetailsPanel(context, state.selectedLog!, isDark),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolbar(BuildContext context, AdminLogsState state, bool isDark) {
    final theme = Theme.of(context);
    final levels = ['DEBUG', 'INFO', 'WARN', 'ERROR'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C0F12) : Colors.grey.shade100,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Search input
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Filter logs message/level...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              context.read<AdminLogsCubit>().updateSearchQuery('');
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) => context.read<AdminLogsCubit>().updateSearchQuery(val),
                ),
              ),
              const SizedBox(width: 8),
              // Autoscroll toggle button - collapse text on narrow screens
              MediaQuery.of(context).size.width > 500
                  ? TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _autoScroll = !_autoScroll;
                          if (_autoScroll) _scrollToBottom();
                        });
                      },
                      icon: Icon(
                        _autoScroll
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        size: 20,
                      ),
                      label: const Text('Auto-scroll'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Toggle auto-scroll',
                      onPressed: () {
                        setState(() {
                          _autoScroll = !_autoScroll;
                          if (_autoScroll) _scrollToBottom();
                        });
                      },
                      icon: Icon(
                        _autoScroll
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        size: 22,
                      ),
                    ),
            ],
          ),
          const SizedBox(height: 8),
          // Level Filters Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: levels.map((lvl) {
                final isSelected = state.levelFilters.contains(lvl);
                final color = _getLevelColor(lvl);
                final count = state.logs.where((l) => l.level == lvl).length;

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$lvl ($count)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected
                                ? (isDark ? Colors.white : Colors.black87)
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (_) => context.read<AdminLogsCubit>().toggleLevelFilter(lvl),
                    selectedColor: color.withValues(alpha: 0.15),
                    checkmarkColor: color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected
                            ? color.withValues(alpha: 0.5)
                            : theme.colorScheme.outline.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsoleList(
      BuildContext context, List<LogEntry> logs, AdminLogsState state, bool isDark) {
    if (logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.terminal_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No logs found matching filters',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return Container(
      color: isDark ? const Color(0xFF0C0F12) : const Color(0xFFFAFAFB),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final log = logs[index];
          final isSelected = state.selectedLog == log;
          final timeStr = DateFormat('HH:mm:ss.SSS').format(log.timestamp);
          final levelColor = _getLevelColor(log.level);

          return Material(
            color: isSelected
                ? levelColor.withValues(alpha: 0.08)
                : Colors.transparent,
            child: InkWell(
              onTap: () {
                final cubit = context.read<AdminLogsCubit>();
                cubit.selectLog(isSelected ? null : log);
                
                // On mobile, click triggers a bottom drawer
                final isWide = MediaQuery.of(context).size.width > 850;
                if (!isWide && !isSelected) {
                  _showMobileDetailsSheet(context, log, isDark);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Micro-timestamp
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Small Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      width: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: levelColor.withValues(alpha: 0.1),
                        border: Border.all(color: levelColor.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        log.level,
                        style: TextStyle(
                          fontSize: 9,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: levelColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Log Message
                    Expanded(
                      child: Text(
                        log.message,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                          height: 1.3,
                        ),
                        maxLines: isSelected ? 12 : 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailsPanel(BuildContext context, LogEntry log, bool isDark) {
    final theme = Theme.of(context);
    final levelColor = _getLevelColor(log.level);
    final formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(log.timestamp);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Log Details',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => context.read<AdminLogsCubit>().selectLog(null),
              )
            ],
          ),
          const Divider(height: 20),

          // Metadata row
          Text(
            'TIMESTAMP',
            style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 4),
          Text(
            formattedTime,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
          const SizedBox(height: 16),

          Text(
            'LEVEL',
            style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: levelColor.withValues(alpha: 0.1),
              border: Border.all(color: levelColor.withValues(alpha: 0.25)),
            ),
            child: Text(
              log.level,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: levelColor,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Message
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MESSAGE',
                style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey.shade500),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    tooltip: 'Copy message text',
                    onPressed: () => _copyToClipboard(context, log.message, 'Message'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.code_rounded, size: 16),
                    tooltip: 'Copy full JSON',
                    onPressed: () => _copyToClipboard(
                      context,
                      json.encode(log.toJson()),
                      'Log JSON',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            log.message,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  void _showMobileDetailsSheet(BuildContext context, LogEntry log, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (scrollContext, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: _buildDetailsPanel(context, log, isDark),
            );
          },
        );
      },
    );
  }
}
