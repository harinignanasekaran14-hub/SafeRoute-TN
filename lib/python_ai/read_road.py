import pandas as pd

data = pd.read_csv("road_data.csv")

district = input("Enter district name: ")

result = data[
    data["District"].str.lower() == district.lower()
]

if result.empty:
    print("District not found")
else:
    surfaced = result.iloc[0]["Surfaced_Roads_KM"]
    unsurfaced = result.iloc[0]["Unsurfaced_Roads_KM"]
    total = result.iloc[0]["Total_Roads_KM"]

    print("District:", district)
    print("Surfaced Roads:", surfaced, "km")
    print("Unsurfaced Roads:", unsurfaced, "km")
    print("Total Roads:", total, "km")