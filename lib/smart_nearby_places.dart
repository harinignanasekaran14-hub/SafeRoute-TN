// ============================================================================
// SafeRoute TN — Smart Nearby Safety Places
// Module: lib/smart_nearby_places.dart
// Description: Smart, responsive, bilingual nearby-places panel showcasing REAL
//              nearby facilities (hospitals, police, pharmacies, petrol, EV,
//              ATMs, food, hotels, parking, restrooms) along the user's route.
//              Strictly deterministic rule-based evaluation using OpenStreetMap.
//              Zero fake places, fake ratings, or fabricated phone numbers.
//              No live GPS tracking. No persistent location history.
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'main.dart';
import 'personal_safety_profile.dart';

// ============================================================================
// 1. DATA MODEL
// ============================================================================

class NearbySafetyPlace {
  final String id;
  final String name;
  final String category;
  final double latitude;
  final double longitude;
  final String? address;
  final String? phone;
  final String? openingHours;
  final double distanceKm;
  final bool isAlongRoute;
  final String? osmType;
  final Map<String, dynamic>? osmTags;

  const NearbySafetyPlace({
    required this.id,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.address,
    this.phone,
    this.openingHours,
    required this.distanceKm,
    required this.isAlongRoute,
    this.osmType,
    this.osmTags,
  });

  /// True if a genuine phone number is present in the OSM tags
  bool get hasRealPhone => phone != null && phone!.trim().isNotEmpty;

  /// True if OSM explicitly tags wheelchair accessibility
  bool get isAccessible {
    if (osmTags == null) return false;
    final wc = osmTags!['wheelchair']?.toString().toLowerCase().trim();
    return wc == 'yes' || wc == 'designated';
  }

  /// Wheelchair tag explanation or null if unavailable
  String? get accessibilityInfo {
    if (osmTags == null) return null;
    final wc = osmTags!['wheelchair']?.toString().toLowerCase().trim();
    if (wc == 'yes' || wc == 'designated') return 'Wheelchair accessible';
    if (wc == 'limited') return 'Partially accessible';
    if (wc == 'no') return 'Not wheelchair accessible';
    return null;
  }

