import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:musee/features/admin_artists/presentation/widgets/uuid_picker_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:musee/core/common/entities/user.dart';
import 'package:musee/core/usecase/usecase.dart';
import 'package:musee/features/admin_plans/domain/entities/plan.dart';
import 'package:musee/features/admin_plans/domain/usecases/list_plans.dart';
import 'package:musee/features/admin_users/domain/usecases/get_user.dart';
import 'package:musee/features/admin_users/domain/usecases/update_user.dart';
import 'package:musee/init_dependencies.dart';

class AdminUserDetailPage extends StatefulWidget {
  final String userId;
  const AdminUserDetailPage({super.key, required this.userId});

  @override
  State<AdminUserDetailPage> createState() => _AdminUserDetailPageState();
}

class _AdminUserDetailPageState extends State<AdminUserDetailPage> {
  User? _user;
  bool _loading = true;
  String? _error;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  SubscriptionType _subscriptionType = SubscriptionType.free;
  Plan? _selectedPlan;
  List<Plan> _plans = [];
  bool _loadingPlans = true;
  PlatformFile? _avatarFile;

  @override
  void initState() {
    super.initState();
    _fetchUser();
    _loadPlans();
  }

  Future<void> _fetchUser() async {
    final getUser = serviceLocator<GetUser>();
    final res = await getUser(widget.userId);
    res.fold(
      (f) {
        setState(() {
          _error = f.message;
          _loading = false;
        });
      },
      (u) {
        setState(() {
          _user = u;
          _nameCtrl.text = u.name;
          _emailCtrl.text = u.email ?? '';
          _subscriptionType = u.subscriptionType;
          _loading = false;
        });
      },
    );
  }

