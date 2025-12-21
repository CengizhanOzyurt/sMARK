import cv2
import easyocr
import numpy as np
from typing import Optional
import re

TR_PLATE_REGEX = re.compile(r"^(0[1-9]|[1-7][0-9]|8[01])[A-Z]{1,3}[0-9]{2,4}$")

class PlateOCR:
    def __init__(self):
        self.reader = easyocr.Reader(['en'], gpu=False)

    def read(self, plate_img: np.ndarray) -> Optional[str]:
        if plate_img is None or plate_img.size == 0:
            return None    
        img = cv2.resize(plate_img, None, fx=3.0, fy=3.0, interpolation=cv2.INTER_CUBIC)
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)      
        gray = cv2.bilateralFilter(gray, 11, 17, 17)
        results = self.reader.readtext(
            gray, 
            allowlist='ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789', 
            detail=1,
            paragraph=False
        )
        best_text = None
        best_conf = 0.0
        print(f"\n--- OCR Ham Sonuçlar ---") 
        for bbox, text, conf in results:
            print(f"Okunan: '{text}' - Güven: {conf:.2f}") 
            clean_text = text.upper().replace(' ', '')

            if len(clean_text) < 5:
                continue

            if TR_PLATE_REGEX.match(clean_text):
                if conf > best_conf:
                    best_conf = conf
                    best_text = clean_text
            
            elif len(clean_text) >= 7 and conf > 0.5:
                 if conf > best_conf:
                    best_text = clean_text 

        return best_text