  /// Formatted distance string (< 1 km => meters, >= 1 km => km)
  String get formattedDistance {
    if (distanceKm < 1.0) {
      final meters = (distanceKm * 1000).round();
      return '$meters m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  IconData get categoryIcon {
    return switch (category.toLowerCase()) {
      'hospital' => Icons.local_hospital_rounded,
      'police' => Icons.local_police_rounded,
      'pharmacy' => Icons.medication_rounded,
      'petrol' || 'fuel' => Icons.local_gas_station_rounded,
      'ev' || 'charging_station' => Icons.ev_station_rounded,
      'atm' || 'bank' => Icons.atm_rounded,
      'restaurant' || 'food' => Icons.restaurant_rounded,
      'hotel' => Icons.hotel_rounded,
      'parking' => Icons.local_parking_rounded,
      'restroom' || 'toilets' => Icons.wc_rounded,
      _ => Icons.place_rounded,
    };
  }

  Color get categoryColor {
    return switch (category.toLowerCase()) {
      'hospital' => const Color(0xffE11D48),
      'police' => const Color(0xff2563EB),
      'pharmacy' => const Color(0xff059669),
      'petrol' || 'fuel' => const Color(0xffD97706),
      'ev' || 'charging_station' => const Color(0xff0891B2),
      'atm' || 'bank' => const Color(0xff7C3AED),
      'restaurant' || 'food' => const Color(0xffEA580C),
      'hotel' => const Color(0xff4F46E5),
      'parking' => const Color(0xff475569),
      'restroom' || 'toilets' => const Color(0xffDB2777),
      _ => NeonTheme.neonCyan,
    };
  }

  String categoryDisplayLabel(bool isTamil) {
    return SmartNearbyPlacesLocalization.categoryName(category, isTamil);
  }

  NearbySafetyPlace copyWith({
    String? id,
    String? name,
    String? category,
    double? latitude,
    double? longitude,
    String? address,
    String? phone,
    String? openingHours,
    double? distanceKm,
    bool? isAlongRoute,
    String? osmType,
    Map<String, dynamic>? osmTags,
  }) {
    return NearbySafetyPlace(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      openingHours: openingHours ?? this.openingHours,
      distanceKm: distanceKm ?? this.distanceKm,
      isAlongRoute: isAlongRoute ?? this.isAlongRoute,
      osmType: osmType ?? this.osmType,
      osmTags: osmTags ?? this.osmTags,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'latitude': latitude,
    'longitude': longitude,
    if (address != null) 'address': address,
    if (phone != null) 'phone': phone,
    if (openingHours != null) 'opening_hours': openingHours,
    'distance_km': distanceKm,
    'is_along_route': isAlongRoute,
    if (osmType != null) 'osm_type': osmType,
    if (osmTags != null) 'osm_tags': osmTags,
  };

  factory NearbySafetyPlace.fromJson(Map<String, dynamic> json) {
    return NearbySafetyPlace(
      id: json['id'] as String? ?? UniqueKey().toString(),
      name: json['name'] as String? ?? 'Facility',
      category: json['category'] as String? ?? 'hospital',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      openingHours: (json['opening_hours'] ?? json['openingHours']) as String?,
      distanceKm:
          ((json['distance_km'] ?? json['distanceKm']) as num?)?.toDouble() ??
          0.0,
      isAlongRoute:
          (json['is_along_route'] ?? json['isAlongRoute']) as bool? ?? false,
      osmType: (json['osm_type'] ?? json['osmType']) as String?,
      osmTags: json['osm_tags'] != null
          ? Map<String, dynamic>.from(json['osm_tags'] as Map)
          : (json['osmTags'] != null
                ? Map<String, dynamic>.from(json['osmTags'] as Map)
                : null),
    );
  }

  /// Converts an existing SafeRoute TN `Facility` model
  factory NearbySafetyPlace.fromFacility(
    Facility facility, {
    required double distanceKm,
    required bool isAlongRoute,
  }) {
    final cleanCategory = switch (facility.categoryId) {
      'fuel' => 'petrol',
      'charging_station' => 'ev',
      'toilets' => 'restroom',
      _ => facility.categoryId,
    };

    final fallbackName = SmartNearbyPlacesLocalization.categoryName(
      cleanCategory,
      false,
    );
    final placeName =
        (facility.name != null && facility.name!.trim().isNotEmpty)
        ? facility.name!.trim()
        : fallbackName;

    final tags = <String, dynamic>{};
    if (facility.wheelchair != null) {
      tags['wheelchair'] = facility.wheelchair;
    }
    if (facility.openingHours != null) {
      tags['opening_hours'] = facility.openingHours;
    }
    if (facility.emergency != null) {
      tags['emergency'] = facility.emergency;
    }
    if (facility.brand != null) {
      tags['brand'] = facility.brand;
    }
    if (facility.operator != null) {
      tags['operator'] = facility.operator;
    }

    return NearbySafetyPlace(
      id: facility.id,
      name: placeName,
      category: cleanCategory,
      latitude: facility.lat,
      longitude: facility.lon,
      address: facility.address,
      phone: facility.phone,
      openingHours: facility.openingHours,
      distanceKm: distanceKm,
      isAlongRoute: isAlongRoute,
      osmType: facility.id.contains('/')
          ? facility.id.split('/').first
          : 'node',
      osmTags: tags.isNotEmpty ? tags : null,
    );
  }
}

// ============================================================================
// 2. GEOGRAPHICAL & PROXIMITY CALCULATIONS
// ============================================================================

class NearbyGeoUtils {
  /// Standard Haversine distance in kilometers between two coordinates
  static double haversineDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = (lat2 - lat1) * (math.pi / 180.0);
    final dLon = (lon2 - lon1) * (math.pi / 180.0);
    final rLat1 = lat1 * (math.pi / 180.0);
    final rLat2 = lat2 * (math.pi / 180.0);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rLat1) *
            math.cos(rLat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// Calculates minimum distance from a coordinate to any point along the route
  static double minDistanceToRouteKm(
    double lat,
    double lon,
    List<LatLng> routePoints,
  ) {
    if (routePoints.isEmpty) return double.infinity;

    double minDist = double.infinity;
    // Sample points along route to keep performance high
    final step = (routePoints.length / 100).ceil().clamp(1, 10);
    for (int i = 0; i < routePoints.length; i += step) {
      final pt = routePoints[i];
      final dist = haversineDistanceKm(lat, lon, pt.latitude, pt.longitude);
      if (dist < minDist) minDist = dist;
    }

    // Always include the last point
    final lastPt = routePoints.last;
    final lastDist = haversineDistanceKm(
      lat,
      lon,
      lastPt.latitude,
      lastPt.longitude,
    );
    if (lastDist < minDist) minDist = lastDist;

    return minDist;
  }

  /// Determines whether a coordinate is considered "along route" based on proximity threshold
  static bool isPointAlongRoute(
    double lat,
    double lon,
    List<LatLng> routePoints, {
    double thresholdKm = 1.0,
  }) {
    if (routePoints.isEmpty) return false;
    final dist = minDistanceToRouteKm(lat, lon, routePoints);
    return dist <= thresholdKm;
  }
}

// ============================================================================
// 3. DETERMINISTIC SMART PRIORITY RANKER
// ============================================================================

enum NearbySortMode {
  safetyPriority,
  nearest,
  alongRoute;

  String label(bool isTamil) => switch (this) {
    NearbySortMode.safetyPriority =>
      isTamil ? 'பாதுகாப்பு முன்னுரிமை' : 'Safety Priority',
    NearbySortMode.nearest => isTamil ? 'அருகிலுள்ளவை' : 'Nearest',
    NearbySortMode.alongRoute => isTamil ? 'வழியில் அருகில்' : 'Along Route',
  };
}

class SmartPriorityRanker {
  /// Deterministic score calculation without external AI
  static double computeScore(
    NearbySafetyPlace place, {
    PersonalSafetyProfile? profile,
    bool isNight = false,
    bool isEmergencyMode = false,
  }) {
    double score = 0.0;

    // 1. Emergency Mode Prioritization
    if (isEmergencyMode) {
      if (place.category == 'hospital') score += 100.0;
      if (place.category == 'police') score += 90.0;
      if (place.category == 'pharmacy') score += 80.0;
      // Proximity is critical in emergency
      score += place.isAlongRoute ? 25.0 : 0.0;
      score -= place.distanceKm * 3.0;
      return score;
    }

    // 2. Base Category Weights
    score += switch (place.category) {
      'hospital' => 50.0,
      'police' => 45.0,
      'pharmacy' => 40.0,
      'petrol' => 35.0,
      'ev' => 30.0,
      'restroom' => 28.0,
      'atm' => 22.0,
      'restaurant' => 20.0,
      'hotel' => 18.0,
      'parking' => 16.0,
      _ => 10.0,
    };

    // 3. Along-route bonus
    if (place.isAlongRoute) {
      score += 30.0;
    }

    // 4. Night Travel Context
    if (isNight) {
      if (place.category == 'hospital') score += 20.0;
      if (place.category == 'police') score += 20.0;
      if (place.category == 'pharmacy') score += 15.0;
      if (place.category == 'petrol') score += 15.0;
      if (place.category == 'hotel') score += 15.0;
    }

    // 5. Personal Safety Profile Context
    if (profile != null) {
      // Vehicle mode adjustments
      final mode = profile.vehicleMode;
      if (mode == 'Car') {
        if (place.category == 'petrol' || place.category == 'parking') {
          score += 15.0;
        }
      } else if (mode == 'Bike') {
        if (place.category == 'petrol' || place.category == 'pharmacy') {
          score += 15.0;
        }
      } else if (mode == 'Walk') {
        if (place.category == 'restroom' || place.category == 'pharmacy') {
          score += 20.0;
        }
        if (place.category == 'restaurant') {
          score += 10.0;
        }
      }

      // Travel purpose adjustments
      final purpose = profile.travelPurpose;
      if (purpose == 'Long-distance travel') {
        if (place.category == 'petrol' ||
            place.category == 'restroom' ||
            place.category == 'hotel') {
          score += 20.0;
        }
      } else if (purpose == 'Family travel') {
        if (place.category == 'hospital' ||
            place.category == 'pharmacy' ||
            place.category == 'restroom') {
          score += 20.0;
        }
      }

      // Accessibility preference
      if (profile.accessibilityPreference == 'Prefer accessible routes' &&
          place.isAccessible) {
        score += 25.0;
      }
    }

    // 6. Proximity penalty: places further away score lower
    score -= place.distanceKm * 1.5;

    return score;
  }

  /// Sorts a list of places deterministically based on selected mode
  static List<NearbySafetyPlace> sortPlaces(
    List<NearbySafetyPlace> places,
    NearbySortMode mode, {
    PersonalSafetyProfile? profile,
    bool isNight = false,
    bool isEmergencyMode = false,
  }) {
    final list = List<NearbySafetyPlace>.from(places);

    switch (mode) {
      case NearbySortMode.nearest:
        list.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        break;

      case NearbySortMode.alongRoute:
        list.sort((a, b) {
          if (a.isAlongRoute != b.isAlongRoute) {
            return a.isAlongRoute ? -1 : 1;
          }
          return a.distanceKm.compareTo(b.distanceKm);
        });
        break;

      case NearbySortMode.safetyPriority:
        list.sort((a, b) {
          final scoreA = computeScore(
            a,
            profile: profile,
            isNight: isNight,
            isEmergencyMode: isEmergencyMode,
          );
          final scoreB = computeScore(
            b,
            profile: profile,
            isNight: isNight,
            isEmergencyMode: isEmergencyMode,
          );
          return scoreB.compareTo(scoreA); // Highest score first
        });
        break;
    }

    return list;
  }
}

// ============================================================================
// 4. IN-MEMORY CACHE & OVERPASS SERVICE
// ============================================================================

class NearbyPlacesCache {
  static final Map<String, _CacheEntry> _cache = {};
  static const Duration ttl = Duration(minutes: 5);

  static List<NearbySafetyPlace>? get(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiry)) {
      _cache.remove(key);
      return null;
    }
    return entry.places;
  }

