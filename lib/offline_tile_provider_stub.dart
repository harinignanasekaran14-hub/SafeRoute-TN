import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;

/// Browser CacheStorage name for passively viewed map tiles.
const String kTileCacheName = 'saferoute-viewed-tiles-v1';

/// Checks whether browser CacheStorage is supported.
/// In the stub / VM environment, this is always false.
bool get isBrowserCacheStorageSupported => false;

/// Requests persistent storage permission from the browser where supported.
/// In the stub / VM environment, this is always false.
Future<bool> requestPersistentStoragePermission() async => false;

/// Returns the number of cached tile entries in browser CacheStorage.
/// In the stub / VM environment, returns 0.
Future<int> getCachedTileCount() async => 0;

/// Clears only the SafeRoute tile cache.
/// Returns false in the stub to accurately reflect that browser CacheStorage is not present.
Future<bool> clearTileCache() async => false;

/// Utility class for evaluating HTTP Cache-Control and Expires directives.
class HttpCachePolicy {
  /// Parses standard HTTP date strings (RFC 1123, RFC 850, ISO 8601).
  static DateTime? parseHttpDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim();

    final iso = DateTime.tryParse(trimmed);
    if (iso != null) return iso;

    try {
      const months = {
        'jan': 1,
        'feb': 2,
        'mar': 3,
        'apr': 4,
        'may': 5,
        'jun': 6,
        'jul': 7,
        'aug': 8,
        'sep': 9,
        'oct': 10,
        'nov': 11,
        'dec': 12,
      };

      final normalized = trimmed.replaceAll('-', ' ');
      final parts = normalized.split(RegExp(r'[\s,]+'));

      int idx = 0;
      if (parts.isNotEmpty &&
          parts[0].length >= 3 &&
          int.tryParse(parts[0]) == null &&
          !months.containsKey(parts[0].toLowerCase())) {
        idx = 1;
      }

      if (idx + 3 <= parts.length) {
        final day = int.tryParse(parts[idx]);
        final month = months[parts[idx + 1].toLowerCase()];
        var year = int.tryParse(parts[idx + 2]);

        if (year != null && year < 100) {
          year += (year < 70) ? 2000 : 1900;
        }

        if (day != null && month != null && year != null && idx + 3 < parts.length) {
          final timeParts = parts[idx + 3].split(':');
          final hour = int.tryParse(timeParts[0]) ?? 0;
          final minute =
              timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
          final second =
              timeParts.length > 2 ? (int.tryParse(timeParts[2]) ?? 0) : 0;
          return DateTime.utc(year, month, day, hour, minute, second);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Determines whether a response should be stored in persistent cache.
  /// Returns false if Cache-Control contains `no-store`, `no-cache`, `max-age=0`,
  /// or if Expires specifies a past date or 0.
  static bool isStorable({
    String? cacheControl,
    String? expires,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();

    if (cacheControl != null) {
      final cc = cacheControl.toLowerCase();
      if (cc.contains('no-store')) return false;
      if (cc.contains('no-cache')) return false;

      final maxAgeMatch = RegExp(r'max-age\s*=\s*(\d+)').firstMatch(cc);
      if (maxAgeMatch != null) {
        final seconds = int.tryParse(maxAgeMatch.group(1)!);
        if (seconds != null && seconds <= 0) return false;
      }
    }

    if (expires != null) {
      final exp = expires.trim();
      if (exp == '0' || exp == '-1') return false;
      final expDate = parseHttpDate(exp);
      if (expDate != null && expDate.isBefore(currentTime)) {
        return false;
      }
    }

    return true;
  }

  /// Determines whether a cached response is still fresh according to
  /// Cache-Control max-age and Expires directives.
  static bool isFresh({
    String? cacheControl,
    String? expires,
    String? date,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();

    if (cacheControl != null) {
      final cc = cacheControl.toLowerCase();
      if (cc.contains('no-store') || cc.contains('no-cache')) {
        return false;
      }

      final maxAgeMatch = RegExp(r'max-age\s*=\s*(\d+)').firstMatch(cc);
      if (maxAgeMatch != null) {
        final maxAgeSec = int.tryParse(maxAgeMatch.group(1)!);
        if (maxAgeSec != null) {
          if (maxAgeSec <= 0) return false;
          final responseDate = parseHttpDate(date) ?? currentTime;
          final age = currentTime.difference(responseDate).inSeconds;
          if (age > maxAgeSec) {
            return false;
          }
        }
      }
    }

    if (expires != null) {
      final exp = expires.trim();
      if (exp == '0' || exp == '-1') return false;
      final expDate = parseHttpDate(exp);
      if (expDate != null && !expDate.isAfter(currentTime)) {
        return false;
      }
    }

    return true;
  }
}

/// Tile provider using browser persistent CacheStorage on web,
/// and an in-memory/fallback cache in non-web environments (tests, VM).
class WebCacheTileProvider extends TileProvider {
  /// Ephemeral in-memory tile cache store for unit tests and VM execution.
  /// NOTE: This is NOT persistent browser CacheStorage.
  final Map<String, Uint8List>? testCacheStore;

  /// Optional header metadata store for testing caching directives in VM.
  final Map<String, Map<String, String>>? testHeadersStore;

  final bool simulateOffline;

  WebCacheTileProvider({
    super.headers,
    this.testCacheStore,
    this.testHeadersStore,
    this.simulateOffline = false,
  });

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    final fallbackUrl = getTileFallbackUrl(coordinates, options);
    return WebCacheTileImageProvider(
      url: url,
      fallbackUrl: fallbackUrl,
      headers: headers,
      testCacheStore: testCacheStore,
      testHeadersStore: testHeadersStore,
      simulateOffline: simulateOffline,
    );
  }
}

/// Dedicated ImageProvider that retrieves map tiles from browser CacheStorage
/// before falling back to network fetch, and safely returns transparent tiles when offline.
class WebCacheTileImageProvider
    extends ImageProvider<WebCacheTileImageProvider> {
  final String url;
  final String? fallbackUrl;
  final Map<String, String> headers;

  /// Ephemeral in-memory test store. Not included in equality or hashCode.
  final Map<String, Uint8List>? testCacheStore;

  /// Ephemeral in-memory test headers store. Not included in equality or hashCode.
  final Map<String, Map<String, String>>? testHeadersStore;

  final bool simulateOffline;

  const WebCacheTileImageProvider({
    required this.url,
    this.fallbackUrl,
    this.headers = const {},
    this.testCacheStore,
    this.testHeadersStore,
    this.simulateOffline = false,
  });

  @override
  ImageStreamCompleter loadImage(
    WebCacheTileImageProvider key,
    ImageDecoderCallback decode,
  ) {
    final chunkEvents = StreamController<ImageChunkEvent>();
    return MultiFrameImageStreamCompleter(
      codec: _loadImage(key, chunkEvents.sink, decode)
        ..then(
          (_) => unawaited(chunkEvents.close()),
          onError: (_) => unawaited(chunkEvents.close()),
        ),
      chunkEvents: chunkEvents.stream,
      scale: 1.0,
      debugLabel: key.url,
      informationCollector: () => [
        DiagnosticsProperty('URL', url),
        DiagnosticsProperty('Fallback URL', fallbackUrl),
        DiagnosticsProperty('Headers', headers),
        DiagnosticsProperty('Provider', key),
      ],
    );
  }

  Future<Codec> _loadImage(
    WebCacheTileImageProvider key,
    StreamSink<ImageChunkEvent> chunkEvents,
    ImageDecoderCallback decode, {
    bool useFallback = false,
  }) async {
    void evict() =>
        scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
    Future<Codec> decodeBytes(Uint8List bytes) =>
        ImmutableBuffer.fromUint8List(bytes).then(decode);

    final targetUrl = useFallback ? (fallbackUrl ?? '') : url;
    if (targetUrl.isEmpty) {
      evict();
      return await decodeBytes(TileProvider.transparentImage);
    }

    // 1. Check in-memory/test cache store
    if (testCacheStore != null && testCacheStore!.containsKey(targetUrl)) {
      final cachedBytes = testCacheStore![targetUrl]!;
      final cachedHeaders = testHeadersStore?[targetUrl];

      final isFresh = cachedHeaders == null ||
          HttpCachePolicy.isFresh(
            cacheControl: cachedHeaders['cache-control'],
            expires: cachedHeaders['expires'],
            date: cachedHeaders['date'],
          );

      if (!isFresh) {
        // Expired cached entry: evict from test store and fall through to network
        testCacheStore?.remove(targetUrl);
        testHeadersStore?.remove(targetUrl);
      } else if (cachedBytes.isNotEmpty) {
        try {
          return await decodeBytes(cachedBytes);
        } catch (_) {
          // Corrupt cache data: remove and fall through
          testCacheStore?.remove(targetUrl);
          testHeadersStore?.remove(targetUrl);
        }
      }
    }

    // 2. If simulating offline mode and not in cache, return transparent image
    if (simulateOffline) {
      evict();
      return await decodeBytes(TileProvider.transparentImage);
    }

    // 3. Network fetch passing configured headers
    try {
      final response = await http.get(Uri.parse(targetUrl), headers: headers);
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final canStore = HttpCachePolicy.isStorable(
          cacheControl: response.headers['cache-control'],
          expires: response.headers['expires'],
        );

        if (canStore) {
          testCacheStore?[targetUrl] = response.bodyBytes;
          testHeadersStore?[targetUrl] = response.headers;
        }

        return await decodeBytes(response.bodyBytes);
      }
    } catch (_) {
      // Network error
    }

    // 4. Fallback URL
    if (!useFallback && fallbackUrl != null && fallbackUrl!.isNotEmpty) {
      return _loadImage(
        key,
        chunkEvents,
        decode,
        useFallback: true,
      );
    }

    // 5. Offline or error: safely return transparent tile without throwing
    evict();
    return await decodeBytes(TileProvider.transparentImage);
  }

  @override
  SynchronousFuture<WebCacheTileImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) =>
      SynchronousFuture(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WebCacheTileImageProvider &&
          url == other.url &&
          fallbackUrl == other.fallbackUrl &&
          mapEquals(headers, other.headers));

  @override
  int get hashCode => Object.hash(
        url,
        fallbackUrl,
        Object.hashAllUnordered(
          headers.entries.map((e) => Object.hash(e.key, e.value)),
        ),
      );
}
