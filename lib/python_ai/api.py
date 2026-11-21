import os
import time
import re
import json
import math
import gzip
import struct
import sqlite3
from datetime import datetime, timezone, timedelta
import secrets
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

    def _point_to_tile(lat, lon):
        if not (-85.05112878 < lat < 85.05112878):
            return None
        x = (lon + 180.0) / 360.0 * world_tiles
        lat_rad = math.radians(lat)
        y = (
            1.0 - math.asinh(math.tan(lat_rad)) / math.pi
        ) / 2.0 * world_tiles
        tx = int(math.floor(x))
        ty = int(math.floor(y))
        if 0 <= tx < world_tiles and 0 <= ty < world_tiles:
            return (tx, ty)
        return None

    for i in range(len(route_points)):
        pt = route_points[i]
        tile = _point_to_tile(pt[0], pt[1])
        if tile:
            tiles.add(tile)
        if i < len(route_points) - 1:
            next_pt = route_points[i + 1]
            dist = haversine_distance(pt[0], pt[1], next_pt[0], next_pt[1])
            if dist > 2500.0:
                steps = min(50, math.ceil(dist / 2000.0))
                for step in range(1, steps):
                    frac = step / steps
                    interp_lat = pt[0] + (next_pt[0] - pt[0]) * frac
                    interp_lon = pt[1] + (next_pt[1] - pt[1]) * frac
                    interp_tile = _point_to_tile(interp_lat, interp_lon)
                    if interp_tile:
                        tiles.add(interp_tile)

    return sorted(tiles)