  static void set(String key, List<NearbySafetyPlace> places) {
    _cache[key] = _CacheEntry(places: places, expiry: DateTime.now().add(ttl));
  }

  static void clear() {
    _cache.clear();
  }
}

class _CacheEntry {
  final List<NearbySafetyPlace> places;
  final DateTime expiry;

  _CacheEntry({required this.places, required this.expiry});
}

class NearbyPlacesService {
  static final Set<String> _activeRequests = {};
  static const List<String> endpoints = [
    'overpass.openstreetmap.fr',
    'overpass-api.de',
    'overpass.kumi.systems',
  ];

  /// Fetches real nearby places from Overpass API along the given route points
  static Future<List<NearbySafetyPlace>> fetchNearbyPlaces({
    required List<LatLng> routePoints,
    List<String>? categories,
    double proximityThresholdKm = 1.0,
    http.Client? client,
  }) async {
    if (routePoints.isEmpty) return [];

    // Cache key based on route bounds
    final cacheKey = _generateRouteKey(routePoints, categories);
    final cached = NearbyPlacesCache.get(cacheKey);
    if (cached != null) return cached;

    // Prevent duplicate simultaneous requests
    if (_activeRequests.contains(cacheKey)) {
      debugPrint(
        'Nearby places query already in flight for this corridor; skipping duplicate.',
      );
      return [];
    }

    _activeRequests.add(cacheKey);
    final httpClient = client ?? http.Client();

    try {
      // 1. Try local backend first
      try {
        final backendUrl = Uri.parse('http://127.0.0.1:5000/nearby-places');
        final backendResp = await httpClient
            .post(
              backendUrl,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'points': routePoints
                    .map((p) => [p.latitude, p.longitude])
                    .toList(),
                'proximity_threshold_km': proximityThresholdKm,
                'categories': categories,
              }),
            )
            .timeout(const Duration(seconds: 8));

        if (backendResp.statusCode == 200) {
          final decoded = jsonDecode(backendResp.body);
          if (decoded is Map<String, dynamic> && decoded['places'] is List) {
            final placesList = decoded['places'] as List;
            final parsedPlaces = <NearbySafetyPlace>[];
            for (final item in placesList) {
              if (item is Map<String, dynamic>) {
                try {
                  parsedPlaces.add(NearbySafetyPlace.fromJson(item));
                } catch (_) {}
              }
            }
            if (parsedPlaces.isNotEmpty) {
              final hospitals = parsedPlaces
                  .where((p) => p.category == 'hospital')
                  .length;
              final police = parsedPlaces
                  .where((p) => p.category == 'police')
                  .length;
              final pharmacies = parsedPlaces
                  .where((p) => p.category == 'pharmacy')
                  .length;
              final fuel = parsedPlaces
                  .where((p) => p.category == 'petrol_pump')
                  .length;

              debugPrint('\n=== NEARBY DATA AUDIT ===');
              debugPrint(
                'Queried corridor chunks: ${decoded['audit']?['corridor_chunks'] ?? 5}',
              );
              debugPrint(
                'Raw POIs found: ${decoded['audit']?['raw_pois'] ?? parsedPlaces.length}',
              );
              debugPrint(
                'Deduplicated POIs: ${decoded['audit']?['deduplicated_pois'] ?? parsedPlaces.length}',
              );
              debugPrint('Matched along route: ${parsedPlaces.length}');
              debugPrint('Hospitals: $hospitals');
              debugPrint('Police: $police');
              debugPrint('Pharmacies: $pharmacies');
              debugPrint('Fuel: $fuel');
              debugPrint('=========================\n');

              NearbyPlacesCache.set(cacheKey, parsedPlaces);
              return parsedPlaces;
            }
          }
        }
      } catch (backendErr) {
        // Fall back to direct Overpass
      }

      final query = _buildOverpassQuery(routePoints);
      final rawData = await _executeOverpassQuery(query, httpClient);
      if (rawData == null || rawData['elements'] is! List) {
        debugPrint('\n=== NEARBY DATA AUDIT ===');
        debugPrint('Queried corridor chunks: 1');
        debugPrint('Raw POIs found: 0');
        debugPrint('Deduplicated POIs: 0');
        debugPrint('Matched along route: 0');
        debugPrint('Hospitals: 0');
        debugPrint('Police: 0');
        debugPrint('Pharmacies: 0');
        debugPrint('Fuel: 0');
        debugPrint('=========================\n');
        return [];
      }

      final elements = rawData['elements'] as List;
      final places = <NearbySafetyPlace>[];
      final seenIds = <String>{};

