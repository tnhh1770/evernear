import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/services/asset_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AssetCacheService.instance.clearCache();
  });

  group('AssetCacheService Tests', () {
    test('should return fallback if key not found and no remote URL', () async {
      final res = await AssetCacheService.instance.getString('missing_key', fallback: '<svg>fallback</svg>');
      expect(res, '<svg>fallback</svg>');
    });

    test('should store and retrieve string in memory & disk', () async {
      const key = 'flag_vn';
      const svgContent = '<svg viewBox="0 0 100 100"><polygon points="50,15 60,40"/></svg>';

      await AssetCacheService.instance.putString(key, svgContent);

      // Memory synchronous check
      expect(AssetCacheService.instance.getCachedStringSync(key), svgContent);

      // Async retrieval
      final retrieved = await AssetCacheService.instance.getString(key);
      expect(retrieved, svgContent);

      // Verify SharedPreferences has it
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('asset_cache_str_$key'), svgContent);
    });

    test('should store and retrieve binary bytes in memory & disk', () async {
      const key = 'icon_shield';
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5, 255]);

      await AssetCacheService.instance.putBytes(key, bytes);

      // Memory synchronous check
      expect(AssetCacheService.instance.getCachedBytesSync(key), bytes);

      // Async retrieval
      final retrieved = await AssetCacheService.instance.getBytes(key);
      expect(retrieved, bytes);

      // Verify SharedPreferences has base64 string
      final prefs = await SharedPreferences.getInstance();
      final base64Val = prefs.getString('asset_cache_bin_$key');
      expect(base64Val, base64Encode(bytes));
    });

    test('should read from disk into memory when memory is cleared', () async {
      const key = 'cached_remote_svg';
      const content = '<svg>hello</svg>';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('asset_cache_str_$key', content);

      // Memory does not have it yet
      expect(AssetCacheService.instance.getCachedStringSync(key), isNull);

      // Retrieval populates memory from disk
      final val = await AssetCacheService.instance.getString(key);
      expect(val, content);
      expect(AssetCacheService.instance.getCachedStringSync(key), content);
    });

    test('clearCache should purge both memory and disk caches', () async {
      await AssetCacheService.instance.putString('k1', 'val1');
      await AssetCacheService.instance.putBytes('b1', Uint8List.fromList([42]));

      await AssetCacheService.instance.clearCache();

      expect(AssetCacheService.instance.getCachedStringSync('k1'), isNull);
      expect(AssetCacheService.instance.getCachedBytesSync('b1'), isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('asset_cache_str_k1'), isNull);
      expect(prefs.getString('asset_cache_bin_b1'), isNull);
    });
  });
}
