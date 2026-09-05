import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:musee/core/equalizer/eq_presets.dart';
import 'package:musee/features/cast/presentation/bloc/cast_bloc.dart';
import 'package:musee/features/cast/presentation/bloc/cast_event.dart';
import 'package:musee/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:musee/features/settings/presentation/cubit/settings_state.dart';

class RemoteEqPanel extends StatelessWidget {
  const RemoteEqPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settings) {
        final eqEnabled = settings.equalizerEnabled;

        return Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & master toggle
              Row(
                children: [
                  Icon(Icons.equalizer_rounded, color: cs.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Remote Equalizer',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Switch(
                    value: eqEnabled,
                    onChanged: (val) {
                      context.read<CastBloc>().add(RemoteToggleEqEvent(enabled: val));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              IgnorePointer(
                ignoring: !eqEnabled,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: eqEnabled ? 1.0 : 0.4,
                  child: Column(
                    children: [
                      // Preset chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: kEqPresetOrder.map((key) {
                            final isActive = settings.equalizerPreset == key;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(kEqPresetLabels[key] ?? key),
                                selected: isActive,
                                onSelected: (sel) {
                                  if (sel) {
                                    final bands = kEqPresets[key] ?? [0.0, 0.0, 0.0, 0.0, 0.0];
                                    context.read<CastBloc>().add(RemoteSetEqBandsEvent(bands: bands));
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Bass Slider
                      Row(
                        children: [
                          Icon(Icons.speaker_rounded, size: 16, color: cs.secondary),
                          const SizedBox(width: 6),
                          Text('Bass', style: theme.textTheme.bodySmall),
                          const Spacer(),
                          Text('${settings.bassLevel}%', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Slider(
                        value: settings.bassLevel.toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 20,
                        activeColor: cs.secondary,
                        onChanged: (v) {
                          context.read<CastBloc>().add(RemoteSetBassEvent(level: v.round()));
                        },
                      ),
                      // Surround Slider
                      Row(
                        children: [
                          Icon(Icons.spatial_audio_rounded, size: 16, color: cs.tertiary),
                          const SizedBox(width: 6),
                          Text('Surround Widening', style: theme.textTheme.bodySmall),
                          const Spacer(),
                          Text('${settings.surroundLevel}%', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Slider(
                        value: settings.surroundLevel.toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 20,
                        activeColor: cs.tertiary,
                        onChanged: (v) {
                          context.read<CastBloc>().add(RemoteSetSurroundEvent(level: v.round()));
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