      for (final el in elements) {
        if (el is! Map<String, dynamic>) continue;
        final place = parseOsmElement(
          el,
          routePoints: routePoints,
          proximityThresholdKm: proximityThresholdKm,
        );
        if (place != null && seenIds.add(place.id)) {
          places.add(place);
        }
      }

      final hospitals = places.where((p) => p.category == 'hospital').length;
      final police = places.where((p) => p.category == 'police').length;
      final pharmacies = places.where((p) => p.category == 'pharmacy').length;
      final fuel = places.where((p) => p.category == 'petrol_pump').length;

      debugPrint('\n=== NEARBY DATA AUDIT ===');
      debugPrint('Queried corridor chunks: 1');
      debugPrint('Raw POIs found: ${elements.length}');
      debugPrint('Deduplicated POIs: ${seenIds.length}');
      debugPrint('Matched along route: ${places.length}');
      debugPrint('Hospitals: $hospitals');
      debugPrint('Police: $police');
      debugPrint('Pharmacies: $pharmacies');
      debugPrint('Fuel: $fuel');
      debugPrint('=========================\n');

      // Cache result for 5 minutes
      NearbyPlacesCache.set(cacheKey, places);
      return places;
    } catch (e) {
      debugPrint('Error fetching nearby places from Overpass: $e');
      return [];
    } finally {
      _activeRequests.remove(cacheKey);
      if (client == null) httpClient.close();
    }
  }

  static String _generateRouteKey(
    List<LatLng> points,
    List<String>? categories,
  ) {
    if (points.isEmpty) return 'empty';
    final pStart = points.first;
    final pEnd = points.last;
    final catKey = categories?.join(',') ?? 'all';
    return '${pStart.latitude.toStringAsFixed(3)},${pStart.longitude.toStringAsFixed(3)}_'
        '${pEnd.latitude.toStringAsFixed(3)},${pEnd.longitude.toStringAsFixed(3)}_$catKey';
  }

  static String _buildOverpassQuery(List<LatLng> routePoints) {
    if (routePoints.isEmpty) return '';

    double minLat = 90.0, maxLat = -90.0, minLon = 180.0, maxLon = -180.0;
    for (final pt in routePoints) {
      if (pt.latitude < minLat) minLat = pt.latitude;
      if (pt.latitude > maxLat) maxLat = pt.latitude;
      if (pt.longitude < minLon) minLon = pt.longitude;
      if (pt.longitude > maxLon) maxLon = pt.longitude;
    }

    if ((maxLat - minLat) > 0.25 || (maxLon - minLon) > 0.25) {
      final sampleCount = (routePoints.length < 5) ? routePoints.length : 5;
      final clauses = <String>[];
      for (var i = 0; i < sampleCount; i++) {
        final idx = (i * (routePoints.length - 1) / (sampleCount - 1)).round();
        final pt = routePoints[idx];
        clauses.add(
          'nwr["amenity"~"^(hospital|clinic|police|pharmacy|fuel|charging_station)\$"](around:2000,${pt.latitude.toStringAsFixed(5)},${pt.longitude.toStringAsFixed(5)});',
        );
      }
      return '[out:json][timeout:10];(${clauses.join()});out center 60;';
    }

    // Expand bounding box slightly (~1.5 km buffer)
    const buffer = 0.015;
    final s = (minLat - buffer).clamp(-90.0, 90.0).toStringAsFixed(5);
    final w = (minLon - buffer).clamp(-180.0, 180.0).toStringAsFixed(5);
    final n = (maxLat + buffer).clamp(-90.0, 90.0).toStringAsFixed(5);
    final e = (maxLon + buffer).clamp(-180.0, 180.0).toStringAsFixed(5);

    return '[out:json][timeout:12];'
        '('
        'nwr["amenity"~"^(hospital|clinic|police|pharmacy|fuel|charging_station|atm|bank|restaurant|fast_food|cafe|parking|toilets)\$"]($s,$w,$n,$e);'
        'nwr["tourism"~"^(hotel|motel|guest_house)\$"]($s,$w,$n,$e);'
        ');'
        'out center 80;';
  }

  static Future<Map<String, dynamic>?> _executeOverpassQuery(
    String query,
    http.Client client,
  ) async {
    for (final endpoint in endpoints) {
      try {
        final response = await client
            .post(
              Uri.parse('https://$endpoint/api/interpreter'),
              headers: {
                'Content-Type':
                    'application/x-www-form-urlencoded; charset=UTF-8',
                'User-Agent': 'SafeRouteTN/1.0',
              },
              body: {'data': query},
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map<String, dynamic>) return data;
        } else if (response.statusCode == 429 ||
            response.statusCode == 500 ||
            response.statusCode == 502 ||
            response.statusCode == 503 ||
            response.statusCode == 504) {
          debugPrint(
            'Overpass endpoint $endpoint returned HTTP ${response.statusCode}',
          );
          continue;
        }
      } catch (e) {
        debugPrint('Overpass request failed at $endpoint: $e');
      }
    }
    return null;
  }

  /// Parses a single OSM element safely into `NearbySafetyPlace`
  static NearbySafetyPlace? parseOsmElement(
    Map<String, dynamic> element, {
    required List<LatLng> routePoints,
    double proximityThresholdKm = 1.0,
  }) {
    final type = element['type']?.toString();
    final id = element['id']?.toString();
    final tags = element['tags'];

    if (id == null || tags is! Map<String, dynamic>) return null;

    final coords = type == 'node' ? element : element['center'];
    if (coords is! Map<String, dynamic>) return null;
    final lat = (coords['lat'] as num?)?.toDouble();
    final lon = (coords['lon'] as num?)?.toDouble();

    if (lat == null || lon == null || !lat.isFinite || !lon.isFinite) {
      return null;
    }

    // Determine category
    final amenity = tags['amenity']?.toString().toLowerCase().trim();
    final tourism = tags['tourism']?.toString().toLowerCase().trim();

    String? category;
    if (amenity == 'hospital' || amenity == 'clinic') {
      category = 'hospital';
    } else if (amenity == 'police') {
      category = 'police';
    } else if (amenity == 'pharmacy') {
      category = 'pharmacy';
    } else if (amenity == 'fuel') {
      category = 'petrol';
    } else if (amenity == 'charging_station') {
      category = 'ev';
    } else if (amenity == 'atm' || amenity == 'bank') {
      category = 'atm';
    } else if (amenity == 'restaurant' ||
        amenity == 'fast_food' ||
        amenity == 'cafe') {
      category = 'restaurant';
    } else if (amenity == 'parking') {
      category = 'parking';
    } else if (amenity == 'toilets') {
      category = 'restroom';
    } else if (tourism == 'hotel' ||
        tourism == 'motel' ||
        tourism == 'guest_house') {
      category = 'hotel';
    }

    if (category == null) return null;

    final rawName = tags['name']?.toString().trim();
    final name = (rawName != null && rawName.isNotEmpty)
        ? rawName
        : SmartNearbyPlacesLocalization.categoryName(category, false);

    final phone =
        tags['phone']?.toString().trim() ??
        tags['contact:phone']?.toString().trim();
    final openingHours = tags['opening_hours']?.toString().trim();

    final addressParts =
        [tags['addr:housenumber'], tags['addr:street'], tags['addr:city']]
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

    final address =
        tags['addr:full']?.toString().trim() ??
        (addressParts.isNotEmpty ? addressParts.join(', ') : null);

    // Distance calculation relative to route start / first point
    final refPoint = routePoints.isNotEmpty
        ? routePoints.first
        : LatLng(lat, lon);
    final distanceKm = NearbyGeoUtils.haversineDistanceKm(
      refPoint.latitude,
      refPoint.longitude,
      lat,
      lon,
    );

    final isAlong = NearbyGeoUtils.isPointAlongRoute(
      lat,
      lon,
      routePoints,
      thresholdKm: proximityThresholdKm,
    );

    return NearbySafetyPlace(
      id: '$type/$id',
      name: name,
      category: category,
      latitude: lat,
      longitude: lon,
      address: address,
      phone: phone,
      openingHours: openingHours,
      distanceKm: distanceKm,
      isAlongRoute: isAlong,
      osmType: type,
      osmTags: tags,
    );
  }
}

