import firebase_admin
from firebase_admin import credentials, firestore
import os
import sys

current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(current_dir)
sys.path.append(parent_dir)

if not firebase_admin._apps:
    cred_path = os.path.join(parent_dir, "serviceAccountKey.json")
    cred = credentials.Certificate(cred_path)
    firebase_admin.initialize_app(cred)

db = firestore.client()

def init_lot():
    print(" A Parkı veritabanında oluşturuluyor...")
    
    lot_data = {
        "name": "A Parkı Merkez",
        "total_capacity": 100,
        "current_occupancy": 50, 
        "is_full": False
    }

    db.collection('parking_lots').document('main_lot').set(lot_data)
    print(f" Otopark Hazır! Kapasite: {lot_data['total_capacity']}, Mevcut: {lot_data['current_occupancy']}")

if __name__ == "__main__":
    init_lot()