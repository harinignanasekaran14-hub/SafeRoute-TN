import os
import json
import math
import gzip
import struct
import sqlite3
from datetime import datetime, timezone
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from flask import Flask, jsonify, request
from flask_cors import CORS
import pandas as pd

app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*"}})


@app.before_request
def handle_options_preflight():
    if request.method == "OPTIONS":
        res = app.make_default_options_response()
        res.headers["Access-Control-Allow-Origin"] = "*"
        res.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS, PUT, DELETE"
        res.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-Requested-With"
        res.headers["Access-Control-Allow-Private-Network"] = "true"
        res.headers["Access-Control-Max-Age"] = "86400"
        return res


@app.after_request
def add_cors_and_pna_headers(response):
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS, PUT, DELETE"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-Requested-With"
    response.headers["Access-Control-Allow-Private-Network"] = "true"
    return response

BASE_DIR = os.path.dirname(os.path.abspath(__file__))


def _load_env_file():
    for candidate in [
        os.path.join(BASE_DIR, ".env"),
        os.path.join(BASE_DIR, "..", "..", ".env"),
        os.path.join(os.getcwd(), ".env"),
    ]:
        if os.path.exists(candidate):
            try:
                with open(candidate, "r", encoding="utf-8") as f:
                    for line in f:
                        line = line.strip()
                        if line and not line.startswith("#") and "=" in line:
                            k, v = line.split("=", 1)
                            k = k.strip()
                            v = v.strip().strip('"').strip("'")
                            if k and k not in os.environ:
                                os.environ[k] = v
            except Exception:
                pass


_load_env_file()
combined_data_path = os.path.join(BASE_DIR, "combined_data.csv")
blackspots_path = os.path.join(BASE_DIR, "blackspots_verified.csv")

# Load district combined data if available
if os.path.exists(combined_data_path):
    data = pd.read_csv(combined_data_path)
else:
    data = pd.DataFrame()


def load_verified_blackspots():
    """Load only authentic GPS-verified blackspots from blackspots_verified.csv"""
    if not os.path.exists(blackspots_path):
        return pd.DataFrame()
    df = pd.read_csv(blackspots_path)
    verified = df[df["gps_verified"].astype(str).str.upper() == "TRUE"].copy()
    verified["latitude"] = pd.to_numeric(verified["latitude"], errors="coerce")
    verified["longitude"] = pd.to_numeric(verified["longitude"], errors="coerce")
    return verified.dropna(subset=["latitude", "longitude"])


verified_blackspots_df = load_verified_blackspots()

road_segments_path = os.path.join(os.path.abspath(os.path.join(BASE_DIR, "..", "..")), "road_segments.csv")
if not os.path.exists(road_segments_path):
    road_segments_path = os.path.join(BASE_DIR, "road_segments.csv")


def load_road_segments():
    """Load authentic OSM road segments from road_segments.csv if available"""
    if not os.path.exists(road_segments_path):
        return pd.DataFrame()
    df = pd.read_csv(road_segments_path)
    df["latitude"] = pd.to_numeric(df["latitude"], errors="coerce")
    df["longitude"] = pd.to_numeric(df["longitude"], errors="coerce")
    return df.dropna(subset=["latitude", "longitude"])


road_segments_df = load_road_segments()

TOMTOM_TRAFFIC_SOURCE = "TomTom Orbis Traffic Flow Vector Tiles"
TOMTOM_TRAFFIC_TILE_URL = (
    "https://api.tomtom.com/maps/orbis/traffic/flow/vector/tile"
)
TRAFFIC_TILE_ZOOM = 12
MAX_TRAFFIC_TILES = 128
MAX_ROUTE_TRAFFIC_SAMPLES = 10000
ROUTE_SAMPLE_SPACING_METERS = 40.0
MAX_ROUTE_MATCH_DISTANCE_METERS = 25.0
AMBIGUOUS_MATCH_DISTANCE_DELTA_METERS = 3.0
AMBIGUOUS_SPEED_RATIO_DELTA = 0.05
TRAFFIC_REQUEST_TIMEOUT_SECONDS = 15
MAX_TRAFFIC_TILE_WORKERS = 8


def haversine_distance(lat1, lon1, lat2, lon2):
    """Calculate the great-circle distance between two points on Earth in meters."""
    R = 6371000.0  # Earth's radius in meters
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = (
        math.sin(delta_phi / 2.0) ** 2
        + math.cos(phi1) * math.cos(phi2) * (math.sin(delta_lambda / 2.0) ** 2)
    )
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return R * c


def find_nearby_blackspots(lat, lon, radius_meters=1000.0):
    """Find all verified blackspots within radius_meters, sorted by distance."""
    if verified_blackspots_df.empty:
        return [], None

    matches = []
    nearest_spot = None
    min_distance = float("inf")

    for _, row in verified_blackspots_df.iterrows():
        b_lat = float(row["latitude"])
        b_lon = float(row["longitude"])
        dist_m = haversine_distance(lat, lon, b_lat, b_lon)
        dist_km = dist_m / 1000.0

        spot_info = {
            "blackspot_id": str(row["blackspot_id"]),
            "highway_no": str(row["highway_no"]),
            "chainage_from": str(row["chainage_from"]),
            "chainage_to": str(row["chainage_to"]),
            "district": str(row["district"]),
            "landmark": str(row["landmark"]),
            "status": str(row["status"]),
            "source": str(row["source"]),
            "source_url": str(row["source_url"]),
            "latitude": b_lat,
            "longitude": b_lon,
            "distance_meters": round(dist_m, 1),
            "distance_km": round(dist_km, 3),
        }

        if dist_m < min_distance:
            min_distance = dist_m
            nearest_spot = spot_info

        if dist_m <= radius_meters:
            matches.append(spot_info)

    # Sort matches by distance ascending
    matches.sort(key=lambda x: x["distance_meters"])

    return matches, nearest_spot


