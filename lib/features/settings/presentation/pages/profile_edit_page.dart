import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:musee/core/cache/services/image_cache_service.dart';
import 'package:musee/core/common/cubit/app_user_cubit.dart';
import 'package:musee/core/common/entities/user.dart';
import 'package:musee/core/secrets/app_secrets.dart';
import 'package:musee/init_dependencies.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum ProfileSaveStatus { idle, saving, success, error }

class ProfileEditState {
  final String name;
  final Uint8List? pendingAvatarBytes;
  final String? pendingAvatarFilename;
  final ProfileSaveStatus status;
  final String? errorMessage;

  const ProfileEditState({
    this.name = '',
    this.pendingAvatarBytes,
    this.pendingAvatarFilename,
    this.status = ProfileSaveStatus.idle,
    this.errorMessage,
  });

  ProfileEditState copyWith({
    String? name,
    Uint8List? pendingAvatarBytes,
    bool clearAvatar = false,
    String? pendingAvatarFilename,
    ProfileSaveStatus? status,
    String? errorMessage,
  }) {
    return ProfileEditState(
      name: name ?? this.name,
      pendingAvatarBytes:
          clearAvatar ? null : (pendingAvatarBytes ?? this.pendingAvatarBytes),
      pendingAvatarFilename: clearAvatar
          ? null
          : (pendingAvatarFilename ?? this.pendingAvatarFilename),
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }
}

// ---------------------------------------------------------------------------
// Cubit
// ---------------------------------------------------------------------------

class ProfileEditCubit extends Cubit<ProfileEditState> {
  final dio.Dio _dio;
  final SupabaseClient _supabase;
  final AppUserCubit _appUserCubit;
  final ImageCacheService _imageCache;

  ProfileEditCubit({
    required dio.Dio dioClient,
    required SupabaseClient supabase,
    required AppUserCubit appUserCubit,
    required ImageCacheService imageCache,
  })  : _dio = dioClient,
        _supabase = supabase,
        _appUserCubit = appUserCubit,
        _imageCache = imageCache,
        super(const ProfileEditState());

  void setName(String name) => emit(state.copyWith(name: name));

