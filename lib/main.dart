import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import 'dart:async';

void main() {
  runApp(const SafeRouteTN());
}

class SafeRouteTN extends StatefulWidget {
  const SafeRouteTN({super.key});

  @override
  State<SafeRouteTN> createState() => _SafeRouteTNState();
}

class _SafeRouteTNState extends State<SafeRouteTN> {
  bool isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SafeRoute TN',
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      themeAnimationDuration: const Duration(milliseconds: 350),
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff2563EB),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xffF4F8FB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xffF4F8FB),
          foregroundColor: Color(0xff172B3A),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xffE2EAF0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xffE2EAF0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xff2563EB), width: 1.5),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff65A9FF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xff101820),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xff101820),
          foregroundColor: Color(0xffEDF5FB),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xff1A2731),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xff30414D)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xff30414D)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xff65A9FF), width: 1.5),
          ),
        ),
      ),
      home: HomePage(
        onToggleTheme: () => setState(() => isDarkMode = !isDarkMode),
      ),
    );
  }
}

class _Location {
  final double lat;
  final double lon;
  final String name;

  _Location({required this.lat, required this.lon, required this.name});
}

class _RouteResult {
  final List<LatLng> points;
  final double distance;
  final double duration;
  final double? accessibilityScore;

  _RouteResult({
    required this.points,
    required this.distance,
    required this.duration,
    this.accessibilityScore,
  });
}

class _WeatherData {
  final double temperature;
  final double windSpeed;
  final double precipitation;
  final int weatherCode;

  _WeatherData({
    required this.temperature,
    required this.windSpeed,
    required this.precipitation,
    required this.weatherCode,
  });
}

class SafetyFactor {
  final String title;
  final IconData icon;
  final double score;

  SafetyFactor({required this.title, required this.icon, required this.score});
}

