import os
import math
from flask import Flask, jsonify, request
from flask_cors import CORS
import pandas as pd

app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*"}})

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
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


@app.route("/check-blackspot", methods=["GET", "POST"])
def check_blackspot():
    """Checks whether given latitude/longitude coordinates are within a reasonable

    distance of any verified blackspot (gps_verified=TRUE).
    """
    if request.method == "POST":
        json_data = request.get_json(silent=True) or {}
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
        "is_near_blackspot": len(matches) > 0,
        "matches_count": len(matches),
        "nearby_blackspots": matches,
        "nearest_blackspot": nearest,
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


if __name__ == "__main__":
    app.run(
        host="127.0.0.1",
        port=5000,
        debug=True
    )