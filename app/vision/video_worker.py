import cv2 
import numpy as np 
from typing import Optional
from app.vision.tracker import PlateTracker


from app.vision.plate_detector import PlateDetector
from app.vision.ocr import PlateOCR

class VideoPlateReader:

    def __init__(self, model_path: str):
        self.detector = PlateDetector(model_path=model_path)
        self.ocr = PlateOCR()
        self.tracker = PlateTracker(
            window_size=40,
            min_votes=5
        )


    @staticmethod
    def crop_plate(frame: np.ndarray, box) -> Optional[np.ndarray]:
        x1, y1, x2, y2 = box
        h, w = frame.shape[:2]

        x1 = max(0, min(w - 1, x1))
        x2 = max(0, min(w, x2))
        y1 = max(0, min(h - 1, y1))
        y2 = max(0, min(h, y2))

        if x2 <= x1 or y2 <= y1:
            return None

        return frame[y1:y2, x1:x2]

    def process_video(self, video_path: str):
        cap = cv2.VideoCapture(video_path)

        if not cap.isOpened():
            raise RuntimeError(f"Video acılmadı: {video_path}")

        frame_index = 0
        seen_plates = set()

        print("Video Isleniyor...")   

        while True:
            ret, frame = cap.read()
            if not ret:
                break

            frame_index += 1

            boxes = self.detector.detect(frame)
            if frame_index % 30 == 0:
                print(f"[DEBUG] Frame {frame_index} → {len(boxes)} plaka tespit edildi")

            for box in boxes:
                plate_crop = self.crop_plate(frame, box)
                if plate_crop is None:
                    continue
                cv2.imwrite(f"debug_plate_{frame_index}.jpg", plate_crop)

                plate_text = self.ocr.read(plate_crop)
                if plate_text is None:
                    continue

                if plate_text in seen_plates:
                    continue
                seen_plates.add(plate_text)

                plate_text = self.ocr.read(plate_crop)
                self.tracker.add(plate_text)

                best_plate = self.tracker.get_best_plate()
                if best_plate and best_plate not in seen_plates:
                    seen_plates.add(best_plate)
                    print(f"\n[FINAL] PLAKA TESPİT EDİLDİ -> {best_plate}\n")


        cap.release()
        print("\n Video bitti.")









