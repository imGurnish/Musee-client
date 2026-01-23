import 'dart:async';

import 'package:flutter/material.dart';

class UuidItem {
  final String id;
  final String label;
  UuidItem({required this.id, required this.label});
}

class UuidPageResult {
  final List<UuidItem> items;
  final int total;
  UuidPageResult({required this.items, required this.total});
}

class UuidPickResult {
  final String id;
  final String label;
  UuidPickResult({required this.id, required this.label});
}

typedef FetchPage =
    Future<UuidPageResult> Function(int page, int limit, String? query);

class UuidPickerDialog extends StatefulWidget {
  final String title;
  final FetchPage fetchPage;
  final int pageSize;

  const UuidPickerDialog({
    super.key,
    required this.title,
    required this.fetchPage,
    this.pageSize = 20,
  });

  @override
  State<UuidPickerDialog> createState() => _UuidPickerDialogState();
}

class _UuidPickerDialogState extends State<UuidPickerDialog> {
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();

  List<UuidItem> _items = [];
  int _page = 0;
  int _total = 0;
  bool _loading = false;
  String? _query;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loading) return;
    if (_items.length >= _total) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 100) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    setState(() => _loading = true);
    final page = reset ? 0 : _page + 1;
    try {
      final res = await widget.fetchPage(page, widget.pageSize, _query);
      setState(() {
        _page = page;
        _total = res.total;
        if (reset) {
          _items = res.items;
        } else {
          _items.addAll(res.items);
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applySearch() {
    setState(() {
      _query = _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim();
    });
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onSubmitted: (_) => _applySearch(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _applySearch,
                    child: const Text('Search'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Stack(
                  children: [
                    ListView.separated(
                      controller: _scrollCtrl,
                      itemCount: _items.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return ListTile(
                          title: Text(item.label),
                          onTap: () => Navigator.of(
                            context,
                          ).pop(UuidPickResult(id: item.id, label: item.label)),
                        );
                      },
                    ),
                    if (_loading)
                      const Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
