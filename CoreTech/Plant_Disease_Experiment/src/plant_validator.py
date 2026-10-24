"""
PhytoCare Plant Presence & Out-of-Distribution (OOD) Validator
Determines if an input image contains authentic botanical plant foliage
prior to executing clinical pathology classification.
"""

from typing import Tuple, Optional
import cv2
import numpy as np

def validate_is_plant(
    img_rgb: np.ndarray,
    botanical_conf: float,
    yolo_model=None
) -> Tuple[bool, float, str]:
    """
    Multi-stage verification gate to filter out non-plant images
    (e.g., human faces, pets, furniture, vehicles, documents, solid walls).

    Returns:
        (is_plant: bool, confidence_score: float, reason_message: str)
    """
    h, w, _ = img_rgb.shape
    total_px = h * w

    # 1. Texture & Edge density check (rejects blank walls, solid surfaces, dark/blurred voids)
    gray = cv2.cvtColor(img_rgb, cv2.COLOR_RGB2GRAY)
    sobelx = cv2.Sobel(gray, cv2.CV_32F, 1, 0, ksize=3)
    sobely = cv2.Sobel(gray, cv2.CV_32F, 0, 1, ksize=3)
    edge_density = float(np.mean(cv2.magnitude(sobelx, sobely)))
    if edge_density < 2.5:
        return False, 0.0, "Image has insufficient surface texture or botanical detail (blank or blurred void)."

    # 2. Chromatic & Botanical Tissue Analysis (RGB, HSV, Excess Green & Excess Red)
    r, g, b = cv2.split(img_rgb.astype(np.float32))
    exg = 2.0 * g - r - b  # Excess Green Index (chlorophyll presence)
    exr = 2.0 * r - g - b  # Excess Red Index (common in mammalian skin, bricks, plastics)

    hsv = cv2.cvtColor(img_rgb, cv2.COLOR_RGB2HSV)
    h_ch, s_ch, v_ch = cv2.split(hsv)

    # Botanical Tissue Masks
    is_green = (h_ch >= 18) & (h_ch <= 102) & (s_ch >= 18) & (v_ch >= 22)
    is_yellow_chlorosis = (h_ch >= 12) & (h_ch < 25) & (s_ch >= 25) & (v_ch >= 28) & (exr < 55)
    is_wilted_brown = (h_ch >= 4) & (h_ch <= 26) & (s_ch >= 20) & (v_ch >= 20) & (exr < 65) & (exg > -40)
    is_succulent_variegated = (s_ch >= 10) & (s_ch <= 60) & (h_ch >= 14) & (h_ch <= 105) & (v_ch >= 45)
    is_purple_foliage = ((h_ch <= 10) | (h_ch >= 155)) & (s_ch >= 35) & (v_ch >= 30)

    veg_mask = (exg > 3.5) | is_green | is_yellow_chlorosis | is_wilted_brown | is_succulent_variegated | is_purple_foliage
    veg_ratio = float(np.count_nonzero(veg_mask) / total_px)

    # Human skin & non-vegetative tissue filter
    is_skin = (h_ch >= 0) & (h_ch <= 25) & (s_ch >= 40) & (s_ch <= 180) & (v_ch >= 70) & (exr > 40) & (exg < -15)
    skin_ratio = float(np.count_nonzero(is_skin) / total_px)

    # 3. Optional YOLO Semantic Object Screening
    if yolo_model is not None:
        try:
            results = yolo_model.predict(img_rgb, conf=0.55, verbose=False)
            for res in results:
                if res.boxes is not None and len(res.boxes) > 0:
                    for box in res.boxes:
                        cls_id = int(box.cls[0].item())
                        cls_name = yolo_model.names.get(cls_id, "").lower()
                        # Reject dominant non-plant objects
                        if cls_name in ["person", "cat", "dog", "car", "motorcycle", "airplane", "bus", "train", "truck", "boat", "chair", "couch", "bed", "laptop", "cell phone"]:
                            # If non-plant object occupies significant area and plant foliage is minimal
                            bx = box.xywhn[0].cpu().numpy()
                            box_area = bx[2] * bx[3]
                            if box_area > 0.25 and veg_ratio < 0.20:
                                return False, 0.0, f"Non-plant object detected ({cls_name.capitalize()}). Please aim the camera at a plant leaf or foliage."
        except Exception:
            pass

    # 4. Decision Rule Base for Out-Of-Distribution Rejection:
    # Rule A: Dominant human skin
    if skin_ratio > 0.35 and veg_ratio < 0.15:
        return False, 0.0, "Non-botanical subject detected (human skin tone). Please point camera at a plant leaf."

    # Rule B: Virtually no botanical tissue (< 4.5% of total frame)
    if veg_ratio < 0.045:
        return False, round(veg_ratio * 100, 1), f"No plant foliage or leaf tissue found ({round(veg_ratio * 100, 1)}% vegetative tissue detected)."

    # Rule C: FloraNet Out-of-Distribution threshold
    # On a 250-class botanical model, pure noise/non-plant typically scores 1-5% (random chance = 0.4%)
    if botanical_conf < 14.0:
        return False, round(botanical_conf, 1), f"Subject not recognized as a plant species (botanical confidence: {round(botanical_conf, 1)}%)."

    # Rule D: Borderline botanical confidence (< 24%) combined with low foliage ratio (< 12%)
    if botanical_conf < 24.0 and veg_ratio < 0.12:
        return False, round(botanical_conf, 1), f"Unrecognized object ({round(botanical_conf, 1)}% plant match, {round(veg_ratio * 100, 1)}% foliage area)."

    # Plant verified!
    plant_score = min(99.0, max(60.0, botanical_conf * 0.7 + veg_ratio * 30.0))
    return True, round(plant_score, 1), "Plant foliage verified successfully."

