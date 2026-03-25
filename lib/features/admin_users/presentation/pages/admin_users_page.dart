import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:musee/core/common/entities/user.dart';
import 'package:musee/features/admin_users/presentation/bloc/admin_users_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'dart:typed_data';
import 'package:musee/features/admin_users/presentation/widgets/admin_user_search_bar.dart';
import 'package:musee/features/admin_users/presentation/widgets/page_size_dropdown.dart';
import 'package:musee/features/admin_users/presentation/widgets/users_table.dart';
import 'package:musee/features/admin_users/presentation/widgets/users_list.dart';
import 'package:musee/features/admin_users/presentation/widgets/pagination_controls.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  int _limit = 20;
  final Set<String> _selectedUserIds = <String>{};

  @override
  void initState() {
    super.initState();
    context.read<AdminUsersBloc>().add(LoadUsers(page: 0, limit: _limit));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _goCreatePage() => context.push('/admin/users/create-new');

  void _goDetail(User user) => context.push('/admin/users/${user.id}');

  Future<void> _confirmDeleteOne(User user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete user?'),
        content: Text(
          'Are you sure you want to delete ${user.name}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      context.read<AdminUsersBloc>().add(DeleteUserEvent(user.id));
      setState(() => _selectedUserIds.remove(user.id));
    }
  }

  Future<void> _confirmDeleteSelected() async {
    final count = _selectedUserIds.length;
    if (count == 0) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete selected users?'),
        content: Text('Delete $count selected user(s)? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      context.read<AdminUsersBloc>().add(
        DeleteUsersEvent(_selectedUserIds.toList(growable: false)),
      );
      setState(() => _selectedUserIds.clear());
    }
  }

  void _toggleSelectUser(User user, bool selected) {
    setState(() {
      if (selected) {
        _selectedUserIds.add(user.id);
      } else {
        _selectedUserIds.remove(user.id);
      }
    });
  }

  void _toggleSelectAllVisible(List<User> users, bool selected) {
    setState(() {
      if (selected) {
        _selectedUserIds.addAll(users.map((e) => e.id));
      } else {
        _selectedUserIds.removeAll(users.map((e) => e.id));
      }
    });
  }

  void _clearSelection() => setState(_selectedUserIds.clear);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          if (_selectedUserIds.isNotEmpty)
            IconButton(
              onPressed: _confirmDeleteSelected,
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Delete selected (${_selectedUserIds.length})',
            ),
          IconButton(
            onPressed: _goCreatePage,
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Create user',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final isMobile = c.maxWidth < 760;
                    return isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Search & Filters',
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(height: 10),
                              AdminUserSearchBar(
                                controller: _searchCtrl,
                                onSubmitted: (value) {
                                  context.read<AdminUsersBloc>().add(
                                    LoadUsers(
                                      page: 0,
                                      limit: _limit,
                                      search: value.isEmpty ? null : value,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: PageSizeDropdown(
                                      value: _limit,
                                      onChanged: (v) {
                                        setState(() => _limit = v);
                                        context.read<AdminUsersBloc>().add(
                                          LoadUsers(
                                            page: 0,
                                            limit: v,
                                            search: _searchCtrl.text.trim().isEmpty
                                                ? null
                                                : _searchCtrl.text.trim(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: AdminUserSearchBar(
                                  controller: _searchCtrl,
                                  onSubmitted: (value) {
                                    context.read<AdminUsersBloc>().add(
                                      LoadUsers(
                                        page: 0,
                                        limit: _limit,
                                        search: value.isEmpty ? null : value,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 210,
                                child: PageSizeDropdown(
                                  value: _limit,
                                  onChanged: (v) {
                                    setState(() => _limit = v);
                                    context.read<AdminUsersBloc>().add(
                                      LoadUsers(
                                        page: 0,
                                        limit: v,
                                        search: _searchCtrl.text.trim().isEmpty
                                            ? null
                                            : _searchCtrl.text.trim(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_selectedUserIds.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.checklist_rounded,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_selectedUserIds.length} selected',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: _clearSelection,
                      child: const Text('Clear'),
                    ),
                    FilledButton.icon(
                      onPressed: _confirmDeleteSelected,
                      icon: const Icon(Icons.delete_sweep_outlined),
                      label: const Text('Delete'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: BlocBuilder<AdminUsersBloc, AdminUsersState>(
                builder: (context, state) {
                  if (state is AdminUsersLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is AdminUsersFailure) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            state.message,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => context.read<AdminUsersBloc>().add(
                              LoadUsers(
                                page: 0,
                                limit: _limit,
                                search: _searchCtrl.text.trim().isEmpty
                                    ? null
                                    : _searchCtrl.text.trim(),
                              ),
                            ),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  if (state is AdminUsersPageLoaded) {
                    final users = state.items;
                    final visibleIds = users.map((u) => u.id).toSet();
                    final stale = _selectedUserIds.difference(visibleIds);
                    if (stale.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        setState(() => _selectedUserIds.removeAll(stale));
                      });
                    }
                    final totalPages = (state.total / state.limit).ceil().clamp(
                      1,
                      999999,
                    );
                    return LayoutBuilder(
                      builder: (context, c) {
                        final isMobile = c.maxWidth < 700;
                        return Column(
                          children: [
                            Expanded(
                              child: Card(
                                elevation: 0,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: isMobile
                                      ? UsersList(
                                          users: users,
                                          onEdit: _goDetail,
                                          onDelete: _confirmDeleteOne,
                                          selectedIds: _selectedUserIds,
                                          onSelect: _toggleSelectUser,
                                        )
                                      : UsersTable(
                                          users: users,
                                          onEdit: _goDetail,
                                          onDelete: _confirmDeleteOne,
                                          selectedIds: _selectedUserIds,
                                          onToggleSelectAll: (selected) =>
                                              _toggleSelectAllVisible(
                                                users,
                                                selected,
                                              ),
                                          onSelect: _toggleSelectUser,
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'Total: ${state.total}',
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  PaginationControls(
                                    page: state.page, // zero-based
                                    totalPages: totalPages,
                                    onPrev: state.page > 0
                                        ? () =>
                                              context.read<AdminUsersBloc>().add(
                                                LoadUsers(
                                                  page: state.page - 1,
                                                  limit: state.limit,
                                                  search: state.search,
                                                ),
                                              )
                                        : null,
                                    onNext: state.page < (totalPages - 1)
                                        ? () =>
                                              context.read<AdminUsersBloc>().add(
                                                LoadUsers(
                                                  page: state.page + 1,
                                                  limit: state.limit,
                                                  search: state.search,
                                                ),
                                              )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserFormDialog extends StatefulWidget {
  final void Function(
    String name,
    String email,
    SubscriptionType subType,
    String? planId,
    Uint8List? avatarBytes,
    String? avatarFilename,
  )
  onSubmit;

  const _UserFormDialog({required this.onSubmit});

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _planCtrl;
  SubscriptionType _subscriptionType = SubscriptionType.free;
  Uint8List? _avatarBytes;
  String? _avatarFilename;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: '');
    _emailCtrl = TextEditingController(text: '');
    _planCtrl = TextEditingController(text: '');
    _subscriptionType = SubscriptionType.free;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _planCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // legacy flag removed; dialog only supports create
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create user',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              // Avatar preview and picker
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: _avatarBytes != null
                        ? MemoryImage(_avatarBytes!)
                        : null,
                    child: _avatarBytes == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _avatarFilename ?? 'No image selected',
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () async {
                                final result = await FilePicker.platform
                                    .pickFiles(
                                      type: FileType.image,
                                      allowMultiple: false,
                                      withData: true,
                                    );
                                if (result != null && result.files.isNotEmpty) {
                                  final f = result.files.first;
                                  if (f.bytes != null) {
                                    setState(() {
                                      _avatarBytes = f.bytes;
                                      _avatarFilename = f.name;
                                    });
                                  }
                                }
                              },
                              icon: const Icon(Icons.image),
                              label: const Text('Select image'),
                            ),
                            if (_avatarBytes != null)
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _avatarBytes = null;
                                    _avatarFilename = null;
                                  });
                                },
                                icon: const Icon(Icons.clear),
                                label: const Text('Clear'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<SubscriptionType>(
                initialValue: _subscriptionType,
                items: SubscriptionType.values
                    .map(
                      (e) => DropdownMenuItem(value: e, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: (v) =>
                    setState(() => _subscriptionType = v ?? _subscriptionType),
                decoration: const InputDecoration(
                  labelText: 'Subscription Type',
                ),
              ),
              const SizedBox(height: 8),

              const SizedBox(height: 8),
              TextFormField(
                controller: _planCtrl,
                decoration: const InputDecoration(
                  labelText: 'Plan ID (optional)',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      if (_formKey.currentState?.validate() != true) return;
                      widget.onSubmit(
                        _nameCtrl.text.trim(),
                        _emailCtrl.text.trim(),
                        _subscriptionType,
                        _planCtrl.text.trim().isEmpty
                            ? null
                            : _planCtrl.text.trim(),
                        _avatarBytes,
                        _avatarFilename,
                      );
                      Navigator.pop(context);
                    },
                    child: const Text('Create'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