// ============================================================================
// 5. BILINGUAL LOCALIZATION
// ============================================================================

class SmartNearbyPlacesLocalization {
  static String title(bool isTamil) =>
      isTamil ? 'ஸ்மார்ட் அருகிலுள்ள இடங்கள்' : 'Smart Nearby Places';

  static String subtitle(bool isTamil) => isTamil
      ? 'உங்கள் பாதைக்கு அருகிலுள்ள அவசர மற்றும் பயண வசதிகள்'
      : 'Real nearby safety, emergency, and travel facilities along your route';

  static String nearbyYourRoute(bool isTamil) =>
      isTamil ? 'உங்கள் வழிக்கு அருகில்' : 'Nearby Your Route';

  static String emergencyNearby(bool isTamil) =>
      isTamil ? 'அவசர உதவி அருகில்' : 'Emergency Nearby';

  static String viewOnMap(bool isTamil) =>
      isTamil ? 'வரைபடத்தில் காண்க' : 'View on Map';

  static String directions(bool isTamil) =>
      isTamil ? 'வழிகாட்டுதல்' : 'Directions';

  static String call(bool isTamil) => isTamil ? 'அழைக்கவும்' : 'Call';

  static String refresh(bool isTamil) =>
      isTamil ? 'புதுப்பிக்கவும்' : 'Refresh';

  static String alongRouteBadge(bool isTamil) =>
      isTamil ? '✓ வழியில் அருகில்' : '✓ Near your route';

  static String offRouteBadge(bool isTamil) =>
      isTamil ? 'வழியிலிருந்து தள்ளி' : 'Off-route';

  static String searchHint(bool isTamil) =>
      isTamil ? 'அருகிலுள்ள இடங்களைத் தேடுங்கள்...' : 'Search nearby places...';

  static String noNearbyPlaces(bool isTamil) =>
      isTamil ? 'அருகிலுள்ள இடங்கள் இல்லை.' : 'No nearby places found.';

  static String temporarilyUnavailable(bool isTamil) => isTamil
      ? 'அருகிலுள்ள இடங்கள் தற்காலிகமாக கிடைக்கவில்லை.'
      : 'Nearby places are temporarily unavailable.';

  static String timeoutError(bool isTamil) => isTamil
      ? 'அருகிலுள்ள இடங்களை ஏற்ற முடியவில்லை. மீண்டும் முயற்சிக்கவும்.'
      : 'Could not load nearby places. Please try again.';

  static String invalidDataError(bool isTamil) => isTamil
      ? 'இடங்களின் தரவை வாசிக்க முடியவில்லை.'
      : 'Nearby place data could not be read.';

  static String planRoutePrompt(bool isTamil) => isTamil
      ? 'உங்கள் பயணத்தின் போது பயனுள்ள இடங்களை கண்டறிய முதலில் ஒரு வழியை திட்டமிடுங்கள்.'
      : 'Plan a route to discover useful places along your journey.';

  static String planARoute(bool isTamil) =>
      isTamil ? 'வழியைத் திட்டமிடுங்கள்' : 'Plan a Route';

  static String exploreNearby(bool isTamil) =>
      isTamil ? 'அருகிலுள்ளவற்றை ஆராயுங்கள்' : 'Explore Nearby';

  static String backToRoute(bool isTamil) =>
      isTamil ? 'மீண்டும் பாதைக்கு' : 'Back to Route';

  static String categoryName(String category, bool isTamil) {
    return switch (category.toLowerCase()) {
      'hospital' => isTamil ? 'மருத்துவமனை' : 'Hospital',
      'police' => isTamil ? 'காவல் நிலையம்' : 'Police Station',
      'pharmacy' => isTamil ? 'மருந்தகம்' : 'Pharmacy',
      'petrol' || 'fuel' => isTamil ? 'பெட்ரோல் பங்க்' : 'Petrol Pump',
      'ev' ||
      'charging_station' => isTamil ? 'மின்சார சார்ஜிங்' : 'EV Charging',
      'atm' || 'bank' => isTamil ? 'ஏடிஎம்' : 'ATM',
      'restaurant' || 'food' => isTamil ? 'உணவகம்' : 'Restaurant',
      'hotel' => isTamil ? 'விடுதி' : 'Hotel',
      'parking' => isTamil ? 'வாகன நிறுத்துமிடம்' : 'Parking',
      'restroom' || 'toilets' => isTamil ? 'கழிப்பறை' : 'Restroom',
      _ => isTamil ? 'இடம்' : 'Place',
    };
  }