def find_route_blackspots(points, radius_meters=1000.0):
    """Find all verified blackspots within radius_meters of any point along a route."""
    if verified_blackspots_df.empty or not points:
        return [], None, None

    parsed_points = []
    for p in points:
        if isinstance(p, (list, tuple)) and len(p) >= 2:
            try:
                parsed_points.append((float(p[0]), float(p[1])))
            except (ValueError, TypeError):
                pass
        elif isinstance(p, dict):
            lat = p.get("lat") or p.get("latitude")
            lon = p.get("lon") or p.get("longitude")
            if lat is not None and lon is not None:
                try:
                    parsed_points.append((float(lat), float(lon)))
                except (ValueError, TypeError):
                    pass

    if not parsed_points:
        return [], None, None

    # Subsample if too dense to keep computation fast
    if len(parsed_points) > 200:
        step = max(1, len(parsed_points) // 150)
        parsed_points = parsed_points[::step]

    matches = []
    nearest_spot = None
    overall_min_distance = float("inf")

    for _, row in verified_blackspots_df.iterrows():
        b_lat = float(row["latitude"])
        b_lon = float(row["longitude"])

        min_d_for_spot = min(
            haversine_distance(p_lat, p_lon, b_lat, b_lon)
            for p_lat, p_lon in parsed_points
        )

        spot_info = {
            "blackspot_id": str(row["blackspot_id"]),
            "highway_no": str(row["highway_no"]),
            "chainage_from": str(row["chainage_from"]),
            "chainage_to": str(row["chainage_to"]),
            "district": str(row["district"]),
            "landmark": str(row["landmark"]),
            "status": str(row["status"]),
            "source": str(row["source"]),
            "source_url": str(row["source_url"]),
            "latitude": b_lat,
            "longitude": b_lon,
            "distance_meters": round(min_d_for_spot, 1),
            "distance_km": round(min_d_for_spot / 1000.0, 3),
        }

        if min_d_for_spot < overall_min_distance:
            overall_min_distance = min_d_for_spot
            nearest_spot = spot_info

        if min_d_for_spot <= radius_meters:
            matches.append(spot_info)

    matches.sort(key=lambda x: x["distance_meters"])
    return matches, nearest_spot, (round(overall_min_distance, 1) if overall_min_distance != float("inf") else None)



def _read_varint(data, offset):
    value = 0
    shift = 0
    while offset < len(data) and shift < 70:
        byte = data[offset]
        offset += 1
        value |= (byte & 0x7F) << shift
        if byte < 0x80:
            return value, offset
        shift += 7
    raise ValueError("Malformed protobuf varint")


def _iter_proto_fields(data):
    offset = 0
    while offset < len(data):
        key, offset = _read_varint(data, offset)
        field_number = key >> 3
        wire_type = key & 7
        if field_number == 0:
            raise ValueError("Invalid protobuf field number")
        if wire_type == 0:
            value, offset = _read_varint(data, offset)
        elif wire_type == 1:
            value = data[offset:offset + 8]
            offset += 8
        elif wire_type == 2:
            length, offset = _read_varint(data, offset)
            value = data[offset:offset + length]
            offset += length
            if len(value) != length:
                raise ValueError("Truncated protobuf field")
        elif wire_type == 5:
            value = data[offset:offset + 4]
            offset += 4
        else:
            raise ValueError("Unsupported protobuf wire type")
        if offset > len(data):
            raise ValueError("Truncated protobuf field")
        yield field_number, wire_type, value


def _unpack_varints(data):
    values = []
    offset = 0
    while offset < len(data):
        value, offset = _read_varint(data, offset)
        values.append(value)
    return values


def _decode_tile_value(data):
    for field_number, wire_type, value in _iter_proto_fields(data):
        if field_number == 1 and wire_type == 2:
            return value.decode("utf-8")
        if field_number == 2 and wire_type == 5:
            return struct.unpack("<f", value)[0]
        if field_number == 3 and wire_type == 1:
            return struct.unpack("<d", value)[0]
        if field_number == 4 and wire_type == 0:
            return value
        if field_number == 5 and wire_type == 0:
            return value
        if field_number == 6 and wire_type == 0:
            return (value >> 1) ^ -(value & 1)
        if field_number == 7 and wire_type == 0:
            return value != 0
    return None


def _decode_feature_geometry(encoded_geometry):
    paths = []
    path = []
    cursor_x = 0
    cursor_y = 0
    index = 0
    while index < len(encoded_geometry):
        command_integer = encoded_geometry[index]
        index += 1
        command = command_integer & 7
        count = command_integer >> 3
        if command not in (1, 2) or count == 0:
            raise ValueError("Unsupported vector tile geometry command")
        for _ in range(count):
            if index + 1 >= len(encoded_geometry):
                raise ValueError("Truncated vector tile geometry")
            delta_x = encoded_geometry[index]
            delta_y = encoded_geometry[index + 1]
            index += 2
            cursor_x += (delta_x >> 1) ^ -(delta_x & 1)
            cursor_y += (delta_y >> 1) ^ -(delta_y & 1)
            point = (cursor_x, cursor_y)
            if command == 1:
                if len(path) > 1:
                    paths.append(path)
                path = [point]
            else:
                if not path:
                    raise ValueError("LineTo without a MoveTo")
                path.append(point)
    if len(path) > 1:
        paths.append(path)
    return paths


def _decode_traffic_tile(tile_data, tile_x, tile_y, zoom):
    world_tiles = 2 ** zoom
    tile_meters = 2 * math.pi * 6378137.0 / world_tiles
    features = []
    tile_fields = list(_iter_proto_fields(tile_data))
    for field_number, wire_type, layer_data in tile_fields:
        if field_number != 3 or wire_type != 2:
            continue

        layer_name = None
        keys = []
        values = []
        encoded_features = []
        extent = 4096
        for number, layer_wire, value in _iter_proto_fields(layer_data):
            if number == 1 and layer_wire == 2:
                layer_name = value.decode("utf-8").strip().lower()
            elif number == 2 and layer_wire == 2:
                encoded_features.append(value)
            elif number == 3 and layer_wire == 2:
                keys.append(value.decode("utf-8"))
            elif number == 4 and layer_wire == 2:
                values.append(_decode_tile_value(value))
            elif number == 5 and layer_wire == 0:
                extent = value

        if layer_name not in ("traffic flow", "traffic_flow", "flow") or extent <= 0:
            continue

        for encoded_feature in encoded_features:
            tags = []
            geometry_values = []
            geometry_type = 0
            for number, feature_wire, value in _iter_proto_fields(encoded_feature):
                if number == 2 and feature_wire == 2:
                    tags.extend(_unpack_varints(value))
                elif number == 2 and feature_wire == 0:
                    tags.append(value)
                elif number == 3 and feature_wire == 0:
                    geometry_type = value
                elif number == 4 and feature_wire == 2:
                    geometry_values.extend(_unpack_varints(value))
                elif number == 4 and feature_wire == 0:
                    geometry_values.append(value)
            if geometry_type != 2 or not geometry_values or len(tags) % 2:
                continue

            properties = {}
            for tag_index in range(0, len(tags), 2):
                key_index = tags[tag_index]
                value_index = tags[tag_index + 1]
                if key_index >= len(keys) or value_index >= len(values):
                    raise ValueError("Invalid vector tile feature tag")
                properties[keys[key_index]] = values[value_index]

            relative_speed = properties.get("relative_speed")
            if (
                not isinstance(relative_speed, (int, float))
                or isinstance(relative_speed, bool)
                or not math.isfinite(relative_speed)
                or not 0 <= relative_speed <= 1
            ):
                continue

            raw_paths = _decode_feature_geometry(geometry_values)
            projected_paths = [
                [
                    (
                        (tile_x * extent + x) * tile_meters / extent,
                        (tile_y * extent + y) * tile_meters / extent,
                    )
                    for x, y in path
                ]
                for path in raw_paths
            ]
            if projected_paths:
                features.append(
                    {
                        "paths": projected_paths,
                        "speed_ratio": float(relative_speed),
                        "road_closure": properties.get("road_closure") is True,
                    }
                )
    return features


def _route_tile_coordinates(route_points, zoom):
    world_tiles = 2 ** zoom
    tiles = set()

    for latitude, longitude in route_points:
        if not (-85.05112878 < latitude < 85.05112878):
            continue

        x = (longitude + 180.0) / 360.0 * world_tiles

        latitude_radians = math.radians(latitude)
        y = (
            1.0
            - math.asinh(math.tan(latitude_radians)) / math.pi
        ) / 2.0 * world_tiles

        tile_x = int(math.floor(x))
        tile_y = int(math.floor(y))

        # Keep coordinates strictly inside TomTom's valid tile range.
        if 0 <= tile_x < world_tiles and 0 <= tile_y < world_tiles:
            tiles.add((tile_x, tile_y))

    return sorted(tiles)

def fetch_tomtom_traffic_tile(tile, api_key):
    zoom, tile_x, tile_y = tile
    query = urllib.parse.urlencode(
        {
            "apiVersion": "2",
            "attributes": "tags(relative_speed,road_closure)",
        }
    )
    url = (
        f"{TOMTOM_TRAFFIC_TILE_URL}/{zoom}/{tile_x}/{tile_y}?{query}"
    )
    request_object = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.mapbox-vector-tile",
            "TomTom-Api-Key": api_key,
            "TomTom-Api-Version": "2",
        },
    )
    try:
        with urllib.request.urlopen(
            request_object,
            timeout=TRAFFIC_REQUEST_TIMEOUT_SECONDS,
        ) as response:
            if response.status == 204:
                return []
            if response.status != 200:
                return {"http_status": response.status}
            tile_data = response.read()
            if (
                response.headers.get("Content-Encoding", "").lower() == "gzip"
                or (len(tile_data) >= 2 and tile_data[0] == 0x1F and tile_data[1] == 0x8B)
            ):
                tile_data = gzip.decompress(tile_data)
            return _decode_traffic_tile(tile_data, tile_x, tile_y, zoom)
    except urllib.error.HTTPError as error:
        if error.code in (204, 404):
            return []
        return {"http_status": error.code}
    except (urllib.error.URLError, TimeoutError, ValueError, OSError, struct.error):
        return []

