import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Robust Two-Tier (Memory + Persistent Storage) Asset Caching Service.
/// 
/// Solves repetitive network overhead for assets like country flag SVGs,
/// avatars, status vectors, and configuration files.
/// Tier 1: In-Memory cache for 0ms synchronous widget builds.
/// Tier 2: SharedPreferences disk cache for instant offline startup.
class AssetCacheService {
  static final AssetCacheService _instance = AssetCacheService._internal();
  factory AssetCacheService() => _instance;
  static AssetCacheService get instance => _instance;

  AssetCacheService._internal() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ));
  }

  // Allow custom Dio instance for mock/testing
  @visibleForTesting
  AssetCacheService.withDio(Dio dio) {
    _dio = dio;
  }

  late final Dio _dio;
  static const String _strPrefix = 'asset_cache_str_';
  static const String _binPrefix = 'asset_cache_bin_';

  final Map<String, String> _memoryStringCache = {};
  final Map<String, Uint8List> _memoryBytesCache = {};

  /// Synchronously checks if a string asset (e.g. SVG) is in memory.
  String? getCachedStringSync(String key) => _memoryStringCache[key];

  /// Synchronously checks if a binary asset is in memory.
  Uint8List? getCachedBytesSync(String key) => _memoryBytesCache[key];

  /// Retrieves a string asset (e.g., SVG markup, flag vector, JSON template).
  /// 
  /// 1. Memory lookup (instant)
  /// 2. Disk storage lookup via SharedPreferences
  /// 3. Remote HTTP fetch if [remoteUrl] is provided
  /// 4. Fallback if network fails or asset is absent
  Future<String?> getString(
    String key, {
    String? remoteUrl,
    String? fallback,
  }) async {
    // 1. Memory Cache
    if (_memoryStringCache.containsKey(key)) {
      return _memoryStringCache[key];
    }

    // 2. Persistent Disk Cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final diskVal = prefs.getString('$_strPrefix$key');
      if (diskVal != null && diskVal.isNotEmpty) {
        _memoryStringCache[key] = diskVal;
        return diskVal;
      }
    } catch (e) {
      debugPrint('[AssetCacheService] Disk read failed for $key: $e');
    }

    // 3. Remote Network Fetch
    if (remoteUrl != null && remoteUrl.isNotEmpty) {
      try {
        final res = await _dio.get<String>(
          remoteUrl,
          options: Options(responseType: ResponseType.plain),
        );
        final fetched = res.data;
        if (fetched != null && fetched.isNotEmpty) {
          await putString(key, fetched);
          return fetched;
        }
      } catch (e) {
        debugPrint('[AssetCacheService] Network fetch failed for $remoteUrl: $e');
      }
    }

    // 4. Fallback
    return fallback;
  }

  /// Persists a string asset into both memory and disk storage.
  Future<void> putString(String key, String value) async {
    _memoryStringCache[key] = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_strPrefix$key', value);
    } catch (e) {
      debugPrint('[AssetCacheService] Disk write failed for $key: $e');
    }
  }

  /// Retrieves a binary asset (e.g., image PNG/JPG/WebP).
  /// 
  /// 1. Memory lookup
  /// 2. Disk storage lookup (Base64 decoded)
  /// 3. Remote HTTP fetch (ResponseType.bytes)
  /// 4. Fallback
  Future<Uint8List?> getBytes(
    String key, {
    String? remoteUrl,
    Uint8List? fallback,
  }) async {
    // 1. Memory Cache
    if (_memoryBytesCache.containsKey(key)) {
      return _memoryBytesCache[key];
    }

    // 2. Persistent Disk Cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final base64Str = prefs.getString('$_binPrefix$key');
      if (base64Str != null && base64Str.isNotEmpty) {
        final bytes = base64Decode(base64Str);
        _memoryBytesCache[key] = bytes;
        return bytes;
      }
    } catch (e) {
      debugPrint('[AssetCacheService] Disk bytes read failed for $key: $e');
    }

    // 3. Remote Network Fetch
    if (remoteUrl != null && remoteUrl.isNotEmpty) {
      try {
        final res = await _dio.get<List<int>>(
          remoteUrl,
          options: Options(responseType: ResponseType.bytes),
        );
        final data = res.data;
        if (data != null && data.isNotEmpty) {
          final bytes = Uint8List.fromList(data);
          await putBytes(key, bytes);
          return bytes;
        }
      } catch (e) {
        debugPrint('[AssetCacheService] Network fetch bytes failed for $remoteUrl: $e');
      }
    }

    // 4. Fallback
    return fallback;
  }

  /// Persists binary bytes into memory and disk storage (Base64).
  Future<void> putBytes(String key, Uint8List bytes) async {
    _memoryBytesCache[key] = bytes;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_binPrefix$key', base64Encode(bytes));
    } catch (e) {
      debugPrint('[AssetCacheService] Disk bytes write failed for $key: $e');
    }
  }

  /// Preloads a map of asset keys to remote URLs in the background.
  Future<void> preloadAssets(Map<String, String> keyToUrlMap) async {
    for (final entry in keyToUrlMap.entries) {
      try {
        await getString(entry.key, remoteUrl: entry.value);
      } catch (_) {}
    }
  }

  /// Clears in-memory and persistent disk caches for this service.
  Future<void> clearCache() async {
    _memoryStringCache.clear();
    _memoryBytesCache.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().toList();
      for (final k in keys) {
        if (k.startsWith(_strPrefix) || k.startsWith(_binPrefix)) {
          await prefs.remove(k);
        }
      }
    } catch (e) {
      debugPrint('[AssetCacheService] Clear cache failed: $e');
    }
  }
}