  Future<void> _loadPlans() async {
    final listPlans = serviceLocator<ListPlans>();
    final res = await listPlans(NoParams());
    res.fold(
      (_) => setState(() => _loadingPlans = false),
      (plans) => setState(() {
        _plans = plans;
        // preselect plan if user has one
        if (_user?.planId != null) {
          final match = plans.where((p) => p.id == _user!.planId);
          _selectedPlan = match.isNotEmpty ? match.first : null;
        }
        _loadingPlans = false;
      }),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin User Details'),
        actions: [
          IconButton(
            tooltip: 'Back to users',
            icon: const Icon(Icons.list),
            onPressed: () => context.go('/admin/users'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _user == null
          ? const Center(child: Text('User not found'))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      children: [
                        _HeaderRow(userId: _user!.id, planId: _user!.planId),
                        const SizedBox(height: 12),
                        _AvatarRow(
                          avatarUrl: _user!.avatarUrl,
                          previewBytes: _avatarFile?.bytes,
                          onPick: (f) => setState(() => _avatarFile = f),
                          onClear: () => setState(() => _avatarFile = null),
                          pickedName: _avatarFile?.name,
                        ),
                        const SizedBox(height: 12),
                        _ResponsiveRow(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _nameCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Name *',
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Required'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _emailCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Email *',
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) {
                                  final value = v?.trim() ?? '';
                                  if (value.isEmpty) return 'Required';
                                  final emailRegex = RegExp(
                                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                  );
                                  if (!emailRegex.hasMatch(value)) {
                                    return 'Enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _ResponsiveRow(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<SubscriptionType>(
                                initialValue: _subscriptionType,
                                decoration: const InputDecoration(
                                  labelText: 'Subscription type',
                                ),
                                items: SubscriptionType.values
                                    .map(
                                      (t) => DropdownMenuItem(
                                        value: t,
                                        child: Text(t.value),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) => setState(
                                  () => _subscriptionType =
                                      v ?? _subscriptionType,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _PlanAutocomplete(
                                    plans: _plans,
                                    loading: _loadingPlans,
                                    initial: _selectedPlan,
                                    onSelected: (p) =>
                                        setState(() => _selectedPlan = p),
                                    onCreateNew: () =>
                                        context.go('/admin/plans?create-new=1'),
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: OutlinedButton.icon(
                                      onPressed: _openPlanUuidPicker,
                                      icon: const Icon(Icons.search),
                                      label: const Text('Pick plan by UUID…'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _UserMetaGrid(user: _user!),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => context.go('/admin/users'),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: _onSave,
                              child: const Text('Save changes'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _onSave() async {
    if (_formKey.currentState?.validate() != true) return;
    final update = serviceLocator<UpdateUser>();
    final prevAvatar = _user!.avatarUrl;
    final res = await update(
      UpdateUserParams(
        id: _user!.id,
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        subscriptionType: _subscriptionType,
        planId: _selectedPlan?.id,
        avatarBytes: _avatarFile?.bytes,
        avatarFilename: _avatarFile?.name,
      ),
    );
    res.fold((f) => _snack(f.message, error: true), (updated) async {
      // Update local state with server response so UI reflects new values
      setState(() {
        _user = updated;
        _avatarFile = null;
      });
      // Evict old and new avatar URLs to force refresh
      try {
        if (prevAvatar.isNotEmpty) {
          await NetworkImage(prevAvatar).evict();
        }
        if (updated.avatarUrl.isNotEmpty) {
          await NetworkImage(updated.avatarUrl).evict();
        }
      } catch (_) {}
      _snack('Saved');
    });
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  Future<void> _openPlanUuidPicker() async {
    if (!mounted) return;
    final picked = await showDialog<UuidPickResult>(
      context: context,
      builder: (ctx) => UuidPickerDialog(
        title: 'Pick Plan',
        fetchPage: (page, limit, query) async {
          // Fetch all plans once, filter and paginate locally
          final listPlans = serviceLocator<ListPlans>();
          final res = await listPlans(NoParams());
          return res.fold((_) => UuidPageResult(items: const [], total: 0), (
            plans,
          ) {
            final q = (query ?? '').toLowerCase();
            final filtered = q.isEmpty
                ? plans
                : plans.where(
                    (p) => p.name.toLowerCase().contains(q) || p.id.contains(q),
                  );
            final total = filtered.length;
            final start = (page * limit).clamp(0, total);
            final end = ((page + 1) * limit).clamp(0, total);
            final slice = filtered.toList().sublist(start, end);
            return UuidPageResult(
              items: [for (final p in slice) UuidItem(id: p.id, label: p.name)],
              total: total,
            );
          });
        },
      ),
    );
    if (!mounted) return;
    if (picked != null) {
      // Reflect in autocomplete by finding the plan with this id
      final match = _plans.where((p) => p.id == picked.id);
      setState(() {
        _selectedPlan = match.isNotEmpty ? match.first : _selectedPlan;
      });
    }
  }
}

class _HeaderRow extends StatelessWidget {
  final String userId;
  final String? planId;
  const _HeaderRow({required this.userId, this.planId});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _KeyValueCopy(label: 'User UUID', value: userId),
        if (planId != null) _KeyValueCopy(label: 'Plan UUID', value: planId!),
      ],
    );
  }
}

class _KeyValueCopy extends StatelessWidget {
  final String label;
  final String value;
  const _KeyValueCopy({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: Theme.of(context).textTheme.bodySmall),
          SizedBox(
            width: 200,
            child: Text(value, overflow: TextOverflow.ellipsis),
          ),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Copied')));
            },
          ),
        ],
      ),
    );
  }
}

class _AvatarRow extends StatelessWidget {
  final String avatarUrl;
  final String? pickedName;
  final Uint8List? previewBytes;
  final ValueChanged<PlatformFile> onPick;
  final VoidCallback onClear;
  const _AvatarRow({
    required this.avatarUrl,
    required this.onPick,
    required this.onClear,
    this.previewBytes,
    this.pickedName,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundImage: previewBytes != null
              ? MemoryImage(previewBytes!)
              : (avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null),
          child: (previewBytes == null && avatarUrl.isEmpty)
              ? const Icon(Icons.person)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pickedName ?? 'No image selected'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.image),
                    label: const Text('Choose avatar'),
                    onPressed: () async {
                      final res = await FilePicker.platform.pickFiles(
                        withData: true,
                        type: FileType.image,
                      );
                      if (res != null && res.files.isNotEmpty) {
                        onPick(res.files.first);
                      }
                    },
                  ),
                  if (pickedName != null)
                    TextButton.icon(
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear'),
                      onPressed: onClear,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UserMetaGrid extends StatelessWidget {
  final User user;
  const _UserMetaGrid({required this.user});

  Widget _chip(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      _chip(context, 'User type', user.userType.value),
      _chip(context, 'Followers', user.followersCount.toString()),
      _chip(context, 'Followings', user.followingsCount.toString()),
      _chip(context, 'Created', user.createdAt?.toIso8601String() ?? '—'),
      _chip(context, 'Updated', user.updatedAt?.toIso8601String() ?? '—'),
      _chip(context, 'Last login', user.lastLoginAt?.toIso8601String() ?? '—'),
      _chip(context, 'Playlists', user.playlists.length.toString()),
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: LayoutBuilder(
          builder: (context, c) {
            final isNarrow = c.maxWidth < 600;
            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < items.length; i++) ...[
                    items[i],
                    if (i != items.length - 1) const SizedBox(height: 8),
                  ],
                ],
              );
            }
            return GridView.count(
              crossAxisCount: 3,
              childAspectRatio: 3.6,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: items,
            );
          },
        ),
      ),
    );
  }
}

class _ResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  const _ResponsiveRow({required this.children});

  Widget _unwrapFlexible(Widget w) {
    if (w is Expanded) return w.child;
    if (w is Flexible) return w.child;
    return w;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 600) {
          const gap = 12.0;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < children.length; i++) ...[
                _unwrapFlexible(children[i]),
                if (i != children.length - 1) const SizedBox(height: gap),
              ],
            ],
          );
        }
        return Row(children: children);
      },
    );
  }
}

