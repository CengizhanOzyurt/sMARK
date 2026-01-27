# Smart Parking Backend

Computer-vision backend that detects vehicle license plates from video using YOLOv8, reads plates with OCR, validates users against Firebase Firestore, and updates parking occupancy. Includes demo scripts to run on local videos or webcam and utilities to seed Firestore data.

**Highlights**
- YOLOv8 plate detection (`ultralytics`)
- OCR via `easyocr` with plate tracking and voting
- Firebase Firestore integration for user lookup and occupancy updates
- Demo UI overlay in OpenCV showing barrier logic and guidance

## Project Structure
- `app/services/firebase.py` – Firestore initialization, plate lookup, occupancy updates, nearest spot fetch.
- `app/vision/plate_detector.py` – YOLOv8-based plate detection.
- `app/vision/ocr.py` – EasyOCR plate reading with basic preprocessing and TR plate regex.
- `app/vision/tracker.py` – Sliding-window voting for a stable final plate.
- `app/vision/video_worker.py` – High-level video processor that wires detection + OCR + tracking.
- `scripts/run_local_video.py` – End-to-end demo: video/frame processing, overlay, and Firestore updates.
- `scripts/init_parking_lot.py` – Initializes a parking lot document.
- `scripts/create_parking_spots.py` – Seeds example parking spots.
- `scripts/create_demo_data.py` – Seeds demo spots and a lot with sample values.
- `anpr-backend/Automatic-License-Plate-Recognition-using-YOLOv8/license_plate_detector.pt` – YOLOv8 weights.
- `test_video*.mp4` – Sample test videos.
- `sMARK-iOS/` – iOS client (separate app) included for reference.

## Prerequisites
- Python `3.10+`
- macOS (tested), Linux should work similarly
- Firebase project with Firestore enabled
- `serviceAccountKey.json` placed in the repository root
- YOLOv8 weights: `anpr-backend/Automatic-License-Plate-Recognition-using-YOLOv8/license_plate_detector.pt`

## Installation
1. Create and activate a virtual environment.
   - `python -m venv .venv`
   - macOS/Linux: `source .venv/bin/activate`
   - Windows (PowerShell): `.venv\Scripts\Activate.ps1`
2. Install dependencies.
   - `pip install -r requirements.txt`
   - Note: If `torch` is not automatically installed, install a compatible CPU build for your OS. Example (CPU-only):
     - macOS/Linux: `pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu`
3. Verify that `serviceAccountKey.json` exists in the repo root.

## Firebase Setup
Place your Firebase Admin SDK key file at the root as `serviceAccountKey.json`. Firestore collections used:
- `users` – Documents with at least a `plate` field (e.g., `34ABC123`).
- `parking_spots` – Documents like `spot_A1` with fields: `name`, `location` (`GeoPoint`), `is_occupied`, and optionally `current_occupancy`, `total_capacity`.
- `parking_lots` – Lot-level aggregate: `name`, `total_capacity`, `current_occupancy`, `is_full`.

Seed demo data with the provided scripts:
- `python scripts/init_parking_lot.py`
- `python scripts/create_parking_spots.py`
- `python scripts/create_demo_data.py`

## Model and Video Paths
The demo script `scripts/run_local_video.py` uses constants:
- `MODEL_PATH` – Update this to the local weights path, for example:
  - ``anpr-backend/Automatic-License-Plate-Recognition-using-YOLOv8/license_plate_detector.pt``
- `VIDEO_PATH` – A file under the repo root like `test_video4.mp4`. If not found, webcam (`0`) is used.

## Run the Local Demo
Run the end-to-end demo with overlay, OCR, and Firestore updates:
- `python scripts/run_local_video.py`

Controls and behavior:
- Press `q` to quit.
- Status text overlays show system state, occupancy guidance, and barrier logic.
- When a registered plate is detected, occupancy is updated and a short cooldown prevents repeated triggers.

## Programmatic Usage
Use the `VideoPlateReader` for simple batch processing:

```python
from app.vision.video_worker import VideoPlateReader

reader = VideoPlateReader(model_path="anpr-backend/Automatic-License-Plate-Recognition-using-YOLOv8/license_plate_detector.pt")
reader.process_video("test_video4.mp4")
```

## Troubleshooting
- `serviceAccountKey.json` missing: The app prints a warning and disables Firestore calls.
- Torch not found: Install an appropriate `torch` build for your platform.
- Webcam permission on macOS: Grant camera access to your terminal/IDE.
- Firestore rules: Ensure the Admin SDK service account has write access to target collections.
- Model path: Confirm the `.pt` file exists and the path used by demo matches your repo location.

## Notes
- `fastapi` and `uvicorn` are included in requirements for potential API usage, but an HTTP server is not configured in this snapshot.
- The iOS client (`sMARK-iOS`) is not required to run the backend demos.

## Acknowledgments
- YOLOv8 model and utilities are under `anpr-backend/Automatic-License-Plate-Recognition-using-YOLOv8` with its own license.
