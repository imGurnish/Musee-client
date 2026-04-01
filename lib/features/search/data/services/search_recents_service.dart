import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:musee/features/search/domain/entities/search_recent_item.dart';

abstract interface class SearchRecentsService {
  Future<List<SearchRecentItem>> getRecents({int limit = 12});

  Future<void> addRecent(SearchRecentItem item);

  Future<void> clearRecents();
}

class SearchRecentsServiceImpl implements SearchRecentsService {
  static const String _boxName = 'search_recent_items';
  static const String _itemsKey = 'items';
  static const int _maxItems = 30;

  Box<dynamic>? _box;

  Future<Box<dynamic>> _getBox() async {
    _box ??= await Hive.openBox<dynamic>(_boxName);
    return _box!;
  }

  @override
  Future<List<SearchRecentItem>> getRecents({int limit = 12}) async {
    final box = await _getBox();
    final raw = box.get(_itemsKey);
    if (raw is! List) return const <SearchRecentItem>[];

    final parsed = raw
        .whereType<String>()
        .map((entry) => _tryParseEntry(entry))
        .whereType<SearchRecentItem>()
        .toList(growable: false);

    parsed.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (parsed.length <= limit) return parsed;
    return parsed.take(limit).toList(growable: false);
  }

  @override
  Future<void> addRecent(SearchRecentItem item) async {
    if (item.id.trim().isEmpty || item.title.trim().isEmpty) return;

    final box = await _getBox();
    final existing = await getRecents(limit: _maxItems);
    final updatedItem = SearchRecentItem(
      type: item.type,
      id: item.id,
      title: item.title,
      subtitle: item.subtitle,
      imageUrl: item.imageUrl,
      updatedAt: DateTime.now(),
    );

    final merged = <SearchRecentItem>[
      updatedItem,
      ...existing.where((entry) => entry.uniqueKey != updatedItem.uniqueKey),
    ];

    final normalized = merged.take(_maxItems).map((entry) {
      return jsonEncode(entry.toJson());
    }).toList(growable: false);

    await box.put(_itemsKey, normalized);
  }

  @override
  Future<void> clearRecents() async {
    final box = await _getBox();
    await box.put(_itemsKey, <String>[]);
  }

  SearchRecentItem? _tryParseEntry(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return SearchRecentItem.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }
}