class SafeRouteService {
  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      debugPrint('Location service is disabled.');
      return null;
    }

    permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        debugPrint('Location permission denied.');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permission permanently denied.');
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    debugPrint(
      'CURRENT LOCATION: '
      '${position.latitude}, ${position.longitude}',
    );

    return position;
  }

  Future<_Location?> searchLocation(String place) async {
    try {
      final url = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': '$place, Tamil Nadu, India',
        'format': 'jsonv2',
        'limit': '1',
      });

      final response = await http.get(
        url,
        headers: {'User-Agent': 'SafeRouteTN/1.0 (Flutter Web project)'},
      );

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body);

      if (data is! List || data.isEmpty) {
        return null;
      }

      final item = data[0];

      return _Location(
        lat: double.parse(item['lat'].toString()),
        lon: double.parse(item['lon'].toString()),
        name: item['display_name'].toString(),
      );
    } catch (e) {
      debugPrint('LOCATION ERROR: $e');
      return null;
    }
  }

  Future<double> getLightingScore(List<LatLng> routePoints) async {
    try {
      if (routePoints.isEmpty) {
        return 50;
      }

      // Check 3 points instead of only the middle point
      final indexes = [0, routePoints.length ~/ 2, routePoints.length - 1];

      int streetLamps = 0;
      int litRoads = 0;

      for (final index in indexes.toSet()) {
        final point = routePoints[index];

        final lat = point.latitude;
        final lon = point.longitude;

        final query =
            '''
[out:json][timeout:15];

(
  node["highway"="street_lamp"]
    (around:500,$lat,$lon);

  way["highway"]["lit"="yes"]
    (around:500,$lat,$lon);
);

out tags;
''';

        final endpoints = [
          'https://overpass-api.de/api/interpreter',
          'https://overpass.kumi.systems/api/interpreter',
        ];

        bool success = false;

        for (final endpoint in endpoints) {
          try {
            final url = Uri.parse(
              '$endpoint?data=${Uri.encodeComponent(query)}',
            );

            final response = await http
                .get(url)
                .timeout(const Duration(seconds: 20));

            debugPrint('LIGHTING STATUS: ${response.statusCode}');

            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);

              final elements = data['elements'] as List<dynamic>? ?? [];

              for (final element in elements) {
                if (element['type'] == 'node') {
                  streetLamps++;
                } else if (element['type'] == 'way') {
                  litRoads++;
                }
              }

              success = true;
              break;
            }
          } catch (e) {
            debugPrint('Lighting endpoint failed: $e');
          }
        }

        if (!success) {
          debugPrint('Lighting data unavailable for point $index');
        }
      }

      final lightingObjects = streetLamps + (litRoads * 2);

      double score;

      if (lightingObjects >= 100) {
        score = 95;
      } else if (lightingObjects >= 50) {
        score = 85;
      } else if (lightingObjects >= 20) {
        score = 70;
      } else if (lightingObjects >= 5) {
        score = 50;
      } else {
        // Limited OSM lighting data
        score = 50;
      }

      debugPrint(
        'LIGHTING RESULT: '
        'lamps=$streetLamps, '
        'litRoads=$litRoads, '
        'score=$score',
      );

      return score;
    } catch (e) {
      debugPrint('LIGHTING ERROR: $e');

      // Do not show 0 when external data is temporarily unavailable
      return 50;
    }
  }

  Future<double> getAccessibilityScore(List<LatLng> routePoints) async {
    try {
      if (routePoints.isEmpty) {
        return 50;
      }

      final indexes = [0, routePoints.length ~/ 2, routePoints.length - 1];

      int sidewalk = 0;
      int wheelchair = 0;
      int tactile = 0;
      int crossings = 0;

      for (final index in indexes.toSet()) {
        final point = routePoints[index];

        final lat = point.latitude;
        final lon = point.longitude;

        final query =
            '''
[out:json][timeout:15];

(
  way["sidewalk"]
    (around:500,$lat,$lon);

  way["wheelchair"="yes"]
    (around:500,$lat,$lon);

  way["tactile_paving"="yes"]
    (around:500,$lat,$lon);

  node["crossing"]
    (around:500,$lat,$lon);
);

out tags;
''';

        final endpoints = [
          'https://overpass-api.de/api/interpreter',
          'https://overpass.kumi.systems/api/interpreter',
        ];

        bool success = false;

        for (final endpoint in endpoints) {
          try {
            final url = Uri.parse(
              '$endpoint?data=${Uri.encodeComponent(query)}',
            );

            final response = await http
                .get(url)
                .timeout(const Duration(seconds: 20));

            debugPrint('ACCESSIBILITY STATUS: ${response.statusCode}');

            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);

              final elements = data['elements'] as List<dynamic>? ?? [];

              for (final element in elements) {
                final tags = element['tags'] as Map<String, dynamic>? ?? {};

                if (tags.containsKey('sidewalk')) {
                  sidewalk++;
                }

                if (tags['wheelchair'] == 'yes') {
                  wheelchair++;
                }

                if (tags['tactile_paving'] == 'yes') {
                  tactile++;
                }

                if (tags.containsKey('crossing')) {
                  crossings++;
                }
              }

              success = true;
              break;
            }
          } catch (e) {
            debugPrint('Accessibility endpoint failed: $e');
          }
        }

        if (!success) {
          debugPrint('Accessibility data unavailable for point $index');
        }
      }

      final accessibilityObjects = sidewalk + wheelchair + tactile + crossings;

      double score;

      if (accessibilityObjects >= 100) {
        score = 95;
      } else if (accessibilityObjects >= 50) {
        score = 85;
      } else if (accessibilityObjects >= 20) {
        score = 70;
      } else if (accessibilityObjects >= 5) {
        score = 50;
      } else {
        // Limited OSM accessibility data
        score = 50;
      }

      debugPrint(
        'ACCESSIBILITY RESULT: '
        'sidewalk=$sidewalk, '
        'wheelchair=$wheelchair, '
        'tactile=$tactile, '
        'crossings=$crossings, '
        'score=$score',
      );

      return score;
    } catch (e) {
      debugPrint('ACCESSIBILITY ERROR: $e');

      // Do not show 0 when external data is temporarily unavailable
      return 50;
    }
  }

  Future<_RouteResult?> getRoute(
    _Location start,
    _Location end, {
    required String preference,
  }) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.lon},${start.lat};'
        '${end.lon},${end.lat}'
        '?overview=full&geometries=geojson&alternatives=true',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body);

      final routeData = data['routes'] as List<dynamic>?;
      if (routeData == null || routeData.isEmpty) {
        return null;
      }

      final routes = routeData.map((route) {
        final coordinates = route['geometry']['coordinates'] as List<dynamic>;
        final points = coordinates.map((point) {
          return LatLng(
            (point[1] as num).toDouble(),
            (point[0] as num).toDouble(),
          );
        }).toList();

        return _RouteResult(
          points: points,
          distance: (route['distance'] as num).toDouble() / 1000,
          duration: (route['duration'] as num).toDouble() / 60,
        );
      }).toList();

      switch (preference) {
        case 'Fastest Route':
        case 'Less Traffic':
          // OSRM's public route endpoint has no live traffic feed, so use
          // the quickest available alternative for both preferences.
          return routes.reduce((a, b) => a.duration <= b.duration ? a : b);
        case 'Shortest Route':
          return routes.reduce((a, b) => a.distance <= b.distance ? a : b);
        case 'Accessibility Friendly':
          var bestRoute = routes.first;
          var bestScore = await getAccessibilityScore(bestRoute.points);
          for (final route in routes.skip(1)) {
            final score = await getAccessibilityScore(route.points);
            if (score > bestScore) {
              bestRoute = route;
              bestScore = score;
            }
          }
          return _RouteResult(
            points: bestRoute.points,
            distance: bestRoute.distance,
            duration: bestRoute.duration,
            accessibilityScore: bestScore,
          );
        default:
          // Keep OSRM's existing recommended route for Safety First.
          return routes.first;
      }
    } catch (e) {
      return null;
    }
  }

  Future<_WeatherData?> getWeather(double latitude, double longitude) async {
    try {
      final url = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'current': 'temperature_2m,wind_speed_10m,precipitation,weather_code',
        'timezone': 'auto',
      });

      final response = await http.get(url);

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body);
      final current = data['current'];

      return _WeatherData(
        temperature: (current['temperature_2m'] as num).toDouble(),
        windSpeed: (current['wind_speed_10m'] as num).toDouble(),
        precipitation: (current['precipitation'] as num).toDouble(),
        weatherCode: (current['weather_code'] as num).toInt(),
      );
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> checkBlackspotProximity(
    double lat,
    double lon, {
    double radiusMeters = 1000.0,
  }) async {
    try {
      final url = Uri.parse(
        'http://127.0.0.1:5000/check-blackspot'
        '?lat=$lat&lon=$lon&radius_meters=$radiusMeters',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('BLACKSPOT CHECK ERROR: $e');
    }
    return null;
  }
}