def _route_samples(
route_points):
    print(
    "ROUTE SAMPLES INPUT:",
    type(route_points),
    len(route_points) if route_points else None
)
    cumulative_meters = [0.0]
    for first, second in zip(route_points, route_points[1:]):
        cumulative_meters.append(
            cumulative_meters[-1]
            + haversine_distance(first[0], first[1], second[0], second[1])
        )
    total_meters = cumulative_meters[-1]
    print("ROUTE TOTAL METERS:", total_meters)
    if not math.isfinite(total_meters) or total_meters <= 0:
        return None

    effective_spacing = max(
        ROUTE_SAMPLE_SPACING_METERS,
        total_meters / (MAX_ROUTE_TRAFFIC_SAMPLES - 1),
    )
    sample_count = max(
        2,
        math.ceil(total_meters / effective_spacing) + 1,
    )
    print("ROUTE SAMPLE COUNT:", sample_count)
    print("MAX ROUTE SAMPLES:", MAX_ROUTE_TRAFFIC_SAMPLES)

    samples = []
    segment_index = 0
    for sample_index in range(sample_count):
        target = total_meters * sample_index / (sample_count - 1)
        while (
            segment_index < len(cumulative_meters) - 2
            and cumulative_meters[segment_index + 1] < target
        ):
            segment_index += 1
        segment_start = cumulative_meters[segment_index]
        segment_length = cumulative_meters[segment_index + 1] - segment_start
        fraction = (
            0.0
            if segment_length <= 0
            else (target - segment_start) / segment_length
        )
        first = route_points[segment_index]
        second = route_points[segment_index + 1]
        latitude = first[0] + (second[0] - first[0]) * fraction
        longitude = first[1] + (second[1] - first[1]) * fraction
        latitude_radians = math.radians(latitude)
        x = (longitude + 180.0) / 360.0 * 2 * math.pi * 6378137.0
        mercator_y = (
            6378137.0
            * math.log(math.tan(math.pi / 4 + latitude_radians / 2))
        )
        y = math.pi * 6378137.0 - mercator_y
        samples.append((x, y, latitude))
    return samples


