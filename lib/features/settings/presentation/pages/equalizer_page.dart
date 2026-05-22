import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:musee/core/equalizer/eq_presets.dart';
import 'package:musee/core/equalizer/headphone_service.dart';
import 'package:musee/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:musee/features/settings/presentation/cubit/settings_state.dart';

void _noop() {}

class EqualizerPage extends StatefulWidget {
  const EqualizerPage({super.key});

  @override
  State<EqualizerPage> createState() => _EqualizerPageState();
}

class _EqualizerPageState extends State<EqualizerPage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, settings) {
            final eqEnabled = settings.equalizerEnabled;

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _EqHeader()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 16),
                      _buildMasterToggle(context, cs, settings),
                      const SizedBox(height: 24),
                      IgnorePointer(
                        ignoring: !eqEnabled,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: eqEnabled ? 1.0 : 0.4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildPresetsSection(context, cs, settings),
                              const SizedBox(height: 24),
                              _buildBassSection(context, cs, settings),
                              const SizedBox(height: 24),
                              _buildSurroundSection(context, cs, settings),
                            ],
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ─── Master Toggle Card ────────────────────────────────────────────────────

  Widget _buildMasterToggle(
      BuildContext context, ColorScheme cs, SettingsState settings) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: settings.equalizerEnabled
                  ? cs.primary.withValues(alpha: 0.15)
                  : cs.onSurface.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.power_settings_new_rounded,
              color: settings.equalizerEnabled ? cs.primary : cs.onSurfaceVariant,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Equalizer & Sound Effects',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                ),
                const SizedBox(height: 1),
                Text(
                  settings.equalizerEnabled ? 'Active' : 'Bypassed',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: settings.equalizerEnabled ? cs.primary : cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          Switch(
            value: settings.equalizerEnabled,
            activeThumbColor: cs.primary,
            onChanged: (val) {
              context.read<SettingsCubit>().setEqualizerEnabled(val);
            },
          ),
        ],
      ),
    );
  }

  // ─── Preset Chips Section ───────────────────────────────────────────────────

  Widget _buildPresetsSection(
      BuildContext context, ColorScheme cs, SettingsState settings) {
    return _SoundSection(
      title: 'EQ Preset',
      icon: Icons.graphic_eq_rounded,
      iconColor: cs.primary,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Graphical Equalizer Board
            _EqBoard(
              bands: settings.equalizerBands,
              color: cs.primary,
              onChanged: (newBands) {
                context.read<SettingsCubit>().setEqualizerBands(newBands);
              },
            ),
            const SizedBox(height: 16),
            // Preset chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...kEqPresetOrder.map((key) {
                  final isActive = settings.equalizerPreset == key;
                  return _PresetChip(
                    label: kEqPresetLabels[key]!,
                    isActive: isActive,
                    onTap: () =>
                        context.read<SettingsCubit>().setEqualizerPreset(key),
                  );
                }),
                if (settings.equalizerPreset == 'custom')
                  const _PresetChip(
                    label: 'Custom',
                    isActive: true,
                    onTap: _noop,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Bass Section ───────────────────────────────────────────────────────────

  Widget _buildBassSection(
      BuildContext context, ColorScheme cs, SettingsState settings) {
    return _SoundSection(
      title: 'Bass Enhancement',
      icon: Icons.speaker_rounded,
      iconColor: cs.secondary,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SliderRow(
              icon: Icons.volume_up_rounded,
              iconColor: cs.secondary,
              label: 'Bass',
              value: settings.bassLevel.toDouble(),
              min: 0,
              max: 100,
              divisions: 100,
              activeColor: cs.secondary,
              displayValue: '${settings.bassLevel}%',
              onChanged: (v) =>
                  context.read<SettingsCubit>().setBassLevel(v.round()),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Boosts low frequencies for a punchier sound.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Surround Section ───────────────────────────────────────────────────────

  Widget _buildSurroundSection(
      BuildContext context, ColorScheme cs, SettingsState settings) {
    return StreamBuilder<bool>(
      stream: HeadphoneService.instance.isConnectedStream,
      initialData: HeadphoneService.instance.isConnected,
      builder: (context, snapshot) {
        final headphonesConnected = snapshot.data ?? false;

        return _SoundSection(
          title: 'Surround Sound',
          icon: Icons.surround_sound_rounded,
          iconColor: cs.tertiary,
          trailing: headphonesConnected ? _buildActiveBadge(cs) : null,
          child: headphonesConnected
              ? _buildSurroundActive(context, cs, settings)
              : _buildSurroundInactive(context, cs),
        );
      },
    );
  }

  Widget _buildActiveBadge(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.tertiary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.tertiary.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.headphones_rounded,
            color: cs.tertiary,
            size: 11,
          ),
          const SizedBox(width: 5),
          Text(
            'ACTIVE',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: cs.tertiary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurroundActive(
      BuildContext context, ColorScheme cs, SettingsState settings) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SliderRow(
            icon: Icons.spatial_audio_rounded,
            iconColor: cs.tertiary,
            label: 'Stereo Widening',
            value: settings.surroundLevel.toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            activeColor: cs.tertiary,
            displayValue: '${settings.surroundLevel}%',
            onChanged: (v) =>
                context.read<SettingsCubit>().setSurroundLevel(v.round()),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Widens the stereo field for a more immersive listening experience.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurroundInactive(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.headphones_outlined,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connect earphones to enable',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Surround Sound activates automatically when earphones or headphones are connected.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section Container ────────────────────────────────────────────────────────

class _SoundSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget? trailing;
  final Widget child;

  const _SoundSection({
    required this.title,
    required this.icon,
    required this.iconColor,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ],
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: cs.outlineVariant.withValues(alpha: 0.2),
          ),
          child,
        ],
      ),
    );
  }
}

// ─── Preset Chip ─────────────────────────────────────────────────────────────

class _PresetChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: isActive ? cs.primary : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: isActive
                  ? cs.primary
                  : cs.outlineVariant.withValues(alpha: 0.4),
              width: isActive ? 1.5 : 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? cs.onPrimary : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── EQ Band Visualizer ────────────────────────────────────────────────────────

class _EqBoard extends StatelessWidget {
  final List<double> bands;
  final Color color;
  final ValueChanged<List<double>> onChanged;

  const _EqBoard({
    required this.bands,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
        );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // dB Axis labels
          Padding(
            padding: const EdgeInsets.only(bottom: 24, top: 22),
            child: SizedBox(
              height: 120,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('+12', style: textStyle),
                  Text('0', style: textStyle),
                  Text('-12', style: textStyle),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Sliders
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (index) {
                final dbValue = bands.length > index ? bands[index] : 0.0;
                return _EqBandSlider(
                  frequency: kEqBandLabels[index],
                  value: dbValue,
                  activeColor: color,
                  onChanged: (newVal) {
                    final newBands = List<double>.from(bands);
                    while (newBands.length <= index) {
                      newBands.add(0.0);
                    }
                    newBands[index] = double.parse(newVal.toStringAsFixed(1));
                    onChanged(newBands);
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _EqBandSlider extends StatelessWidget {
  final String frequency;
  final double value;
  final Color activeColor;
  final ValueChanged<double> onChanged;

  const _EqBandSlider({
    required this.frequency,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final formattedValue =
        value > 0 ? '+${value.toStringAsFixed(1)}' : value.toStringAsFixed(1);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // dB value at top
        Text(
          formattedValue,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: activeColor,
          ),
        ),
        const SizedBox(height: 8),
        // Slider container
        SizedBox(
          height: 120,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.5,
              activeTrackColor: activeColor,
              inactiveTrackColor: cs.outlineVariant.withValues(alpha: 0.35),
              thumbColor: activeColor,
              overlayColor: activeColor.withValues(alpha: 0.15),
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 7,
                elevation: 2,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: RotatedBox(
              quarterTurns: 3,
              child: Slider(
                value: value,
                min: -12.0,
                max: 12.0,
                divisions: 24, // snapping to 1.0 dB steps
                onChanged: onChanged,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Frequency label at bottom
        Text(
          frequency,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

// ─── Slider Row ───────────────────────────────────────────────────────────────

class _SliderRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final Color activeColor;
  final String displayValue;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.activeColor,
    required this.displayValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const Spacer(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Text(
                displayValue,
                key: ValueKey(displayValue),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: activeColor,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: activeColor,
            inactiveTrackColor: cs.outlineVariant.withValues(alpha: 0.4),
            thumbColor: activeColor,
            overlayColor: activeColor.withValues(alpha: 0.15),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// ─── Gradient Header ──────────────────────────────────────────────────────────

class _EqHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.15),
            cs.tertiary.withValues(alpha: 0.08),
            cs.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 20),
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
              Icon(
                Icons.equalizer_rounded,
                color: cs.primary.withValues(alpha: 0.5),
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Equalizer & Sound',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Shape your audio to your preference',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
