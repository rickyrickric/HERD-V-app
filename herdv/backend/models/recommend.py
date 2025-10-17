# backend/models/recommend.py
import pandas as pd

def cluster_recommendations(means: pd.DataFrame) -> dict[int, dict]:
    herd_means = means.mean(numeric_only=True)
    herd_median = means.median(numeric_only=True)

    recs = {}
    for _, row in means.iterrows():
        c = int(row["Cluster"])
        cluster_name = []
        actions = []

        # naming heuristics
        if row.get("Milk_Yield", 0) >= herd_means.get("Milk_Yield", 0):
            cluster_name.append("High Yielders")
        if row.get("Parasite_Load_Index", 0) >= herd_median.get("Parasite_Load_Index", 0) * 1.2:
            cluster_name.append("High Parasite Load")
            actions.append("Start deworming protocol and rotate pasture; schedule fecal egg count recheck.")
        if row.get("Forage_Quality_Index", 0) < herd_median.get("Forage_Quality_Index", 0):
            actions.append("Improve forage quality; review ration with nutritionist.")
        if row.get("Ear_Temperature_C", 0) > 39.5 and row.get("Respiration_Rate_BPM", 0) > 35:
            cluster_name.append("At‑Risk (Heat/Illness)")
            actions.append("Provide shade and cool water; evaluate for fever; consult veterinarian.")
        if row.get("Fertility_Score", 0) < herd_median.get("Fertility_Score", 0):
            actions.append("Conduct reproductive assessment; check minerals and body condition.")
        if row.get("Rumination_Minutes_Per_Day", 0) < herd_median.get("Rumination_Minutes_Per_Day", 0):
            actions.append("Monitor rumination; adjust fiber length and feeding schedule.")
        if row.get("Weight_kg", 0) < herd_means.get("Weight_kg", 0) and row.get("Movement_Score", 0) > herd_means.get("Movement_Score", 0):
            actions.append("Assess energy balance; consider dietary energy increase.")

        if not cluster_name:
            cluster_name = ["Balanced"]

        recs[c] = {
            "name": ", ".join(cluster_name),
            "recommendation": " ".join(actions) if actions else "Maintain current management and routine monitoring."
        }
    return recs