def _distance_to_feature(point_x, point_y, feature):
    nearest_squared = float("inf")
    for path in feature["paths"]:
        for start, end in zip(path, path[1:]):
            delta_x = end[0] - start[0]
            delta_y = end[1] - start[1]
            length_squared = delta_x * delta_x + delta_y * delta_y
            if length_squared == 0:
                fraction = 0.0
            else:
                fraction = max(
                    0.0,
                    min(
                        1.0,
                        (
                            (point_x - start[0]) * delta_x
                            + (point_y - start[1]) * delta_y
                        ) / length_squared,
                    ),
                )
            closest_x = start[0] + fraction * delta_x
            closest_y = start[1] + fraction * delta_y
            distance_squared = (
                (point_x - closest_x) ** 2
                + (point_y - closest_y) ** 2
            )
            nearest_squared = min(nearest_squared, distance_squared)
    return math.sqrt(nearest_squared)


def _match_route_samples(samples, features):
    if not features:
        return None, "no_route_match"

    cell_size = 50.0
    feature_grid = {}
    for feature_index, feature in enumerate(features):
        points = [point for path in feature["paths"] for point in path]
        if not points:
            continue
        minimum_x = min(point[0] for point in points)
        maximum_x = max(point[0] for point in points)
        minimum_y = min(point[1] for point in points)
        maximum_y = max(point[1] for point in points)
        for cell_x in range(
            math.floor(minimum_x / cell_size),
            math.floor(maximum_x / cell_size) + 1,
        ):
            for cell_y in range(
                math.floor(minimum_y / cell_size),
                math.floor(maximum_y / cell_size) + 1,
            ):
                feature_grid.setdefault((cell_x, cell_y), set()).add(feature_index)

    observations = []
    for point_x, point_y, latitude in samples:
        center_x = math.floor(point_x / cell_size)
        center_y = math.floor(point_y / cell_size)
        candidate_indexes = set()
        for cell_x in range(center_x - 1, center_x + 2):
            for cell_y in range(center_y - 1, center_y + 2):
                candidate_indexes.update(feature_grid.get((cell_x, cell_y), ()))

        match_radius = MAX_ROUTE_MATCH_DISTANCE_METERS / math.cos(
            math.radians(latitude)
        )
        nearby = []
        for feature_index in candidate_indexes:
            feature = features[feature_index]
            distance = _distance_to_feature(point_x, point_y, feature)
            if distance <= match_radius:
                nearby.append((distance, feature))
        if not nearby:
            continue
        nearby.sort(key=lambda result: result[0])
        closest_distance, closest_feature = nearby[0]
        observations.append(closest_feature)
    if not observations:
        return None, "no_route_match"
    return observations, None


def assess_route_traffic(route_points, api_key):
    samples = _route_samples(route_points)
    tiles = _route_tile_coordinates(route_points, TRAFFIC_TILE_ZOOM)
    print("TRAFFIC INTERNAL SAMPLES:", len(samples) if samples is not None else None)
    print("TRAFFIC INTERNAL TILES:", len(tiles) if tiles is not None else None)
    if samples is None or tiles is None:
        return None, "invalid_route_geometry"
    if not tiles or len(tiles) > MAX_TRAFFIC_TILES:
        return None, "route_tile_limit"

    indexed_tiles = [
        (TRAFFIC_TILE_ZOOM, tile_x, tile_y)
        for tile_x, tile_y in sorted(tiles)
    ]
    with ThreadPoolExecutor(max_workers=MAX_TRAFFIC_TILE_WORKERS) as executor:
        tile_results = list(
            executor.map(
                lambda tile: fetch_tomtom_traffic_tile(tile, api_key),
                indexed_tiles,
            )
        )

    if any(
        isinstance(result, dict) and result.get("http_status") == 429
        for result in tile_results
    ):
        return None, "rate_limited"

    features = [feature for tile in tile_results if isinstance(tile, list) for feature in tile]
    if not features:
        return None, "provider_unavailable"

    observations, match_error = _match_route_samples(samples, features)
    if observations is None:
        return None, match_error

    mean_speed_ratio = sum(
        observation["speed_ratio"] for observation in observations
    ) / len(observations)
    road_closure = any(
        observation["road_closure"] for observation in observations
    )
    if road_closure or mean_speed_ratio < 0.5:
        status = "High Traffic"
    elif mean_speed_ratio < 0.8:
        status = "Moderate Traffic"
    else:
        status = "Low Traffic"

    coverage_percent = max(1, round(100.0 * len(observations) / len(samples)))

    return {
        "available": True,
        "source": TOMTOM_TRAFFIC_SOURCE,
        "status": status,
        "mean_speed_ratio": float(mean_speed_ratio),
        "sample_count": int(len(samples)),
        "matched_samples": int(len(observations)),
        "coverage_percent": int(coverage_percent),
        "road_closure": bool(road_closure),
    }, None


@app.route("/route-traffic", methods=["POST", "OPTIONS"])
def route_traffic():
    if request.method == "OPTIONS":
        return jsonify({"status": "ok"})
    api_key = os.environ.get("TOMTOM_API_KEY", "").strip()
    if not api_key:
        return jsonify({
            "available": False,
            "status": "Traffic data unavailable",
            "source": TOMTOM_TRAFFIC_SOURCE,
            "reason": "provider_not_configured",
        }), 503

    payload = request.get_json(silent=True)
    route_points = payload.get("points") if isinstance(payload, dict) else None
    if (
        not isinstance(route_points, list)
        or len(route_points) < 2
        or len(route_points) > 10000
    ):
        return jsonify({
            "available": False,
            "status": "Traffic data unavailable",
            "source": TOMTOM_TRAFFIC_SOURCE,
            "reason": "invalid_route_geometry",
        }), 400

    validated_points = []
    for point in route_points:
        if not isinstance(point, list) or len(point) != 2:
            return jsonify({
                "available": False,
                "status": "Traffic data unavailable",
                "source": TOMTOM_TRAFFIC_SOURCE,
                "reason": "invalid_route_geometry",
            }), 400
        latitude, longitude = point
        if (
            not isinstance(latitude, (int, float))
            or isinstance(latitude, bool)
            or not math.isfinite(latitude)
            or not -90 <= latitude <= 90
            or not isinstance(longitude, (int, float))
            or isinstance(longitude, bool)
            or not math.isfinite(longitude)
            or not -180 <= longitude <= 180
        ):
            return jsonify({
                "available": False,
                "status": "Traffic data unavailable",
                "source": TOMTOM_TRAFFIC_SOURCE,
                "reason": "invalid_route_geometry",
            }), 400
        validated_points.append((float(latitude), float(longitude)))
    print("TRAFFIC POINTS:", len(validated_points), validated_points[:2], validated_points[-2:])
    assessment, reason = assess_route_traffic(validated_points, api_key)
    print("ROUTE TRAFFIC DEBUG:", reason, assessment)
    if assessment is None:
        status_code = 429 if reason == "rate_limited" else 503
        return jsonify({
            "available": False,
            "status": "Traffic data unavailable",
            "source": TOMTOM_TRAFFIC_SOURCE,
            "reason": reason,
        }), status_code
    return jsonify(assessment)


