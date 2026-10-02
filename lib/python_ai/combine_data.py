import pandas as pd

accident_data = pd.read_csv("accident_data.csv")
road_data = pd.read_csv("road_data.csv")

# Remove city, railway police and total rows
accident_data = accident_data[
    ~accident_data["City/District"].str.contains(
        "Railway Police|Total",
        case=False,
        na=False
    )
]
# Use district-level Chennai accident data
accident_data["City/District"] = accident_data["City/District"].replace(
    {
        "Chennai City": "Chennai"
    }
)
print("ACCIDENT NAMES:")
print(accident_data["City/District"].tolist())

print("ROAD NAMES:")
print(road_data["District"].tolist())
# Match district names with road data
combined = pd.merge(
    accident_data,
    road_data,
    left_on="City/District",
    right_on="District",
    how="left"
)

# Keep required columns
selected_columns = combined[
    [
        "City/District",
        "Total Number of Accidents (2018)",
        "Surfaced_Roads_KM",
        "Unsurfaced_Roads_KM",
        "Total_Roads_KM"
    ]
]

selected_columns.to_csv("combined_data.csv", index=False)

print("Combined data saved successfully!")
print("Total district records:", len(selected_columns))