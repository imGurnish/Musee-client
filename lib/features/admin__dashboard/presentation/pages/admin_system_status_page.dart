import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:musee/features/admin__dashboard/data/models/admin_system_status_models.dart';
import 'package:musee/features/listening_history/data/repositories/listening_history_repository.dart';

class AdminSystemStatusPage extends StatefulWidget {
  const AdminSystemStatusPage({super.key});

  @override
  State<AdminSystemStatusPage> createState() => _AdminSystemStatusPageState();
}

class _AdminSystemStatusPageState extends State<AdminSystemStatusPage> {
  late final ListeningHistoryRepository _repository;
  SystemStatusResponse? _status;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = GetIt.I<ListeningHistoryRepository>();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final status = await _repository.getSystemStatus();
      setState(() {
        _status = status;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Status & Diagnostics'),
        elevation: 0,
        actions: [
          if (!_isLoading)
            IconButton(
              tooltip: 'Refresh metrics',
              onPressed: _fetchStatus,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchStatus,
        child: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading && _status == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Gathering system telemetry...'),
          ],
        ),
      );
    }

    if (_error != null && _status == null) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.report_problem_rounded,
                  size: 64, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'Telemetry Collection Failed',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _fetchStatus,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry Connection'),
              ),
            ],
          ),
        ),
      );
    }

    final data = _status!;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp & Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.network_ping_rounded,
                      size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'Last updated: ${_formatDateTime(data.timestamp)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if (_isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Resource Gauges Row
          Text(
            'Physical Resources',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildResourceGauges(theme, data.system),
          const SizedBox(height: 32),

          // Database & Entity Status
          Text(
            'Database Statistics',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildDatabaseGrid(theme, data.database),
          const SizedBox(height: 32),

          // Storage Statistics
          Text(
            'Blob Storage Usage',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildStorageOverview(theme, data.azure, data.supabaseStorage),
          const SizedBox(height: 32),

          // Environment & Hardware Specifications
          Text(
            'Server Specifications',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildServerSpecsCard(theme, data.system),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildResourceGauges(ThemeData theme, SystemResources system) {
    if (system.error != null) {
      return Card(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.15)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: theme.colorScheme.error),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Failed to fetch system host stats: ${system.error}',
                  style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final mem = system.memory;
    final disk = system.disk;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final int crossCount = width > 700 ? 3 : 1;

        if (crossCount == 3) {
          return Row(
            children: [
              Expanded(
                child: _GaugeCard(
                  title: 'Host Memory',
                  pct: mem.hostUsagePct / 100.0,
                  detail: '${_formatBytes(mem.hostUsed)} of ${_formatBytes(mem.hostTotal)}',
                  color: Colors.indigo,
                  icon: Icons.memory_rounded,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _GaugeCard(
                  title: 'Process Memory',
                  // Node heap vs rss relative representation
                  pct: mem.processHeapTotal > 0 ? (mem.processHeapUsed / mem.processHeapTotal) : 0.0,
                  detail: 'Heap Used: ${_formatBytes(mem.processHeapUsed)}\nRSS: ${_formatBytes(mem.processRss)}',
                  color: Colors.teal,
                  icon: Icons.developer_board_rounded,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: disk != null
                    ? _GaugeCard(
                        title: 'Server Storage',
                        pct: disk.usagePct / 100.0,
                        detail: '${_formatBytes(disk.used)} of ${_formatBytes(disk.total)}',
                        color: Colors.amber.shade800,
                        icon: Icons.storage_rounded,
                      )
                    : const _GaugeCard(
                        title: 'Server Storage',
                        pct: 0.0,
                        detail: 'Unavailable or drive permissions denied',
                        color: Colors.grey,
                        icon: Icons.storage_rounded,
                      ),
              ),
            ],
          );
        } else {
          return Column(
            children: [
              _GaugeCard(
                title: 'Host Memory',
                pct: mem.hostUsagePct / 100.0,
                detail: '${_formatBytes(mem.hostUsed)} of ${_formatBytes(mem.hostTotal)}',
                color: Colors.indigo,
                icon: Icons.memory_rounded,
              ),
              const SizedBox(height: 16),
              _GaugeCard(
                title: 'Process Memory',
                pct: mem.processHeapTotal > 0 ? (mem.processHeapUsed / mem.processHeapTotal) : 0.0,
                detail: 'Heap: ${_formatBytes(mem.processHeapUsed)} / ${_formatBytes(mem.processHeapTotal)}\nRSS: ${_formatBytes(mem.processRss)}',
                color: Colors.teal,
                icon: Icons.developer_board_rounded,
              ),
              const SizedBox(height: 16),
              disk != null
                  ? _GaugeCard(
                      title: 'Server Storage',
                      pct: disk.usagePct / 100.0,
                      detail: '${_formatBytes(disk.used)} of ${_formatBytes(disk.total)}',
                      color: Colors.amber.shade800,
                      icon: Icons.storage_rounded,
                    )
                  : const _GaugeCard(
                      title: 'Server Storage',
                      pct: 0.0,
                      detail: 'Unavailable or drive permissions denied',
                      color: Colors.grey,
                      icon: Icons.storage_rounded,
                    ),
            ],
          );
        }
      },
    );
  }

  Widget _buildDatabaseGrid(ThemeData theme, DatabaseCounts db) {
    if (db.error != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Database counts error: ${db.error}'),
        ),
      );
    }

    final tables = db.tables;
    if (tables.isEmpty) {
      return const Center(child: Text('No tables returned.'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 700 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
          ),
          itemCount: tables.length,
          itemBuilder: (context, index) {
            final t = tables[index];
            final cleanName = _capitalizeTable(t.table);
            final iconInfo = _getTableIcon(t.table);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(iconInfo.$1, color: iconInfo.$2, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          cleanName,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _formatNumber(t.count),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStorageOverview(
      ThemeData theme, AzureMetrics azure, SupabaseStorageMetrics supabaseStorage) {
    return Column(
      children: [
        if (azure.enabled)
          _buildAzureStorageCard(theme, azure)
        else
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const ListTile(
              leading: Icon(Icons.cloud_off_rounded, color: Colors.grey),
              title: Text('Azure Blob Storage is disabled'),
              subtitle: Text('Configure AZURE_STORAGE_CONNECTION_STRING in backend env to enable'),
            ),
          ),
        const SizedBox(height: 16),
        if (supabaseStorage.enabled)
          _buildSupabaseStorageCard(theme, supabaseStorage)
        else
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const ListTile(
              leading: Icon(Icons.cloud_off_rounded, color: Colors.grey),
              title: Text('Supabase Object Storage is disabled'),
              subtitle: Text('Check your Supabase project parameters or storage policies'),
            ),
          ),
      ],
    );
  }

  Widget _buildAzureStorageCard(ThemeData theme, AzureMetrics az) {
    if (az.error != null) {
      return Card(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.1),
        child: ListTile(
          leading: Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
          title: const Text('Azure Blob Storage error'),
          subtitle: Text(az.error!),
        ),
      );
    }

    final hls = az.byPrefix.hls;
    final audio = az.byPrefix.audio;
    final other = az.byPrefix.other;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.network(
                'https://uxwing.com/wp-content/themes/uxwing/download/brands-and-social-media/microsoft-azure-icon.png',
                width: 24,
                height: 24,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.cloud_queue_rounded, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Azure Storage',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Container: ${az.container ?? "media"}',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatBytes(az.bytes),
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800, color: Colors.blue.shade700),
                  ),
                  Text(
                    '${az.blobs} blobs',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 28),
          _buildStorageRow(theme, 'HLS Segments', 'hls/', hls.count, hls.bytes, Colors.blue.shade300),
          const SizedBox(height: 12),
          _buildStorageRow(theme, 'Raw Audio Tracks', 'audio/', audio.count, audio.bytes, Colors.green.shade400),
          const SizedBox(height: 12),
          _buildStorageRow(theme, 'Miscellaneous assets', 'other/', other.count, other.bytes, Colors.amber.shade600),
        ],
      ),
    );
  }

  Widget _buildSupabaseStorageCard(ThemeData theme, SupabaseStorageMetrics sup) {
    if (sup.error != null) {
      return Card(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.1),
        child: ListTile(
          leading: Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
          title: const Text('Supabase Storage error'),
          subtitle: Text(sup.error!),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.network(
                'https://uxwing.com/wp-content/themes/uxwing/download/brands-and-social-media/supabase-icon.png',
                width: 24,
                height: 24,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.cloud_circle_rounded, color: Colors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Supabase Storage',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${sup.buckets.length} active buckets',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatBytes(sup.totals.bytes),
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800, color: Colors.green.shade700),
                  ),
                  Text(
                    '${sup.totals.objects} objects',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
          if (sup.buckets.isNotEmpty) ...[
            const Divider(height: 28),
            ...sup.buckets.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _buildStorageRow(theme, 'Bucket: ${b.bucket}', b.bucket, b.objects, b.bytes, Colors.teal),
                )),
          ]
        ],
      ),
    );
  }

  Widget _buildStorageRow(ThemeData theme, String title, String tag, int count, int bytes, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                '$tag • $count items',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Text(
          _formatBytes(bytes),
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildServerSpecsCard(ThemeData theme, SystemResources system) {
    if (system.error != null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          _buildSpecRow(theme, 'Host Node Name', system.hostname, Icons.dns_rounded),
          const Divider(height: 20),
          _buildSpecRow(theme, 'Operating System', '${_capitalizeOS(system.platform)} (${system.release})', Icons.terminal_rounded),
          const Divider(height: 20),
          _buildSpecRow(theme, 'Architecture', '${system.arch} (${system.cpuCores} cores)', Icons.architecture_rounded),
          const Divider(height: 20),
          _buildSpecRow(theme, 'Processor Model', system.cpuModel, Icons.settings_input_hdmi_rounded),
          const Divider(height: 20),
          _buildSpecRow(theme, 'Physical Host Uptime', _formatDuration(system.uptime), Icons.power_rounded),
          const Divider(height: 20),
          _buildSpecRow(theme, 'Node.js Process Uptime', _formatDuration(system.processUptime), Icons.watch_later_rounded),
        ],
      ),
    );
  }

  Widget _buildSpecRow(ThemeData theme, String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Utilities & Formatters
  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${pad(local.month)}-${pad(local.day)} ${pad(local.hour)}:${pad(local.minute)}:${pad(local.second)}';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(1)} ${suffixes[i]}';
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.round());
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    
    if (days > 0) {
      return '$days d $hours h $minutes m';
    } else if (hours > 0) {
      return '$hours h $minutes m';
    } else {
      return '$minutes m';
    }
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  String _capitalizeTable(String rawName) {
    return rawName.split('_').map((str) {
      if (str.isEmpty) return '';
      return str[0].toUpperCase() + str.substring(1);
    }).join(' ');
  }

  String _capitalizeOS(String platform) {
    if (platform == 'win32') return 'Microsoft Windows';
    if (platform == 'darwin') return 'macOS / Darwin';
    if (platform == 'linux') return 'Linux Kernel';
    if (platform.isEmpty) return 'Unknown';
    return platform[0].toUpperCase() + platform.substring(1);
  }

  (IconData, Color) _getTableIcon(String table) {
    switch (table) {
      case 'users':
        return (Icons.people, Colors.blue);
      case 'artists':
        return (Icons.mic, Colors.deepPurple);
      case 'albums':
        return (Icons.album, Colors.amber.shade700);
      case 'tracks':
        return (Icons.music_note, Colors.green);
      case 'playlists':
        return (Icons.queue_music, Colors.teal);
      case 'followers':
        return (Icons.favorite, Colors.redAccent);
      case 'album_artists':
        return (Icons.link_rounded, Colors.orange);
      case 'track_artists':
        return (Icons.swap_horiz_rounded, Colors.purple);
      case 'playlist_tracks':
        return (Icons.checklist_rounded, Colors.blueGrey);
      default:
        return (Icons.table_rows_rounded, Colors.indigo);
    }
  }
}

class _GaugeCard extends StatelessWidget {
  final String title;
  final double pct;
  final String detail;
  final Color color;
  final IconData icon;

  const _GaugeCard({
    required this.title,
    required this.pct,
    required this.detail,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  value: pct.clamp(0.0, 1.0),
                  backgroundColor: color.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  strokeWidth: 8,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Icon(icon, color: color, size: 24),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${(pct * 100).toStringAsFixed(1)}% Used',
                    style: TextStyle(
                      color: isDark ? color.withValues(alpha: 0.9) : color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