  /// Opens the file picker and stores the chosen image bytes locally.
  Future<void> pickAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true, // ensures bytes are loaded on all platforms
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;
      emit(state.copyWith(
        pendingAvatarBytes: file.bytes,
        pendingAvatarFilename: file.name,
      ));
    } catch (_) {
      // ignore picker cancellations
    }
  }

  void clearPendingAvatar() => emit(state.copyWith(clearAvatar: true));

  Future<void> saveProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final name = state.name.trim();
    if (name.isEmpty) {
      emit(state.copyWith(
        status: ProfileSaveStatus.error,
        errorMessage: 'Name cannot be empty',
      ));
      return;
    }

    emit(state.copyWith(status: ProfileSaveStatus.saving));

    try {
      final token = _supabase.auth.currentSession?.accessToken;

      final dio.Response response;

      if (state.pendingAvatarBytes != null) {
        // Multipart upload when there's a new avatar
        final formData = dio.FormData();
        formData.fields.add(MapEntry('name', name));
        formData.files.add(
          MapEntry(
            'avatar',
            dio.MultipartFile.fromBytes(
              state.pendingAvatarBytes!,
              filename: state.pendingAvatarFilename ?? 'avatar.jpg',
            ),
          ),
        );
        response = await _dio.patch(
          '${AppSecrets.backendUrl}/api/user/users/$userId',
          data: formData,
          options: dio.Options(
            headers: {'Authorization': 'Bearer $token'},
          ),
        );
      } else {
        // JSON-only when no new avatar
        response = await _dio.patch(
          '${AppSecrets.backendUrl}/api/user/users/$userId',
          data: {'name': name},
          options: dio.Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          ),
        );
      }

      final updatedUser =
          User.fromJson(response.data as Map<String, dynamic>);

      // Bust file-based image cache for the old avatar URL so the
      // new photo loads immediately without an app restart.
      final oldAvatarUrl = _appUserCubit.state is AppUserLoggedIn
          ? (_appUserCubit.state as AppUserLoggedIn).user.avatarUrl
          : '';
      if (oldAvatarUrl.isNotEmpty) {
        await _imageCache.evictUrl(oldAvatarUrl);
      }
      // Also bust Flutter's in-memory painting cache (works on all platforms)
      PaintingBinding.instance.imageCache.evict(
        NetworkImage(oldAvatarUrl),
      );
      if (updatedUser.avatarUrl.isNotEmpty &&
          updatedUser.avatarUrl != oldAvatarUrl) {
        // Pre-evict the new URL too in case a stale entry somehow exists
        await _imageCache.evictUrl(updatedUser.avatarUrl);
        PaintingBinding.instance.imageCache.evict(
          NetworkImage(updatedUser.avatarUrl),
        );
      }

      _appUserCubit.updateUser(updatedUser);
      emit(state.copyWith(status: ProfileSaveStatus.success, clearAvatar: true));
    } on dio.DioException catch (e) {
      final msg = e.response?.data?['message'] as String? ??
          e.response?.data?.toString() ??
          'Failed to update profile';
      emit(state.copyWith(
        status: ProfileSaveStatus.error,
        errorMessage: msg,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ProfileSaveStatus.error,
        errorMessage: 'An unexpected error occurred',
      ));
    }
  }
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class ProfileEditPage extends StatefulWidget {
  final User user;

  const ProfileEditPage({super.key, required this.user});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  late final TextEditingController _nameController;
  late final ProfileEditCubit _cubit;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _cubit = ProfileEditCubit(
      dioClient: serviceLocator<dio.Dio>(),
      supabase: serviceLocator<SupabaseClient>(),
      appUserCubit: context.read<AppUserCubit>(),
      imageCache: serviceLocator<ImageCacheService>(),
    );
    _cubit.setName(widget.user.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<ProfileEditCubit, ProfileEditState>(
        listener: (context, state) {
          if (state.status == ProfileSaveStatus.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile updated!'),
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.of(context).pop();
          } else if (state.status == ProfileSaveStatus.error &&
              state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
        builder: (context, state) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;
          final isSaving = state.status == ProfileSaveStatus.saving;
          final topPadding = MediaQuery.of(context).padding.top;

          return Scaffold(
            backgroundColor: colorScheme.surface,
            body: Column(
              children: [
                // ── Gradient header ──────────────────────────────────
                _buildHeader(
                  context,
                  theme,
                  colorScheme,
                  isSaving,
                  topPadding,
                  state,
                ),

                // ── Form ────────────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel(context, 'Display Name'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nameController,
                          onChanged: (v) =>
                              context.read<ProfileEditCubit>().setName(v),
                          enabled: !isSaving,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            hintText: 'Your display name',
                            prefixIcon:
                                const Icon(Icons.person_outline_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerLow,
                          ),
                        ),
                        const SizedBox(height: 28),

                        _buildSectionLabel(context, 'Account Info'),
                        const SizedBox(height: 8),
                        _buildInfoCard(context, [
                          _InfoRow(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: widget.user.email ?? '—',
                          ),
                          _InfoRow(
                            icon: Icons.workspace_premium_outlined,
                            label: 'Subscription',
                            value: _subscriptionLabel(
                                widget.user.subscriptionType),
                          ),
                          _InfoRow(
                            icon: Icons.people_outline_rounded,
                            label: 'Followers',
                            value:
                                widget.user.followersCount.toString(),
                          ),
                          _InfoRow(
                            icon: Icons.person_add_outlined,
                            label: 'Following',
                            value:
                                widget.user.followingsCount.toString(),
                          ),
                          if (widget.user.createdAt != null)
                            _InfoRow(
                              icon: Icons.calendar_today_outlined,
                              label: 'Joined',
                              value: _formatDate(widget.user.createdAt!),
                            ),
                        ]),

                        const SizedBox(height: 16),
                        Text(
                          'Only your display name and profile picture can be changed here.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Gradient header with avatar picker ──────────────────────────────────

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isSaving,
    double topPadding,
    ProfileEditState state,
  ) {
    // Preview: pending bytes > existing network URL > initials
    final hasPending = state.pendingAvatarBytes != null;
    final hasNetwork = widget.user.avatarUrl.isNotEmpty;

    return Container(
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
      padding: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: back + save
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: isSaving ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back',
              ),
              const Spacer(),
              if (isSaving)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                FilledButton.icon(
                  onPressed: () =>
                      context.read<ProfileEditCubit>().saveProfile(),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Save'),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Avatar picker
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Avatar circle
                GestureDetector(
                  onTap: isSaving
                      ? null
                      : () => context.read<ProfileEditCubit>().pickAvatar(),
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.4),
                        width: 2.5,
                      ),
                    ),
                    child: ClipOval(
                      child: hasPending
                          ? Image.memory(
                              state.pendingAvatarBytes!,
                              fit: BoxFit.cover,
                            )
                          : hasNetwork
                              ? Image.network(
                                  widget.user.avatarUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      _avatarFallback(
                                          colorScheme, widget.user.name),
                                )
                              : _avatarFallback(
                                  colorScheme, widget.user.name),
                    ),
                  ),
                ),

                // Edit badge
                Positioned(
                  bottom: 0,
                  right: -4,
                  child: GestureDetector(
                    onTap: isSaving
                        ? null
                        : () =>
                            context.read<ProfileEditCubit>().pickAvatar(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.surface,
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.camera_alt_rounded,
                        size: 15,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),

                // Remove pending badge (only shown when a new image is staged)
                if (hasPending)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: GestureDetector(
                      onTap: () =>
                          context.read<ProfileEditCubit>().clearPendingAvatar(),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: colorScheme.error,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: colorScheme.surface, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.close_rounded,
                          size: 12,
                          color: colorScheme.onError,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tap hint
          Center(
            child: Text(
              hasPending ? 'New photo selected — tap Save to apply' : 'Tap photo to change',
              style: theme.textTheme.bodySmall?.copyWith(
                color: hasPending
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                fontStyle: hasPending ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Column(
              children: [
                Text(
                  widget.user.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (widget.user.email != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.user.email!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(ColorScheme colorScheme, String name) {
    return Container(
      color: colorScheme.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  Widget _buildSectionLabel(BuildContext context, String label) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, List<_InfoRow> rows) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      color: colorScheme.surfaceContainerLow,
      child: Column(
        children: rows.indexed
            .map((entry) {
              final i = entry.$1;
              final row = entry.$2;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: colorScheme.primary
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Icon(row.icon,
                              size: 18, color: colorScheme.primary),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          row.label,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        Text(
                          row.value,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  if (i < rows.length - 1)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 54,
                      color: colorScheme.outlineVariant
                          .withValues(alpha: 0.35),
                    ),
                ],
              );
            })
            .toList(),
      ),
    );
  }

  String _subscriptionLabel(SubscriptionType type) {
    switch (type) {
      case SubscriptionType.premium:
        return 'Premium ⭐';
      case SubscriptionType.trial:
        return 'Trial';
      case SubscriptionType.free:
        return 'Free';
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }
}

class _InfoRow {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
}
