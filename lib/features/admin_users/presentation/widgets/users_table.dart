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
    final width = MediaQuery.of(context).size.width;
    final useCompactActions = width < 1200;
    final isIntermediateWidth = width < 1360;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 800),
        child: SingleChildScrollView(
          child: DataTable(
            dataRowMinHeight: 62,
            dataRowMaxHeight: 62,
            columnSpacing: useCompactActions ? (isIntermediateWidth ? 12 : 18) : 24,
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
                cells: [
                  DataCell(
                    Checkbox(
                      value: selected,
                      onChanged: (v) => onSelect(u, v ?? false),
                    ),
                  ),
                  DataCell(
                    CircleAvatar(
                      radius: isIntermediateWidth ? 14 : 16,
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
                  DataCell(
                    SizedBox(
                      width: isIntermediateWidth ? 140 : 180,
                      child: Text(
                        u.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: isIntermediateWidth ? 250 : 340,
                      child: Text(
                        u.email ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(Text(u.userType.value)),
                  DataCell(Text(u.subscriptionType.value)),
                  DataCell(
                    SizedBox(
                      width: isIntermediateWidth ? 140 : 170,
                      child: Text(
                        u.lastLoginAt?.toLocal().toString().split('.').first ??
                            '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    useCompactActions
                        ? PopupMenuButton<String>(
                            tooltip: 'Actions',
                            onSelected: (value) {
                              if (value == 'edit') {
                                onEdit(u);
                              } else if (value == 'delete') {
                                onDelete(u);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem<String>(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.more_vert),
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Edit',
                                icon: const Icon(Icons.edit),
                                visualDensity: VisualDensity.compact,
                                onPressed: () => onEdit(u),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                icon: const Icon(Icons.delete_outline),
                                visualDensity: VisualDensity.compact,
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