  static String categorySelectorLabel(String category, bool isTamil) {
    return switch (category.toLowerCase()) {
      'all' => isTamil ? 'அனைத்தும்' : 'All',
      'hospital' => isTamil ? '🏥 மருத்துவமனை' : '🏥 Hospital',
      'police' => isTamil ? '🚓 காவல்' : '🚓 Police',
      'pharmacy' => isTamil ? '💊 மருந்தகம்' : '💊 Pharmacy',
      'petrol' => isTamil ? '⛽ பெட்ரோல்' : '⛽ Petrol',
      'ev' => isTamil ? '🔋 EV' : '🔋 EV',
      'atm' => isTamil ? '🏧 ஏடிஎம்' : '🏧 ATM',
      'restaurant' => isTamil ? '🍽 உணவு' : '🍽 Food',
      'hotel' => isTamil ? '🏨 விடுதி' : '🏨 Hotel',
      'parking' => isTamil ? '🅿️ பார்க்கிங்' : '🅿️ Parking',
      'restroom' => isTamil ? '🚻 கழிப்பறை' : '🚻 Restroom',
      _ => category,
    };
  }
}

// ============================================================================
// 6. UI VIEW & CARDS
// ============================================================================

class SmartNearbyPlacesView extends StatefulWidget {
  final bool isDarkMode;
  final List<LatLng> routePoints;
  final List<Facility>? activeFacilities;
  final PersonalSafetyProfile? personalProfile;
  final bool initialEmergencyMode;
  final void Function(NearbySafetyPlace place)? onViewOnMap;
  final void Function(NearbySafetyPlace place)? onDirections;
  final VoidCallback? onPlanRoute;

  const SmartNearbyPlacesView({
    super.key,
    required this.isDarkMode,
    required this.routePoints,
    this.activeFacilities,
    this.personalProfile,
    this.initialEmergencyMode = false,
    this.onViewOnMap,
    this.onDirections,
    this.onPlanRoute,
  });

  @override
  State<SmartNearbyPlacesView> createState() => _SmartNearbyPlacesViewState();
}

class _SmartNearbyPlacesViewState extends State<SmartNearbyPlacesView> {
  bool _isLoading = false;
  bool _isTamil = false;
  late bool _isEmergencyMode;
  String _selectedCategory = 'all';
  NearbySortMode _sortMode = NearbySortMode.safetyPriority;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<NearbySafetyPlace> _allPlaces = [];
  String? _errorMessage;

  static const List<String> _categoryFilters = [
    'all',
    'hospital',
    'police',
    'pharmacy',
    'petrol',
    'ev',
    'atm',
    'restaurant',
    'hotel',
    'parking',
    'restroom',
  ];