class HomePage extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const HomePage({super.key, required this.onToggleTheme});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  final fromController = TextEditingController();
  final toController = TextEditingController();
  String selectedPreference = 'Safety First';

  late AnimationController animationController;

  @override
  void initState() {
    super.initState();

    animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    fromController.dispose();
    toController.dispose();
    animationController.dispose();
    super.dispose();
  }

  void searchRoute() {
    final from = fromController.text.trim();
    final to = toController.text.trim();

    if (from.isEmpty || to.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both From and To locations'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapPage(
          from: from,
          to: to,
          preference: selectedPreference,
          onToggleTheme: widget.onToggleTheme,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xff2563EB), Color(0xff7C3AED)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.shield_rounded, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text(
              'SafeRoute TN',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          if (wide)
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.home_rounded, size: 18),
              label: const Text('Home'),
            ),
          if (wide)
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AboutPage(onToggleTheme: widget.onToggleTheme),
                  ),
                );
              },
              icon: const Icon(Icons.info_outline_rounded, size: 18),
              label: const Text('About'),
            ),
          IconButton(
            tooltip: _isDarkMode ? 'Use light theme' : 'Use dark theme',
            onPressed: widget.onToggleTheme,
            icon: Icon(
              _isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final content = wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: _heroPanel(colors, wide: true)),
                    const SizedBox(width: 36),
                    Expanded(child: _searchCard()),
                  ],
                )
              : Column(
                  children: [
                    _heroPanel(colors, wide: false),
                    const SizedBox(height: 22),
                    _searchCard(),
                  ],
                );

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 56 : 20,
              vertical: wide ? 36 : 18,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1220),
                child: content,
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 900
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AboutPage(onToggleTheme: widget.onToggleTheme),
                      ),
                    );
                  },
                  icon: const Icon(Icons.info_outline_rounded, size: 18),
                  label: const Text('About SafeRoute TN'),
                ),
              ),
            )
          : null,
    );
  }

  Widget _heroPanel(ColorScheme colors, {required bool wide}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: wide ? 8 : 22,
        vertical: wide ? 30 : 22,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDarkMode
              ? const [Color(0xff172A35), Color(0xff1B2736)]
              : const [Color(0xffE7F7F8), Color(0xffEDF3FF)],
        ),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: wide
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: animationController,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, animationController.value * 6),
              child: child,
            ),
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(Icons.route_rounded, size: 40, color: colors.primary),
            ),
          ),
          const SizedBox(height: 26),
          Text(
            'A safer way\nto find your way.',
            textAlign: wide ? TextAlign.left : TextAlign.center,
            style: TextStyle(
              fontSize: wide ? 48 : 36,
              height: 1.12,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.4,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Thoughtful, accessible navigation for the roads of Tamil Nadu.',
            textAlign: wide ? TextAlign.left : TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.55,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: wide ? WrapAlignment.start : WrapAlignment.center,
            spacing: 9,
            runSpacing: 9,
            children: const [
              _FeatureChip(icon: Icons.shield_outlined, label: 'Safety aware'),
              _FeatureChip(icon: Icons.accessible_forward, label: 'Accessible'),
              _FeatureChip(icon: Icons.cloud_outlined, label: 'Live context'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _searchCard() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 620),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDarkMode ? 0.12 : 0.06),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Plan your journey',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Choose where to start and where you’re headed.',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: fromController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Starting point',
              hintText: 'Example: Salem',
              prefixIcon: Icon(
                Icons.trip_origin_rounded,
                color: Color(0xff36A889),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 27),
            child: Container(
              height: 18,
              width: 2,
              color: colors.outlineVariant,
            ),
          ),
          TextField(
            controller: toController,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => searchRoute(),
            decoration: const InputDecoration(
              labelText: 'Destination',
              hintText: 'Example: Chennai',
              prefixIcon: Icon(
                Icons.location_on_rounded,
                color: Color(0xffE46D72),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'ROUTE PREFERENCE',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w800,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(16),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedPreference,
                isExpanded: true,
                borderRadius: BorderRadius.circular(16),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Safety First',
                    child: _PreferenceItem(
                      icon: Icons.shield_rounded,
                      label: 'Safety First',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Fastest Route',
                    child: _PreferenceItem(
                      icon: Icons.speed_rounded,
                      label: 'Fastest Route',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Shortest Route',
                    child: _PreferenceItem(
                      icon: Icons.route_rounded,
                      label: 'Shortest Route',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Less Traffic',
                    child: _PreferenceItem(
                      icon: Icons.traffic_rounded,
                      label: 'Less Traffic',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Accessibility Friendly',
                    child: _PreferenceItem(
                      icon: Icons.accessible_rounded,
                      label: 'Accessibility Friendly',
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedPreference = value);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: searchRoute,
              icon: const Icon(Icons.search_rounded),
              label: const Text(
                'Find a safer route',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xff2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xff36A889)),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(fontSize: 12, color: colors.onSurface)),
        ],
      ),
    );
  }
}

class _PreferenceItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PreferenceItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 11),
        Text(label),
      ],
    );
  }
}

