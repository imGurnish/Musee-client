import 'package:flutter/material.dart';

class AdminUserSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final void Function(String value) onSubmitted;
  const AdminUserSearchBar({
    super.key,
    required this.controller,
    required this.onSubmitted,
  });

  @override
  State<AdminUserSearchBar> createState() => _AdminUserSearchBarState();
}

class _AdminUserSearchBarState extends State<AdminUserSearchBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: widget.controller,
              decoration: InputDecoration(
                hintText: 'Search by name or email',
                border: InputBorder.none,
                isDense: true,
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (value) => widget.onSubmitted(value.trim()),
            ),
          ),
          if (widget.controller.text.trim().isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.close_rounded, size: 18),
              visualDensity: VisualDensity.compact,
              onPressed: () {
                widget.controller.clear();
                widget.onSubmitted('');
              },
            ),
          FilledButton.tonal(
            onPressed: () {
              FocusScope.of(context).unfocus();
              widget.onSubmitted(widget.controller.text.trim());
            },
            style: FilledButton.styleFrom(
              minimumSize: const Size(42, 36),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Icon(Icons.arrow_forward_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}
