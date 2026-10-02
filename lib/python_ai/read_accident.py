import pandas as pd

data = pd.read_csv("accident_data.csv")


def calculate_safety_score(accidents):
    risk_score = (accidents / 7580) * 100
    safety_score = 100 - risk_score
    return risk_score, safety_score


district = input("Enter district name: ")

result = data[
    data["City/District"].str.lower() == district.lower()
]

if result.empty:
    print("District not found")
else:
    accidents = result.iloc[0]["Total Number of Accidents (2018)"]

    risk_score, safety_score = calculate_safety_score(accidents)

    print("District:", district)
    print("Accidents:", accidents)
    print("Historical Accident Risk Score:", round(risk_score, 2))
    print("Historical Safety Score:", round(safety_score, 2))