@app.route("/check-blackspot", methods=["GET", "POST", "OPTIONS"])
def check_blackspot():
    """Checks whether given latitude/longitude coordinates are within a reasonable

    distance of any verified blackspot (gps_verified=TRUE).
    Supports single coordinate lookup (GET/POST) and batch lookup for route segments (POST).
    """
    if request.method == "OPTIONS":
        return jsonify({"status": "ok"})
    if request.method == "POST":
        json_data = request.get_json(silent=True) or {}
        pts = json_data.get("points") or json_data.get("route_points")
        if pts and isinstance(pts, list):
            radius = float(json_data.get("radius_meters", 1000.0))
            matches, nearest, min_dist = find_route_blackspots(pts, radius)
            status_text = "Verified accident data: No matched blackspots" if len(matches) == 0 else f"Verified accident data: {len(matches)} matched blackspots"
            return jsonify({
                "verified_dataset_available": not verified_blackspots_df.empty,
                "verified_dataset_count": int(len(verified_blackspots_df)),
                "matches_count": len(matches),
                "matched_blackspots": matches,
                "nearest_blackspot": nearest,
                "min_distance_meters": min_dist,
                "status": status_text,
                "source": "Verified TN accident blackspots",
            })
        if "segments" in json_data and isinstance(json_data["segments"], list):
            segments_in = json_data["segments"]
            results = []
            for item in segments_in:
                lat = item.get("lat") or item.get("latitude")
                lon = item.get("lon") or item.get("longitude")
                radius = item.get("radius_meters", 1000.0)
                osm_id = item.get("osm_id")
                if lat is None or lon is None:
                    results.append({
                        "osm_id": osm_id,
                        "data_available": False,
                        "error": "missing_coords",
                    })
                    continue
                try:
                    lat_f = float(lat)
                    lon_f = float(lon)
                    radius_f = float(radius)
                except (ValueError, TypeError):
                    results.append({
                        "osm_id": osm_id,
                        "data_available": False,
                        "error": "invalid_coords",
                    })
                    continue
                matches, nearest = find_nearby_blackspots(lat_f, lon_f, radius_f)
                results.append({
                    "osm_id": osm_id,
                    "data_available": True,
                    "query": {
                        "latitude": lat_f,
                        "longitude": lon_f,
                        "radius_meters": radius_f,
                    },
                    "is_near_blackspot": len(matches) > 0,
                    "matches_count": len(matches),
                    "nearby_blackspots": matches,
                    "nearest_blackspot": nearest,
                })
            return jsonify({
                "verified_dataset_available": not verified_blackspots_df.empty,
                "verified_dataset_count": int(len(verified_blackspots_df)),
                "results": results,
            })
        lat = json_data.get("lat") or json_data.get("latitude")
        lon = json_data.get("lon") or json_data.get("longitude")
        radius_meters = json_data.get("radius_meters", 1000.0)
    else:
        lat = request.args.get("lat", type=float)
        lon = request.args.get("lon", type=float)
        radius_meters = request.args.get("radius_meters", default=1000.0, type=float)

    if lat is None or lon is None:
        return jsonify({
            "error": "Latitude ('lat') and longitude ('lon') query parameters are required"
        }), 400

    try:
        lat = float(lat)
        lon = float(lon)
        radius_meters = float(radius_meters)
    except (ValueError, TypeError):
        return jsonify({
            "error": "Invalid numeric format for latitude, longitude, or radius_meters"
        }), 400

    if not (-90.0 <= lat <= 90.0) or not (-180.0 <= lon <= 180.0):
        return jsonify({
            "error": "Latitude must be between -90 and 90, and longitude between -180 and 180"
        }), 400

    matches, nearest = find_nearby_blackspots(lat, lon, radius_meters)

    return jsonify({
        "query": {
            "latitude": lat,
            "longitude": lon,
            "radius_meters": radius_meters,
        },
        "verified_dataset_available": not verified_blackspots_df.empty,
        "verified_dataset_count": int(len(verified_blackspots_df)),
        "is_near_blackspot": len(matches) > 0,
        "matches_count": len(matches),
        "nearby_blackspots": matches,
        "nearest_blackspot": nearest,
    })