class MapPage extends StatefulWidget {
  final String from;
  final String to;
  final String preference;
  final VoidCallback onToggleTheme;

  const MapPage({
    super.key,
    required this.from,
    required this.to,
    required this.preference,
    required this.onToggleTheme,
  });

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  final SafeRouteService service = SafeRouteService();
  final MapController mapController = MapController();

  List<LatLng> routePoints = [];

  double distanceKm = 0;
  double durationMinutes = 0;

  double safetyScore = 0;
  double accidentSafety = 0;
  double roadSafety = 0;
  double weatherSafety = 90;
  double lightingSafety = 0;
  double accessibilitySafety = 0;
  Position? currentPosition;
  StreamSubscription<Position>? positionSubscription;
  bool _followMe = false;
  bool _mapReady = false;

  _WeatherData? weather;

  bool isNearBlackspot = false;
  double? blackspotDistanceMeters;
  Map<String, dynamic>? blackspotDetails;

  bool loading = true;
  String errorMessage = '';

  _Location? startLocation;
  _Location? endLocation;

  @override
  void initState() {
    super.initState();
    loadRoute();
  }

  Future<void> updateBlackspotProximity(Position position) async {
    final data = await service.checkBlackspotProximity(
      position.latitude,
      position.longitude,
    );

    if (data != null && mounted) {
      setState(() {
        isNearBlackspot = data['is_near_blackspot'] == true;
        final nearby = data['nearby_blackspots'] as List<dynamic>?;
        if (nearby != null && nearby.isNotEmpty) {
          blackspotDetails = nearby.first as Map<String, dynamic>;
          blackspotDistanceMeters =
              (blackspotDetails!['distance_meters'] as num?)?.toDouble();
        } else {
          final nearest = data['nearest_blackspot'] as Map<String, dynamic>?;
          blackspotDetails = nearest;
          blackspotDistanceMeters = (nearest?['distance_meters'] as num?)
              ?.toDouble();
        }
      });
    }
  }

  void startLiveTracking() {
    positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((Position position) {
          setState(() {
            currentPosition = position;
          });
          if (_followMe) {
            _centerMapOnPosition(position);
          }

          debugPrint(
            'LIVE LOCATION: '
            '${position.latitude}, '
            '${position.longitude}',
          );

          updateBlackspotProximity(position);
        });
  }

  void _centerMapOnPosition(Position position) {
    if (!_mapReady) return;

    mapController.move(
      LatLng(position.latitude, position.longitude),
      mapController.camera.zoom,
    );
  }

