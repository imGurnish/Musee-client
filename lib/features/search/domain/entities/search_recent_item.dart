enum SearchRecentType { track, album, artist, playlist }

class SearchRecentItem {
  final SearchRecentType type;
  final String id;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final DateTime updatedAt;

  const SearchRecentItem({
    required this.type,
    required this.id,
    required this.title,
    this.subtitle,
    this.imageUrl,
    required this.updatedAt,
  });

  String get uniqueKey => '${type.name}:$id';

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'image_url': imageUrl,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory SearchRecentItem.fromJson(Map<String, dynamic> json) {
    final rawType = json['type']?.toString();
    final type = SearchRecentType.values.firstWhere(
      (candidate) => candidate.name == rawType,
      orElse: () => SearchRecentType.track,
    );

    return SearchRecentItem(
      type: type,
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString(),
      imageUrl: json['image_url']?.toString(),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}