import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saferoute_tn/offline_tile_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SafeRoute TN 2.0 – Phase 1A: Offline Tile Provider & Cache Policy Tests', () {
    const testUrl = 'https://tile.openstreetmap.org/12/2944/1932.png';
    const fallbackUrl = 'https://a.tile.openstreetmap.org/12/2944/1932.png';

    test('1. TileCacheName constant is versioned and isolated', () {
      expect(kTileCacheName, equals('saferoute-viewed-tiles-v1'));
    });

    test('2. WebCacheTileProvider instantiates and computes URL and headers correctly', () {
      final provider = WebCacheTileProvider(
        headers: {'X-Custom-Client': 'SafeRoute-TN', 'Authorization': 'Bearer test-token'},
      );
      final tileLayer = TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'saferoute_tn',
      );

      const coordinates = TileCoordinates(2944, 1932, 12);
      final url = provider.getTileUrl(coordinates, tileLayer);
      expect(url, equals('https://tile.openstreetmap.org/12/2944/1932.png'));

      final imageProvider = provider.getImage(coordinates, tileLayer);
      expect(imageProvider, isA<WebCacheTileImageProvider>());
      final webImageProvider = imageProvider as WebCacheTileImageProvider;
      expect(webImageProvider.url, equals(url));
      expect(webImageProvider.headers['X-Custom-Client'], equals('SafeRoute-TN'));
      expect(webImageProvider.headers['Authorization'], equals('Bearer test-token'));
    });

    test('3. ImageProvider equality and hashCode include headers and fallback settings', () async {
      const p1 = WebCacheTileImageProvider(
        url: testUrl,
        fallbackUrl: fallbackUrl,
        headers: {'X-Auth': 'A'},
      );
      const p2 = WebCacheTileImageProvider(
        url: testUrl,
        fallbackUrl: fallbackUrl,
        headers: {'X-Auth': 'A'},
      );
      const pDifferentHeaders = WebCacheTileImageProvider(
        url: testUrl,
        fallbackUrl: fallbackUrl,
        headers: {'X-Auth': 'B'},
      );
      const pDifferentFallback = WebCacheTileImageProvider(
        url: testUrl,
        fallbackUrl: 'https://b.tile.openstreetmap.org/12/2944/1932.png',
        headers: {'X-Auth': 'A'},
      );

      // Equality and hash matching
      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2.hashCode));

      // Header sensitivity
      expect(p1, isNot(equals(pDifferentHeaders)));
      expect(p1.hashCode, isNot(equals(pDifferentHeaders.hashCode)));

      // Fallback URL sensitivity
      expect(p1, isNot(equals(pDifferentFallback)));

      // Mutable test store must NOT affect equality
      final pWithStore = WebCacheTileImageProvider(
        url: testUrl,
        fallbackUrl: fallbackUrl,
        headers: const {'X-Auth': 'A'},
        testCacheStore: {testUrl: Uint8List(0)},
      );
      expect(p1, equals(pWithStore));
      expect(p1.hashCode, equals(pWithStore.hashCode));

      final key = await p1.obtainKey(ImageConfiguration.empty);
      expect(key, equals(p1));
    });

    test('4. HttpCachePolicy.isStorable correctly respects no-store, no-cache, and past Expires', () {
      // Allowed responses
      expect(HttpCachePolicy.isStorable(cacheControl: 'public, max-age=86400'), isTrue);
      expect(HttpCachePolicy.isStorable(cacheControl: 'max-age=3600'), isTrue);

      // Prohibited responses
      expect(HttpCachePolicy.isStorable(cacheControl: 'no-store'), isFalse);
      expect(HttpCachePolicy.isStorable(cacheControl: 'no-store, no-cache, must-revalidate'), isFalse);
      expect(HttpCachePolicy.isStorable(cacheControl: 'no-cache'), isFalse);
      expect(HttpCachePolicy.isStorable(cacheControl: 'max-age=0'), isFalse);
      expect(HttpCachePolicy.isStorable(expires: '0'), isFalse);
      expect(HttpCachePolicy.isStorable(expires: '-1'), isFalse);

      // Expired date in the past
      final pastDate = DateTime.now().subtract(const Duration(days: 1)).toUtc();
      expect(
        HttpCachePolicy.isStorable(expires: pastDate.toIso8601String()),
        isFalse,
      );

      // Future date
      final futureDate = DateTime.now().add(const Duration(days: 30)).toUtc();
      expect(
        HttpCachePolicy.isStorable(expires: futureDate.toIso8601String()),
        isTrue,
      );
    });

    test('5. HttpCachePolicy.isFresh evaluates max-age and Expires correctly', () {
      final now = DateTime.utc(2026, 11, 13, 12, 0, 0);

      // Fresh: response 30 minutes old with max-age=3600 (1 hour)
      expect(
        HttpCachePolicy.isFresh(
          cacheControl: 'max-age=3600',
          date: 'Fri, 13 Nov 2026 11:30:00 GMT',
          now: now,
        ),
        isTrue,
      );

      // Expired: response 90 minutes old with max-age=3600
      expect(
        HttpCachePolicy.isFresh(
          cacheControl: 'max-age=3600',
          date: 'Fri, 13 Nov 2026 10:30:00 GMT',
          now: now,
        ),
        isFalse,
      );

      // Disallowed: no-cache and no-store are never fresh without revalidation
      expect(HttpCachePolicy.isFresh(cacheControl: 'no-store', now: now), isFalse);
      expect(HttpCachePolicy.isFresh(cacheControl: 'no-cache', now: now), isFalse);

      // Expires: future is fresh, past is expired
      expect(
        HttpCachePolicy.isFresh(
          expires: 'Fri, 13 Nov 2026 13:00:00 GMT',
          now: now,
        ),
        isTrue,
      );
      expect(
        HttpCachePolicy.isFresh(
          expires: 'Fri, 13 Nov 2026 11:00:00 GMT',
          now: now,
        ),
        isFalse,
      );
    });

    test('6. Expired cached entry is evicted and not served', () async {
      final validCachedBytes = TileProvider.transparentImage;
      final testStore = <String, Uint8List>{
        testUrl: validCachedBytes,
      };

      // Header indicates entry is expired (max-age=60s, but date is 2 hours ago)
      final testHeaders = <String, Map<String, String>>{
        testUrl: {
          'cache-control': 'max-age=60',
          'date': 'Fri, 13 Nov 2026 08:00:00 GMT',
        },
      };

      final provider = WebCacheTileProvider(
        testCacheStore: testStore,
        testHeadersStore: testHeaders,
        simulateOffline: true, // If expired, cannot fetch from network -> must return transparent placeholder
      );

      final tileLayer = TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      );

      const coordinates = TileCoordinates(2944, 1932, 12);
      final imageProvider = provider.getImage(coordinates, tileLayer);

      final completer = Completer<ImageInfo>();
      final stream = imageProvider.resolve(ImageConfiguration.empty);
      stream.addListener(ImageStreamListener(
        (info, _) => completer.complete(info),
        onError: (err, _) => completer.completeError(err),
      ));

      final imageInfo = await completer.future.timeout(const Duration(seconds: 5));
      expect(imageInfo, isNotNull);

      // The expired entry must have been removed from the store
      expect(testStore.containsKey(testUrl), isFalse);
    });

    test('7. Fresh cached entry is served immediately on cache hit', () async {
      final validCachedBytes = TileProvider.transparentImage;
      final testStore = <String, Uint8List>{
        testUrl: validCachedBytes,
      };

      final imageProvider = WebCacheTileImageProvider(
        url: testUrl,
        testCacheStore: testStore,
        simulateOffline: true,
      );

      final completer = Completer<ImageInfo>();
      final stream = imageProvider.resolve(ImageConfiguration.empty);
      stream.addListener(ImageStreamListener(
        (info, _) => completer.complete(info),
        onError: (err, _) => completer.completeError(err),
      ));

      final imageInfo = await completer.future.timeout(const Duration(seconds: 5));
      expect(imageInfo, isNotNull);
      expect(imageInfo.image.width, equals(1));
    });

    test('8. Corrupt cache entry degrades gracefully to safe transparent tile', () async {
      final corruptBytes = Uint8List.fromList([0, 1, 2, 3, 4, 5]);
      final testStore = <String, Uint8List>{
        testUrl: corruptBytes,
      };

      final imageProvider = WebCacheTileImageProvider(
        url: testUrl,
        testCacheStore: testStore,
        simulateOffline: true,
      );

      final completer = Completer<ImageInfo>();
      final stream = imageProvider.resolve(ImageConfiguration.empty);
      stream.addListener(ImageStreamListener(
        (info, _) => completer.complete(info),
        onError: (err, _) => completer.completeError(err),
      ));

      final imageInfo = await completer.future.timeout(const Duration(seconds: 5));
      expect(imageInfo, isNotNull);
      expect(imageInfo.image.width, equals(1));
    });

    test('9. Transparent tile returned when offline and tile not cached', () async {
      final provider = WebCacheTileProvider(
        testCacheStore: {},
        simulateOffline: true,
      );

      final tileLayer = TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      );

      const coordinates = TileCoordinates(10, 20, 5);
      final imageProvider = provider.getImage(coordinates, tileLayer);

      final completer = Completer<ImageInfo>();
      final stream = imageProvider.resolve(ImageConfiguration.empty);
      stream.addListener(ImageStreamListener(
        (info, _) => completer.complete(info),
        onError: (err, _) => completer.completeError(err),
      ));

      final imageInfo = await completer.future.timeout(const Duration(seconds: 5));
      expect(imageInfo, isNotNull);
      expect(imageInfo.image.width, equals(1));
    });

    test('10. Stub storage management methods report truthful non-web status', () async {
      // NOTE: In the VM environment, the stub is active and reports false for browser storage.
      // Real browser CacheStorage is only available and verified when running in a browser runtime.
      expect(isBrowserCacheStorageSupported, isFalse);
      expect(await requestPersistentStoragePermission(), isFalse);
      expect(await getCachedTileCount(), equals(0));

      // clearTileCache() in stub returns false to avoid falsely implying browser storage was cleared
      final cleared = await clearTileCache();
      expect(cleared, isFalse);
    });

    test('11. TileLayer integration preserves URL template and attribution', () {
      final layer = TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'saferoute_tn',
        tileProvider: WebCacheTileProvider(),
      );

      expect(layer.urlTemplate, equals('https://tile.openstreetmap.org/{z}/{x}/{y}.png'));
      expect(layer.tileProvider, isA<WebCacheTileProvider>());
    });
  });
}