  void _toggleFollowMe() {
    setState(() => _followMe = !_followMe);

    final position = currentPosition;
    if (_followMe && position != null) {
      _centerMapOnPosition(position);
    }
  }

  Future<void> loadRoute() async {
    setState(() {
      loading = true;
      errorMessage = '';
    });
    startLiveTracking();
    final position = await service.getCurrentLocation();

    if (position != null) {
      setState(() {
        currentPosition = position;
      });
      updateBlackspotProximity(position);
    }

    final start = await service.searchLocation(widget.from);
    final end = await service.searchLocation(widget.to);

    if (start == null || end == null) {
      setState(() {
        loading = false;
        errorMessage = 'Location not found. Please try another place.';
      });
      return;
    }

    final route = await service.getRoute(
      start,
      end,
      preference: widget.preference,
    );

    if (route == null) {
      setState(() {
        loading = false;
        errorMessage = 'Unable to find a route.';
      });
      return;
    }

    final weatherData = await service.getWeather(start.lat, start.lon);
    debugPrint('LIGHTING FUNCTION CALLED');
    final lightingScore = await service.getLightingScore(route.points);
    debugPrint('ACCESSIBILITY FUNCTION CALLED');
    final accessibilityScore =
        route.accessibilityScore ??
        await service.getAccessibilityScore(route.points);

    setState(() {
      startLocation = start;
      endLocation = end;

      routePoints = route.points;
      distanceKm = route.distance;
      durationMinutes = route.duration;

      weather = weatherData;
      lightingSafety = lightingScore;
      accessibilitySafety = accessibilityScore;
      loading = false;
    });

    await loadSafety(start);
  }

  Future<void> loadSafety(_Location location) async {
    try {
      final lat = location.lat;
      final lon = location.lon;

      final url = Uri.parse(
        'http://127.0.0.1:5000/location-safety'
        '?lat=$lat&lon=$lon',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        calculateSafety();
        return;
      }

      final data = jsonDecode(response.body);

      setState(() {
        accidentSafety = (data['accident_safety'] as num?)?.toDouble() ?? 0;

        roadSafety = (data['road_safety'] as num?)?.toDouble() ?? 0;
      });

      calculateSafety();
    } catch (e) {
      calculateSafety();
    }
  }

  String getDistrictName(String place) {
    final value = place.toLowerCase().trim();

    final mappings = {
      'chennai': 'Chennai',
      'salem': 'Salem',
      'coimbatore': 'Coimbatore',
      'madurai': 'Madurai',
      'erode': 'Erode',
      'tiruchirappalli': 'Tiruchirappalli',
      'trichy': 'Tiruchirappalli',
      'tiruppur': 'Tiruppur',
      'vellore': 'Vellore',
      'dharmapuri': 'Dharmapuri',
      'dindigul': 'Dindigul',
      'namakkal': 'Namakkal',
      'thanjavur': 'Thanjavur',
      'tirunelveli': 'Tirunelveli',
      'thoothukudi': 'Thoothukudi',
      'karur': 'Karur',
      'perambalur': 'Perambalur',
      'ariyalur': 'Ariyalur',
      'cuddalore': 'Cuddalore',
      'villupuram': 'Villupuram',
      'virudhunagar': 'Virudhunagar',
      'theni': 'Theni',
      'sivaganga': 'Sivaganga',
      'ramanathapuram': 'Ramanathapuram',
      'pudukkottai': 'Pudukkottai',
      'nagapattinam': 'Nagapattinam',
      'tiruvarur': 'Tiruvarur',
      'kanniyakumari': 'Kanniyakumari',
      'krishnagiri': 'Krishnagiri',
      'the nilgiris': 'The Nilgiris',
      'nilgiris': 'The Nilgiris',
    };

    return mappings[value] ?? place;
  }

  void calculateSafety() {
    // Night time = 6:00 PM to 6:00 AM
    final hour = DateTime.now().hour;
    final bool isNight = hour >= 18 || hour < 6;

    double score;

    if (isNight) {
      // NIGHT TRAVEL
      // Lighting included
      if (widget.preference == 'Safety First') {
        score =
            (accidentSafety * 0.40) +
            (roadSafety * 0.15) +
            (weatherSafety * 0.15) +
            (lightingSafety * 0.15) +
            (accessibilitySafety * 0.15);
      } else {
        score =
            (accidentSafety * 0.35) +
            (roadSafety * 0.20) +
            (weatherSafety * 0.15) +
            (lightingSafety * 0.15) +
            (accessibilitySafety * 0.15);
      }
    } else {
      // DAY TRAVEL
      // Lighting excluded
      if (widget.preference == 'Safety First') {
        score =
            (accidentSafety * 0.50) +
            (roadSafety * 0.20) +
            (weatherSafety * 0.15) +
            (accessibilitySafety * 0.15);
      } else {
        score =
            (accidentSafety * 0.45) +
            (roadSafety * 0.25) +
            (weatherSafety * 0.15) +
            (accessibilitySafety * 0.15);
      }
    }

    score = score.clamp(0, 100);

    setState(() {
      safetyScore = score;
    });
  }

