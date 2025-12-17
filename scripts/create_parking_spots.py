import firebase_admin
from firebase_admin import credentials, firestore
import os
import sys

# --- PATH AYARLARI ---
# Ana dizindeki serviceAccountKey.json dosyasını bulmak için
current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(current_dir)
sys.path.append(parent_dir)

# Firebase Başlatma
if not firebase_admin._apps:
    # JSON dosyasının tam yolunu veriyoruz
    cred_path = os.path.join(parent_dir, "serviceAccountKey.json")
    cred = credentials.Certificate(cred_path)
    firebase_admin.initialize_app(cred)

db = firestore.client()

def create_dummy_spots():
    print("🅿️ Park yerleri veritabanına yükleniyor...")

    # Örnek: İstanbul'da bir otopark simülasyonu (Yan yana park yerleri)
    # Latitude (Enlem) ve Longitude (Boylam)
    spots = [
        {"id": "A1", "name": "A-1 (Giriş Yakını)", "lat": 41.08500, "lng": 29.04500, "occupied": False},
        {"id": "A2", "name": "A-2 (Giriş Yakını)", "lat": 41.08505, "lng": 29.04505, "occupied": True}, # Dolu olsun
        {"id": "B1", "name": "B-1 (Orta Alan)",    "lat": 41.08520, "lng": 29.04520, "occupied": False},
        {"id": "B2", "name": "B-2 (Orta Alan)",    "lat": 41.08525, "lng": 29.04525, "occupied": False},
        {"id": "C1", "name": "C-1 (Çıkış Yakını)", "lat": 41.08550, "lng": 29.04550, "occupied": False},
    ]

    collection_ref = db.collection('parking_spots')

    for spot in spots:
        # Firestore GeoPoint oluşturuyoruz
        geo_point = firestore.GeoPoint(spot["lat"], spot["lng"])
        
        data = {
            "id": spot["id"],
            "name": spot["name"],
            "location": geo_point, # Swift bunu haritada pin olarak kullanacak
            "is_occupied": spot["occupied"],
            "last_updated": firestore.SERVER_TIMESTAMP
        }

        # ID'yi döküman adı olarak kullanıyoruz (spot_A1 gibi)
        doc_name = f"spot_{spot['id']}"
        collection_ref.document(doc_name).set(data)
        
        print(f"✅ Eklendi: {doc_name} -> {spot['name']}")

    print("\n🎉 Tüm park yerleri oluşturuldu! Şimdi Swift ekibi bunları çekebilir.")

if __name__ == "__main__":
    create_dummy_spots()