def fetch_tomtom_traffic_tile(tile, api_key):
    zoom, tile_x, tile_y = tile
    query = urllib.parse.urlencode(
        {
            "key": api_key,
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
        if error.code in (401, 403):
            return {"http_status": error.code, "reason": "provider_auth_error"}
        if error.code == 429:
            return {"http_status": 429, "reason": "rate_limited"}
        return {"http_status": error.code}
    except (urllib.error.URLError, TimeoutError):
        return {"http_status": 504, "reason": "timeout"}
    except (ValueError, OSError, struct.error):
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

    cell_size = 150.0
    feature_grid = {}
    for feature_index, feature in enumerate(features):
        points = [point for path in feature["paths"] for point in path]
        if not points:
            continue
        minimum_x = min(point[0] for point in points)
        maximum_x = max(point[0] for point in points)
        minimum_y = min(point[1] for point in points)
        maximum_y = max(point[1] for point in points)
        min_cx = math.floor(minimum_x / cell_size)
        max_cx = math.floor(maximum_x / cell_size)
        min_cy = math.floor(minimum_y / cell_size)
        max_cy = math.floor(maximum_y / cell_size)

        # Protect against unbounded cell ranges for very long features
        if (max_cx - min_cx + 1) * (max_cy - min_cy + 1) > 400:
            for path in feature["paths"]:
                for pt in path:
                    cx = math.floor(pt[0] / cell_size)
                    cy = math.floor(pt[1] / cell_size)
                    feature_grid.setdefault((cx, cy), set()).add(feature_index)
        else:
            for cell_x in range(min_cx, max_cx + 1):
                for cell_y in range(min_cy, max_cy + 1):
                    feature_grid.setdefault((cell_x, cell_y), set()).add(feature_index)

    observations = []
    MAX_ROUTE_MATCH_DISTANCE_METERS = 60.0  # Dual-carriageway divided highway tolerance
    for point_x, point_y, latitude in samples:
        center_x = math.floor(point_x / cell_size)
        center_y = math.floor(point_y / cell_size)
        candidate_indexes = set()
        for cell_x in range(center_x - 1, center_x + 2):
            for cell_y in range(center_y - 1, center_y + 2):
                candidate_indexes.update(feature_grid.get((cell_x, cell_y), ()))

        cos_lat = max(0.1, math.cos(math.radians(latitude)))
        match_radius = MAX_ROUTE_MATCH_DISTANCE_METERS / cos_lat
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

    if any(
        isinstance(result, dict) and result.get("http_status") in (401, 403)
        for result in tile_results
    ):
        return None, "provider_auth_error"

    if any(
        isinstance(result, dict) and result.get("http_status") in (408, 504)
        for result in tile_results
    ):
        return None, "timeout"

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
        congestion_level = "High"
        traffic_score = 0.0 if road_closure else round(mean_speed_ratio * 100.0, 1)
    elif mean_speed_ratio < 0.8:
        status = "Moderate Traffic"
        congestion_level = "Moderate"
        traffic_score = round(mean_speed_ratio * 100.0, 1)
    else:
        status = "Low Traffic"
        congestion_level = "Low"
        traffic_score = round(mean_speed_ratio * 100.0, 1)

    coverage_percent = max(1, round(100.0 * len(observations) / len(samples)))
    unmonitored_samples = max(0, len(samples) - len(observations))
    unmonitored_percent = max(0, 100 - coverage_percent)
    is_partial_coverage = coverage_percent < 90
    if is_partial_coverage:
        status_description = (
            f"{status} on monitored segments "
            f"({coverage_percent}% covered, {unmonitored_percent}% unmonitored)"
        )
    else:
        status_description = f"{status} ({coverage_percent}% coverage)"

    return {
        "available": True,
        "source": TOMTOM_TRAFFIC_SOURCE,
        "status": status,
        "statusDescription": status_description,
        "status_description": status_description,
        "congestionLevel": congestion_level,
        "congestion_level": congestion_level,
        "trafficScore": traffic_score,
        "traffic_score": traffic_score,
        "speedRatio": round(float(mean_speed_ratio), 3),
        "mean_speed_ratio": float(mean_speed_ratio),
        "sampleCount": int(len(samples)),
        "sample_count": int(len(samples)),
        "matchedSamples": int(len(observations)),
        "matched_samples": int(len(observations)),
        "unmonitoredSamples": int(unmonitored_samples),
        "unmonitored_samples": int(unmonitored_samples),
        "coveragePercentage": int(coverage_percent),
        "coverage_percent": int(coverage_percent),
        "unmonitoredPercentage": int(unmonitored_percent),
        "unmonitored_percent": int(unmonitored_percent),
        "isPartialCoverage": bool(is_partial_coverage),
        "is_partial_coverage": bool(is_partial_coverage),
        "roadClosure": bool(road_closure),
        "road_closure": bool(road_closure),
        "closures": 1 if road_closure else 0,
        "incidents": 1 if road_closure else 0,
        "fetchedAt": datetime.now(timezone.utc).isoformat(),
        "fetched_at": datetime.now(timezone.utc).isoformat(),
        "providerObservationAge": "unavailable",
        "provider_observation_age": "unavailable",
        "freshness": "Fetched just now (provider age unavailable)",
    }, None


@app.route("/route-traffic", methods=["POST", "OPTIONS"])
def route_traffic():
    if request.method == "OPTIONS":
        return jsonify({"status": "ok"})

    # Ensure environment variables are fresh from .env if not yet loaded
    if not os.environ.get("TOMTOM_API_KEY"):
        _load_env_file()
    api_key = os.environ.get("TOMTOM_API_KEY", "").strip()
    if not api_key:
        return jsonify({
            "available": False,
            "status": "Traffic data unavailable",
            "source": TOMTOM_TRAFFIC_SOURCE,
            "reason": "provider_not_configured",
        }), 503

    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify({
            "available": False,
            "status": "Traffic data unavailable",
            "source": TOMTOM_TRAFFIC_SOURCE,
            "reason": "invalid_route_geometry",
        }), 400

    route_points = (
        payload.get("points")
        or payload.get("coordinates")
        or payload.get("route_points")
        or payload.get("route")
    )
    if not route_points and isinstance(payload.get("geometry"), dict):
        route_points = payload.get("geometry", {}).get("coordinates")

    if not isinstance(route_points, list) or len(route_points) < 2 or len(route_points) > 20000:
        return jsonify({
            "available": False,
            "status": "Traffic data unavailable",
            "source": TOMTOM_TRAFFIC_SOURCE,
            "reason": "invalid_route_geometry",
        }), 400

    validated_points = []
    for point in route_points:
        raw_lat = None
        raw_lon = None
        if isinstance(point, (list, tuple)) and len(point) >= 2:
            raw_lat, raw_lon = point[0], point[1]
        elif isinstance(point, dict):
            raw_lat = point.get("lat") or point.get("latitude")
            raw_lon = point.get("lon") or point.get("longitude")
        else:
            return jsonify({
                "available": False,
                "status": "Traffic data unavailable",
                "source": TOMTOM_TRAFFIC_SOURCE,
                "reason": "invalid_route_geometry",
            }), 400

        if (
            not isinstance(raw_lat, (int, float))
            or isinstance(raw_lat, bool)
            or not math.isfinite(raw_lat)
            or not isinstance(raw_lon, (int, float))
            or isinstance(raw_lon, bool)
            or not math.isfinite(raw_lon)
        ):
            return jsonify({
                "available": False,
                "status": "Traffic data unavailable",
                "source": TOMTOM_TRAFFIC_SOURCE,
                "reason": "invalid_route_geometry",
            }), 400

        # Auto-detect GeoJSON [longitude, latitude] vs [latitude, longitude]
        # In India / Tamil Nadu, lat is ~8-14 (< 40) and lon is ~76-81 (> 50).
        f_lat = float(raw_lat)
        f_lon = float(raw_lon)
        if (f_lat > 50.0 and f_lon < 40.0) or (abs(f_lat) > 90.0 and abs(f_lon) <= 90.0):
            # Coordinates were provided as [longitude, latitude] -> swap
            latitude, longitude = f_lon, f_lat
        else:
            latitude, longitude = f_lat, f_lon

        if not (-90.0 <= latitude <= 90.0) or not (-180.0 <= longitude <= 180.0):
            return jsonify({
                "available": False,
                "status": "Traffic data unavailable",
                "source": TOMTOM_TRAFFIC_SOURCE,
                "reason": "invalid_route_geometry",
            }), 400

        validated_points.append((latitude, longitude))

    if len(validated_points) < 2:
        return jsonify({
            "available": False,
            "status": "Traffic data unavailable",
            "source": TOMTOM_TRAFFIC_SOURCE,
            "reason": "invalid_route_geometry",
        }), 400

    assessment, reason = assess_route_traffic(validated_points, api_key)
    if assessment is None:
        if reason == "rate_limited":
            status_code = 429
        elif reason == "timeout":
            status_code = 504
        elif reason == "invalid_route_geometry":
            status_code = 400
        else:
            status_code = 503
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

HAZARD_CATEGORIES = {
    "pothole_damaged_road": {
        "title": "Pothole / damaged road",
        "icon": "pothole",
        "is_permanent": True,
        "reconfirm_days": 14,
        "ttl_hours": None,
    },
    "flooding_waterlogging": {
        "title": "Flooding / waterlogging",
        "icon": "flooding",
        "is_permanent": False,
        "reconfirm_days": None,
        "ttl_hours": 12,
    },
    "road_blocked": {
        "title": "Road blocked",
        "icon": "road_blocked",
        "is_permanent": False,
        "reconfirm_days": None,
        "ttl_hours": 8,
    },
    "construction": {
        "title": "Construction",
        "icon": "construction",
        "is_permanent": False,
        "reconfirm_days": None,
        "ttl_hours": 336,  # 14 days
    },
    "broken_streetlight": {
        "title": "Broken streetlight",
        "icon": "broken_streetlight",
        "is_permanent": True,
        "reconfirm_days": 30,
        "ttl_hours": None,
    },
    "broken_footpath": {
        "title": "Broken footpath / missing sidewalk",
        "icon": "broken_footpath",
        "is_permanent": True,
        "reconfirm_days": 30,
        "ttl_hours": None,
    },
    "missing_wheelchair_ramp": {
        "title": "Missing wheelchair ramp",
        "icon": "missing_wheelchair_ramp",
        "is_permanent": True,
        "reconfirm_days": 30,
        "ttl_hours": None,
    },
    "unsafe_pedestrian_crossing": {
        "title": "Unsafe pedestrian crossing",
        "icon": "unsafe_pedestrian_crossing",
        "is_permanent": True,
        "reconfirm_days": 30,
        "ttl_hours": None,
    },
    "accident_hazard": {
        "title": "Accident / other hazard",
        "icon": "accident_hazard",
        "is_permanent": False,
        "reconfirm_days": None,
        "ttl_hours": 8,
    },
}

_REPORT_RATE_LIMITS = {}  # session_id -> list of datetime
_VERIFY_RATE_LIMITS = {}


def _check_rate_limit(store, key, max_requests=5, window_seconds=60):
    now = datetime.now(timezone.utc)
    if key not in store:
        store[key] = []
    # purge old
    store[key] = [t for t in store[key] if (now - t).total_seconds() < window_seconds]
    if len(store[key]) >= max_requests:
        return False
    store[key].append(now)
    return True


def normalize_hazard_category(cat_str):
    if not cat_str or not isinstance(cat_str, str):
        return None
    s = cat_str.strip().lower()
    for key, cfg in HAZARD_CATEGORIES.items():
        if key == s or key in s:
            return key
        if cfg["title"].lower() in s:
            return key
    if "pothole" in s or "damaged road" in s or "crater" in s:
        return "pothole_damaged_road"
    if "flood" in s or "waterlog" in s:
        return "flooding_waterlogging"
    if "block" in s or "closure" in s:
        return "road_blocked"
    if "construction" in s or "road work" in s or "work" in s:
        return "construction"
    if "streetlight" in s or "street light" in s or "signal" in s or "light" in s:
        return "broken_streetlight"
    if "footpath" in s or "sidewalk" in s or "pavement" in s:
        return "broken_footpath"
    if "wheelchair" in s or "ramp" in s or "accessibility" in s:
        return "missing_wheelchair_ramp"
    if "pedestrian" in s or "crossing" in s or "zebra" in s:
        return "unsafe_pedestrian_crossing"
    if "accident" in s or "hazard" in s or "crash" in s:
        return "accident_hazard"
    return None


def calculate_hazard_confidence(report):
    score = 25.0
    confs = int(report.get("confirmations_count") or 0)
    score += min(confs * 20.0, 50.0)
    disputes = int(report.get("disputes_count") or 0)
    score -= (disputes * 30.0)

    acc = report.get("location_accuracy")
    if acc is not None:
        try:
            acc_val = float(acc)
            if acc_val <= 15.0:
                score += 10.0
            elif acc_val <= 50.0:
                score += 5.0
        except (ValueError, TypeError):
            pass

    desc = report.get("description") or ""
    if len(desc.strip()) >= 20:
        score += 5.0
    if report.get("location_landmark"):
        score += 5.0
    if report.get("photo_url"):
        score += 10.0

    ts_str = report.get("timestamp")
    if ts_str:
        try:
            created_at = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
            age_hours = (datetime.now(timezone.utc) - created_at).total_seconds() / 3600.0
            if age_hours <= 4.0:
                score += 10.0
            elif age_hours <= 24.0:
                score += 5.0
            elif age_hours > 48.0 and confs == 0:
                score -= 15.0
        except Exception:
            pass

    score = max(0.0, min(100.0, score))
    if score >= 70.0:
        level = "High confidence"
    elif score >= 40.0:
        level = "Moderate confidence"
    else:
        level = "Low confidence"

    return round(score, 1), level


def compute_hazard_status_and_expiry(report):
    status = report.get("status") or "Pending"
    if status == "Resolved":
        return "Resolved", False

    cat_key = report.get("category")
    cfg = HAZARD_CATEGORIES.get(cat_key, {})
    is_perm = cfg.get("is_permanent", False)
    ttl = cfg.get("ttl_hours")

    disputes = int(report.get("disputes_count") or 0)
    confs = int(report.get("confirmations_count") or 0)

    ts_str = report.get("timestamp")
    last_conf_str = report.get("last_confirmed_at")
    age_hours = 0.0
    if ts_str:
        try:
            created_at = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
            ref_time = created_at
            if last_conf_str:
                try:
                    ref_time = max(ref_time, datetime.fromisoformat(last_conf_str.replace("Z", "+00:00")))
                except Exception:
                    pass
            age_hours = (datetime.now(timezone.utc) - ref_time).total_seconds() / 3600.0
        except Exception:
            pass

    if not is_perm and ttl and age_hours > ttl and confs == 0:
        return "Expired", False

    if disputes >= 2 and disputes >= confs:
        return "Disputed", False
    if confs >= 2 and confs > disputes:
        return "Confirmed", False

    needs_reconf = False
    reconf_days = cfg.get("reconfirm_days")
    if is_perm and reconf_days and (age_hours / 24.0) > reconf_days:
        needs_reconf = True

    return status if status in ["Pending", "Confirmed", "Disputed"] else "Pending", needs_reconf


def check_hazard_near_blackspot(lat, lon, threshold_meters=200.0):
    if lat is None or lon is None or verified_blackspots_df.empty:
        return False, None
    try:
        lat_f = float(lat)
        lon_f = float(lon)
    except (ValueError, TypeError):
        return False, None

    for _, row in verified_blackspots_df.iterrows():
        b_lat = float(row["latitude"])
        b_lon = float(row["longitude"])
        d = haversine_distance(lat_f, lon_f, b_lat, b_lon)
        if d <= threshold_meters:
            return True, str(row["blackspot_id"])
    return False, None


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
        # Migrate road_reports columns if missing
        cursor.execute("PRAGMA table_info(road_reports)")
        existing_cols = {col[1] for col in cursor.fetchall()}
        new_cols = [
            ("category", "TEXT"),
            ("latitude", "REAL"),
            ("longitude", "REAL"),
            ("location_accuracy", "REAL"),
            ("location_source", "TEXT"),
            ("photo_url", "TEXT"),
            ("user_session_id", "TEXT"),
            ("status", "TEXT DEFAULT 'Pending'"),
            ("confirmations_count", "INTEGER DEFAULT 0"),
            ("disputes_count", "INTEGER DEFAULT 0"),
            ("last_confirmed_at", "TEXT"),
            ("resolved_at", "TEXT"),
            ("confidence_score", "REAL DEFAULT 25.0"),
            ("confidence_level", "TEXT DEFAULT 'Low confidence'"),
        ]
        for col_name, col_type in new_cols:
            if col_name not in existing_cols:
                try:
                    cursor.execute(f"ALTER TABLE road_reports ADD COLUMN {col_name} {col_type}")
                except Exception:
                    pass

        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS hazard_verifications (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                report_id INTEGER NOT NULL,
                user_session_id TEXT NOT NULL,
                action TEXT NOT NULL,
                comment TEXT,
                timestamp TEXT NOT NULL,
                UNIQUE(report_id, user_session_id)
            )
            """
        )
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS live_shared_trips (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                share_token TEXT UNIQUE NOT NULL,
                update_token TEXT NOT NULL,
                origin TEXT,
                destination TEXT NOT NULL,
                vehicle TEXT,
                eta_minutes INTEGER,
                status TEXT NOT NULL DEFAULT 'active',
                latitude REAL,
                longitude REAL,
                heading REAL,
                speed REAL,
                accuracy REAL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                expires_at TEXT NOT NULL
            )
            """
        )
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_shared_trips_share_token ON live_shared_trips(share_token)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_shared_trips_update_token ON live_shared_trips(update_token)")
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

    user_session_id = str(payload.get("user_session_id") or "session_anonymous").strip()
    if not _check_rate_limit(_REPORT_RATE_LIMITS, user_session_id, max_requests=5, window_seconds=60):
        return jsonify({
            "success": False,
            "error": "Rate limit exceeded. Maximum 5 reports per minute.",
        }), 429

    problem_type = payload.get("problem_type")
    raw_cat = payload.get("category") or problem_type
    cat_slug = normalize_hazard_category(raw_cat)
    if not cat_slug:
        return jsonify({
            "success": False,
            "error": "A valid hazard category is required",
        }), 400

    description = payload.get("description")
    if not isinstance(description, str) or not description.strip():
        return jsonify({
            "success": False,
            "error": "Description is required and cannot be empty",
        }), 400

    severity = payload.get("severity") or "Medium"
    if not isinstance(severity, str):
        severity = "Medium"
    clean_severity = severity.strip().title()
    if clean_severity not in ["Low", "Medium", "High"]:
        clean_severity = "Medium"

    lat = payload.get("latitude")
    lon = payload.get("longitude")
    clean_lat = None
    clean_lon = None
    if lat is not None or lon is not None:
        try:
            clean_lat = float(lat)
            clean_lon = float(lon)
            if not (-90.0 <= clean_lat <= 90.0 and -180.0 <= clean_lon <= 180.0):
                return jsonify({
                    "success": False,
                    "error": "Latitude and longitude must be valid geographical coordinates",
                }), 400
        except (ValueError, TypeError):
            return jsonify({
                "success": False,
                "error": "Invalid coordinate format",
            }), 400

    clean_accuracy = None
    if payload.get("location_accuracy") is not None:
        try:
            clean_accuracy = float(payload.get("location_accuracy"))
        except (ValueError, TypeError):
            clean_accuracy = None

    clean_source = str(payload.get("location_source") or "gps").strip()
    clean_photo = str(payload.get("photo_url") or "").strip() or None
    clean_landmark = (
        payload.get("location_landmark").strip()
        if isinstance(payload.get("location_landmark"), str) and payload.get("location_landmark").strip()
        else None
    )
    clean_origin = (
        payload.get("route_origin").strip()
        if isinstance(payload.get("route_origin"), str) and payload.get("route_origin").strip()
        else None
    )
    clean_destination = (
        payload.get("route_destination").strip()
        if isinstance(payload.get("route_destination"), str) and payload.get("route_destination").strip()
        else None
    )

    clean_route_idx = None
    if payload.get("selected_route_index") is not None:
        try:
            clean_route_idx = int(payload.get("selected_route_index"))
        except (ValueError, TypeError):
            clean_route_idx = None

    clean_score = None
    if payload.get("safety_score") is not None:
        try:
            clean_score = float(payload.get("safety_score"))
        except (ValueError, TypeError):
            clean_score = None

    timestamp = payload.get("timestamp")
    if not isinstance(timestamp, str) or not timestamp.strip():
        timestamp = datetime.now(timezone.utc).isoformat()
    else:
        timestamp = timestamp.strip()

    force_new = bool(payload.get("force_new", False))

    init_feedback_db()
    # Check duplicate reports within 50m of same category in last 6 hours
    if clean_lat is not None and clean_lon is not None and not force_new:
        try:
            with sqlite3.connect(FEEDBACK_DB_PATH) as conn:
                conn.row_factory = sqlite3.Row
                cursor = conn.cursor()
                cursor.execute(
                    """
                    SELECT id, problem_type, category, severity, description,
                           latitude, longitude, status, timestamp
                    FROM road_reports
                    WHERE category = ? AND status NOT IN ('Resolved', 'Expired')
                    """,
                    (cat_slug,)
                )
                for row in cursor.fetchall():
                    r_dict = dict(row)
                    if r_dict.get("latitude") is not None and r_dict.get("longitude") is not None:
                        dist_m = haversine_distance(clean_lat, clean_lon, r_dict["latitude"], r_dict["longitude"])
                        if dist_m <= 50.0:
                            try:
                                r_time = datetime.fromisoformat(r_dict["timestamp"].replace("Z", "+00:00"))
                                if (datetime.now(timezone.utc) - r_time).total_seconds() <= 21600:
                                    return jsonify({
                                        "success": False,
                                        "error": "duplicate_detected",
                                        "duplicate_detected": True,
                                        "duplicate_report": r_dict,
                                        "existing_report": r_dict,
                                        "existing_report_id": r_dict["id"],
                                        "distance_meters": round(dist_m, 1),
                                        "message": f"A similar {r_dict['problem_type']} report already exists {round(dist_m, 1)}m away. You can confirm it instead.",
                                    }), 409
                            except Exception:
                                pass
        except Exception:
            pass

    # Double-counting check with verified blackspots
    is_near_b, matched_b_id = check_hazard_near_blackspot(clean_lat, clean_lon, threshold_meters=200.0)

    cat_title = HAZARD_CATEGORIES[cat_slug]["title"]
    temp_rep = {
        "description": description.strip(),
        "location_accuracy": clean_accuracy,
        "location_landmark": clean_landmark,
        "photo_url": clean_photo,
        "confirmations_count": 0,
        "disputes_count": 0,
        "timestamp": timestamp,
    }
    conf_score, conf_level = calculate_hazard_confidence(temp_rep)

    try:
        with sqlite3.connect(FEEDBACK_DB_PATH) as conn:
            cursor = conn.cursor()
            cursor.execute(
                """
                INSERT INTO road_reports (
                    problem_type, category, severity, description, location_landmark,
                    latitude, longitude, location_accuracy, location_source, photo_url,
                    user_session_id, status, confirmations_count, disputes_count,
                    confidence_score, confidence_level, route_origin, route_destination,
                    selected_route_index, safety_score, timestamp
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    cat_title,
                    cat_slug,
                    clean_severity,
                    description.strip(),
                    clean_landmark,
                    clean_lat,
                    clean_lon,
                    clean_accuracy,
                    clean_source,
                    clean_photo,
                    user_session_id,
                    "Pending",
                    0,
                    0,
                    conf_score,
                    conf_level,
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
            "message": "Community road hazard reported successfully",
            "report_id": report_id,
            "category": cat_slug,
            "status": "Pending",
            "confidence_score": conf_score,
            "confidence_level": conf_level,
            "is_near_blackspot": is_near_b,
            "matched_blackspot_id": matched_b_id,
        }), 201
    except Exception as exc:
        return jsonify({
            "success": False,
            "error": f"Failed to save road report: {str(exc)}",
        }), 500


@app.route("/road-report/<int:report_id>/verify", methods=["POST", "OPTIONS"])
def verify_road_report(report_id):
    if request.method == "OPTIONS":
        return jsonify({"status": "ok"})

    payload = request.get_json(silent=True) or {}
    user_session_id = str(payload.get("user_session_id") or "").strip()
    action = str(payload.get("action") or "").strip().lower()
    comment = str(payload.get("comment") or "").strip() or None

    if not user_session_id:
        return jsonify({"success": False, "error": "user_session_id is required"}), 400

    if not _check_rate_limit(_VERIFY_RATE_LIMITS, user_session_id, max_requests=15, window_seconds=60):
        return jsonify({
            "success": False,
            "error": "Rate limit exceeded. Maximum 15 verification actions per minute.",
        }), 429

    if action not in ["still_there", "resolved", "incorrect_location", "incorrect_report"]:
        return jsonify({
            "success": False,
            "error": "Action must be one of: 'still_there', 'resolved', 'incorrect_location', 'incorrect_report'",
        }), 400

    try:
        init_feedback_db()
        with sqlite3.connect(FEEDBACK_DB_PATH) as conn:
            conn.row_factory = sqlite3.Row
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM road_reports WHERE id = ?", (report_id,))
            rep_row = cursor.fetchone()
            if not rep_row:
                return jsonify({"success": False, "error": "Report not found"}), 404
            report = dict(rep_row)

            # Prevent self-confirmation
            if report.get("user_session_id") == user_session_id and action == "still_there":
                return jsonify({
                    "success": False,
                    "error": "You cannot confirm your own report.",
                }), 403

            now_ts = datetime.now(timezone.utc).isoformat()

            cursor.execute(
                "SELECT * FROM hazard_verifications WHERE report_id = ? AND user_session_id = ?",
                (report_id, user_session_id),
            )
            prev_ver = cursor.fetchone()

            if prev_ver:
                if prev_ver["action"] == action:
                    return jsonify({
                        "success": False,
                        "error": "You have already submitted this verification action.",
                    }), 409
                cursor.execute(
                    """
                    UPDATE hazard_verifications SET action = ?, comment = ?, timestamp = ?
                    WHERE report_id = ? AND user_session_id = ?
                    """,
                    (action, comment, now_ts, report_id, user_session_id),
                )
            else:
                cursor.execute(
                    """
                    INSERT INTO hazard_verifications (report_id, user_session_id, action, comment, timestamp)
                    VALUES (?, ?, ?, ?, ?)
                    """,
                    (report_id, user_session_id, action, comment, now_ts),
                )

            cursor.execute(
                "SELECT action, COUNT(*) FROM hazard_verifications WHERE report_id = ? GROUP BY action",
                (report_id,),
            )
            action_counts = dict(cursor.fetchall())
            confs = action_counts.get("still_there", 0)
            disputes = action_counts.get("incorrect_location", 0) + action_counts.get("incorrect_report", 0)
            resolveds = action_counts.get("resolved", 0)

            report["confirmations_count"] = confs
            report["disputes_count"] = disputes
            if action == "still_there":
                report["last_confirmed_at"] = now_ts
            if resolveds >= 2:
                report["status"] = "Resolved"
                report["resolved_at"] = now_ts

            new_status, _ = compute_hazard_status_and_expiry(report)
            conf_score, conf_level = calculate_hazard_confidence(report)

            cursor.execute(
                """
                UPDATE road_reports SET
                    confirmations_count = ?,
                    disputes_count = ?,
                    status = ?,
                    confidence_score = ?,
                    confidence_level = ?,
                    last_confirmed_at = COALESCE(?, last_confirmed_at),
                    resolved_at = COALESCE(?, resolved_at)
                WHERE id = ?
                """,
                (
                    confs,
                    disputes,
                    new_status,
                    conf_score,
                    conf_level,
                    now_ts if action == "still_there" else None,
                    now_ts if new_status == "Resolved" else None,
                    report_id,
                ),
            )
            conn.commit()

        return jsonify({
            "success": True,
            "message": f"Verification '{action}' recorded successfully",
            "report_id": report_id,
            "action": action,
            "status": new_status,
            "confirmations_count": confs,
            "disputes_count": disputes,
            "confidence_score": conf_score,
            "confidence_level": conf_level,
        }), 200
    except Exception as exc:
        return jsonify({"success": False, "error": str(exc)}), 500


@app.route("/road-reports", methods=["GET"])
def get_road_reports():
    try:
        init_feedback_db()
        active_only = request.args.get("active_only", "true").lower() in ["true", "1", "yes"]
        filter_status = request.args.get("status")
        filter_cat = request.args.get("category")
        session_id = request.args.get("session_id")
        lat_param = request.args.get("lat", type=float)
        lon_param = request.args.get("lon", type=float)
        radius_m = request.args.get("radius_meters", default=1000.0, type=float)

        pts_param = request.args.get("points")
        parsed_route_points = []
        if pts_param:
            try:
                raw_pts = json.loads(pts_param)
                if isinstance(raw_pts, list):
                    for p in raw_pts:
                        if isinstance(p, (list, tuple)) and len(p) >= 2:
                            parsed_route_points.append((float(p[0]), float(p[1])))
                        elif isinstance(p, dict) and "lat" in p and "lon" in p:
                            parsed_route_points.append((float(p["lat"]), float(p["lon"])))
            except Exception:
                pass

        with sqlite3.connect(FEEDBACK_DB_PATH) as conn:
            conn.row_factory = sqlite3.Row
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM road_reports ORDER BY id DESC")
            raw_reports = [dict(row) for row in cursor.fetchall()]

            # Fetch user verifications if session_id provided
            user_votes = {}
            if session_id:
                cursor.execute(
                    "SELECT report_id, action FROM hazard_verifications WHERE user_session_id = ?",
                    (session_id,)
                )
                user_votes = dict(cursor.fetchall())

        enriched_reports = []
        for rep in raw_reports:
            # Check expiry & status dynamically
            current_status, needs_reconf = compute_hazard_status_and_expiry(rep)
            rep["status"] = current_status
            rep["needs_reconfirmation"] = needs_reconf
            conf_score, conf_level = calculate_hazard_confidence(rep)
            rep["confidence_score"] = conf_score
            rep["confidence_level"] = conf_level

            # Double-counting check
            is_near_b, b_id = check_hazard_near_blackspot(rep.get("latitude"), rep.get("longitude"))
            rep["is_near_blackspot"] = is_near_b
            rep["matched_blackspot_id"] = b_id

            if session_id:
                rep["my_verification"] = user_votes.get(rep["id"])
                rep["is_my_report"] = (rep.get("user_session_id") == session_id)

            # Apply filters
            if active_only and rep["status"] in ["Resolved", "Expired"]:
                continue
            if filter_status and rep["status"].lower() != filter_status.lower():
                continue
            if filter_cat:
                norm = normalize_hazard_category(filter_cat)
                if norm and rep.get("category") != norm:
                    continue

            # Point distance filter
            r_lat = rep.get("latitude")
            r_lon = rep.get("longitude")
            if lat_param is not None and lon_param is not None:
                if r_lat is None or r_lon is None:
                    continue
                d = haversine_distance(lat_param, lon_param, r_lat, r_lon)
                if d > radius_m:
                    continue
                rep["distance_meters"] = round(d, 1)

            # Route distance filter
            if parsed_route_points:
                if r_lat is None or r_lon is None:
                    continue
                min_route_dist = min(
                    haversine_distance(p_lat, p_lon, r_lat, r_lon)
                    for p_lat, p_lon in parsed_route_points
                )
                if min_route_dist > radius_m:
                    continue
                rep["distance_from_route_meters"] = round(min_route_dist, 1)

            enriched_reports.append(rep)

        return jsonify({
            "success": True,
            "count": len(enriched_reports),
            "reports": enriched_reports,
        })
    except Exception as exc:
        return jsonify({"success": False, "error": str(exc)}), 500


@app.route("/road-reports/my-reports", methods=["GET"])
def get_my_road_reports():
    session_id = request.args.get("session_id", "").strip()
    if not session_id:
        return jsonify({"success": False, "error": "session_id is required"}), 400

    try:
        init_feedback_db()
        with sqlite3.connect(FEEDBACK_DB_PATH) as conn:
            conn.row_factory = sqlite3.Row
            cursor = conn.cursor()
            cursor.execute(
                "SELECT * FROM road_reports WHERE user_session_id = ? ORDER BY id DESC",
                (session_id,)
            )
            raw_reports = [dict(row) for row in cursor.fetchall()]

            cursor.execute(
                "SELECT report_id, action FROM hazard_verifications WHERE user_session_id = ?",
                (session_id,)
            )
            user_votes = dict(cursor.fetchall())

        for rep in raw_reports:
            current_status, needs_reconf = compute_hazard_status_and_expiry(rep)
            rep["status"] = current_status
            rep["needs_reconfirmation"] = needs_reconf
            conf_score, conf_level = calculate_hazard_confidence(rep)
            rep["confidence_score"] = conf_score
            rep["confidence_level"] = conf_level
            rep["my_verification"] = user_votes.get(rep["id"])
            rep["is_my_report"] = True

        return jsonify({
            "success": True,
            "count": len(raw_reports),
            "reports": raw_reports,
        })
    except Exception as exc:
        return jsonify({"success": False, "error": str(exc)}), 500


@app.route("/route-hazard-reroute-check", methods=["POST"])
def check_route_hazard_reroute():
    try:
        data = request.get_json(silent=True) or {}
        curr_pts = data.get("current_route_points") or []
        alt_pts = data.get("alternative_route_points") or []
        curr_dist = float(data.get("current_distance_km") or 0.0)
        curr_dur = float(data.get("current_duration_minutes") or 0.0)
        alt_dist = float(data.get("alternative_distance_km") or 0.0)
        alt_dur = float(data.get("alternative_duration_minutes") or 0.0)

        def _parse_pts(pts):
            res = []
            for p in pts:
                if isinstance(p, (list, tuple)) and len(p) >= 2:
                    try:
                        res.append((float(p[0]), float(p[1])))
                    except (ValueError, TypeError):
                        pass
                elif isinstance(p, dict) and "lat" in p and "lon" in p:
                    try:
                        res.append((float(p["lat"]), float(p["lon"])))
                    except (ValueError, TypeError):
                        pass
            return res

        curr_parsed = _parse_pts(curr_pts)
        alt_parsed = _parse_pts(alt_pts)

        if not curr_parsed:
            return jsonify({
                "success": False,
                "error": "current_route_points is required and must not be empty",
            }), 400

        init_feedback_db()
        with sqlite3.connect(FEEDBACK_DB_PATH) as conn:
            conn.row_factory = sqlite3.Row
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM road_reports ORDER BY id DESC")
            raw_reports = [dict(row) for row in cursor.fetchall()]

        curr_confirmed_hazards = []
        alt_confirmed_hazards = []
        pending_hazards = []
        disputed_hazards = []

        for rep in raw_reports:
            status, needs_reconf = compute_hazard_status_and_expiry(rep)
            rep["status"] = status
            rep["needs_reconfirmation"] = needs_reconf
            conf_score, conf_level = calculate_hazard_confidence(rep)
            rep["confidence_score"] = conf_score
            rep["confidence_level"] = conf_level

            is_near_b, b_id = check_hazard_near_blackspot(rep.get("latitude"), rep.get("longitude"))
            rep["is_near_blackspot"] = is_near_b
            rep["matched_blackspot_id"] = b_id

            if status in ["Resolved", "Expired"]:
                continue

            r_lat = rep.get("latitude")
            r_lon = rep.get("longitude")
            if r_lat is None or r_lon is None:
                continue

            d_curr = min(haversine_distance(p[0], p[1], r_lat, r_lon) for p in curr_parsed)
            rep["distance_to_current_route_meters"] = round(d_curr, 1)

            d_alt = None
            if alt_parsed:
                d_alt = min(haversine_distance(p[0], p[1], r_lat, r_lon) for p in alt_parsed)
                rep["distance_to_alternative_route_meters"] = round(d_alt, 1)

            if d_curr <= 800.0:
                if status == "Confirmed":
                    curr_confirmed_hazards.append(rep)
                elif status == "Pending":
                    pending_hazards.append(rep)
                elif status == "Disputed":
                    disputed_hazards.append(rep)

            if d_alt is not None and d_alt <= 800.0 and status == "Confirmed":
                alt_confirmed_hazards.append(rep)

        can_reroute = False
        reason = ""
        avoided_count = 0

        if not curr_confirmed_hazards:
            can_reroute = False
            reason = "No confirmed hazards detected along current route."
        elif not alt_parsed:
            can_reroute = False
            reason = "Single route corridor. No alternative route is available to bypass hazard."
        else:
            avoided = []
            for h in curr_confirmed_hazards:
                d_to_alt = h.get("distance_to_alternative_route_meters") or 0.0
                if d_to_alt > 1500.0:
                    avoided.append(h)

            avoided_count = len(avoided)
            if avoided_count > 0 and len(alt_confirmed_hazards) < len(curr_confirmed_hazards):
                can_reroute = True
                dist_diff = round(alt_dist - curr_dist, 2) if (alt_dist > 0 and curr_dist > 0) else 0.0
                dur_diff = round(alt_dur - curr_dur, 1) if (alt_dur > 0 and curr_dur > 0) else 0.0
                sign_dist = f"+{dist_diff}" if dist_diff >= 0 else f"{dist_diff}"
                sign_dur = f"+{dur_diff}" if dur_diff >= 0 else f"{dur_diff}"
                reason = f"Alternative route bypasses {avoided_count} confirmed hazard(s) ({sign_dist} km, {sign_dur} mins)."
            else:
                can_reroute = False
                reason = "Alternative route does not avoid the hazard corridor or has equal/higher hazard exposure."

        return jsonify({
            "success": True,
            "can_reroute": can_reroute,
            "reason": reason,
            "avoided_hazard_count": avoided_count,
            "current_confirmed_hazards": curr_confirmed_hazards,
            "alternative_confirmed_hazards": alt_confirmed_hazards,
            "pending_hazards": pending_hazards,
            "disputed_hazards": disputed_hazards,
            "distance_diff_km": round(alt_dist - curr_dist, 2) if (alt_dist > 0 and curr_dist > 0) else None,
            "duration_diff_minutes": round(alt_dur - curr_dur, 1) if (alt_dur > 0 and curr_dur > 0) else None,
        })
    except Exception as exc:
        return jsonify({"success": False, "error": str(exc)}), 500




# ==============================================================================
# WEATHER & WATERLOGGING-AWARE SMART ROUTING SYSTEM
# ==============================================================================

WMO_WEATHER_CODES = {
    0: "Clear sky",
    1: "Mainly clear",
    2: "Partly cloudy",
    3: "Overcast",
    45: "Fog",
    48: "Depositing rime fog",
    51: "Light drizzle",
    53: "Moderate drizzle",
    55: "Dense drizzle",
    56: "Light freezing drizzle",
    57: "Dense freezing drizzle",
    61: "Slight rain",
    63: "Moderate rain",
    65: "Heavy rain",
    66: "Light freezing rain",
    67: "Heavy freezing rain",
    71: "Slight snow fall",
    73: "Moderate snow fall",
    75: "Heavy snow fall",
    77: "Snow grains",
    80: "Slight rain showers",
    81: "Moderate rain showers",
    82: "Violent rain showers",
    85: "Slight snow showers",
    86: "Heavy snow showers",
    95: "Thunderstorm",
    96: "Thunderstorm with slight hail",
    99: "Thunderstorm with heavy hail",
}

WEATHER_CACHE = {}
WEATHER_CACHE_TTL_SECONDS = 900  # 15 minutes


def fetch_open_meteo_weather(lat, lon, timeout_sec=5.0):
    cache_key = (round(float(lat), 2), round(float(lon), 2))
    now = time.time()
    if cache_key in WEATHER_CACHE:
        cached_entry, timestamp = WEATHER_CACHE[cache_key]
        if now - timestamp < WEATHER_CACHE_TTL_SECONDS:
            return cached_entry

    url = (
        f"https://api.open-meteo.com/v1/forecast?latitude={lat:.4f}&longitude={lon:.4f}"
        "&current=temperature_2m,relative_humidity_2m,precipitation,rain,weather_code,wind_speed_10m,visibility"
        "&hourly=temperature_2m,precipitation_probability,precipitation,weather_code,visibility"
        "&forecast_days=1&timezone=auto"
    )

    req = urllib.request.Request(url, headers={"User-Agent": "SafeRouteTN-Weather/2.0"})
    try:
        with urllib.request.urlopen(req, timeout=timeout_sec) as resp:
            raw = json.loads(resp.read().decode("utf-8"))
            current = raw.get("current") or {}
            hourly = raw.get("hourly") or {}

            code = int(current.get("weather_code") or 0)
            desc = WMO_WEATHER_CODES.get(code, "Unknown")
            obs_time = current.get("time") or datetime.now(timezone.utc).isoformat()

            # Age calculation
            age_min = 0.0
            is_fresh = True
            try:
                dt_obs = datetime.fromisoformat(obs_time)
                # If naive, assume local or UTC
                if dt_obs.tzinfo is None:
                    dt_obs = dt_obs.replace(tzinfo=timezone.utc)
                age_min = max(0.0, (datetime.now(timezone.utc) - dt_obs).total_seconds() / 60.0)
                if age_min > 120.0:  # Older than 2 hours
                    is_fresh = False
            except Exception:
                pass

            # Hourly forecast (next 3 hours)
            h_times = hourly.get("time") or []
            h_temps = hourly.get("temperature_2m") or []
            h_probs = hourly.get("precipitation_probability") or []
            h_precips = hourly.get("precipitation") or []
            h_codes = hourly.get("weather_code") or []
            h_vis = hourly.get("visibility") or []

            forecast_entries = []
            now_str = datetime.now().strftime("%Y-%m-%dT%H:00")
            start_idx = 0
            for idx, t in enumerate(h_times):
                if t >= now_str:
                    start_idx = idx
                    break

            for i in range(start_idx, min(start_idx + 3, len(h_times))):
                f_code = int(h_codes[i]) if i < len(h_codes) and h_codes[i] is not None else 0
                forecast_entries.append({
                    "time": h_times[i] if i < len(h_times) else "",
                    "temperature_c": float(h_temps[i]) if i < len(h_temps) and h_temps[i] is not None else 0.0,
                    "precipitation_probability_pct": int(h_probs[i]) if i < len(h_probs) and h_probs[i] is not None else 0,
                    "precipitation_mm": float(h_precips[i]) if i < len(h_precips) and h_precips[i] is not None else 0.0,
                    "weather_code": f_code,
                    "weather_description": WMO_WEATHER_CODES.get(f_code, "Clear sky"),
                    "visibility_m": float(h_vis[i]) if i < len(h_vis) and h_vis[i] is not None else None,
                })

            parsed = {
                "available": True,
                "provider": "Open-Meteo Weather API",
                "latitude": round(lat, 4),
                "longitude": round(lon, 4),
                "temperature_c": float(current.get("temperature_2m") or 0.0),
                "relative_humidity_pct": float(current.get("relative_humidity_2m") or 0.0),
                "precipitation_mm": float(current.get("precipitation") or 0.0),
                "rain_mm": float(current.get("rain") or 0.0),
                "weather_code": code,
                "weather_description": desc,
                "wind_speed_kmh": float(current.get("wind_speed_10m") or 0.0),
                "visibility_m": float(current["visibility"]) if "visibility" in current and current["visibility"] is not None else None,
                "observation_time": obs_time,
                "is_fresh": is_fresh,
                "data_age_minutes": round(age_min, 1),
                "hourly_forecast": forecast_entries,
            }
            WEATHER_CACHE[cache_key] = (parsed, now)
            return parsed
    except Exception as exc:
        return {
            "available": False,
            "provider": "Open-Meteo Weather API",
            "latitude": round(lat, 4),
            "longitude": round(lon, 4),
            "error": str(exc),
            "is_fresh": False,
            "hourly_forecast": [],
        }


def sample_route_waypoints(route_points, max_samples=4):
    if not route_points or len(route_points) < 2:
        return []

    # Calculate cumulative distance
    total_dist = 0.0
    for i in range(len(route_points) - 1):
        p1 = route_points[i]
        p2 = route_points[i + 1]
        total_dist += haversine_distance(p1[0], p1[1], p2[0], p2[1])

    total_km = total_dist / 1000.0

    if total_km <= 30.0 or len(route_points) <= 4:
        indices = [0, len(route_points) - 1]
        labels = ["Start", "Destination"]
    elif total_km <= 150.0:
        indices = [0, len(route_points) // 2, len(route_points) - 1]
        labels = ["Start", "Midpoint", "Destination"]
    else:
        n = len(route_points)
        indices = [0, n // 3, (2 * n) // 3, n - 1]
        labels = ["Start", "Midpoint 1", "Midpoint 2", "Destination"]

    waypoints = []
    for idx, label in zip(indices, labels):
        pt = route_points[idx]
        waypoints.append({
            "label": label,
            "latitude": pt[0],
            "longitude": pt[1],
            "route_point_index": idx,
        })
    return waypoints


@app.route("/route-weather", methods=["POST", "OPTIONS"])
def route_weather():
    if request.method == "OPTIONS":
        return jsonify({"status": "ok"})

    try:
        data = request.get_json(silent=True) or {}
        raw_pts = (
            data.get("route_points")
            or data.get("coordinates")
            or data.get("points")
        )

        def _parse_pts(pts):
            res = []
            if not isinstance(pts, list):
                return res
            for p in pts:
                if isinstance(p, (list, tuple)) and len(p) >= 2:
                    try:
                        res.append((float(p[0]), float(p[1])))
                    except (ValueError, TypeError):
                        pass
                elif isinstance(p, dict) and "lat" in p and "lon" in p:
                    try:
                        res.append((float(p["lat"]), float(p["lon"])))
                    except (ValueError, TypeError):
                        pass
            return res

        route_points = _parse_pts(raw_pts)
        if not route_points or len(route_points) < 2:
            return jsonify({
                "success": False,
                "error": "route_points is required and must contain at least 2 coordinate pairs",
            }), 400

        # Sample waypoints
        sampled = sample_route_waypoints(route_points)

        # Query weather for waypoints
        waypoint_weathers = []
        any_success = False
        max_rain = 0.0
        min_vis = None
        max_wind = 0.0
        primary_condition = "Clear sky"

        for wp in sampled:
            w = fetch_open_meteo_weather(wp["latitude"], wp["longitude"])
            combined = dict(wp)
            combined.update(w)
            waypoint_weathers.append(combined)
            if w.get("available"):
                any_success = True
                rain = float(w.get("precipitation_mm") or 0.0)
                if rain > max_rain:
                    max_rain = rain
                vis = w.get("visibility_m")
                if vis is not None:
                    if min_vis is None or vis < min_vis:
                        min_vis = vis
                wind = float(w.get("wind_speed_kmh") or 0.0)
                if wind > max_wind:
                    max_wind = wind
                if w.get("weather_description") and w.get("weather_description") != "Clear sky":
                    primary_condition = w["weather_description"]

        # Cross-reference community waterlogging/flood reports along the corridor
        init_feedback_db()
        with sqlite3.connect(FEEDBACK_DB_PATH) as conn:
            conn.row_factory = sqlite3.Row
            cursor = conn.cursor()
            cursor.execute(
                """
                SELECT * FROM road_reports
                WHERE category IN ('flooding_waterlogging', 'waterlogging_flooding')
                ORDER BY id DESC
                """
            )
            raw_reports = [dict(row) for row in cursor.fetchall()]

        confirmed_floods = []
        pending_floods = []
        disputed_floods = []

        for rep in raw_reports:
            status, needs_reconf = compute_hazard_status_and_expiry(rep)
            rep["status"] = status
            rep["needs_reconfirmation"] = needs_reconf
            conf_score, conf_level = calculate_hazard_confidence(rep)
            rep["confidence_score"] = conf_score
            rep["confidence_level"] = conf_level

            is_near_b, b_id = check_hazard_near_blackspot(rep.get("latitude"), rep.get("longitude"))
            rep["is_near_blackspot"] = is_near_b
            rep["matched_blackspot_id"] = b_id

            if status in ["Resolved", "Expired"]:
                continue

            r_lat = rep.get("latitude")
            r_lon = rep.get("longitude")
            if r_lat is None or r_lon is None:
                continue

            d_route = min(haversine_distance(p[0], p[1], r_lat, r_lon) for p in route_points)
            rep["distance_to_route_meters"] = round(d_route, 1)

            if d_route <= 800.0:
                if status == "Confirmed":
                    confirmed_floods.append(rep)
                elif status == "Pending":
                    pending_floods.append(rep)
                elif status == "Disputed":
                    disputed_floods.append(rep)

        # Formulate data-honest warnings
        warnings = []
        flood_status = "none"

        # 1. Weather condition alerts
        if max_rain >= 15.0:
            warnings.append(
                f"Heavy Rainfall Warning: Heavy rain (up to {max_rain:.1f} mm/h) along route. "
                "Roadways will be slick with high risk of surface ponding. Reduce speed."
            )
        elif max_rain >= 5.0:
            warnings.append(
                f"Moderate Rainfall Alert: Steady rain (up to {max_rain:.1f} mm/h) along corridor. "
                "Drive with headlights and maintain safe braking distance."
            )

        if min_vis is not None and min_vis < 1000.0:
            warnings.append(
                f"Low Visibility Advisory: Visibility drops to {int(min_vis)}m in misty/rainy stretches. "
                "Use fog lamps and maintain increased headway."
            )

        if max_wind >= 45.0:
            warnings.append(
                f"High Wind Advisory: Gusts up to {max_wind:.0f} km/h along open highway stretches."
            )

        # 2. Waterlogging distinction (Never equate rain forecast with road flooding!)
        if len(confirmed_floods) > 0:
            flood_status = "verified_flooding"
            landmarks = [f.get("location_landmark") or f"km {round(f.get('distance_to_route_meters', 0))}" for f in confirmed_floods[:2]]
            landmark_str = ", ".join(landmarks)
            warnings.append(
                f"Verified Road Flooding: {len(confirmed_floods)} confirmed waterlogging hazard(s) along route near {landmark_str}. "
                "Consider the verified smart alternative route."
            )
        elif len(pending_floods) > 0:
            flood_status = "pending_flooding"
            warnings.append(
                f"Community Notice: {len(pending_floods)} unverified waterlogging report(s) along route under review. "
                "Authoritative safety score is preserved."
            )
        elif max_rain >= 10.0:
            flood_status = "rain_ponding_risk"
            warnings.append(
                "Surface Water Notice: Sustained rainfall may cause localized water accumulation. "
                "No verified road flooding reported on this corridor."
            )

        return jsonify({
            "success": True,
            "available": any_success,
            "provider": "Open-Meteo Weather API",
            "fetched_at": datetime.now(timezone.utc).isoformat(),
            "waypoints": waypoint_weathers,
            "max_rainfall_mm": round(max_rain, 1),
            "min_visibility_meters": round(min_vis, 0) if min_vis is not None else None,
            "highest_wind_kmh": round(max_wind, 1),
            "overall_condition": primary_condition,
            "warnings": warnings,
            "flood_status": flood_status,
            "verified_waterlogging_hazards": confirmed_floods,
            "pending_waterlogging_hazards": pending_floods,
            "disputed_waterlogging_hazards": disputed_floods,
        })
    except Exception as exc:
        return jsonify({
            "success": False,
            "error": str(exc),
            "available": False,
        }), 500



# ==============================================================================
# SHARED LOCATION NAVIGATION: PARSING, SSRF-SAFE RESOLUTION & REVERSE GEOCODING
# ==============================================================================

ALLOWED_MAPS_HOSTS = {
    "maps.app.goo.gl",
    "goo.gl",
    "maps.google.com",
    "www.google.com",
    "google.com",
    "maps.google.co.in",
    "www.google.co.in",
}


def extract_coordinates_from_text(text):
    if not text or not isinstance(text, str):
        return None, None, None

    text = text.strip()

    # 1. @lat,lon (e.g. https://www.google.com/maps/@11.3410364,77.7171642,15z)
    m = re.search(r'@(-?\d{1,2}(?:\.\d+)?),(-?\d{1,3}(?:\.\d+)?)', text)
    if m:
        try:
            return float(m.group(1)), float(m.group(2)), "google_maps_at_coord"
        except (ValueError, TypeError):
            pass

    # 2. !3dlat!4dlon (Google Maps embed / place links)
    m = re.search(r'!3d(-?\d{1,2}(?:\.\d+)?)[^!]*!4d(-?\d{1,3}(?:\.\d+)?)', text)
    if m:
        try:
            return float(m.group(1)), float(m.group(2)), "google_maps_3d_4d"
        except (ValueError, TypeError):
            pass

    # 3. q=lat,lon or query=lat,lon or ll=lat,lon
    m = re.search(r'[?&](?:q|query|ll)=(-?\d{1,2}(?:\.\d+)?),(-?\d{1,3}(?:\.\d+)?)', text)
    if m:
        try:
            return float(m.group(1)), float(m.group(2)), "google_maps_query_param"
        except (ValueError, TypeError):
            pass

    # 4. Direct plain coordinates: e.g. 11.3410, 77.7171 or Lat: 11.34, Lon: 77.71
    m = re.search(
        r'(?:^|[^\d.-])(?:lat(?:itude)?\s*[:=]?\s*)?(-?\d{1,2}(?:\.\d+)?)[,\s]+(?:lon(?:gitude)?\s*[:=]?\s*)?(-?\d{1,3}(?:\.\d+)?)(?:[^\d.-]|$)',
        text,
        re.IGNORECASE,
    )
    if m:
        try:
            return float(m.group(1)), float(m.group(2)), "direct_coordinates"
        except (ValueError, TypeError):
            pass

    return None, None, None


def is_safe_google_maps_url(url_str):
    try:
        parsed = urllib.parse.urlparse(url_str.strip())
        if parsed.scheme not in ("http", "https"):
            return False
        host = parsed.netloc.lower().split(":")[0]
        # Prevent SSRF: only allow verified Google Maps domains
        return host in ALLOWED_MAPS_HOSTS
    except Exception:
        return False


def reverse_geocode_nominatim(lat, lon, timeout_sec=3.0):
    try:
        url = f"https://nominatim.openstreetmap.org/reverse?lat={lat:.6f}&lon={lon:.6f}&format=json"
        req = urllib.request.Request(url, headers={"User-Agent": "SafeRouteTN-Reverse/2.0"})
        with urllib.request.urlopen(req, timeout=timeout_sec) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            addr = data.get("address") or {}
            road = addr.get("road") or addr.get("suburb") or addr.get("neighbourhood")
            city = (
                addr.get("city")
                or addr.get("town")
                or addr.get("village")
                or addr.get("county")
                or addr.get("state_district")
            )
            parts = [p for p in [road, city] if p]
            if parts:
                return ", ".join(parts)
            return data.get("name") or data.get("display_name", "")[:50]
    except Exception:
        return None


def resolve_short_maps_link(short_url, timeout_sec=5.0):
    if not is_safe_google_maps_url(short_url):
        return None, "URL is not a permitted Google Maps domain"

    class SafeRedirectHandler(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, headers, newurl):
            if not is_safe_google_maps_url(newurl):
                return None
            return super().redirect_request(req, fp, code, msg, headers, newurl)

    opener = urllib.request.build_opener(SafeRedirectHandler)
    req = urllib.request.Request(short_url, headers={"User-Agent": "SafeRouteTN/2.0"})
    try:
        with opener.open(req, timeout=timeout_sec) as resp:
            final_url = resp.geturl()
            lat, lon, fmt = extract_coordinates_from_text(final_url)
            if lat is not None and lon is not None:
                return (lat, lon, final_url), None

            content = resp.read().decode("utf-8", errors="ignore")
            lat, lon, fmt = extract_coordinates_from_text(content)
            if lat is not None and lon is not None:
                return (lat, lon, final_url), None

            return None, "Could not extract coordinates from resolved Google Maps URL"
    except Exception as exc:
        return None, f"Failed to resolve short link: {str(exc)}"


@app.route("/resolve-shared-location", methods=["POST", "OPTIONS"])
def resolve_shared_location():
    if request.method == "OPTIONS":
        return jsonify({"status": "ok"})

    try:
        data = request.get_json(silent=True) or {}
        shared_text = data.get("shared_text") or data.get("input") or data.get("text") or data.get("url")
        if not shared_text or not isinstance(shared_text, str):
            return jsonify({
                "success": False,
                "error": "shared_text is required and must be a non-empty string",
            }), 400

        text = shared_text.strip()

        # Security check: If text contains URLs, reject disallowed/untrusted hosts
        found_urls = re.findall(r'https?://[^\s<>"]+', text)
        for u in found_urls:
            clean_u = re.sub(r'[\.,;:\)\]]+$', '', u)
            if not is_safe_google_maps_url(clean_u):
                return jsonify({
                    "success": False,
                    "error": "Disallowed or untrusted URL. Only official Google Maps links are supported."
                }), 400

        # Step 1: Direct extraction from text/URL
        lat, lon, fmt = extract_coordinates_from_text(text)
        resolved_url = None

        # Step 2: Check for Google Maps short links (e.g. maps.app.goo.gl or goo.gl/maps)
        if lat is None or lon is None:
            short_match = re.search(r'https?://(?:maps\.app\.goo\.gl|goo\.gl/maps)/[a-zA-Z0-9_-]+', text)
            if short_match:
                short_url = short_match.group(0)
                res, err = resolve_short_maps_link(short_url)
                if res:
                    lat, lon, resolved_url = res
                    fmt = "google_maps_short_link"
                else:
                    return jsonify({
                        "success": False,
                        "error": err or "Failed to resolve Google Maps short link",
                    }), 400

        if lat is None or lon is None:
            return jsonify({
                "success": False,
                "error": "Could not identify valid geographic coordinates in the shared link or text. Supported formats include Google Maps links, short links, or latitude/longitude coordinates.",
            }), 400

        # Step 3: Range validation
        if not (-90.0 <= lat <= 90.0) or not (-180.0 <= lon <= 180.0):
            return jsonify({
                "success": False,
                "error": f"Coordinates out of valid range: latitude must be between -90 and 90, longitude between -180 and 180 (got {lat}, {lon})",
            }), 400

        # Step 4: Reverse geocoding for friendly destination name
        friendly_name = reverse_geocode_nominatim(lat, lon)
        if not friendly_name:
            friendly_name = f"Shared Location ({lat:.4f}, {lon:.4f})"

        return jsonify({
            "success": True,
            "latitude": round(lat, 6),
            "longitude": round(lon, 6),
            "name": friendly_name,
            "display_name": friendly_name,
            "source_format": fmt,
            "resolved_url": resolved_url,
        })
    except Exception as exc:
        return jsonify({
            "success": False,
            "error": str(exc),
        }), 500

# ============================================================================
# LIVE TRIP SHARING & SAFE ARRIVAL ENDPOINTS
# ============================================================================

@app.route("/api/trip/create_share", methods=["POST", "OPTIONS"])
def create_trip_share():
    if request.method == "OPTIONS":
        return jsonify({"status": "ok"})
    try:
        data = request.get_json(silent=True) or {}
        destination = data.get("destination")
        if not destination or not isinstance(destination, str) or not destination.strip():
            return jsonify({"success": False, "error": "destination is required and must be a non-empty string"}), 400

        destination = destination.strip()
        origin = data.get("origin")
        if isinstance(origin, str):
            origin = origin.strip()
        else:
            origin = None

        vehicle = data.get("vehicle", "Car")
        if not isinstance(vehicle, str):
            vehicle = "Car"

        eta_minutes = data.get("eta_minutes")
        if eta_minutes is not None:
            try:
                eta_minutes = int(eta_minutes)
            except (ValueError, TypeError):
                eta_minutes = None

        lat = data.get("latitude")
        lon = data.get("longitude")
        if lat is not None and lon is not None:
            try:
                lat = float(lat)
                lon = float(lon)
                if not (-90.0 <= lat <= 90.0) or not (-180.0 <= lon <= 180.0):
                    return jsonify({"success": False, "error": "Coordinates out of valid range"}), 400
            except (ValueError, TypeError):
                return jsonify({"success": False, "error": "Coordinates must be numbers"}), 400
        else:
            lat = None
            lon = None

        heading = data.get("heading")
        if heading is not None:
            try:
                heading = float(heading)
            except (ValueError, TypeError):
                heading = None

        speed = data.get("speed")
        if speed is not None:
            try:
                speed = float(speed)
            except (ValueError, TypeError):
                speed = None

        accuracy = data.get("accuracy")
        if accuracy is not None:
            try:
                accuracy = float(accuracy)
            except (ValueError, TypeError):
                accuracy = None

        share_token = secrets.token_urlsafe(16)
        update_token = secrets.token_urlsafe(24)
        now_dt = datetime.now(timezone.utc)
        created_at = now_dt.isoformat()
        expires_at = (now_dt + timedelta(hours=12)).isoformat()

        init_feedback_db()
        with sqlite3.connect(FEEDBACK_DB_PATH) as conn:
            cursor = conn.cursor()
            cursor.execute(
                """
                INSERT INTO live_shared_trips (
                    share_token, update_token, origin, destination, vehicle, eta_minutes,
                    status, latitude, longitude, heading, speed, accuracy,
                    created_at, updated_at, expires_at
                ) VALUES (?, ?, ?, ?, ?, ?, 'active', ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    share_token, update_token, origin, destination, vehicle, eta_minutes,
                    lat, lon, heading, speed, accuracy,
                    created_at, created_at, expires_at
                )
            )
            conn.commit()

        return jsonify({
            "success": True,
            "share_token": share_token,
            "update_token": update_token,
            "status": "active",
            "destination": destination,
            "origin": origin,
            "vehicle": vehicle,
            "eta_minutes": eta_minutes,
            "expires_at": expires_at,
            "created_at": created_at,
        })
    except Exception as exc:
        return jsonify({"success": False, "error": str(exc)}), 500


@app.route("/api/trip/update_location", methods=["POST", "OPTIONS"])
def update_trip_location():
    if request.method == "OPTIONS":
        return jsonify({"status": "ok"})
    try:
        data = request.get_json(silent=True) or {}
        update_token = data.get("update_token")
        if not update_token or not isinstance(update_token, str):
            return jsonify({"success": False, "error": "update_token is required"}), 401

        lat = data.get("latitude")
        lon = data.get("longitude")
        if lat is None or lon is None:
            return jsonify({"success": False, "error": "latitude and longitude are required"}), 400
        try:
            lat = float(lat)
            lon = float(lon)
            if not (-90.0 <= lat <= 90.0) or not (-180.0 <= lon <= 180.0):
                return jsonify({"success": False, "error": "Coordinates out of valid range"}), 400
        except (ValueError, TypeError):
            return jsonify({"success": False, "error": "Coordinates must be numbers"}), 400

        heading = data.get("heading")
        if heading is not None:
            try:
                heading = float(heading)
            except (ValueError, TypeError):
                heading = None

        speed = data.get("speed")
        if speed is not None:
            try:
                speed = float(speed)
            except (ValueError, TypeError):
                speed = None

        accuracy = data.get("accuracy")
        if accuracy is not None:
            try:
                accuracy = float(accuracy)
            except (ValueError, TypeError):
                accuracy = None

        eta_minutes = data.get("eta_minutes")
        if eta_minutes is not None:
            try:
                eta_minutes = int(eta_minutes)
            except (ValueError, TypeError):
                eta_minutes = None

        req_status = data.get("status")
        now_dt = datetime.now(timezone.utc)
        now_iso = now_dt.isoformat()

        init_feedback_db()
        with sqlite3.connect(FEEDBACK_DB_PATH) as conn:
            conn.row_factory = sqlite3.Row
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM live_shared_trips WHERE update_token = ?", (update_token,))
            row = cursor.fetchone()
            if not row:
                return jsonify({"success": False, "error": "Invalid update token or session not found"}), 404

            # Expiration check
            expires_at = datetime.fromisoformat(row["expires_at"])
            if now_dt > expires_at:
                return jsonify({"success": False, "error": "Trip sharing session has expired", "status": "expired"}), 410

            current_status = row["status"]
            if current_status in ("stopped", "completed"):
                return jsonify({"success": False, "error": f"Cannot update location for {current_status} trip", "status": current_status}), 400

            new_status = current_status
            if req_status in ("active", "paused"):
                new_status = req_status

            cursor.execute(
                """
                UPDATE live_shared_trips
                SET latitude = ?, longitude = ?, heading = ?, speed = ?, accuracy = ?,
                    eta_minutes = COALESCE(?, eta_minutes), status = ?, updated_at = ?
                WHERE id = ?
                """,
                (lat, lon, heading, speed, accuracy, eta_minutes, new_status, now_iso, row["id"])
            )
            conn.commit()

        return jsonify({
            "success": True,
            "status": new_status,
            "updated_at": now_iso
        })
    except Exception as exc:
        return jsonify({"success": False, "error": str(exc)}), 500


@app.route("/api/trip/status/<share_token>", methods=["GET"])
def get_trip_status(share_token):
    try:
        if not share_token or not isinstance(share_token, str):
            return jsonify({"success": False, "error": "Invalid share token"}), 400

        now_dt = datetime.now(timezone.utc)
        init_feedback_db()
        with sqlite3.connect(FEEDBACK_DB_PATH) as conn:
            conn.row_factory = sqlite3.Row
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM live_shared_trips WHERE share_token = ?", (share_token.strip(),))
            row = cursor.fetchone()
            if not row:
                return jsonify({"success": False, "error": "Shared trip not found"}), 404

            expires_at = datetime.fromisoformat(row["expires_at"])
            if now_dt > expires_at:
                return jsonify({
                    "success": True,
                    "status": "expired",
                    "destination": row["destination"],
                    "message": "This trip sharing session has expired."
                })

            status = row["status"]
            if status == "stopped":
                return jsonify({
                    "success": True,
                    "status": "stopped",
                    "destination": row["destination"],
                    "message": "Trip sharing was stopped by the user."
                })

            if status == "completed":
                return jsonify({
                    "success": True,
                    "status": "completed",
                    "destination": row["destination"],
                    "origin": row["origin"],
                    "vehicle": row["vehicle"],
                    "completed_at": row["updated_at"],
                    "message": f"Arrived safely at {row['destination']}."
                })

            updated_dt = datetime.fromisoformat(row["updated_at"])
            stale_seconds = max(0, int((now_dt - updated_dt).total_seconds()))
            is_stale = stale_seconds > 120

            return jsonify({
                "success": True,
                "status": status,
                "origin": row["origin"],
                "destination": row["destination"],
                "vehicle": row["vehicle"],
                "eta_minutes": row["eta_minutes"],
                "latitude": row["latitude"],
                "longitude": row["longitude"],
                "heading": row["heading"],
                "speed": row["speed"],
                "accuracy": row["accuracy"],
                "updated_at": row["updated_at"],
                "is_stale": is_stale,
                "stale_seconds": stale_seconds
            })
    except Exception as exc:
        return jsonify({"success": False, "error": str(exc)}), 500


@app.route("/api/trip/stop_sharing", methods=["POST", "OPTIONS"])
def stop_trip_sharing():
    if request.method == "OPTIONS":
        return jsonify({"status": "ok"})
    try:
        data = request.get_json(silent=True) or {}
        update_token = data.get("update_token")
        if not update_token or not isinstance(update_token, str):
            return jsonify({"success": False, "error": "update_token is required"}), 401

        now_iso = datetime.now(timezone.utc).isoformat()
        init_feedback_db()
        with sqlite3.connect(FEEDBACK_DB_PATH) as conn:
            conn.row_factory = sqlite3.Row
            cursor = conn.cursor()
            cursor.execute("SELECT id FROM live_shared_trips WHERE update_token = ?", (update_token,))
            row = cursor.fetchone()
            if not row:
                return jsonify({"success": False, "error": "Session not found"}), 404

            # Privacy: clear coordinates upon stopping
            cursor.execute(
                """
                UPDATE live_shared_trips
                SET status = 'stopped', latitude = NULL, longitude = NULL, updated_at = ?
                WHERE id = ?
                """,
                (now_iso, row["id"])
            )
            conn.commit()

        return jsonify({"success": True, "status": "stopped", "message": "Live trip sharing has stopped."})
    except Exception as exc:
        return jsonify({"success": False, "error": str(exc)}), 500


@app.route("/api/trip/complete_trip", methods=["POST", "OPTIONS"])
def complete_trip_sharing():
    if request.method == "OPTIONS":
        return jsonify({"status": "ok"})
    try:
        data = request.get_json(silent=True) or {}
        update_token = data.get("update_token")
        if not update_token or not isinstance(update_token, str):
            return jsonify({"success": False, "error": "update_token is required"}), 401

        now_iso = datetime.now(timezone.utc).isoformat()
        init_feedback_db()
        with sqlite3.connect(FEEDBACK_DB_PATH) as conn:
            conn.row_factory = sqlite3.Row
            cursor = conn.cursor()
            cursor.execute("SELECT id, destination FROM live_shared_trips WHERE update_token = ?", (update_token,))
            row = cursor.fetchone()
            if not row:
                return jsonify({"success": False, "error": "Session not found"}), 404

            cursor.execute(
                """
                UPDATE live_shared_trips
                SET status = 'completed', updated_at = ?
                WHERE id = ?
                """,
                (now_iso, row["id"])
            )
            conn.commit()

        return jsonify({
            "success": True,
            "status": "completed",
            "destination": row["destination"],
            "message": f"Trip marked as completed. Safe arrival confirmed at {row['destination']}."
        })
    except Exception as exc:
        return jsonify({"success": False, "error": str(exc)}), 500

if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=5000,
        debug=True
    )