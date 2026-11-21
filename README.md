# saferoute_tn

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Live traffic configuration

Live route traffic uses TomTom's current [Orbis Maps v2 Vector Flow Tiles API](https://docs.tomtom.com/traffic-api/documentation/tomtom-orbis-maps/v2/traffic-flow/vector-flow-tiles),
not the unavailable legacy Flow Segment Data API. The Flutter app sends each
OSRM candidate route's geometry to the existing Flask backend at
`/route-traffic`. The backend requests and decodes the route's vector tiles,
using Orbis `relative_speed` and `road_closure` attributes. It reads the API
key only from the `TOMTOM_API_KEY` environment variable. Do not put that key
in Flutter, this repository, or a client build.

For local development, set the key in the backend process environment and run
`lib/python_ai/api.py` (for example, in PowerShell set
`$env:TOMTOM_API_KEY = "<your TomTom key>"` before starting the process).
Configure the Flutter app to reach that backend with:

```text
flutter run --dart-define=SAFEROUTE_API_BASE_URL=http://127.0.0.1:5000
```

The same backend URL is used for verified blackspot checks at
`/check-blackspot`. Only GPS-verified records from `blackspots_verified.csv`
are considered.

For Android emulators use `http://10.0.2.2:5000`; for a physical device use the
backend machine's reachable LAN address. Production deployments should use a
private server-side secret store for `TOMTOM_API_KEY` and an HTTPS backend URL
for `SAFEROUTE_API_BASE_URL`.

The backend requests vector tiles at zoom 16 and conservatively matches
sampled points along the candidate route to decoded traffic-flow road geometry.
It requires complete route sample coverage, a match within 25 metres, and no
equally close conflicting flow observation. If tile retrieval, geometry
decoding, coverage, or matching is incomplete or ambiguous, the result is
“Traffic data unavailable”; it does not extrapolate missing values. The API
does not provide the earlier flow-segment `confidence` field in this product,
so the app does not display or invent a confidence value.

The displayed Low/Moderate/High categories are app-defined using the mean
TomTom `relative_speed` observations (0–1): at least 0.8 is Low, 0.5 to less
than 0.8 is Moderate, and below 0.5 is High. Any matched road closure also
produces High Traffic. These bands are not labels returned by TomTom. Only the
Less Traffic preference uses these observations to rank routes; if fewer than
two routes have comparable data, no traffic recommendation is made. Route
requests exceeding 128 tiles or 5,000 samples are left unavailable.

Vector tiles provide road-segment observations, not an explicit OSRM route
assessment. Conservative geometry matching can therefore leave some routes
unavailable, especially where TomTom coverage differs from the route geometry.
Traffic availability also depends on the server-side key's product entitlement,
coverage, quota, and update latency.
