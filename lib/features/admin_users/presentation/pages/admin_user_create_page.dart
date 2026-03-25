import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:musee/features/admin_artists/presentation/widgets/uuid_picker_dialog.dart';
import 'package:musee/core/common/entities/user.dart';
import 'package:musee/core/usecase/usecase.dart';
import 'package:musee/features/admin_plans/domain/entities/plan.dart';
import 'package:musee/features/admin_plans/domain/usecases/list_plans.dart';
import 'package:musee/features/admin_users/domain/usecases/create_user.dart';
import 'package:musee/init_dependencies.dart';

class AdminUserCreatePage extends StatefulWidget {
  const AdminUserCreatePage({super.key});

  @override
  State<AdminUserCreatePage> createState() => _AdminUserCreatePageState();
}

class _AdminUserCreatePageState extends State<AdminUserCreatePage> {
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
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    final listPlans = serviceLocator<ListPlans>();
    final res = await listPlans(NoParams());
    res.fold(
      (_) => setState(() => _loadingPlans = false),
      (plans) => setState(() {
        _plans = plans;
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
      appBar: AppBar(title: const Text('Create User')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  _ResponsiveRow(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Name *',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _emailCtrl,
                          decoration: const InputDecoration(labelText: 'Email'),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            if (value.isEmpty) return 'Required';
                            final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
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
                            () => _subscriptionType = v ?? _subscriptionType,
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
                  const SizedBox(height: 12),
                  _FilePickerTile(
                    label: 'Avatar (optional)',
                    pickedName: _avatarFile?.name,
                    onPick: () async {
                      final res = await FilePicker.platform.pickFiles(
                        withData: true,
                        type: FileType.image,
                      );
                      if (res != null && res.files.isNotEmpty) {
                        setState(() => _avatarFile = res.files.first);
                      }
                    },
                    onClear: () => setState(() => _avatarFile = null),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => context.pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _onSubmit,
                        child: const Text('Create'),
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

  Future<void> _onSubmit() async {
    if (_formKey.currentState?.validate() != true) return;
    final create = serviceLocator<CreateUser>();
    final res = await create(
      CreateUserParams(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        subscriptionType: _subscriptionType,
        planId: _selectedPlan?.id,
        avatarBytes: _avatarFile?.bytes,
        avatarFilename: _avatarFile?.name,
      ),
    );
    res.fold((f) => _showSnack(f.message, isError: true), (_) {
      _showSnack('User created');
      context.go('/admin/users');
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  Future<void> _openPlanUuidPicker() async {
    final picked = await showDialog<UuidPickResult>(
      context: context,
      builder: (ctx) => UuidPickerDialog(
        title: 'Pick Plan',
        fetchPage: (page, limit, query) async {
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
    if (picked != null) {
      final match = _plans.where((p) => p.id == picked.id);
      setState(() {
        _selectedPlan = match.isNotEmpty ? match.first : _selectedPlan;
      });
    }
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
  final ValueChanged<Plan?> onSelected;
  final VoidCallback onCreateNew;
  const _PlanAutocomplete({
    required this.plans,
    required this.loading,
    required this.onSelected,
    required this.onCreateNew,
  });

  @override
  State<_PlanAutocomplete> createState() => _PlanAutocompleteState();
}

class _PlanAutocompleteState extends State<_PlanAutocomplete> {
  Plan? _value;

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
                  onPressed: () => _copy(_value!.id),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied')));
  }
}

class _FilePickerTile extends StatelessWidget {
  final String label;
  final String? pickedName;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _FilePickerTile({
    required this.label,
    required this.pickedName,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          if (pickedName != null)
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Text(
                  pickedName!,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          if (pickedName != null)
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.close),
              onPressed: onClear,
            ),
          FilledButton.tonal(onPressed: onPick, child: const Text('Choose')),
        ],
      ),
    );
  }
}
