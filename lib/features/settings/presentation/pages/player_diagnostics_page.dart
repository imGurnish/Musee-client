import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:musee/core/player/playback_diagnostics.dart';
import 'package:musee/core/player/player_cubit.dart';
import 'package:musee/core/player/player_diagnostics_info.dart';
import 'package:musee/init_dependencies.dart';

/// Dev-only live view of the player's internal state — current playback quality,
/// network estimate, buffer health, source, queue and a tail of the playback
/// log. Polls [PlayerCubit.diagnostics] on a timer so values update live while a
/// track is playing.
class PlayerDiagnosticsPage extends StatefulWidget {
  const PlayerDiagnosticsPage({super.key});

  @override
  State<PlayerDiagnosticsPage> createState() => _PlayerDiagnosticsPageState();
}

class _PlayerDiagnosticsPageState extends State<PlayerDiagnosticsPage> {
  final PlayerCubit _player = serviceLocator<PlayerCubit>();

  Timer? _timer;
  PlayerDiagnosticsInfo? _info;
  String _logTail = 'Loading logs…';
  int _tick = 0;

  static const _logTailLines = 120;

  @override
  void initState() {
    super.initState();
    _refresh();
    _loadLogs();
    _timer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      _refresh();
      // Reload the log tail less often — file I/O every tick is wasteful.
      if (_tick++ % 4 == 0) _loadLogs();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _info = _player.diagnostics);
  }

  Future<void> _loadLogs() async {
    final logs = await PlaybackDiagnostics.readLogs();
    if (!mounted) return;
    final lines = logs.trimRight().split('\n');
    final tail = lines.length > _logTailLines
        ? lines.sublist(lines.length - _logTailLines)
        : lines;
    setState(() => _logTail = tail.join('\n'));
  }

  Future<void> _copyAll() async {
    final info = _info;
    if (info == null) return;
    final report =
        '${info.toReportString()}\n\n── Recent Logs ──\n$_logTail';
    await Clipboard.setData(ClipboardData(text: report));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Diagnostics copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final topPadding = MediaQuery.of(context).padding.top;
    final info = _info;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          // ── Gradient header ──
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withValues(alpha: 0.15),
                  colorScheme.secondary.withValues(alpha: 0.08),
                  colorScheme.surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: 'Back',
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy_all_rounded),
                      tooltip: 'Copy diagnostics',
                      onPressed: _copyAll,
                    ),
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          _LiveDot(),
                          SizedBox(width: 6),
                          Text('LIVE',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Player Diagnostics',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Live playback, quality, network & buffer state',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // ── Body ──
          Expanded(
            child: info == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    children: [
                      _statusChips(info),
                      const SizedBox(height: 14),
                      _nowPlayingCard(info),
                      const SizedBox(height: 12),
                      _qualityCard(info),
                      const SizedBox(height: 12),
                      _networkCard(info),
                      const SizedBox(height: 12),
                      _bufferCard(info),
                      const SizedBox(height: 12),
                      _queueCard(info),
                      const SizedBox(height: 12),
                      _logCard(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ── Sections ──

  Widget _statusChips(PlayerDiagnosticsInfo i) {
    final chips = <Widget>[
      _StateChip('Playing', i.playing, Colors.green),
      _StateChip('Buffering', i.buffering, Colors.orange),
      _StateChip('Resolving URL', i.resolvingUrl, Colors.amber),
      _StateChip('Transitioning', i.isTransitioning, Colors.blueGrey),
      _StateChip('User-paused', i.userPausedIntent, Colors.redAccent),
      _StateChip('Online', i.isOnline, Colors.teal),
    ];
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _nowPlayingCard(PlayerDiagnosticsInfo i) {
    return _Section(
      title: 'Now Playing',
      icon: Icons.music_note_rounded,
      children: [
        _kv('Title', i.title ?? '—'),
        _kv('Artist', i.artist ?? '—'),
        _kv('Album', i.album ?? '—'),
        _kv('Track ID', i.trackId ?? '—', mono: true),
        if (i.errorMessage != null)
          _kv('Error', i.errorMessage!, valueColor: Colors.redAccent),
      ],
    );
  }

  Widget _qualityCard(PlayerDiagnosticsInfo i) {
    return _Section(
      title: 'Quality & Source',
      icon: Icons.high_quality_rounded,
      children: [
        _kv('Setting', i.streamingQualitySetting),
        _kv(
          'Streaming at',
          i.streamingTargetKbps != null
              ? '${i.streamingTargetKbps} kbps'
              : '— (master / local file)',
          valueColor: i.streamingTargetKbps != null ? Colors.green : null,
        ),
        _kv(
          'Auto would pick now',
          i.recommendedKbps != null ? '${i.recommendedKbps} kbps' : '—',
        ),
        _kv(
          'Decoded bitrate (mpv)',
          i.decodedAudioBitrateKbps != null
              ? '${i.decodedAudioBitrateKbps!.toStringAsFixed(0)} kbps'
              : '—',
        ),
        _kv(
          'Format',
          [
            if (i.sampleRateHz != null)
              '${(i.sampleRateHz! / 1000).toStringAsFixed(1)} kHz',
            if (i.channels != null) '${i.channels} ch',
          ].join(' · ').ifEmptyDash(),
        ),
        _kv('Source', i.playbackSource),
        if (i.playbackUrl != null)
          _kv('URL', i.playbackUrl!, mono: true, maxLines: 3),
      ],
    );
  }

  Widget _networkCard(PlayerDiagnosticsInfo i) {
    return _Section(
      title: 'Network',
      icon: Icons.network_check_rounded,
      children: [
        _kv('Connection', i.connectionType),
        _kv('Online', i.isOnline ? 'yes' : 'no'),
        _kv(
          'Measured throughput',
          i.estimatedThroughputKbps != null
              ? '${i.estimatedThroughputKbps!.toStringAsFixed(0)} kbps'
              : '— (no sample yet)',
        ),
        _kv('Active background caches', '${i.activeBackgroundCaches}'),
      ],
    );
  }

  Widget _bufferCard(PlayerDiagnosticsInfo i) {
    final ahead = i.bufferAhead;
    final aheadColor = ahead.inSeconds >= 10
        ? Colors.green
        : ahead.inSeconds >= 3
            ? Colors.orange
            : Colors.redAccent;
    return _Section(
      title: 'Buffer & Position',
      icon: Icons.av_timer_rounded,
      children: [
        _kv('Position', '${_fmt(i.position)} / ${_fmt(i.duration)}'),
        _kv('Buffered ahead', _fmtSecs(ahead), valueColor: aheadColor),
        _kv('Volume', '${(i.volume * 100).round()}%'),
        _kv('Platform audio init', i.platformInitialized ? 'yes' : 'no'),
      ],
    );
  }

  Widget _queueCard(PlayerDiagnosticsInfo i) {
    return _Section(
      title: 'Queue',
      icon: Icons.queue_music_rounded,
      children: [
        _kv('Index',
            '${i.currentIndex} / ${i.queueLength == 0 ? 0 : i.queueLength - 1}'),
        _kv('Length', '${i.queueLength}'),
        _kv('Shuffle', i.shuffleEnabled ? 'on' : 'off'),
        _kv('Repeat', i.repeatMode),
      ],
    );
  }

  Widget _logCard() {
    final colorScheme = Theme.of(context).colorScheme;
    return _Section(
      title: 'Recent Logs',
      icon: Icons.terminal_rounded,
      trailing: IconButton(
        icon: const Icon(Icons.refresh_rounded, size: 20),
        tooltip: 'Reload logs',
        onPressed: _loadLogs,
      ),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: SelectionArea(
            child: Text(
              _logTail,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Row helper ──

  Widget _kv(
    String label,
    String value, {
    bool mono = false,
    Color? valueColor,
    int maxLines = 2,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                fontFamily: mono ? 'monospace' : null,
                color: valueColor ?? colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(Duration v) {
    final m = v.inMinutes;
    final s = v.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static String _fmtSecs(Duration v) {
    final s = (v.inMilliseconds / 1000).toStringAsFixed(1);
    return '${s}s';
  }
}

// ── Small widgets ──

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip(this.label, this.active, this.color);

  final String label;
  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active
            ? color.withValues(alpha: 0.16)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active
              ? color.withValues(alpha: 0.5)
              : colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? color : colorScheme.outline,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: active ? color : colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.3, end: 1.0).animate(_c),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.green,
        ),
      ),
    );
  }
}

extension _DashIfEmpty on String {
  String ifEmptyDash() => trim().isEmpty ? '—' : this;
}