@app.route("/osm-roads", methods=["POST", "OPTIONS"])
def osm_roads():
    if request.method == "OPTIONS":
        return jsonify({"status": "ok"})
    json_data = request.get_json(silent=True) or {}
    points = json_data.get("points") or []
    if not points:
        return jsonify({"status": "unavailable", "reason": "No route points provided", "elements": []})

    parsed = []
    for p in points:
        if isinstance(p, (list, tuple)) and len(p) >= 2:
            try:
                parsed.append((float(p[0]), float(p[1])))
            except (ValueError, TypeError):
                pass
        elif isinstance(p, dict):
            lat = p.get("lat") or p.get("latitude")
            lon = p.get("lon") or p.get("longitude")
            if lat is not None and lon is not None:
                try:
                    parsed.append((float(lat), float(lon)))
                except (ValueError, TypeError):
                    pass

    if not parsed:
        return jsonify({"status": "unavailable", "reason": "Invalid route points", "elements": []})

    sample_count = min(5, max(2, len(parsed)))
    indices = [int(i * (len(parsed) - 1) / (sample_count - 1)) for i in range(sample_count)]
    samples = [parsed[i] for i in indices]

    clauses = [f'way["highway"~"^(motorway|trunk|primary|secondary|tertiary|residential)$"](around:500,{lat:.5f},{lon:.5f});' for lat, lon in samples]
    query = f'[out:json][timeout:8];({"".join(clauses)});out tags geom 35;'

    endpoints = [
        "https://overpass.openstreetmap.fr/api/interpreter",
        "https://overpass-api.de/api/interpreter"
    ]
    elements = []
    for ep in endpoints:
        try:
            data = urllib.parse.urlencode({"data": query}).encode("utf-8")
            req = urllib.request.Request(ep, data=data, headers={"User-Agent": "SafeRouteTN/1.0"})
            with urllib.request.urlopen(req, timeout=8) as resp:
                if resp.status == 200:
                    res = json.loads(resp.read().decode("utf-8"))
                    elements = res.get("elements", [])
                    if elements:
                        break
        except Exception as e:
            print(f"OSM ROADS ERROR at {ep}: {e}")
            continue

    if elements:
        return jsonify({
            "status": "ok",
            "source": "OpenStreetMap Overpass API",
            "elements": elements
        })

    if not road_segments_df.empty:
        matched_rows = []
        for _, row in road_segments_df.iterrows():
            rlat, rlon = float(row["latitude"]), float(row["longitude"])
            if any(haversine_distance(rlat, rlon, slat, slon) <= 2000.0 for slat, slon in samples):
                tags = {}
                for col in ["highway", "surface", "smoothness", "maxspeed", "lit", "lanes", "sidewalk", "access"]:
                    val = row.get(col)
                    if pd.notna(val) and str(val).strip():
                        tags[col] = str(val).strip()
                if "highway" in tags:
                    matched_rows.append({
                        "type": "way",
                        "id": int(row["osm_id"]),
                        "tags": tags,
                        "geometry": [
                            {"lat": rlat, "lon": rlon},
                            {"lat": rlat + 0.0001, "lon": rlon + 0.0001}
                        ]
                    })
        if matched_rows:
            return jsonify({
                "status": "ok",
                "source": "OpenStreetMap Verified Tamil Nadu Road Segments",
                "elements": matched_rows[:40]
            })

    return jsonify({
        "status": "unavailable",
        "reason": "No OSM road attributes available for this corridor",
        "elements": []
    })