  String weatherText() {
    if (weather == null) return 'Unavailable';

    final code = weather!.weatherCode;

    if (code == 0) return 'Clear';
    if (code >= 1 && code <= 3) return 'Cloudy';
    if (code >= 51 && code <= 67) return 'Rain';
    if (code >= 80 && code <= 82) return 'Rain';
    if (code >= 95) return 'Storm';

    return 'Weather data';
  }

  String formatDuration(double minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes.round() % 60;

    if (hours > 0) {
      return '${hours}h ${mins}m';
    }

    return '${mins} min';
  }

  @override
  void dispose() {
    positionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: Colors.white,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'SafeRoute TN',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          if (compact)
            IconButton(
              tooltip: 'Home',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
            )
          else
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Home'),
            ),
          if (!compact)
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AboutPage(onToggleTheme: widget.onToggleTheme),
                  ),
                );
              },
              child: const Text('About'),
            ),
          IconButton(
            tooltip: _isDarkMode ? 'Use light theme' : 'Use dark theme',
            onPressed: widget.onToggleTheme,
            icon: Icon(
              _isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 60,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 15),
                    Text(errorMessage, textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: loadRoute,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            )
          : _mapContent(),
    );
  }

  Widget _mapContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1050) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _mapView()),
                const SizedBox(width: 18),
                SizedBox(
                  width: 370,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: _detailsPanel(),
                  ),
                ),
              ],
            ),
          );
        }

        final mapHeight = (MediaQuery.sizeOf(context).height * 0.53)
            .clamp(350.0, 570.0)
            .toDouble();
        return SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: mapHeight, child: _mapView()),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                child: _detailsPanel(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _mapView() {
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: routePoints.isNotEmpty
                  ? routePoints.first
                  : const LatLng(11.0168, 76.9558),
              initialZoom: 10,
              onMapReady: () {
                _mapReady = true;
                final position = currentPosition;
                if (_followMe && position != null) {
                  _centerMapOnPosition(position);
                }
              },
              onMapEvent: (event) {
                if (_followMe &&
                    event is MapEventMoveStart &&
                    event.source == MapEventSource.dragStart) {
                  setState(() => _followMe = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.saferoute.tn',
              ),
              if (currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(
                        currentPosition!.latitude,
                        currentPosition!.longitude,
                      ),
                      width: 48,
                      height: 48,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xff3D8BFF)
                              .withValues(alpha: 0.22),
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.my_location_rounded,
                            color: Color(0xff2563EB),
                            size: 23,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              if (routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 10,
                      color: Colors.white,
                    ),
                    Polyline(
                      points: routePoints,
                      strokeWidth: 6,
                      color: const Color(0xff2563EB),
                    ),
                  ],
                ),
              if (startLocation != null && endLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(startLocation!.lat, startLocation!.lon),
                      width: 45,
                      height: 45,
                      child: const Icon(
                        Icons.trip_origin_rounded,
                        size: 34,
                        color: Color(0xff36A889),
                      ),
                    ),
                    Marker(
                      point: LatLng(endLocation!.lat, endLocation!.lon),
                      width: 45,
                      height: 45,
                      child: const Icon(
                        Icons.location_on_rounded,
                        size: 42,
                        color: Color(0xffE46D72),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 76,
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 470),
                child: _routeSearchOverlay(),
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 14,
            child: Column(
              children: [
                _mapControl(
                  icon: Icons.add_rounded,
                  tooltip: 'Zoom in',
                  onPressed: () => mapController.move(
                    mapController.camera.center,
                    mapController.camera.zoom + 1,
                  ),
                ),
                const SizedBox(height: 8),
                _mapControl(
                  icon: Icons.remove_rounded,
                  tooltip: 'Zoom out',
                  onPressed: () => mapController.move(
                    mapController.camera.center,
                    mapController.camera.zoom - 1,
                  ),
                ),
                const SizedBox(height: 8),
                _mapControl(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Center on current location',
                  onPressed: () {
                    final position = currentPosition;
                    if (position == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Current location is not available yet.',
                          ),
                        ),
                      );
                      return;
                    }
                    mapController.move(
                      LatLng(position.latitude, position.longitude),
                      14,
                    );
                  },
                ),
                const SizedBox(height: 8),
                _followMeControl(),
              ],
            ),
          ),
          Positioned(
            left: 16,
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.route_rounded,
                    size: 16,
                    color: Color(0xff2563EB),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Route overview',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _routeSearchOverlay() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            children: [
              const Icon(
                Icons.trip_origin_rounded,
                size: 18,
                color: Color(0xff36A889),
              ),
              Container(height: 18, width: 1.5, color: colors.outlineVariant),
              const Icon(
                Icons.location_on_rounded,
                size: 19,
                color: Color(0xffE46D72),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.from,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  widget.to,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              widget.preference == 'Fastest Route'
                  ? Icons.speed_rounded
                  : widget.preference == 'Shortest Route'
                  ? Icons.route_rounded
                  : widget.preference == 'Less Traffic'
                  ? Icons.traffic_rounded
                  : Icons.shield_rounded,
              color: colors.primary,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapControl({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      elevation: 5,
      shadowColor: Colors.black.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(14),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: colors.primary),
      ),
    );
  }

  Widget _followMeControl() {
    final colors = Theme.of(context).colorScheme;
    final foreground = _followMe ? Colors.white : colors.primary;

    return Tooltip(
      message: 'Follow Me: ${_followMe ? 'ON' : 'OFF'}',
      child: Material(
        color: _followMe ? const Color(0xff2563EB) : colors.surface,
        elevation: 5,
        shadowColor: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: _toggleFollowMe,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 48,
            height: 58,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _followMe
                      ? Icons.gps_fixed_rounded
                      : Icons.gps_not_fixed_rounded,
                  color: foreground,
                  size: 21,
                ),
                const SizedBox(height: 2),
                Text(
                  _followMe ? 'ON' : 'OFF',
                  style: TextStyle(
                    color: foreground,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailsPanel() {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _routeHeader(),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xff36A889).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                widget.preference == 'Safety First'
                    ? Icons.shield_rounded
                    : widget.preference == 'Fastest Route'
                    ? Icons.speed_rounded
                    : widget.preference == 'Shortest Route'
                    ? Icons.route_rounded
                    : widget.preference == 'Less Traffic'
                    ? Icons.traffic_rounded
                    : Icons.accessible_rounded,
                color: const Color(0xff36A889),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ROUTE PREFERENCE',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.preference,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    if (widget.preference == 'Less Traffic')
                      Text(
                        'No live traffic feed; showing the quickest OSRM option.',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.tune_rounded,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _routeInfoCard(),
        const SizedBox(height: 14),
        _blackspotCard(),
        const SizedBox(height: 16),
        _safetyCard(),
        const SizedBox(height: 16),
        _factorCards(),
      ],
    );
  }

  Widget _routeHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isDarkMode
              ? const [Color(0xff1F5E7A), Color(0xff226D65)]
              : const [Color(0xff2563EB), Color(0xff36A889)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_rounded, color: Colors.white, size: 42),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Safe Route Found',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${widget.from} → ${widget.to}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _routeInfoCard() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDarkMode ? 0.12 : 0.035),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _infoItem(
              Icons.route_rounded,
              'Distance',
              '${distanceKm.toStringAsFixed(1)} km',
              Colors.blue,
            ),
          ),
          Expanded(
            child: _infoItem(
              Icons.access_time_rounded,
              'ETA',
              formatDuration(durationMinutes),
              Colors.orange,
            ),
          ),
          Expanded(
            child: _infoItem(
              Icons.shield_rounded,
              'Safety',
              '${safetyScore.toStringAsFixed(0)}%',
              Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String title, String value, Color color) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _blackspotCard() {
    final near = isNearBlackspot;
    final colors = Theme.of(context).colorScheme;
    final alertColor = near ? const Color(0xffD94A54) : const Color(0xff2A9B7D);
    final cardColor = near
        ? (_isDarkMode ? const Color(0xff351F27) : const Color(0xfffff2f1))
        : (_isDarkMode ? const Color(0xff18352F) : const Color(0xffEAF8F2));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: alertColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            near ? Icons.warning_rounded : Icons.verified_rounded,
            color: alertColor,
            size: 32,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  near ? 'Blackspot Warning' : 'Blackspot Check',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  near
                      ? 'A verified accident blackspot is nearby.'
                      : 'No verified blackspot detected nearby.',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                if (near && blackspotDetails != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    '${blackspotDetails!['landmark'] ?? 'Unknown location'}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                  if (blackspotDistanceMeters != null)
                    Text(
                      '${blackspotDistanceMeters!.round()} m away',
                      style: TextStyle(
                        color: alertColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _safetyCard() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDarkMode
              ? const [Color(0xff20445A), Color(0xff1D5B53)]
              : const [Color(0xff2563EB), Color(0xff36A889)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text(
                'Route safety',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TweenAnimationBuilder<double>(
            key: ValueKey(safetyScore),
            tween: Tween<double>(begin: 0, end: safetyScore),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Row(
                children: [
                  SizedBox(
                    width: 94,
                    height: 94,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: (value / 100).clamp(0.0, 1.0),
                            strokeWidth: 8,
                            strokeCap: StrokeCap.round,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.22,
                            ),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xffA8F0D4),
                            ),
                          ),
                        ),
                        Text(
                          '${value.round()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Overall safety score',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          safetyScore >= 75
                              ? 'Looking good'
                              : safetyScore >= 50
                              ? 'Stay aware'
                              : 'Use extra caution',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Selected preference · ${widget.preference}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _factorCards() {
    final colors = Theme.of(context).colorScheme;
    final factors = [
      SafetyFactor(
        title: 'Accident Safety',
        icon: Icons.warning_rounded,
        score: accidentSafety,
      ),
      SafetyFactor(
        title: 'Road Surface',
        icon: Icons.directions_rounded,
        score: roadSafety,
      ),
      SafetyFactor(
        title: 'Weather',
        icon: Icons.cloud_rounded,
        score: weatherSafety,
      ),
      SafetyFactor(
        title: 'Lighting',
        icon: Icons.lightbulb_rounded,
        score: lightingSafety,
      ),
      SafetyFactor(
        title: 'Accessibility',
        icon: Icons.accessible_rounded,
        score: accessibilitySafety,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Safety Factors',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
          ),
        ),

        const SizedBox(height: 12),

        ...factors.map(
          (factor) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              children: [
                Icon(factor.icon, color: const Color(0xff36A889), size: 25),

                const SizedBox(width: 15),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        factor.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          value: (factor.score / 100).clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor: colors.surfaceContainerHighest,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xff36A889),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),
                Text(
                  '${factor.score.toStringAsFixed(2)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),

        if (weather != null)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(Icons.cloud, color: colors.primary),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    '${weatherText()} • '
                    '${weather!.temperature.toStringAsFixed(1)}°C',
                    style: TextStyle(color: colors.onSurface),
                  ),
                ),

                Text(
                  '${weather!.windSpeed.toStringAsFixed(0)} km/h wind',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class AboutPage extends StatelessWidget {
  final VoidCallback onToggleTheme;

  const AboutPage({super.key, required this.onToggleTheme});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'About SafeRoute TN',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: isDarkMode ? 'Use light theme' : 'Use dark theme',
            onPressed: onToggleTheme,
            icon: Icon(
              isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDarkMode
                          ? const [Color(0xff1F5E7A), Color(0xff226D65)]
                          : const [Color(0xff2563EB), Color(0xff36A889)],
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.shield_rounded, color: Colors.white, size: 70),
                      SizedBox(height: 15),
                      Text(
                        'SafeRoute TN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'AI based context-aware safe and accessible '
                        'navigation system for Tamil Nadu',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                _aboutCard(
                  context,
                  icon: Icons.lightbulb_rounded,
                  title: 'Our Idea',
                  text:
                      'SafeRoute TN goes beyond traditional shortest-path '
                      'navigation by considering safety-related factors '
                      'while finding a route.',
                ),

                _aboutCard(
                  context,
                  icon: Icons.warning_rounded,
                  title: 'Accident Risk',
                  text:
                      'Historical accident information is used to understand '
                      'the safety level of the selected district.',
                ),

                _aboutCard(
                  context,
                  icon: Icons.directions_rounded,
                  title: 'Road Surface',
                  text:
                      'Road surface coverage is considered as one of the '
                      'factors in the safety analysis.',
                ),

                _aboutCard(
                  context,
                  icon: Icons.cloud_rounded,
                  title: 'Live Weather',
                  text:
                      'Current weather information is used to adjust the '
                      'weather-related safety factor.',
                ),

                _aboutCard(
                  context,
                  icon: Icons.auto_awesome,
                  title: 'AI Based Future',
                  text:
                      'The system can be extended with machine learning '
                      'models for accident-risk prediction and smarter '
                      'context-aware route selection.',
                ),

                const SizedBox(height: 20),

                const Text(
                  'Smart • Safe • Accessible',
                  style: TextStyle(
                    color: Color(0xff36A889),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _aboutCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String text,
  }) {
    final colors = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.12 : 0.04),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: colors.primary, size: 28),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: TextStyle(color: colors.onSurfaceVariant, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
