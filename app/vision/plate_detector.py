from typing import List,Tuple
import numpy as np
from ultralytics import YOLO

class PlateDetector:

    def __init__(
        self,
        model_path: str,
        conf_threshold: float = 0.3,
        img_size: int = 640
    ):
        self.model = YOLO(model_path)
        self.conf_threshold = conf_threshold
        self.img_size = img_size
    
    def detect(self, frame: np.ndarray) -> List[Tuple[int, int, int,int]]:
        results = self.model.predict(
            source=frame,
            conf=self.conf_threshold,
            imgsz=self.img_size,
            verbose=False
        )

        boxes = []

        for result in results:
            if result.boxes is None:
                continue
            
            for box in result.boxes:
                x1, y1, x2, y2 = map(int, box.xyxy[0])
                boxes.append((x1, y1, x2, y2))
        return boxes
        
        