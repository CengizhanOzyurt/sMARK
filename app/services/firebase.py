import firebase_admin
from firebase_admin import credentials, firestore
import os
import sys

current_dir = os.path.dirname(os.path.abspath(__file__))
app_dir = os.path.dirname(current_dir)
root_dir = os.path.dirname(app_dir)

if not firebase_admin._apps:
    cred_path = os.path.join(root_dir, "serviceAccountKey.json")
    
    if os.path.exists(cred_path):
        try:
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
            print(" Firebase Bağlantısı Başarılı!")
        except Exception as e:
            print(f" Firebase Bağlantı Hatası: {e}")
    else:
        print(f" UYARI: 'serviceAccountKey.json' bulunamadı!")

if firebase_admin._apps:
    db = firestore.client()
else:
    db = None


def check_plate_in_db(plate_text):
    """
    Veritabanında bu plaka var mı diye bakar.
    """
    if not db: return False

    clean_plate = plate_text.replace(" ", "").upper()
    print(f" Firebase Sorgusu: {clean_plate}...")

    try:
        users_ref = db.collection('users')
        query = users_ref.where('plate', '==', clean_plate).limit(1).stream()

        for user in query:
            print(f" Kullanıcı Bulundu: {user.id}")
            return True
        
        print(" Kullanıcı Kayıtlı Değil.")
        return False
    except Exception as e:
        print(f"Sorgu Hatası: {e}")
        return False

# firebase.py dosyasındaki update_occupancy fonksiyonunu bununla değiştirin:

def update_occupancy(spot_id, action='enter'):
    """
    Belirtilen spot_id (örneğin 'spot_B1') için doluluk oranını günceller.
    """
    if not db: return False, 0

    # DİKKAT: Resimdeki koleksiyon adınız 'parking_spots'
    spot_ref = db.collection('parking_spots').document(spot_id)
    
    try:
        # Transaction kullanarak veri tutarlılığını garantiye alabiliriz ama
        # şimdilik basit update yapıyoruz.
        doc = spot_ref.get()
        
        if not doc.exists:
            print(f"❌ Hata: {spot_id} veritabanında bulunamadı!")
            return False, 0
            
        data = doc.to_dict()
        current = data.get('current_occupancy', 0)
        total = data.get('total_capacity', 0) # Resimde 200 görünüyordu

        if action == 'enter':
            if current >= total:
                print(f"⚠️ {spot_id} DOLU! (Kapasite: {total})")
                return False, current
            
            # Firestore'da +1 artır
            spot_ref.update({"current_occupancy": firestore.Increment(1)})
            new_count = current + 1
            print(f"📈 {spot_id} Güncellendi. Yeni Doluluk: {new_count}/{total}")
            return True, new_count

        elif action == 'exit':
            if current <= 0:
                return False, 0
            
            # Firestore'da -1 azalt
            spot_ref.update({"current_occupancy": firestore.Increment(-1)})
            new_count = current - 1
            print(f"📉 {spot_id} Güncellendi. Yeni Doluluk: {new_count}/{total}")
            return True, new_count
            
    except Exception as e:
        print(f"🔥 Firebase Hatası: {e}")
        return False, 0

def get_nearest_empty_spot():
    if not db: return None
    try:
        spots = db.collection('parking_spots').where('is_occupied', '==', False).limit(1).stream()
        for spot in spots:
            return spot.to_dict()
    except: pass
    return None