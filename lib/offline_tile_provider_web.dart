import 'dart:async';
import 'dart:js_interop';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
// ignore: depend_on_referenced_packages
import 'package:web/web.dart' as web;

/// Browser CacheStorage name for passively viewed map tiles.
const String kTileCacheName = 'saferoute-viewed-tiles-v1';

/// Checks whether browser CacheStorage is supported.
bool get isBrowserCacheStorageSupported {
  try {
    final _ = web.window.caches;
    return true;
  } catch (_) {
    return false;
  }
}

/// Requests persistent storage permission from the browser where supported.
/// Returns true if persistent storage is granted or already active.
Future<bool> requestPersistentStoragePermission() async {
  try {
    final nav = web.window.navigator;
    final storage = nav.storage;
    final isPersisted = await storage.persisted().toDart;
    if (isPersisted.toDart) return true;
    final granted = await storage.persist().toDart;
    return granted.toDart;
  } catch (_) {
    return false;
  }
}

/// Returns the number of cached tile entries in the SafeRoute tile cache.
Future<int> getCachedTileCount() async {
  try {
    if (!isBrowserCacheStorageSupported) return 0;
    final cache = await web.window.caches.open(kTileCacheName).toDart;
    final keys = await cache.keys().toDart;
    return keys.toDart.length;
  } catch (_) {
    return 0;
  }
}

/// Clears only the SafeRoute tile cache. Unrelated browser caches are never touched.
Future<bool> clearTileCache() async {
  try {
    if (!isBrowserCacheStorageSupported) return false;
    final deleted = await web.window.caches.delete(kTileCacheName).toDart;
    return deleted.toDart;
  } catch (_) {
    return false;
  }
}

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

/// Tile provider using browser persistent CacheStorage for Flutter Web.
class WebCacheTileProvider extends TileProvider {
  /// Ephemeral in-memory tile cache store for unit tests and VM execution.
  /// NOTE: This is NOT persistent browser CacheStorage.
  final Map<String, Uint8List>? testCacheStore;

  /// Optional header metadata store for testing caching directives.
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

    // 0. Check testCacheStore if injected
    if (testCacheStore != null && testCacheStore!.containsKey(targetUrl)) {
      final testBytes = testCacheStore![targetUrl]!;
      final testHeaders = testHeadersStore?[targetUrl];

      final isFresh = testHeaders == null ||
          HttpCachePolicy.isFresh(
            cacheControl: testHeaders['cache-control'],
            expires: testHeaders['expires'],
            date: testHeaders['date'],
          );

      if (!isFresh) {
        testCacheStore?.remove(targetUrl);
        testHeadersStore?.remove(targetUrl);
      } else if (testBytes.isNotEmpty) {
        try {
          return await decodeBytes(testBytes);
        } catch (_) {
          testCacheStore?.remove(targetUrl);
          testHeadersStore?.remove(targetUrl);
        }
      }
    }

    // 1. Try retrieving from browser CacheStorage first (offline-capable)
    if (isBrowserCacheStorageSupported) {
      try {
        final cache = await web.window.caches.open(kTileCacheName).toDart;
        final cached = await cache.match(targetUrl.toJS).toDart;
        if (cached != null) {
          final ccHeader = cached.headers.get('cache-control');
          final expHeader = cached.headers.get('expires');
          final dateHeader = cached.headers.get('date');

          final isFresh = HttpCachePolicy.isFresh(
            cacheControl: ccHeader,
            expires: expHeader,
            date: dateHeader,
          );

          if (!isFresh) {
            // Expired entry: safely evict from cache and fall through to network
            unawaited(() async {
              try {
                await cache.delete(targetUrl.toJS).toDart;
              } catch (_) {}
            }());
          } else {
            final arrayBuffer = await cached.arrayBuffer().toDart;
            final bytes = arrayBuffer.toDart.asUint8List();
            if (bytes.isNotEmpty) {
              try {
                return await decodeBytes(bytes);
              } catch (_) {
                // Cached image data is corrupt: delete from cache
                unawaited(() async {
                  try {
                    await cache.delete(targetUrl.toJS).toDart;
                  } catch (_) {}
                }());
              }
            }
          }
        }
      } catch (_) {
        // CacheStorage read error; fall through to network attempt
      }
    }

    // 2. If simulating offline mode, return safe transparent tile
    if (simulateOffline) {
      evict();
      return await decodeBytes(TileProvider.transparentImage);
    }

    // 3. Fetch from network passing configured headers
    try {
      web.RequestInit? requestInit;
      if (headers.isNotEmpty) {
        final h = web.Headers();
        const forbidden = {
          'user-agent',
          'content-length',
          'host',
          'connection',
          'cookie'
        };
        headers.forEach((k, v) {
          if (!forbidden.contains(k.toLowerCase())) {
            try {
              h.append(k, v);
            } catch (_) {}
          }
        });
        requestInit = web.RequestInit(headers: h);
      }

      final fetchPromise = requestInit != null
          ? web.window.fetch(targetUrl.toJS, requestInit)
          : web.window.fetch(targetUrl.toJS);
      final response = await fetchPromise.toDart;

      if (response.status == 200) {
        final ccHeader = response.headers.get('cache-control');
        final expHeader = response.headers.get('expires');

        final canStore = HttpCachePolicy.isStorable(
          cacheControl: ccHeader,
          expires: expHeader,
        );

        if (canStore && isBrowserCacheStorageSupported) {
          final clone = response.clone();
          unawaited(() async {
            try {
              final cache = await web.window.caches.open(kTileCacheName).toDart;
              await cache.put(targetUrl.toJS, clone).toDart;
            } catch (_) {
              // Silently handle quota exceeded or storage denial
            }
          }());
        }

        final arrayBuffer = await response.arrayBuffer().toDart;
        final bytes = arrayBuffer.toDart.asUint8List();
        if (bytes.isNotEmpty) {
          return await decodeBytes(bytes);
        }
      }
    } catch (_) {
      // Network failure, offline mode, or fetch error
    }

    // 4. Fallback URL handling
    if (!useFallback && fallbackUrl != null && fallbackUrl!.isNotEmpty) {
      return _loadImage(
        key,
        chunkEvents,
        decode,
        useFallback: true,
      );
    }

    // 5. Missing tile when offline / error: return safe transparent tile
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