  @override
  void initState() {
    super.initState();
    _isEmergencyMode = widget.initialEmergencyMode;
    if (_isEmergencyMode) {
      _selectedCategory = 'all';
    }
    _loadPlaces();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPlaces({bool forceRefresh = false}) async {
    if (widget.routePoints.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (forceRefresh) {
      NearbyPlacesCache.clear();
    }

    // 1. If activeFacilities already present from the map planner and not forced refresh, convert them!
    if (!forceRefresh &&
        widget.activeFacilities != null &&
        widget.activeFacilities!.isNotEmpty) {
      final converted = widget.activeFacilities!.map((f) {
        final dist = NearbyGeoUtils.haversineDistanceKm(
          widget.routePoints.first.latitude,
          widget.routePoints.first.longitude,
          f.lat,
          f.lon,
        );
        final isAlong = NearbyGeoUtils.isPointAlongRoute(
          f.lat,
          f.lon,
          widget.routePoints,
        );
        return NearbySafetyPlace.fromFacility(
          f,
          distanceKm: dist,
          isAlongRoute: isAlong,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _allPlaces = converted;
          _isLoading = false;
        });
      }
      return;
    }

    // 2. Fetch directly from Overpass API
    final results = await NearbyPlacesService.fetchNearbyPlaces(
      routePoints: widget.routePoints,
    );

    if (mounted) {
      setState(() {
        _allPlaces = results;
        _isLoading = false;
        if (results.isEmpty) {
          _errorMessage =
              null; // Clean empty state, not necessarily API failure
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;

    // No Route Loaded State
    if (widget.routePoints.isEmpty) {
      return _buildNoRouteState(isDark);
    }

    // Filter & Sort
    var displayed = _allPlaces.where((p) {
      // 1. Emergency mode filter
      if (_isEmergencyMode) {
        if (p.category != 'hospital' &&
            p.category != 'police' &&
            p.category != 'pharmacy') {
          return false;
        }
      }

      // 2. Category filter
      if (_selectedCategory != 'all' && p.category != _selectedCategory) {
        return false;
      }

      // 3. Search query
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchName = p.name.toLowerCase().contains(q);
        final matchCat = p.category.toLowerCase().contains(q);
        final matchAddr = p.address?.toLowerCase().contains(q) ?? false;
        if (!matchName && !matchCat && !matchAddr) return false;
      }

      return true;
    }).toList();

    displayed = SmartPriorityRanker.sortPlaces(
      displayed,
      _sortMode,
      profile: widget.personalProfile,
      isEmergencyMode: _isEmergencyMode,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: isDesktop
                ? _buildDesktopLayout(displayed, isDark)
                : _buildMobileLayout(displayed, isDark),
          ),
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // DESKTOP LAYOUT (2 Columns)
  // --------------------------------------------------------------------------

  Widget _buildDesktopLayout(List<NearbySafetyPlace> displayed, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Places, Filters, Search
        Expanded(
          flex: 7,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(isDark),
                const SizedBox(height: 16),
                _buildSearchAndFilters(isDark),
                const SizedBox(height: 16),
                _buildPlacesList(displayed, isDark),
              ],
            ),
          ),
        ),
        // Right Column: Corridor Safety Context Panel
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, 20, 20, 20),
            child: _buildRouteContextPanel(isDark),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // MOBILE LAYOUT (1 Column)
  // --------------------------------------------------------------------------

  Widget _buildMobileLayout(List<NearbySafetyPlace> displayed, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(isDark),
          const SizedBox(height: 14),
          _buildRouteSummaryChipBar(isDark),
          const SizedBox(height: 14),
          _buildSearchAndFilters(isDark),
          const SizedBox(height: 16),
          _buildPlacesList(displayed, isDark),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // HEADER
  // --------------------------------------------------------------------------

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? NeonTheme.cardDark : NeonTheme.cardLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isEmergencyMode
              ? NeonTheme.dangerRed.withValues(alpha: 0.6)
              : (isDark ? NeonTheme.cyanBorder : const Color(0x350284C7)),
          width: 1.2,
        ),
        boxShadow: _isEmergencyMode
            ? [
                BoxShadow(
                  color: NeonTheme.dangerRed.withValues(alpha: 0.25),
                  blurRadius: 14,
                ),
              ]
            : NeonTheme.cardShadow(isDark),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  (_isEmergencyMode ? NeonTheme.dangerRed : NeonTheme.neonCyan)
                      .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isEmergencyMode
                  ? Icons.emergency_rounded
                  : Icons.explore_rounded,
              color: _isEmergencyMode
                  ? NeonTheme.dangerRed
                  : NeonTheme.neonCyan,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEmergencyMode
                      ? SmartNearbyPlacesLocalization.emergencyNearby(_isTamil)
                      : SmartNearbyPlacesLocalization.title(_isTamil),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: isDark
                        ? NeonTheme.textPrimaryDark
                        : NeonTheme.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  SmartNearbyPlacesLocalization.subtitle(_isTamil),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? NeonTheme.textSecondaryDark
                        : NeonTheme.textSecondaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Emergency Mode Toggle
          IconButton(
            tooltip: 'Emergency Mode',
            onPressed: () {
              setState(() {
                _isEmergencyMode = !_isEmergencyMode;
              });
            },
            icon: Icon(
              Icons.warning_amber_rounded,
              color: _isEmergencyMode
                  ? NeonTheme.dangerRed
                  : (isDark ? Colors.white38 : Colors.black38),
            ),
            style: IconButton.styleFrom(
              backgroundColor: _isEmergencyMode
                  ? NeonTheme.dangerRed.withValues(alpha: 0.18)
                  : Colors.transparent,
            ),
          ),
          // Refresh Button
          IconButton(
            tooltip: SmartNearbyPlacesLocalization.refresh(_isTamil),
            onPressed: _isLoading
                ? null
                : () => _loadPlaces(forceRefresh: true),
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: NeonTheme.neonCyan,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, size: 20),
          ),
          // Language Toggle
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? NeonTheme.cardElevatedDark
                  : const Color(0xffF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLangBtn('EN', !_isTamil, isDark),
                _buildLangBtn('தமிழ்', _isTamil, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLangBtn(String text, bool isSelected, bool isDark) {
    return InkWell(
      onTap: () => setState(() => _isTamil = text == 'தமிழ்'),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? NeonTheme.neonCyan : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            color: isSelected
                ? Colors.black
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // SEARCH & CATEGORY FILTERS
  // --------------------------------------------------------------------------

  Widget _buildSearchAndFilters(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search Bar & Sort Dropdown
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: SmartNearbyPlacesLocalization.searchHint(_isTamil),
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? NeonTheme.textSecondaryDark
                        : NeonTheme.textSecondaryLight,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  filled: true,
                  fillColor: isDark
                      ? NeonTheme.cardElevatedDark
                      : const Color(0xffF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Sort Mode Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? NeonTheme.cardElevatedDark
                    : const Color(0xffF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<NearbySortMode>(
                  value: _sortMode,
                  dropdownColor: isDark ? NeonTheme.cardDark : Colors.white,
                  icon: const Icon(Icons.sort_rounded, size: 18),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  items: NearbySortMode.values.map((mode) {
                    return DropdownMenuItem(
                      value: mode,
                      child: Text(mode.label(_isTamil)),
                    );
                  }).toList(),
                  onChanged: (newMode) {
                    if (newMode != null) setState(() => _sortMode = newMode);
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Horizontal Scrollable Category Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final cat in _categoryFilters) ...[
                _buildCategoryFilterChip(cat, isDark),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryFilterChip(String cat, bool isDark) {
    final isSelected = _selectedCategory == cat;
    final label = SmartNearbyPlacesLocalization.categorySelectorLabel(
      cat,
      _isTamil,
    );

    return InkWell(
      onTap: () => setState(() => _selectedCategory = cat),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? NeonTheme.neonCyan.withValues(alpha: 0.18)
              : (isDark ? NeonTheme.cardDark : NeonTheme.cardLight),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: isSelected
                ? NeonTheme.neonCyan
                : (isDark ? Colors.white10 : Colors.black12),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? NeonTheme.neonCyan
                : (isDark
                      ? NeonTheme.textSecondaryDark
                      : NeonTheme.textSecondaryLight),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // PLACES LIST
  // --------------------------------------------------------------------------

  Widget _buildPlacesList(List<NearbySafetyPlace> displayed, bool isDark) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        child: const Column(
          children: [
            CircularProgressIndicator(color: NeonTheme.neonCyan),
            SizedBox(height: 14),
            Text(
              'Finding real facilities along your route...',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (displayed.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: isDark ? NeonTheme.cardDark : NeonTheme.cardLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.place_outlined,
                size: 36,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage ??
                    SmartNearbyPlacesLocalization.noNearbyPlaces(_isTamil),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? NeonTheme.textPrimaryDark
                      : NeonTheme.textPrimaryLight,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final place in displayed) ...[
          NearbyPlaceCard(
            place: place,
            isDark: isDark,
            isTamil: _isTamil,
            onViewOnMap: () => widget.onViewOnMap?.call(place),
            onDirections: () => widget.onDirections?.call(place),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  // --------------------------------------------------------------------------
  // ROUTE CONTEXT PANEL (Desktop Right Column)
  // --------------------------------------------------------------------------

  Widget _buildRouteContextPanel(bool isDark) {
    final counts = <String, int>{};
    for (final p in _allPlaces) {
      counts[p.category] = (counts[p.category] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? NeonTheme.cardDark : NeonTheme.cardLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? NeonTheme.cyanBorder : const Color(0x350284C7),
          width: 1.2,
        ),
        boxShadow: NeonTheme.cardShadow(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shield_rounded,
                color: NeonTheme.safeGreen,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                SmartNearbyPlacesLocalization.nearbyYourRoute(_isTamil),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Real facilities discovered along route corridor:',
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? NeonTheme.textSecondaryDark
                  : NeonTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final cat in _categoryFilters.where((c) => c != 'all'))
                _buildCountBadge(cat, counts[cat] ?? 0, isDark),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: NeonTheme.safeGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: NeonTheme.safeGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  color: NeonTheme.safeGreen,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'All facilities are sourced from OpenStreetMap without simulated locations or fake phone numbers.',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountBadge(String category, int count, bool isDark) {
    final label = SmartNearbyPlacesLocalization.categoryName(
      category,
      _isTamil,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? NeonTheme.cardElevatedDark : const Color(0xffF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: count > 0
              ? (isDark ? Colors.white : Colors.black87)
              : Colors.white38,
        ),
      ),
    );
  }

  Widget _buildRouteSummaryChipBar(bool isDark) {
    final counts = <String, int>{};
    for (final p in _allPlaces) {
      counts[p.category] = (counts[p.category] ?? 0) + 1;
    }

    final topCategories = [
      'hospital',
      'police',
      'petrol',
      'restaurant',
      'pharmacy',
    ].where((c) => (counts[c] ?? 0) > 0).toList();

    if (topCategories.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final cat in topCategories) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? NeonTheme.cardDark : NeonTheme.cardLight,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
              child: Text(
                '${counts[cat]} ${SmartNearbyPlacesLocalization.categoryName(cat, _isTamil)}',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // EMPTY STATE (No Route)
  // --------------------------------------------------------------------------

  Widget _buildNoRouteState(bool isDark) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(36),
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: isDark ? NeonTheme.cardDark : NeonTheme.cardLight,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? NeonTheme.cyanBorder : const Color(0x350284C7),
            width: 1.2,
          ),
          boxShadow: NeonTheme.cardShadow(isDark),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: NeonTheme.neonCyan.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(color: NeonTheme.neonCyan, width: 1.5),
              ),
              child: const Center(
                child: Icon(
                  Icons.alt_route_rounded,
                  size: 36,
                  color: NeonTheme.neonCyan,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              SmartNearbyPlacesLocalization.title(_isTamil),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: isDark
                    ? NeonTheme.textPrimaryDark
                    : NeonTheme.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              SmartNearbyPlacesLocalization.planRoutePrompt(_isTamil),
              style: TextStyle(
                fontSize: 12.5,
                color: isDark
                    ? NeonTheme.textSecondaryDark
                    : NeonTheme.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: widget.onPlanRoute,
              icon: const Icon(Icons.explore_rounded, size: 16),
              label: Text(
                SmartNearbyPlacesLocalization.planARoute(_isTamil),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: NeonTheme.neonCyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 7. PLACE CARD COMPONENT
// ============================================================================

class NearbyPlaceCard extends StatelessWidget {
  final NearbySafetyPlace place;
  final bool isDark;
  final bool isTamil;
  final VoidCallback? onViewOnMap;
  final VoidCallback? onDirections;

  const NearbyPlaceCard({
    super.key,
    required this.place,
    required this.isDark,
    required this.isTamil,
    this.onViewOnMap,
    this.onDirections,
  });

  Future<void> _makePhoneCall(String phoneNumber) async {
    final clean = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$clean');
    try {
      await launchUrl(uri);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final color = place.categoryColor;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? NeonTheme.cardDark : NeonTheme.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: place.isAlongRoute
              ? color.withValues(alpha: isDark ? 0.45 : 0.35)
              : (isDark ? Colors.white10 : Colors.black12),
          width: 1.1,
        ),
        boxShadow: NeonTheme.cardShadow(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Category Icon, Name, Category Pill, Distance
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Icon(place.categoryIcon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          place.categoryDisplayLabel(isTamil),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '· ${place.formattedDistance}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? NeonTheme.textSecondaryDark
                                : NeonTheme.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Along Route Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: place.isAlongRoute
                      ? NeonTheme.safeGreen.withValues(alpha: 0.15)
                      : (isDark
                            ? Colors.white10
                            : Colors.black.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: place.isAlongRoute
                        ? NeonTheme.safeGreen.withValues(alpha: 0.5)
                        : Colors.transparent,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  place.isAlongRoute
                      ? SmartNearbyPlacesLocalization.alongRouteBadge(isTamil)
                      : SmartNearbyPlacesLocalization.offRouteBadge(isTamil),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: place.isAlongRoute
                        ? NeonTheme.safeGreen
                        : (isDark
                              ? NeonTheme.textSecondaryDark
                              : NeonTheme.textSecondaryLight),
                  ),
                ),
              ),
            ],
          ),

          // Address if available
          if (place.address != null && place.address!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 13,
                  color: isDark
                      ? NeonTheme.textSecondaryDark
                      : NeonTheme.textSecondaryLight,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    place.address!,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? NeonTheme.textSecondaryDark
                          : NeonTheme.textSecondaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          // Accessibility info if available
          if (place.isAccessible) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.accessible_rounded,
                  size: 13,
                  color: NeonTheme.neonCyan,
                ),
                const SizedBox(width: 4),
                Text(
                  place.accessibilityInfo ?? 'Wheelchair accessible',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: NeonTheme.neonCyan,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 10),

          // Action Buttons: View on Map, Directions, Call (if real phone exists)
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onViewOnMap,
                icon: const Icon(Icons.map_rounded, size: 13),
                label: Text(
                  SmartNearbyPlacesLocalization.viewOnMap(isTamil),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: NeonTheme.neonCyan,
                  side: const BorderSide(color: NeonTheme.cyanBorder),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                onPressed: onDirections,
                icon: const Icon(Icons.directions_rounded, size: 13),
                label: Text(
                  SmartNearbyPlacesLocalization.directions(isTamil),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
              ),
              const Spacer(),
              // Real phone call button
              if (place.hasRealPhone)
                IconButton(
                  tooltip: 'Call ${place.phone}',
                  onPressed: () => _makePhoneCall(place.phone!),
                  icon: const Icon(
                    Icons.call_rounded,
                    size: 16,
                    color: NeonTheme.safeGreen,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: NeonTheme.safeGreen.withValues(
                      alpha: 0.14,
                    ),
                    padding: const EdgeInsets.all(8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
