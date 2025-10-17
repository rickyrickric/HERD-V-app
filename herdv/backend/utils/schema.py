# backend/utils/schema.py
REQUIRED_COLUMNS = [
    "ID",
    "Breed",
    "Age",
    "Weight_kg",
    "Milk_Yield",
    "Fertility_Score",
    "Rumination_Minutes_Per_Day",
    "Ear_Temperature_C",
    "Parasite_Load_Index",
    "Fecal_Egg_Count",
    "Respiration_Rate_BPM",
    "Forage_Quality_Index",
    "Vaccination_Up_To_Date",
    "Movement_Score",
    "Remaining_Months"
]
CATEGORICAL = ["Breed"]
BOOLEAN = ["Vaccination_Up_To_Date"]
ID_COL = "ID"
NUMERIC = [
    "Age","Weight_kg","Milk_Yield","Fertility_Score","Rumination_Minutes_Per_Day",
    "Ear_Temperature_C","Parasite_Load_Index","Fecal_Egg_Count","Respiration_Rate_BPM",
    "Forage_Quality_Index","Movement_Score","Remaining_Months"
]
