import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Service for caching album artwork and track images locally.
/// Uses a simple file-based cache with content-addressable naming.
abstract class ImageCacheService {
  /// Initialize the image cache directory
  Future<void> init();

  /// Get local file path for a cached image, or null if not cached
  Future<String?> getLocalImagePath(String imageUrl);

  /// Download and cache an image, returns local path on success
  Future<String?> cacheImage(String imageUrl);

  /// Remove a single URL from the file-based cache
  Future<void> evictUrl(String imageUrl);

  /// Get total size of cached images in bytes
  Future<int> getTotalCacheSize();

  /// Clear all cached images
  Future<void> clearAll();

  /// Clear oldest cached images when over size limit
  Future<void> enforceMaxSize();
}

class ImageCacheServiceImpl implements ImageCacheService {
  Directory? _cacheDir;

  /// Maximum size for image cache (100 MB)
  static const int maxImageCacheSizeBytes = 100 * 1024 * 1024;

  @override
  Future<void> init() async {
    if (kIsWeb) return;
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDir = Directory('${appDir.path}/image_cache');
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
  }

  Directory get _dir {
    if (kIsWeb) {
      throw UnsupportedError('Image caching is not supported on web');
    }
    if (_cacheDir == null) {
      throw StateError('ImageCacheService not initialized. Call init() first.');
    }
    return _cacheDir!;
  }

  /// Generate a filename from URL using a simple hash
  String _getFilename(String url) {
    // Use hashCode for simplicity (collision-resistant enough for cache)
    final hash = url.hashCode.toRadixString(16);
    // Extract extension from URL if available
    final uri = Uri.tryParse(url);
    String ext = 'jpg';
    if (uri != null && uri.path.isNotEmpty) {
      final parts = uri.path.split('.');
      if (parts.length > 1) {
        final urlExt = parts.last.toLowerCase();
        if (['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(urlExt)) {
          ext = urlExt;
        }
      }
    }
    return '$hash.$ext';
  }

  String _getFilePath(String url) {
    return '${_dir.path}/${_getFilename(url)}';
  }

  @override
  Future<String?> getLocalImagePath(String imageUrl) async {
    if (kIsWeb || imageUrl.isEmpty) return null;
    final file = File(_getFilePath(imageUrl));
    if (await file.exists()) {
      return file.path;
    }
    return null;
  }

  @override
  Future<String?> cacheImage(String imageUrl) async {
    if (kIsWeb || imageUrl.isEmpty) return null;

    // Check if already cached
    final existingPath = await getLocalImagePath(imageUrl);
    if (existingPath != null) return existingPath;

    try {
      final response = await http
          .get(Uri.parse(imageUrl))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        if (kDebugMode) {
          print('[ImageCache] Failed to download: $imageUrl');
        }
        return null;
      }

      final filePath = _getFilePath(imageUrl);
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      if (kDebugMode) {
        print('[ImageCache] Cached: ${_getFilename(imageUrl)}');
      }

      return filePath;
    } catch (e) {
      if (kDebugMode) {
        print('[ImageCache] Error caching $imageUrl: $e');
      }
      return null;
    }
  }

  @override
  Future<void> evictUrl(String imageUrl) async {
    if (kIsWeb || imageUrl.isEmpty) return;
    try {
      final file = File(_getFilePath(imageUrl));
      if (await file.exists()) {
        await file.delete();
        if (kDebugMode) {
          print('[ImageCache] Evicted: ${_getFilename(imageUrl)}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ImageCache] Error evicting $imageUrl: $e');
      }
    }
  }

  @override
  Future<int> getTotalCacheSize() async {
    if (kIsWeb) return 0;
    int totalSize = 0;
    if (await _dir.exists()) {
      await for (final entity in _dir.list()) {
        if (entity is File) {
          try {
            if (await entity.exists()) {
              totalSize += await entity.length();
            }
          } catch (e) {
            if (kDebugMode) {
              print('[ImageCache] Skipping file when sizing ${entity.path}: $e');
            }
          }
        }
      }
    }
    return totalSize;
  }

  @override
  Future<void> enforceMaxSize() async {
    if (kIsWeb) return;
    final currentSize = await getTotalCacheSize();
    if (currentSize <= maxImageCacheSizeBytes) return;

    // Get all files sorted by modification time (oldest first)
    final files = <File>[];
    if (await _dir.exists()) {
      await for (final entity in _dir.list()) {
        if (entity is File) {
          files.add(entity);
        }
      }
    }

    // Map files to (file, modified) while skipping ones that vanish or error
    final List<MapEntry<File, DateTime>> fileWithTimes = [];
    for (final file in files) {
      try {
        if (!await file.exists()) continue;
        final stat = await file.stat();
        fileWithTimes.add(MapEntry(file, stat.modified));
      } catch (e) {
        if (kDebugMode) {
          print('[ImageCache] Skipping file when statting ${file.path}: $e');
        }
      }
    }

    // Sort by modification time (oldest first) for LRU eviction
    fileWithTimes.sort((a, b) => a.value.compareTo(b.value));

    int freedBytes = 0;
    final targetFree = currentSize - maxImageCacheSizeBytes;

    for (final entry in fileWithTimes) {
      if (freedBytes >= targetFree) break;
      final file = entry.key;
      try {
        if (!await file.exists()) continue;
        final size = await file.length();
        await file.delete();
        freedBytes += size;
        if (kDebugMode) {
          print('[ImageCache] Evicted: ${file.path}');
        }
      } catch (e) {
        if (kDebugMode) {
          print('[ImageCache] Failed to evict ${file.path}: $e');
        }
      }
    }
  }

  @override
  Future<void> clearAll() async {
    if (kIsWeb) return;
    if (await _dir.exists()) {
      await for (final entity in _dir.list()) {
        if (entity is File) {
          await entity.delete();
        }
      }
    }
  }
}
