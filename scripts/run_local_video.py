import cv2
import time
import sys
import os
from collections import Counter
from ultralytics import YOLO

current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(current_dir)
sys.path.append(parent_dir)

try:
    from app.vision.ocr import PlateOCR
    from app.services.firebase import check_plate_in_db, update_occupancy
except ImportError as e:
    print("Moduller bulunamadi.")
    raise e

MODEL_PATH = "/Users/kawhi2ceng/Desktop/smart-parking-backend/anpr-backend/Automatic-License-Plate-Recognition-using-YOLOv8/license_plate_detector.pt"
VIDEO_PATH = "test_video4.mp4" 
BARRIER_COOLDOWN = 15 

def run_smart_parking():
    try:
        yolo_model = YOLO(MODEL_PATH)
    except:
        print("Model bulunamadi.")
        return

    ocr_engine = PlateOCR()
    
    video_full_path = os.path.join(parent_dir, VIDEO_PATH)
    source = video_full_path if os.path.exists(video_full_path) else 0
    cap = cv2.VideoCapture(source)

    frame_count = 0
    plate_buffer = [] 
    last_barrier_open_time = 0 
    
    current_status_message = "SISTEM AKTIF"
    occupancy_info = "" 
    current_status_color = (255, 0, 0)

    print("SISTEM BASLATILDI")

    while cap.isOpened():
        ret, frame = cap.read()
        if not ret: break

        frame_count += 1
        if frame_count % 3 != 0:
            cv2.putText(frame, current_status_message, (30, 50), cv2.FONT_HERSHEY_SIMPLEX, 1, current_status_color, 2)
            if occupancy_info:
                cv2.putText(frame, occupancy_info, (30, 90), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 255), 2)
            
            cv2.imshow("Smart Parking System", frame)
            if cv2.waitKey(1) & 0xFF == ord('q'): break
            continue

        if time.time() - last_barrier_open_time < BARRIER_COOLDOWN:
            remaining = int(BARRIER_COOLDOWN - (time.time() - last_barrier_open_time))
            msg = f"GECIS IZNI VERILDI ({remaining}s)"
            cv2.putText(frame, msg, (30, 50), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
            if occupancy_info:
                cv2.putText(frame, occupancy_info, (30, 90), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 255), 2)
            
            cv2.imshow("Smart Parking System", frame)
            if cv2.waitKey(1) & 0xFF == ord('q'): break
            continue
        
        current_status_message = "ARAC ARANIYOR..."
        current_status_color = (255, 0, 0)

        results = yolo_model(frame, verbose=False)
        detected_something = False

        for r in results:
            boxes = r.boxes
            for box in boxes:
                if box.conf[0] < 0.5: continue
                detected_something = True
                x1, y1, x2, y2 = map(int, box.xyxy[0])

                plate_crop = frame[y1:y2, x1:x2]
                text = ocr_engine.read(plate_crop)

                if text:
                    print(f"Okunan: {text}")
                    plate_buffer.append(text)
                    if len(plate_buffer) > 5: plate_buffer.pop(0)

                    counts = Counter(plate_buffer)
                    most_common, count = counts.most_common(1)[0]

                    if count >= 3:
                        final_plate = most_common
                        is_registered = check_plate_in_db(final_plate)
                        
                        if is_registered:
                            success, new_count = update_occupancy('main_lot', 'enter')
                            
                            if success:
                                current_status_color = (0, 255, 0)
                                current_status_message = f"HOSGELDIN: {final_plate}"
                                occupancy_info = f"DOLULUK: {new_count}/100" 
                                print(f"BARIYER ACILIYOR -> {final_plate} | {occupancy_info}")
                                
                                last_barrier_open_time = time.time()
                                plate_buffer = []
                            else:
                                current_status_color = (0, 0, 255)
                                current_status_message = "OTOPARK DOLU!"
                                occupancy_info = f"DOLULUK: {new_count}/100"
                        else:
                            current_status_color = (0, 0, 255)
                            current_status_message = f"KAYITSIZ: {final_plate}"
                        
                        cv2.rectangle(frame, (x1, y1), (x2, y2), current_status_color, 3)

        if not detected_something: plate_buffer = []

        cv2.putText(frame, current_status_message, (30, 50), cv2.FONT_HERSHEY_SIMPLEX, 1, current_status_color, 2)
        if occupancy_info:
            cv2.putText(frame, occupancy_info, (30, 90), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 255), 2)

        cv2.imshow("Smart Parking System", frame)
        if cv2.waitKey(1) & 0xFF == ord('q'): break

    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    run_smart_parking()