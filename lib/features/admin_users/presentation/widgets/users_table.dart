import 'package:flutter/material.dart';
import 'package:musee/core/common/entities/user.dart';

class UsersTable extends StatelessWidget {
  final List<User> users;
  final void Function(User user) onEdit;
  final void Function(User user) onDelete;
  final Set<String> selectedIds;
  final ValueChanged<bool> onToggleSelectAll;
  final void Function(User user, bool selected) onSelect;
  const UsersTable({
    super.key,
    required this.users,
    required this.onEdit,
    required this.onDelete,
    required this.selectedIds,
    required this.onToggleSelectAll,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final allSelected = users.isNotEmpty && users.every((u) => selectedIds.contains(u.id));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 800),
        child: SingleChildScrollView(
          child: DataTable(
            columns: [
              DataColumn(
                label: Checkbox(
                  value: allSelected,
                  onChanged: (v) => onToggleSelectAll(v ?? false),
                ),
              ),
              DataColumn(label: Text('Avatar')),
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Email')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Subscription')),
              DataColumn(label: Text('Last login')),
              DataColumn(label: Text('Actions')),
            ],
            headingRowColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.surfaceContainerHighest),
            rows: users.map((u) {
              final selected = selectedIds.contains(u.id);
              return DataRow(
                selected: selected,
                onSelectChanged: (_) => onEdit(u),
                cells: [
                  DataCell(
                    Checkbox(
                      value: selected,
                      onChanged: (v) => onSelect(u, v ?? false),
                    ),
                  ),
                  DataCell(
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: u.avatarUrl.isNotEmpty
                          ? NetworkImage(u.avatarUrl)
                          : null,
                      child: u.avatarUrl.isEmpty
                          ? Text(
                              u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                            )
                          : null,
                    ),
                  ),
                  DataCell(Text(u.name)),
                  DataCell(Text(u.email ?? '—')),
                  DataCell(Text(u.userType.value)),
                  DataCell(Text(u.subscriptionType.value)),
                  DataCell(
                    Text(
                      u.lastLoginAt?.toLocal().toString().split('.').first ??
                          '—',
                    ),
                  ),
                  DataCell(
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit),
                          onPressed: () => onEdit(u),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => onDelete(u),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
            showCheckboxColumn: false,
          ),
        ),
      ),
    );
  }
}
