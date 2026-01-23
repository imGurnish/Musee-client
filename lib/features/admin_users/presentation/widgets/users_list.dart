import 'package:flutter/material.dart';
import 'package:musee/core/common/entities/user.dart';

class UsersList extends StatelessWidget {
  final List<User> users;
  final void Function(User user) onEdit;
  final void Function(User user) onDelete;
  const UsersList({
    super.key,
    required this.users,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.separated(
      itemCount: users.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final u = users[i];
        return Material(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            onTap: () => onEdit(u),
            leading: CircleAvatar(
              radius: 22,
              backgroundImage: u.avatarUrl.isNotEmpty
                  ? NetworkImage(u.avatarUrl)
                  : null,
              child: u.avatarUrl.isEmpty
                  ? Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?')
                  : null,
            ),
            title: Text(u.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (u.email != null)
                  Text(u.email!, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  '${u.userType.value} • ${u.subscriptionType.value}',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  'Last: ${u.lastLoginAt?.toLocal().toString().split('.').first ?? '—'}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            trailing: Wrap(
              spacing: 4,
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
        );
      },
    );
  }
}