@app.route("/nearby-places", methods=["POST", "OPTIONS"])
def nearby_places():
    if request.method == "OPTIONS":
        return jsonify({"status": "ok"})
    json_data = request.get_json(silent=True) or {}
    points = json_data.get("points") or []
    proximity_km = float(json_data.get("proximity_threshold_km", 1.5))
    categories = json_data.get("categories") or []

    parsed = []
    for p in points:
        if isinstance(p, (list, tuple)) and len(p) >= 2:
            try:
                parsed.append((float(p[0]), float(p[1])))
            except (ValueError, TypeError):
                pass
        elif isinstance(p, dict):
            lat = p.get("lat") or p.get("latitude")
            lon = p.get("lon") or p.get("longitude")
            if lat is not None and lon is not None:
                try:
                    parsed.append((float(lat), float(lon)))
                except (ValueError, TypeError):
                    pass

    if not parsed:
        return jsonify({"status": "unavailable", "places": [], "count": 0})

    sample_count = min(5, max(2, len(parsed)))
    indices = [int(i * (len(parsed) - 1) / (sample_count - 1)) for i in range(sample_count)]
    samples = [parsed[i] for i in indices]

    around_radius = min(2000, max(800, int(proximity_km * 1000)))
    clauses = []
    for lat, lon in samples:
        clauses.append(f'nwr["amenity"~"^(hospital|clinic|police|pharmacy|fuel|charging_station)$"](around:{around_radius},{lat:.5f},{lon:.5f});')

    query = f'[out:json][timeout:10];({"".join(clauses)});out center 50;'
    endpoints = [
        "https://overpass.openstreetmap.fr/api/interpreter",
        "https://overpass-api.de/api/interpreter"
    ]
    raw_elements = []
    for ep in endpoints:
        try:
            data = urllib.parse.urlencode({"data": query}).encode("utf-8")
            req = urllib.request.Request(ep, data=data, headers={"User-Agent": "SafeRouteTN/1.0"})
            with urllib.request.urlopen(req, timeout=8) as resp:
                if resp.status == 200:
                    res = json.loads(resp.read().decode("utf-8"))
                    raw_elements = res.get("elements", [])
                    if raw_elements:
                        break
        except Exception as e:
            print(f"POIS FETCH ERROR at {ep}: {e}")
            continue

    seen_ids = set()
    places = []
    sample_poly = parsed[::max(1, len(parsed) // 60)]

    for el in raw_elements:
        el_type = el.get("type", "node")
        el_id = el.get("id")
        unique_id = f"{el_type}/{el_id}"
        if unique_id in seen_ids:
            continue
        seen_ids.add(unique_id)

        tags = el.get("tags", {})
        center = el.get("center") if isinstance(el.get("center"), dict) else {}
        lat = el.get("lat") or center.get("lat")
        lon = el.get("lon") or center.get("lon")
        if lat is None or lon is None:
            continue

        try:
            lat, lon = float(lat), float(lon)
        except (ValueError, TypeError):
            continue

        min_d = min(haversine_distance(lat, lon, plat, plon) for plat, plon in sample_poly)
        dist_km = min_d / 1000.0

        if dist_km > proximity_km:
            continue

        amenity = tags.get("amenity", "")
        tourism = tags.get("tourism", "")

        if amenity in ["hospital", "clinic"]:
            cat = "hospital"
        elif amenity == "police":
            cat = "police"
        elif amenity == "pharmacy":
            cat = "pharmacy"
        elif amenity == "fuel":
            cat = "petrol_pump"
        elif amenity == "charging_station":
            cat = "ev_charging"
        elif amenity in ["atm", "bank"]:
            cat = "atm"
        elif amenity in ["restaurant", "fast_food", "cafe"]:
            cat = "restaurant"
        elif tourism in ["hotel", "motel", "guest_house"]:
            cat = "hotel"
        elif amenity == "toilets":
            cat = "restroom"
        elif amenity == "parking":
            cat = "parking"
        else:
            continue

        if categories and cat not in categories:
            continue

        name = tags.get("name")
        if not name:
            if cat == "hospital":
                name = "Hospital / Clinic"
            elif cat == "police":
                name = "Police Station"
            elif cat == "pharmacy":
                name = "Pharmacy"
            elif cat == "petrol_pump":
                name = tags.get("brand") or "Fuel Station"
            elif cat == "ev_charging":
                name = "EV Charging Station"
            elif cat == "atm":
                name = tags.get("operator") or "ATM"
            elif cat == "restaurant":
                name = "Restaurant"
            elif cat == "hotel":
                name = "Hotel"
            elif cat == "restroom":
                name = "Public Restroom"
            elif cat == "parking":
                name = "Parking Area"
            else:
                name = "Nearby Facility"

        place_obj = {
            "id": unique_id,
            "name": name,
            "category": cat,
            "latitude": lat,
            "longitude": lon,
            "distanceKm": round(dist_km, 2),
            "address": tags.get("addr:street") or tags.get("addr:full") or tags.get("addr:city"),
            "phoneNumber": tags.get("phone") or tags.get("contact:phone"),
            "openingHours": tags.get("opening_hours"),
            "wheelchairAccessible": tags.get("wheelchair") in ["yes", "designated"],
            "emergencyServicesAvailable": tags.get("emergency") == "yes" or cat in ["hospital", "police"],
            "isAlongRoute": dist_km <= 1.0,
            "rating": 4.2 if cat == "hospital" else 4.0,
        }
        places.append(place_obj)

    places.sort(key=lambda x: x["distanceKm"])

    hospitals = sum(1 for p in places if p["category"] == "hospital")
    police = sum(1 for p in places if p["category"] == "police")
    pharmacy = sum(1 for p in places if p["category"] == "pharmacy")
    fuel = sum(1 for p in places if p["category"] == "petrol_pump")

    print("\n=== NEARBY DATA AUDIT ===")
    print(f"Queried corridor chunks: {len(samples)}")
    print(f"Raw POIs found: {len(raw_elements)}")
    print(f"Deduplicated POIs: {len(seen_ids)}")
    print(f"Matched along route: {len(places)}")
    print(f"Hospitals: {hospitals}")
    print(f"Police: {police}")
    print(f"Pharmacies: {pharmacy}")
    print(f"Fuel: {fuel}")
    print("=========================\n")

    return jsonify({
        "status": "ok",
        "count": len(places),
        "places": places,
        "audit": {
            "corridor_chunks": len(samples),
            "raw_pois": len(raw_elements),
            "deduplicated_pois": len(seen_ids),
            "matched_along_route": len(places),
            "hospitals": hospitals,
            "police": police,
            "pharmacies": pharmacy,
            "fuel": fuel
        }
    })


@app.route("/location-safety", methods=["GET"])
def location_safety():
    lat = request.args.get("lat", type=float)
    lon = request.args.get("lon", type=float)
    radius_meters = request.args.get("radius_meters", default=1000.0, type=float)

    if lat is None or lon is None:
        return jsonify({
            "error": "Latitude and longitude are required"
        }), 400

    matches, nearest = find_nearby_blackspots(lat, lon, radius_meters)

    return jsonify({
        "latitude": lat,
        "longitude": lon,
        "status": "location received",
        "is_near_blackspot": len(matches) > 0,
        "matches_count": len(matches),
        "nearby_blackspots": matches,
        "nearest_blackspot": nearest,
    })


@app.route("/safety", methods=["GET"])
def safety():
    district = request.args.get("district", "")

    if data.empty:
        return jsonify({"error": "District dataset unavailable"}), 500

    result = data[
        data["City/District"].str.lower() == district.lower()
    ]

    if result.empty:
        return jsonify({
            "error": "District not found"
        }), 404

    row = result.iloc[0]
    accidents = row["Total Number of Accidents (2018)"]
    total_roads = row["Total_Roads_KM"]

    if pd.isna(total_roads) or total_roads <= 0:
        accident_safety = 50.0
    else:
        accident_rate = accidents / total_roads
        accident_safety = max(0, min(100, 100 - (accident_rate * 100)))

    surfaced = row["Surfaced_Roads_KM"]

    if pd.isna(surfaced) or pd.isna(total_roads):
        road_safety = None
        overall_score = accident_safety
    else:
        road_safety = (surfaced / total_roads) * 100
        overall_score = (accident_safety * 0.60 + road_safety * 0.40)

    return jsonify({
        "district": district,
        "accidents_2018": int(accidents),
        "accident_safety": round(accident_safety, 2),
        "road_safety": (
            None if road_safety is None else round(road_safety, 2)
        ),
        "overall_safety": round(overall_score, 2),
    })


FEEDBACK_DB_PATH = os.path.join(BASE_DIR, "feedback.db")


def init_feedback_db():
    with sqlite3.connect(FEEDBACK_DB_PATH) as conn:
        cursor = conn.cursor()
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS feedback (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                rating INTEGER NOT NULL,
                category TEXT NOT NULL,
                comment TEXT NOT NULL,
                email TEXT,
                timestamp TEXT NOT NULL
            )
            """
        )
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS road_reports (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                problem_type TEXT NOT NULL,
                severity TEXT NOT NULL,
                description TEXT NOT NULL,
                location_landmark TEXT,
                route_origin TEXT,
                route_destination TEXT,
                selected_route_index INTEGER,
                safety_score REAL,
                timestamp TEXT NOT NULL
            )
            """
        )
        conn.commit()


@app.route("/feedback", methods=["POST", "OPTIONS"])
def submit_feedback():
    if request.method == "OPTIONS":
        return jsonify({"status": "ok"})

    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify({"success": False, "error": "Invalid JSON body"}), 400

    rating = payload.get("rating")
    category = payload.get("category")
    comment = payload.get("comment")
    email = payload.get("email")
    timestamp = payload.get("timestamp")

    if not isinstance(rating, int) or rating < 1 or rating > 5:
        return jsonify({
            "success": False,
            "error": "Rating must be an integer between 1 and 5",
        }), 400

    if not isinstance(category, str) or not category.strip():
        return jsonify({
            "success": False,
            "error": "Category is required and cannot be empty",
        }), 400

    if not isinstance(comment, str) or not comment.strip():
        return jsonify({
            "success": False,
            "error": "Comment is required and cannot be empty",
        }), 400

    clean_category = category.strip()
    clean_comment = comment.strip()
    clean_email = email.strip() if isinstance(email, str) and email.strip() else None

    if not isinstance(timestamp, str) or not timestamp.strip():
        timestamp = datetime.now(timezone.utc).isoformat()
    else:
        timestamp = timestamp.strip()

    try:
        init_feedback_db()
        with sqlite3.connect(FEEDBACK_DB_PATH) as conn:
            cursor = conn.cursor()
            cursor.execute(
                """
                INSERT INTO feedback (rating, category, comment, email, timestamp)
                VALUES (?, ?, ?, ?, ?)
                """,
                (rating, clean_category, clean_comment, clean_email, timestamp),
            )
            conn.commit()
            feedback_id = cursor.lastrowid

        return jsonify({
            "success": True,
            "message": "Feedback submitted successfully",
            "feedback_id": feedback_id,
        }), 201
    except Exception as exc:
        return jsonify({
            "success": False,
            "error": f"Failed to save feedback: {str(exc)}",
        }), 500


@app.route("/feedback", methods=["GET"])
def get_feedback():
    try:
        init_feedback_db()
        with sqlite3.connect(FEEDBACK_DB_PATH) as conn:
            conn.row_factory = sqlite3.Row
            cursor = conn.cursor()
            cursor.execute(
                "SELECT id, rating, category, comment, email, timestamp FROM feedback ORDER BY id DESC"
            )
            rows = [dict(row) for row in cursor.fetchall()]
        return jsonify({"success": True, "count": len(rows), "feedback": rows})
    except Exception as exc:
        return jsonify({"success": False, "error": str(exc)}), 500


@app.route("/road-report", methods=["POST", "OPTIONS"])
def submit_road_report():
    if request.method == "OPTIONS":
        return jsonify({"status": "ok"})

    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify({"success": False, "error": "Invalid JSON body"}), 400

    problem_type = payload.get("problem_type")
    severity = payload.get("severity")
    description = payload.get("description")
    location_landmark = payload.get("location_landmark")
    route_origin = payload.get("route_origin")
    route_destination = payload.get("route_destination")
    selected_route_index = payload.get("selected_route_index")
    safety_score = payload.get("safety_score")
    timestamp = payload.get("timestamp")

    if not isinstance(problem_type, str) or not problem_type.strip():
        return jsonify({
            "success": False,
            "error": "Problem type is required and cannot be empty",
        }), 400

    if not isinstance(severity, str):
        return jsonify({
            "success": False,
            "error": "Severity must be 'Low', 'Medium', or 'High'",
        }), 400

    clean_severity = severity.strip().title()
    if clean_severity not in ["Low", "Medium", "High"]:
        return jsonify({
            "success": False,
            "error": "Severity must be 'Low', 'Medium', or 'High'",
        }), 400

    if not isinstance(description, str) or not description.strip():
        return jsonify({
            "success": False,
            "error": "Description is required and cannot be empty",
        }), 400

    clean_problem_type = problem_type.strip()
    clean_description = description.strip()
    clean_landmark = (
        location_landmark.strip()
        if isinstance(location_landmark, str) and location_landmark.strip()
        else None
    )
    clean_origin = (
        route_origin.strip()
        if isinstance(route_origin, str) and route_origin.strip()
        else None
    )
    clean_destination = (
        route_destination.strip()
        if isinstance(route_destination, str) and route_destination.strip()
        else None
    )

    clean_route_idx = None
    if selected_route_index is not None:
        try:
            clean_route_idx = int(selected_route_index)
        except (ValueError, TypeError):
            clean_route_idx = None

    clean_score = None
    if safety_score is not None:
        try:
            clean_score = float(safety_score)
        except (ValueError, TypeError):
            clean_score = None

    if not isinstance(timestamp, str) or not timestamp.strip():
        timestamp = datetime.now(timezone.utc).isoformat()
    else:
        timestamp = timestamp.strip()

    try:
        init_feedback_db()
        with sqlite3.connect(FEEDBACK_DB_PATH) as conn:
            cursor = conn.cursor()
            cursor.execute(
                """
                INSERT INTO road_reports (
                    problem_type, severity, description, location_landmark,
                    route_origin, route_destination, selected_route_index,
                    safety_score, timestamp
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    clean_problem_type,
                    clean_severity,
                    clean_description,
                    clean_landmark,
                    clean_origin,
                    clean_destination,
                    clean_route_idx,
                    clean_score,
                    timestamp,
                ),
            )
            conn.commit()
            report_id = cursor.lastrowid

        return jsonify({
            "success": True,
            "message": "Road problem reported successfully",
            "report_id": report_id,
        }), 201
    except Exception as exc:
        return jsonify({
            "success": False,
            "error": f"Failed to save road report: {str(exc)}",
        }), 500


@app.route("/road-reports", methods=["GET"])
def get_road_reports():
    try:
        init_feedback_db()
        with sqlite3.connect(FEEDBACK_DB_PATH) as conn:
            conn.row_factory = sqlite3.Row
            cursor = conn.cursor()
            cursor.execute(
                """
                SELECT id, problem_type, severity, description, location_landmark,
                       route_origin, route_destination, selected_route_index,
                       safety_score, timestamp
                FROM road_reports
                ORDER BY id DESC
                """
            )
            rows = [dict(row) for row in cursor.fetchall()]
        return jsonify({"success": True, "count": len(rows), "reports": rows})
    except Exception as exc:
        return jsonify({"success": False, "error": str(exc)}), 500


if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=5000,
        debug=True
    )