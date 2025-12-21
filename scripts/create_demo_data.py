import firebase_admin
from firebase_admin import credentials, firestore
import os
import sys

current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(current_dir)
sys.path.append(parent_dir)

if not firebase_admin._apps:
    cred = credentials.Certificate(os.path.join(parent_dir, "serviceAccountKey.json"))
    firebase_admin.initialize_app(cred)

db = firestore.client()

def setup_demo_database():
    print(" Demo Veritabanı Hazırlanıyor...")
    spots = [
        {"id": "A1", "name": "A1 - Giriş",   "lat": 41.1083, "lng": 29.0260, "full": False},
        {"id": "A2", "name": "A2 - Giriş",   "lat": 41.1084, "lng": 29.0261, "full": True}, 
        {"id": "B1", "name": "B1 - Alt Kat", "lat": 41.1085, "lng": 29.0263, "full": False},
        {"id": "B2", "name": "B2 - Alt Kat", "lat": 41.1086, "lng": 29.0264, "full": False},
        {"id": "C1", "name": "C1 - Teras",   "lat": 41.1088, "lng": 29.0266, "full": False},
    ]

    print(" Park yerleri haritaya işleniyor...")
    for spot in spots:
        data = {
            "name": spot["name"],
            "location": firestore.GeoPoint(spot["lat"], spot["lng"]),
            "is_occupied": spot["full"]
        }
        db.collection("parking_spots").document(f"spot_{spot['id']}").set(data)

    print(" Sayaç ayarlanıyor...")
    db.collection("parking_lots").document("main_lot").set({
        "current_occupancy": 45,
        "total_capacity": 100,
        "name": "Merkez Otopark"
    })

if __name__ == "__main__":
    setup_demo_database()