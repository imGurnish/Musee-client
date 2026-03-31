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
        final subIsPremium = u.subscriptionType.value == 'premium';
        final subIsTrial = u.subscriptionType.value == 'trial';
        final accentColor = selected
            ? theme.colorScheme.primary
            : theme.colorScheme.outlineVariant;

        return Card(
          elevation: selected ? 1 : 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: accentColor.withOpacity(selected ? 0.45 : 0.30)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              if (hasSelection) {
                onSelect(u, !selected);
              } else {
                onEdit(u);
              }
            },
            onLongPress: () => onSelect(u, !selected),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.surface,
                    theme.colorScheme.surfaceContainerLowest,
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: accentColor.withOpacity(0.7),
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 24,
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
                        ),
                        if (selected)
                          Positioned(
                            top: -3,
                            right: -3,
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  u.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  visualDensity: VisualDensity.compact,
                                  iconSize: 18,
                                  icon: const Icon(Icons.more_vert),
                                  tooltip: 'Actions',
                                  onPressed: () =>
                                      _showMobileMenu(context, u, selected),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (u.email != null && u.email!.trim().isNotEmpty)
                                ? u.email!
                                : 'No email',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _Tag(
                                icon: Icons.person_outline,
                                label: u.userType.value,
                              ),
                              _Tag(
                                icon: subIsPremium
                                    ? Icons.workspace_premium_outlined
                                    : subIsTrial
                                    ? Icons.auto_awesome_outlined
                                    : Icons.sell_outlined,
                                label: u.subscriptionType.value,
                                backgroundColor: subIsPremium
                                    ? Colors.green.withOpacity(0.15)
                                    : subIsTrial
                                    ? Colors.blue.withOpacity(0.15)
                                    : Colors.orange.withOpacity(0.15),
                                foregroundColor: subIsPremium
                                    ? Colors.green[700]
                                    : subIsTrial
                                    ? Colors.blue[700]
                                    : Colors.orange[700],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Last login: ${u.lastLoginAt?.toLocal().toString().split('.').first ?? '—'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
  final IconData? icon;
  final String label;
  final Color? backgroundColor;
  final Color? foregroundColor;
  const _Tag({
    this.icon,
    required this.label,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 12,
              color: foregroundColor ?? theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
