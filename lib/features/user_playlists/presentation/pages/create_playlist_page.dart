import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:musee/features/user_playlists/domain/usecases/create_playlist.dart';
import 'package:musee/init_dependencies.dart';

class CreatePlaylistPage extends StatefulWidget {
  const CreatePlaylistPage({super.key});

  @override
  State<CreatePlaylistPage> createState() => _CreatePlaylistPageState();
}

class _CreatePlaylistPageState extends State<CreatePlaylistPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _nameFocus = FocusNode();

  int _step = 1; // 1 = type picker, 2 = detail form
  bool _isPublic = false;
  bool _isCollaborative = false;
  PlatformFile? _coverFile;
  bool _isLoading = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.06, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _nameFocus.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _goToStep2(bool collaborative) {
    setState(() {
      _isCollaborative = collaborative;
      _step = 2;
    });
    _animCtrl.forward(from: 0);
    // Auto-focus name field after animation
    Future.delayed(const Duration(milliseconds: 420), () {
      if (mounted) _nameFocus.requestFocus();
    });
  }

  void _goBack() {
    setState(() => _step = 1);
    _animCtrl.forward(from: 0);
  }

  Future<void> _pickCover() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (!mounted) return;
    if (res != null && res.files.isNotEmpty) {
      setState(() => _coverFile = res.files.first);
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final usecase = serviceLocator<CreatePlaylist>();
      final newPlaylist = await usecase(
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        isPublic: _isPublic,
        isCollaborative: _isCollaborative,
        coverPath: _coverFile?.path,
      );
      if (mounted) {
        context.pushReplacement('/playlists/${newPlaylist.playlistId}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Step 1: Type Picker ──────────────────────────────────────────────────
  Widget _buildStep1(ThemeData theme) {
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),

        // Wordmark / title
        RichText(
          text: TextSpan(
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              color: isDark ? Colors.white : cs.onSurface,
            ),
            children: [
              const TextSpan(text: 'New '),
              TextSpan(
                text: 'Playlist',
                style: TextStyle(color: cs.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Pick a type to get started.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: (isDark ? Colors.white : cs.onSurface).withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 32),

        // Standard card
        _TypeCard(
          icon: CupertinoIcons.music_note_list,
          title: 'Standard',
          subtitle: 'Personal space for your tracks. Keep it private or go public.',
          accentColor: cs.primary,
          isDark: isDark,
          onTap: () => _goToStep2(false),
        ),
        const SizedBox(height: 14),

        // Collaborative card
        _TypeCard(
          icon: CupertinoIcons.person_3_fill,
          title: 'Collaborative',
          subtitle: 'Invite friends to add and reorder tracks in real-time.',
          accentColor: isDark ? cs.secondary : const Color(0xFF765A51),
          isDark: isDark,
          onTap: () => _goToStep2(true),
        ),
      ],
    );
  }

  // ── Step 2: Detail Form ──────────────────────────────────────────────────
  Widget _buildStep2(ThemeData theme) {
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const BouncingScrollPhysics(),
        children: [
          const SizedBox(height: 12),

          // Type badge
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (_isCollaborative ? cs.secondary : cs.primary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (_isCollaborative ? cs.secondary : cs.primary)
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isCollaborative
                          ? CupertinoIcons.person_3_fill
                          : CupertinoIcons.music_note_list,
                      size: 13,
                      color: _isCollaborative ? cs.secondary : cs.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _isCollaborative ? 'Collaborative' : 'Standard',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _isCollaborative ? cs.secondary : cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Cover image picker — horizontal strip
          GestureDetector(
            onTap: _pickCover,
            child: Row(
              children: [
                // Thumbnail
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _coverFile != null
                          ? cs.primary.withValues(alpha: 0.4)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : cs.outline.withValues(alpha: 0.3)),
                      width: 1.5,
                    ),
                    image: _coverFile?.path != null
                        ? DecorationImage(
                            image: FileImage(File(_coverFile!.path!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _coverFile == null
                      ? Icon(
                          CupertinoIcons.photo,
                          size: 26,
                          color: isDark
                              ? Colors.white38
                              : cs.onSurfaceVariant.withValues(alpha: 0.5),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _coverFile == null
                            ? 'Add Cover Art'
                            : 'Cover Selected',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _coverFile == null
                            ? 'Optional — tap to pick an image'
                            : _coverFile!.name,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? Colors.white38
                              : cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  _coverFile == null
                      ? CupertinoIcons.chevron_right
                      : CupertinoIcons.checkmark_circle_fill,
                  size: 18,
                  color: _coverFile == null
                      ? (isDark
                          ? Colors.white24
                          : cs.outline.withValues(alpha: 0.4))
                      : cs.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Name field
          TextFormField(
            controller: _nameCtrl,
            focusNode: _nameFocus,
            textCapitalization: TextCapitalization.words,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: isDark ? Colors.white : cs.onSurface,
              fontWeight: FontWeight.w500,
            ),
            decoration: _inputDecoration(
              context: context,
              label: 'Playlist Name',
              hint: 'e.g. Late Night Drives',
              icon: Icons.title_rounded,
              isDark: isDark,
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: 14),

          // Description field
          TextFormField(
            controller: _descCtrl,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: isDark ? Colors.white : cs.onSurface,
            ),
            decoration: _inputDecoration(
              context: context,
              label: 'Description',
              hint: 'Optional — describe the vibe…',
              icon: Icons.notes_rounded,
              isDark: isDark,
            ),
          ),
          const SizedBox(height: 24),

          // Public visibility toggle
          _CreateToggleRow(
            icon: CupertinoIcons.globe,
            label: 'Public',
            subtitle: 'Anyone can search and listen',
            value: _isPublic,
            activeColor: cs.primary,
            isDark: isDark,
            onChanged: (v) => setState(() => _isPublic = v),
          ),
          const SizedBox(height: 32),

          // Submit CTA
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: _isLoading ? null : _submit,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: cs.onPrimary,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Create Playlist',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(CupertinoIcons.arrow_right, size: 16),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required BuildContext context,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(
        color: isDark
            ? Colors.white54
            : cs.onSurfaceVariant,
      ),
      hintStyle: TextStyle(
        color: isDark ? Colors.white24 : cs.onSurfaceVariant.withValues(alpha: 0.5),
      ),
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : cs.surfaceContainerHighest.withValues(alpha: 0.45),
      prefixIcon: Icon(icon,
          color: isDark
              ? Colors.white38
              : cs.onSurfaceVariant),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : cs.outline.withValues(alpha: 0.25),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.error),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Background colours per step/type
    final Color bgTop = _step == 1
        ? (isDark ? const Color(0xFF1A0D05) : const Color(0xFFFFF3EE))
        : _isCollaborative
            ? (isDark ? const Color(0xFF1A1005) : const Color(0xFFFFF8EE))
            : (isDark ? const Color(0xFF1A0D05) : const Color(0xFFFFF3EE));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0E0E0E) : cs.surface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: _step == 2
            ? IconButton(
                icon: Icon(
                  CupertinoIcons.back,
                  color: isDark ? Colors.white : cs.onSurface,
                ),
                onPressed: _goBack,
              )
            : IconButton(
                icon: Icon(
                  CupertinoIcons.xmark,
                  color: isDark ? Colors.white70 : cs.onSurface,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
        // Step indicator
        title: _StepDots(step: _step),
        centerTitle: true,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Subtle gradient wash at top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 280,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 450),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    bgTop,
                    (isDark
                        ? const Color(0xFF0E0E0E)
                        : cs.surface),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: _step == 1
                      ? _buildStep1(theme)
                      : _buildStep2(theme),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step dots indicator ────────────────────────────────────────────────────
class _StepDots extends StatelessWidget {
  final int step;
  const _StepDots({required this.step});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(2, (i) {
        final active = i + 1 == step;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active
                ? cs.primary
                : cs.onSurfaceVariant.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// ── Type selection card (Step 1) ──────────────────────────────────────────
class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final bool isDark;
  final VoidCallback onTap;

  const _TypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : cs.outline.withValues(alpha: 0.2),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor, size: 26),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.45)
                            : cs.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: isDark
                    ? Colors.white24
                    : cs.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Toggle row (Step 2) ───────────────────────────────────────────────────
class _CreateToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final Color activeColor;
  final bool isDark;
  final ValueChanged<bool> onChanged;

  const _CreateToggleRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.activeColor,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: value
              ? activeColor.withValues(alpha: isDark ? 0.10 : 0.07)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : cs.surfaceContainerHighest.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value
                ? activeColor.withValues(alpha: 0.35)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : cs.outline.withValues(alpha: 0.2)),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: value
                    ? activeColor.withValues(alpha: 0.15)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : cs.surfaceContainerHighest),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: value
                    ? activeColor
                    : (isDark ? Colors.white38 : cs.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: value
                          ? activeColor
                          : (isDark ? Colors.white : cs.onSurface),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? Colors.white38
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            CupertinoSwitch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: activeColor,
            ),
          ],
        ),
      ),
    );
  }
}
