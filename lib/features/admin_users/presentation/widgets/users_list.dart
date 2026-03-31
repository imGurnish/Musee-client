import 'package:flutter/material.dart';
import 'package:musee/core/common/entities/user.dart';

class UsersList extends StatelessWidget {
  final List<User> users;
  final void Function(User user) onEdit;
  final void Function(User user) onDelete;
  final Set<String> selectedIds;
  final bool hasSelection;
  final void Function(User user, bool selected) onSelect;
  const UsersList({
    super.key,
    required this.users,
    required this.onEdit,
    required this.onDelete,
    required this.selectedIds,
    required this.hasSelection,
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
            onTap: () {
              if (hasSelection) {
                onSelect(u, !selected);
              } else {
                onEdit(u);
              }
            },
            onLongPress: () => onSelect(u, !selected),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
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
                          if (selected)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
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
                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        tooltip: 'Actions',
                        onPressed: () => _showMobileMenu(context, u, selected),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last login: ${u.lastLoginAt?.toLocal().toString().split('.').first ?? '—'}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMobileMenu(BuildContext context, User user, bool selected) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              user.name,
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              selected ? Icons.check_box : Icons.check_box_outline_blank,
            ),
            title: Text(selected ? 'Deselect' : 'Select'),
            onTap: () {
              Navigator.pop(ctx);
              onSelect(user, !selected);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit'),
            onTap: () {
              Navigator.pop(ctx);
              onEdit(user);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Delete', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(ctx);
              onDelete(user);
            },
          ),
        ],
      ),
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