class _PlanAutocomplete extends StatefulWidget {
  final List<Plan> plans;
  final bool loading;
  final Plan? initial;
  final ValueChanged<Plan?> onSelected;
  final VoidCallback onCreateNew;
  const _PlanAutocomplete({
    required this.plans,
    required this.loading,
    required this.onSelected,
    required this.onCreateNew,
    this.initial,
  });

  @override
  State<_PlanAutocomplete> createState() => _PlanAutocompleteState();
}

class _PlanAutocompleteState extends State<_PlanAutocomplete> {
  Plan? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Autocomplete<Plan>(
          displayStringForOption: (p) => p.name,
          optionsBuilder: (text) {
            final q = text.text.toLowerCase();
            if (widget.loading) return const Iterable<Plan>.empty();
            if (q.isEmpty) return widget.plans;
            return widget.plans.where((p) => p.name.toLowerCase().contains(q));
          },
          onSelected: (p) {
            setState(() => _value = p);
            widget.onSelected(p);
          },
          initialValue: TextEditingValue(text: _value?.name ?? ''),
          fieldViewBuilder: (ctx, ctrl, focus, onSubmitted) => TextField(
            controller: ctrl,
            focusNode: focus,
            decoration: const InputDecoration(labelText: 'Plan (optional)'),
          ),
          optionsViewBuilder: (ctx, onSelect, options) {
            final opts = options.toList();
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 240,
                    minWidth: 280,
                  ),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    children: [
                      for (final p in opts)
                        ListTile(
                          title: Text(p.name),
                          subtitle: Text(p.id),
                          onTap: () => onSelect(p),
                        ),
                      ListTile(
                        leading: const Icon(Icons.add),
                        title: const Text('Create new plan…'),
                        onTap: widget.onCreateNew,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        if (_value != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _value!.id,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Copy plan UUID',
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _value!.id));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('Copied')));
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}
