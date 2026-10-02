import pandas as pd

data = pd.read_csv("combined_data.csv")


def calculate_safety_score(accidents, surfaced_roads, total_roads):

    # Accident safety
    accident_risk = (accidents / 7580) * 100
    accident_safety = 100 - accident_risk

    # Road condition safety
    if pd.isna(surfaced_roads) or pd.isna(total_roads):
        road_safety = None
    else:
        road_safety = (surfaced_roads / total_roads) * 100

    # Overall safety score
    if road_safety is None:
        overall_score = accident_safety
    else:
        overall_score = (
            accident_safety * 0.60
            + road_safety * 0.40
        )

    return accident_risk, accident_safety, road_safety, overall_score


district = input("Enter district name: ")

result = data[
    data["City/District"].str.lower() == district.lower()
]

if result.empty:

    print("District not found")

else:

    row = result.iloc[0]

    accidents = row["Total Number of Accidents (2018)"]
    surfaced_roads = row["Surfaced_Roads_KM"]
    total_roads = row["Total_Roads_KM"]

    accident_risk, accident_safety, road_safety, overall_score = (
        calculate_safety_score(
            accidents,
            surfaced_roads,
            total_roads
        )
    )

    print("\n--- SafeRoute TN Safety Analysis ---")
    print("District:", district)
    print("2018 Accidents:", accidents)

    print(
        "Historical Accident Risk Score:",
        round(accident_risk, 2)
    )

    print(
        "Historical Accident Safety Score:",
        round(accident_safety, 2)
    )

    if road_safety is None:

        print("Road Condition Score: Not available")

    else:

        print(
            "Road Condition Score:",
            round(road_safety, 2)
        )

    print(
        "Overall Safety Score:",
        round(overall_score, 2)
    )