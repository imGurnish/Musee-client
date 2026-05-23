import 'dart:io';
import 'dart:ui';
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

class _CreatePlaylistPageState extends State<CreatePlaylistPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  int _step = 1;
  bool _isPublic = false;
  bool _isCollaborative = false;
  PlatformFile? _coverFile;
  bool _isLoading = false;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _animController.dispose();
    super.dispose();
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

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? theme.colorScheme.error : theme.colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _isLoading = true);

    try {
      final createPlaylistUsecase = serviceLocator<CreatePlaylist>();
      final newPlaylist = await createPlaylistUsecase(
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        isPublic: _isPublic,
        isCollaborative: _isCollaborative,
        coverPath: _coverFile?.path,
      );

      _showSnack('Playlist "${newPlaylist.name}" created successfully!');
      if (mounted) {
        // Redirect to detail page
        context.pushReplacement('/playlists/${newPlaylist.playlistId}');
      }
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildStep1(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Create New',
          style: theme.textTheme.headlineLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.0,
          ),
        ),
        Text(
          'Playlist',
          style: theme.textTheme.headlineLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Choose the playlist type to get started.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 40),
        
        _SelectionCard(
          title: 'Standard Playlist',
          description: 'A personal space for your tracks. Keep it private or share it publicly.',
          icon: CupertinoIcons.music_note_list,
          themeColor: theme.colorScheme.primary,
          onTap: () {
            setState(() {
              _isCollaborative = false;
              _step = 2;
              _animController.forward(from: 0);
            });
          },
        ),
        
        const SizedBox(height: 20),
        
        _SelectionCard(
          title: 'Collaborative Playlist',
          description: 'Invite friends to add, remove, and reorder tracks in real-time.',
          icon: CupertinoIcons.person_3_fill,
          themeColor: theme.colorScheme.secondary,
          onTap: () {
            setState(() {
              _isCollaborative = true;
              _step = 2;
              _animController.forward(from: 0);
            });
          },
        ),
      ],
    );
  }

  Widget _buildStep2(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Form(
      key: _formKey,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          const SizedBox(height: 10),

          // Cover Image Picker
          Center(
            child: GestureDetector(
              onTap: _pickCover,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ],
                      image: _coverFile?.path != null
                          ? DecorationImage(
                              image: FileImage(File(_coverFile!.path!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _coverFile?.path == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.music_note_list,
                                size: 56,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Tap to select cover',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          )
                        : Align(
                            alignment: Alignment.bottomRight,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: CircleAvatar(
                                backgroundColor: Colors.black.withValues(alpha: 0.6),
                                radius: 18,
                                child: const Icon(
                                  CupertinoIcons.photo,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Form Inputs
          TextFormField(
            controller: _nameCtrl,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            decoration: InputDecoration(
              labelText: 'Playlist Name',
              labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              prefixIcon: const Icon(CupertinoIcons.pencil, color: Colors.white54),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.white30, width: 1),
              ),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _descCtrl,
            maxLines: 3,
            style: const TextStyle(fontSize: 15, color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Add optional description...',
              labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 40.0),
                child: Icon(CupertinoIcons.text_alignleft, color: Colors.white54),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.white30, width: 1),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Option Toggles
          _ToggleCard(
            title: 'Collaborative Playlist',
            subtitle: 'Let friends add, remove, and reorder tracks',
            value: _isCollaborative,
            icon: CupertinoIcons.person_3_fill,
            activeColor: theme.colorScheme.primary,
            onChanged: (v) {
              setState(() {
                _isCollaborative = v;
              });
            },
          ),
          const SizedBox(height: 12),

          _ToggleCard(
            title: 'Public Playlist',
            subtitle: 'Anyone can search for and view this playlist',
            value: _isPublic,
            icon: CupertinoIcons.globe,
            activeColor: theme.colorScheme.secondary,
            onChanged: (v) {
              setState(() {
                _isPublic = v;
              });
            },
          ),
          const SizedBox(height: 40),

          // Submit button
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 8,
                shadowColor: theme.colorScheme.primary.withValues(alpha: 0.4),
              ),
              child: _isLoading
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Create Playlist',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(CupertinoIcons.arrow_right, color: Colors.white, size: 18),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _step == 1
              ? 'Create Playlist'
              : (_isCollaborative ? 'Collaborative Playlist' : 'Standard Playlist'),
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
        leading: _step == 2
            ? IconButton(
                icon: const Icon(CupertinoIcons.back),
                onPressed: () {
                  setState(() {
                    _step = 1;
                    _animController.forward(from: 0);
                  });
                },
              )
            : null,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Dynamic Background Gradient
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _step == 1
                      ? [
                          const Color(0xFF1E1430), // Private Purple
                          const Color(0xFF0A0B0E),
                        ]
                      : _isCollaborative
                          ? [
                              const Color(0xFF2C150A), // Warm Bronze/Coral
                              const Color(0xFF0A0B0E),
                            ]
                          : [
                              const Color(0xFF16131C), // Deep Aubergine
                              const Color(0xFF0A0B0E),
                            ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: _step == 1 ? _buildStep1(theme) : _buildStep2(theme),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color themeColor;
  final VoidCallback onTap;

  const _SelectionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.themeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: themeColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                CupertinoIcons.chevron_right,
                color: Colors.white.withValues(alpha: 0.3),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final IconData icon;
  final Color activeColor;
  final ValueChanged<bool> onChanged;

  const _ToggleCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.activeColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: value ? activeColor.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: value ? activeColor.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: value ? activeColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: value ? activeColor : Colors.white60,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              CupertinoSwitch(
                value: value,
                activeTrackColor: activeColor,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
