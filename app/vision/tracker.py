from collections import Counter, deque

class PlateTracker:
    def __init__(self, window_size=40, min_votes=5):
        self.window = deque(maxlen=window_size)
        self.min_votes = min_votes

    def add(self, plate_text):
        if plate_text:
            self.window.append(plate_text)

    def get_best_plate(self):
        if len(self.window) < self.min_votes:
            return None

        counter = Counter(self.window)
        plate, votes = counter.most_common(1)[0]

        if votes >= self.min_votes:
            return plate
        return None
