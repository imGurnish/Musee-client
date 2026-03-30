import 'package:flutter/material.dart';
import 'package:musee/core/common/entities/user.dart';

class UsersList extends StatelessWidget {
  final List<User> users;
  final void Function(User user) onEdit;
  final void Function(User user) onDelete;
  final Set<String> selectedIds;
  final void Function(User user, bool selected) onSelect;
  const UsersList({
    super.key,
    required this.users,
    required this.onEdit,
    required this.onDelete,
    required this.selectedIds,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.separated(
      itemCount: users.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final u = users[i];
        final selected = selectedIds.contains(u.id);
        return Material(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onEdit(u),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundImage: u.avatarUrl.isNotEmpty
                            ? NetworkImage(u.avatarUrl)
                            : null,
                        child: u.avatarUrl.isEmpty
                            ? Text(
                                u.name.isNotEmpty
                                    ? u.name[0].toUpperCase()
                                    : '?',
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              u.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall,
                            ),
                            if (u.email != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  u.email!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _Tag(label: u.userType.value),
                                _Tag(label: u.subscriptionType.value),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last login: ${u.lastLoginAt?.toLocal().toString().split('.').first ?? '—'}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(
                        value: selected,
                        onChanged: (v) => onSelect(u, v ?? false),
                      ),
                      Text(selected ? 'Selected' : 'Select'),
                      const Spacer(),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit'),
                        onPressed: () => onEdit(u),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Delete'),
                        onPressed: () => onDelete(u),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: theme.textTheme.labelSmall),
    );
  }
}
