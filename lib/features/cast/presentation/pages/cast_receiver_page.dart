import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:musee/core/player/player_cubit.dart';
import 'package:musee/core/player/player_state.dart';
import 'package:musee/features/cast/domain/entities/cast_session_state.dart';
import 'package:musee/features/cast/presentation/bloc/cast_bloc.dart';
import 'package:musee/features/cast/presentation/bloc/cast_event.dart';
import 'package:musee/features/cast/presentation/bloc/cast_state.dart';
import 'package:musee/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:musee/features/settings/presentation/cubit/settings_state.dart';
import 'package:musee/core/common/device/device_detector.dart';
import 'package:musee/core/common/navigation/routes.dart';
import 'package:go_router/go_router.dart';
import 'package:musee/init_dependencies.dart';

class CastReceiverPage extends StatefulWidget {
  final String sessionId;

  const CastReceiverPage({
    super.key,
    required this.sessionId,
  });

  @override
  State<CastReceiverPage> createState() => _CastReceiverPageState();
}

class _CastReceiverPageState extends State<CastReceiverPage> {
  late final String _fallbackCode;
  bool _forceShowQr = false;

  @override
  void initState() {
    super.initState();
    // Pre-generate a 6-character code immediately so UI is never empty
    final rng = Random();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    final letters = List.generate(4, (_) => chars[rng.nextInt(chars.length)]).join();
    final digits = (rng.nextInt(90) + 10).toString();
    _fallbackCode = '$letters$digits';

    // Dispatch receiver initialization with auto-detected device name
    try {
      final bloc = serviceLocator<CastBloc>();
      final deviceName = DeviceDetector.detectedDisplayName;
      if (widget.sessionId.isNotEmpty) {
        bloc.add(JoinAsReceiverEvent(
          sessionId: widget.sessionId,
          deviceName: deviceName,
        ));
      } else {
        bloc.add(StartReceiverSessionEvent(deviceName: deviceName));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // Safe provider access
    CastBloc castBloc;
    try {
      castBloc = context.read<CastBloc>();
    } catch (_) {
      castBloc = serviceLocator<CastBloc>();
    }

    PlayerCubit playerCubit;
    try {
      playerCubit = context.read<PlayerCubit>();
    } catch (_) {
      playerCubit = serviceLocator<PlayerCubit>();
    }

    SettingsCubit settingsCubit;
    try {
      settingsCubit = context.read<SettingsCubit>();
    } catch (_) {
      settingsCubit = serviceLocator<SettingsCubit>();
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final bg = isDark ? const Color(0xFF0F0F12) : const Color(0xFFF9F9FB);
    final cardBg = isDark ? const Color(0xFF1C1C22) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E24);
    final subtextColor = isDark ? const Color(0xFFA0A0AB) : const Color(0xFF6E6E77);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: BlocBuilder<CastBloc, CastState>(
          bloc: castBloc,
          builder: (context, castState) {
            // Determine active pairing code
            String code = _fallbackCode;
            String? errorMessage;
            CastSessionState? remoteState;

            if (castState is CastActive) {
              remoteState = castState.remoteState;
              if (castState.session.sessionCode != null) {
                code = castState.session.sessionCode!;
              }
            } else if (castState is CastError) {
              errorMessage = castState.message;
            }

            final hasWebOrigin = kIsWeb && Uri.base.hasAuthority && !Uri.base.origin.contains('localhost');
            final pairUrl = hasWebOrigin
                ? '${Uri.base.origin}/cast?code=$code'
                : 'musee://cast?code=$code';

            return BlocBuilder<PlayerCubit, PlayerViewState>(
              bloc: playerCubit,
              builder: (context, playerState) {
                final track = playerState.track;
                final isPlaying = playerState.playing;

                // Resolve track info with fallback to remoteState synced from controller
                final title = (track != null && track.title.isNotEmpty && track.title != 'Unknown Title')
                    ? track.title
                    : (remoteState?.currentTrackTitle ?? '');

                final artist = (track != null && track.artist.isNotEmpty && track.artist != 'Unknown Artist')
                    ? track.artist
                    : (remoteState?.currentTrackArtist ?? 'Controlled from phone');

                final album = track?.album ?? remoteState?.currentTrackAlbum;
                final imageUrl = (track?.imageUrl != null && track!.imageUrl!.isNotEmpty)
                    ? track.imageUrl
                    : remoteState?.currentTrackImageUrl;

                final hasTrack = title.isNotEmpty ||
                    (remoteState?.currentTrackId != null && remoteState!.currentTrackId!.isNotEmpty);

                final effectiveDuration = playerState.duration.inMilliseconds > 0
                    ? playerState.duration
                    : ((remoteState?.currentTrackDurationMs ?? 0) > 0
                        ? Duration(milliseconds: remoteState!.currentTrackDurationMs!)
                        : Duration.zero);

                if (!hasTrack || _forceShowQr) {
                  return _buildPairingView(
                    context,
                    theme,
                    cs,
                    bg,
                    cardBg,
                    textColor,
                    subtextColor,
                    code,
                    pairUrl,
                    errorMessage: errorMessage,
                    hasTrack: hasTrack,
                  );
                }

                return _buildNowPlayingView(
                  context,
                  theme,
                  cs,
                  settingsCubit,
                  castBloc,
                  playerState,
                  title: title,
                  artist: artist,
                  album: album,
                  imageUrl: imageUrl,
                  effectiveDuration: effectiveDuration,
                  isPlaying: isPlaying,
                  code: code,
                  bg: bg,
                  textColor: textColor,
                  subtextColor: subtextColor,
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Pairing View (Always Visible Hero Screen)
  // ---------------------------------------------------------------------------

  Widget _buildPairingView(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    Color bg,
    Color cardBg,
    Color textColor,
    Color subtextColor,
    String code,
    String pairUrl, {
    String? errorMessage,
    required bool hasTrack,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      DeviceDetector.isCar
                          ? Icons.directions_car_rounded
                          : DeviceDetector.isTv
                              ? Icons.tv_rounded
                              : Icons.cast_connected_rounded,
                      size: 16,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${DeviceDetector.detectedDisplayName.toUpperCase()} READY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              Text(
                'Connect Your Phone',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Scan this QR code with your phone camera or enter the code in the Musee app.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: subtextColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // QR Code
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: pairUrl,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                  errorStateBuilder: (cxt, err) {
                    return const SizedBox(
                      width: 200,
                      height: 200,
                      child: Center(
                        child: Icon(Icons.qr_code_2_rounded, size: 80, color: Colors.black54),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // 6-Character Code
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OR ENTER CODE',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          code,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: 'Copy Code',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copied to clipboard!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Status Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Listening for connection...',
                    style: TextStyle(
                      fontSize: 12,
                      color: subtextColor,
                    ),
                  ),
                ],
              ),

              // DB Notice if migration has not been run yet
              if (errorMessage != null && errorMessage.contains('PGRST205')) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Run docs/supabase-cast-migration.sql in Supabase SQL editor to enable sync.',
                          style: TextStyle(fontSize: 11, color: textColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (hasTrack) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Back to Now Playing'),
                  onPressed: () => setState(() => _forceShowQr = false),
                ),
              ],
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.apps_rounded, size: 16),
                label: const Text('Switch to Full Web App'),
                onPressed: () {
                  DeviceDetector.setDeviceMode('standard');
                  context.go(Routes.dashboard);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Fullscreen Now Playing View
  // ---------------------------------------------------------------------------

  Widget _buildNowPlayingView(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    SettingsCubit settingsCubit,
    CastBloc castBloc,
    PlayerViewState playerState, {
    required String title,
    required String artist,
    required String? album,
    required String? imageUrl,
    required Duration effectiveDuration,
    required bool isPlaying,
    required String code,
    required Color bg,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Stack(
      children: [
        // Background Ambient Glow
        if (imageUrl != null)
          Positioned.fill(
            child: Opacity(
              opacity: 0.15,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),

        // Main Content
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 28),
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          DeviceDetector.isCar
                              ? Icons.directions_car_rounded
                              : DeviceDetector.isTv
                                  ? Icons.tv_rounded
                                  : Icons.cast_connected_rounded,
                          size: 16,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${DeviceDetector.detectedDisplayName.toUpperCase()} · $code',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.qr_code_rounded, size: 18),
                    label: const Text('Pair Device'),
                    onPressed: () => setState(() => _forceShowQr = true),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Exit Receiver',
                    onPressed: () {
                      castBloc.add(const EndCastSessionEvent());
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        DeviceDetector.setDeviceMode('standard');
                        context.go(Routes.dashboard);
                      }
                    },
                  ),
                ],
              ),

              const Spacer(),

              // Middle: Artwork + Track Details
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Artwork
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      width: 260,
                      height: 260,
                      color: cs.primary.withValues(alpha: 0.1),
                      child: imageUrl != null
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Icon(
                                Icons.music_note_rounded,
                                size: 80,
                                color: cs.primary,
                              ),
                            )
                          : Icon(
                              Icons.music_note_rounded,
                              size: 80,
                              color: cs.primary,
                            ),
                    ),
                  ),
                  const SizedBox(width: 56),

                  // Metadata
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title.isNotEmpty ? title : 'Ready to stream',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          artist.isNotEmpty ? artist : 'Controlled from phone',
                          style: TextStyle(
                            fontSize: 20,
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (album != null && album.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            album,
                            style: TextStyle(
                              fontSize: 14,
                              color: subtextColor,
                            ),
                            maxLines: 1,
                          ),
                        ],
                        const SizedBox(height: 24),

                        // Badges: EQ & Volume
                        BlocBuilder<SettingsCubit, SettingsState>(
                          bloc: settingsCubit,
                          builder: (context, settings) {
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildBadge(
                                  cs,
                                  playerState.volume <= 0
                                      ? Icons.volume_off_rounded
                                      : playerState.volume < 0.5
                                          ? Icons.volume_down_rounded
                                          : Icons.volume_up_rounded,
                                  'VOL ${(playerState.volume * 100).round()}%',
                                ),
                                _buildBadge(
                                  cs,
                                  Icons.graphic_eq_rounded,
                                  'EQ: ${settings.equalizerPreset.toUpperCase()}',
                                ),
                                if (settings.bassLevel > 0)
                                  _buildBadge(
                                    cs,
                                    Icons.speaker_rounded,
                                    'BASS +${settings.bassLevel}%',
                                  ),
                                if (settings.surroundLevel > 0)
                                  _buildBadge(
                                    cs,
                                    Icons.spatial_audio_rounded,
                                    'SURROUND +${settings.surroundLevel}%',
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Timeline
              Column(
                children: [
                  LinearProgressIndicator(
                    value: (effectiveDuration.inMilliseconds > 0)
                        ? (playerState.position.inMilliseconds /
                                effectiveDuration.inMilliseconds)
                            .clamp(0.0, 1.0)
                        : 0.0,
                    backgroundColor: cs.primary.withValues(alpha: 0.15),
                    color: cs.primary,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(playerState.position),
                        style: TextStyle(fontSize: 12, color: subtextColor),
                      ),
                      Row(
                        children: [
                          Icon(
                            isPlaying
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                            size: 18,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isPlaying ? 'PLAYING' : 'PAUSED',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: cs.primary,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _formatDuration(effectiveDuration),
                        style: TextStyle(fontSize: 12, color: subtextColor),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(ColorScheme cs, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: cs.primary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) {
      return '$h:$m:$s';
    }
    return '$m:$s';
  }
}
