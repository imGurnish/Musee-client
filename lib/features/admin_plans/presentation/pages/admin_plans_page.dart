import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:musee/features/admin_plans/domain/entities/plan.dart';
import 'package:musee/features/admin_plans/presentation/bloc/admin_plans_bloc.dart';

class AdminPlansPage extends StatefulWidget {
  const AdminPlansPage({super.key});

  @override
  State<AdminPlansPage> createState() => _AdminPlansPageState();
}

class _AdminPlansPageState extends State<AdminPlansPage> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<AdminPlansBloc>().add(LoadPlans());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openCreateDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: BlocProvider.value(
          value: context.read<AdminPlansBloc>(),
          child: const _CreatePlanDialog(),
        ),
      ),
    );
  }

  void _openEditDialog(Plan p) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: BlocProvider.value(
          value: context.read<AdminPlansBloc>(),
          child: _EditPlanDialog(plan: p),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin • Plans'),
        actions: [
          IconButton(
            onPressed: _openCreateDialog,
            icon: const Icon(Icons.add_card_outlined),
            tooltip: 'Create plan',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Filter by name',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: BlocBuilder<AdminPlansBloc, AdminPlansState>(
                builder: (context, state) {
                  if (state is AdminPlansLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is AdminPlansFailure) {
                    return Center(
                      child: Text(
                        state.message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    );
                  }
                  if (state is AdminPlansLoaded) {
                    final q = _searchCtrl.text.trim().toLowerCase();
                    final items = q.isEmpty
                        ? state.items
                        : state.items
                              .where((p) => p.name.toLowerCase().contains(q))
                              .toList();
                    return LayoutBuilder(
                      builder: (context, c) {
                        final isMobile = c.maxWidth < 700;
                        if (isMobile) {
                          return ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final p = items[i];
                              return Card(
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.workspace_premium_outlined,
                                  ),
                                  title: Text(
                                    '${p.name} • ${p.currency} ${p.price.toStringAsFixed(2)}',
                                  ),
                                  subtitle: Text(
                                    '${p.billingCycle} • max ${p.maxDevices} devices',
                                  ),
                                  trailing: Wrap(
                                    spacing: 4,
                                    children: [
                                      if (p.isActive)
                                        const Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                          size: 18,
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () => _openEditDialog(p),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Delete plan?'),
                                              content: Text(
                                                'Are you sure you want to delete "${p.name}"?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                FilledButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, true),
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true &&
                                              context.mounted) {
                                            context.read<AdminPlansBloc>().add(
                                              DeletePlanEvent(p.id),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        }

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Name')),
                              DataColumn(label: Text('Price')),
                              DataColumn(label: Text('Cycle')),
                              DataColumn(label: Text('Currency')),
                              DataColumn(label: Text('Max Devices')),
                              DataColumn(label: Text('Active')),
                              DataColumn(label: Text('Created')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: items.map((p) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(p.name)),
                                  DataCell(Text(p.price.toStringAsFixed(2))),
                                  DataCell(Text(p.billingCycle)),
                                  DataCell(Text(p.currency)),
                                  DataCell(Text(p.maxDevices.toString())),
                                  DataCell(
                                    Icon(
                                      p.isActive ? Icons.check : Icons.close,
                                      size: 18,
                                      color: p.isActive
                                          ? Colors.green
                                          : Colors.redAccent,
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      p.createdAt
                                              ?.toLocal()
                                              .toString()
                                              .split('.')
                                              .first ??
                                          '—',
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () => _openEditDialog(p),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          onPressed: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text(
                                                  'Delete plan?',
                                                ),
                                                content: Text(
                                                  'Are you sure you want to delete "${p.name}"?',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          ctx,
                                                          false,
                                                        ),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  FilledButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          ctx,
                                                          true,
                                                        ),
                                                    child: const Text('Delete'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true &&
                                                context.mounted) {
                                              context
                                                  .read<AdminPlansBloc>()
                                                  .add(DeletePlanEvent(p.id));
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
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

class _CreatePlanDialog extends StatefulWidget {
  const _CreatePlanDialog();

  @override
  State<_CreatePlanDialog> createState() => _CreatePlanDialogState();
}

class _CreatePlanDialogState extends State<_CreatePlanDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController(text: 'INR');
  String _billingCycle = 'monthly';
  final _maxDevicesCtrl = TextEditingController(text: '1');
  bool _isActive = true;
  final _featuresCtrl = TextEditingController(text: '{}');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _currencyCtrl.dispose();
    _maxDevicesCtrl.dispose();
    _featuresCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Map<String, dynamic>? features;
    try {
      final txt = _featuresCtrl.text.trim();
      if (txt.isNotEmpty) {
        final parsed = jsonDecode(txt);
        if (parsed is Map<String, dynamic>) {
          features = parsed;
        } else {
          throw const FormatException('Features must be a JSON object');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invalid features JSON: $e')));
      return;
    }

    context.read<AdminPlansBloc>().add(
      CreatePlanEvent(
        name: _nameCtrl.text.trim(),
        price: double.parse(_priceCtrl.text.trim()),
        currency: _currencyCtrl.text.trim(),
        billingCycle: _billingCycle,
        features: features,
        maxDevices: int.tryParse(_maxDevicesCtrl.text.trim()),
        isActive: _isActive,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create plan',
                  style: Theme.of(context).textTheme.titleLarge,
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
                  controller: _priceCtrl,
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = double.tryParse(v?.trim() ?? '');
                    if (n == null || n < 0) return 'Price must be >= 0';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _currencyCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Currency',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _billingCycle,
                        decoration: const InputDecoration(
                          labelText: 'Billing cycle',
                        ),
                        items: const ['monthly', 'yearly', 'lifetime']
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _billingCycle = v ?? 'monthly'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _maxDevicesCtrl,
                  decoration: const InputDecoration(labelText: 'Max devices'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    if (n == null || n < 1) return 'Must be >= 1';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v ?? true),
                    ),
                    const Text('Active'),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _featuresCtrl,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Features (JSON object)',
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
                      onPressed: _submit,
                      child: const Text('Create'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditPlanDialog extends StatefulWidget {
  final Plan plan;
  const _EditPlanDialog({required this.plan});

  @override
  State<_EditPlanDialog> createState() => _EditPlanDialogState();
}

class _EditPlanDialogState extends State<_EditPlanDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _currencyCtrl;
  late String _billingCycle;
  late TextEditingController _maxDevicesCtrl;
  bool _isActive = true;
  late TextEditingController _featuresCtrl;

  @override
  void initState() {
    super.initState();
    final p = widget.plan;
    _nameCtrl = TextEditingController(text: p.name);
    _priceCtrl = TextEditingController(text: p.price.toStringAsFixed(2));
    _currencyCtrl = TextEditingController(text: p.currency);
    _billingCycle = p.billingCycle;
    _maxDevicesCtrl = TextEditingController(text: p.maxDevices.toString());
    _isActive = p.isActive;
    _featuresCtrl = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(p.features),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _currencyCtrl.dispose();
    _maxDevicesCtrl.dispose();
    _featuresCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Map<String, dynamic>? features;
    try {
      final txt = _featuresCtrl.text.trim();
      if (txt.isNotEmpty) {
        final parsed = jsonDecode(txt);
        if (parsed is Map<String, dynamic>) {
          features = parsed;
        } else {
          throw const FormatException('Features must be a JSON object');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invalid features JSON: $e')));
      return;
    }

    context.read<AdminPlansBloc>().add(
      UpdatePlanEvent(
        id: widget.plan.id,
        name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        price: double.tryParse(_priceCtrl.text.trim()),
        currency: _currencyCtrl.text.trim(),
        billingCycle: _billingCycle,
        features: features,
        maxDevices: int.tryParse(_maxDevicesCtrl.text.trim()),
        isActive: _isActive,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit plan',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _priceCtrl,
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return null; // optional update
                    }
                    final n = double.tryParse(v.trim());
                    if (n == null || n < 0) return 'Price must be >= 0';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _currencyCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Currency',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _billingCycle,
                        decoration: const InputDecoration(
                          labelText: 'Billing cycle',
                        ),
                        items: const ['monthly', 'yearly', 'lifetime']
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _billingCycle = v ?? 'monthly'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _maxDevicesCtrl,
                  decoration: const InputDecoration(labelText: 'Max devices'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return null; // optional update
                    }
                    final n = int.tryParse(v.trim());
                    if (n == null || n < 1) return 'Must be >= 1';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v ?? true),
                    ),
                    const Text('Active'),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _featuresCtrl,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Features (JSON object)',
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
                    FilledButton(onPressed: _submit, child: const Text('Save')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
