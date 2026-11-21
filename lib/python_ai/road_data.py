import requests
import pandas as pd
import os


def get_roads():
    query = """
[out:json][timeout:60];

way["highway"]
(11.45,77.30,11.55,77.45);

out tags center;
"""

    url = "https://overpass.kumi.systems/api/interpreter"

    response = requests.post(
        url,
        data={"data": query},
        headers={
            "User-Agent": "SafeRouteTN/1.0 (Flutter college project)",
            "Referer": "https://www.openstreetmap.org/",
        },
        timeout=90,
    )

    response.raise_for_status()

    data = response.json()

    roads = []

    for element in data["elements"]:
        tags = element.get("tags", {})
        center = element.get("center", {})

        roads.append({
            "osm_id": element.get("id"),
            "road_name": tags.get("name"),
            "highway": tags.get("highway"),
            "surface": tags.get("surface"),
            "smoothness": tags.get("smoothness"),
            "maxspeed": tags.get("maxspeed"),
            "lit": tags.get("lit"),
            "lanes": tags.get("lanes"),
            "oneway": tags.get("oneway"),
            "sidewalk": tags.get("sidewalk"),
            "access": tags.get("access"),
            "bridge": tags.get("bridge"),
            "tunnel": tags.get("tunnel"),
            "bicycle": tags.get("bicycle"),
            "foot": tags.get("foot"),
            "motor_vehicle": tags.get("motor_vehicle"),
            "width": tags.get("width"),
            "shoulder": tags.get("shoulder"),
            "latitude": center.get("lat"),
            "longitude": center.get("lon"),
        })

    df = pd.DataFrame(roads)

    output_path = os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        "road_segments.csv"
    )

    df.to_csv(output_path, index=False)

    print("Roads collected:", len(df))
    print("CSV created successfully!")
    print("Saved at:", output_path)


if __name__ == "__main__":
    get_roads()