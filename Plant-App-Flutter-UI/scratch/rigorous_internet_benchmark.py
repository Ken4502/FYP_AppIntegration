"""
Rigorous Internet Image Benchmark for FloraNet-251
Tests independent, unseen internet specimens from iNaturalist:
  1. Pandan (Pandanus amaryllifolius)
  2. Dracaena (Dracaena fragrans / Dracaena reflexa)
  3. Chili Pepper (Capsicum frutescens)
  4. Tomato (Solanum lycopersicum)
"""
import sys
import io
import json
import urllib.request
from PIL import Image

sys.path.insert(0, r'C:\Users\user\Desktop\FYP\AppIntegration\CoreTech\Plant_Disease_Experiment')
from src.botanical_identifier import identify_botanical_species, load_botanical_identifier

# Force model reload
import src.botanical_identifier as bi
bi._cached_flora_model = None
bi._cached_flora_classes = None

def fetch_inaturalist_photos(taxon_name: str, count: int = 5, offset: int = 40):
    url = f"https://api.inaturalist.org/v1/observations?taxon_name={urllib.parse.quote(taxon_name)}&quality_grade=research&photos=true&per_page={count}&page={offset // count + 1}"
    req = urllib.request.Request(url, headers={"User-Agent": "FloraResearchBot/2.0"})
    photos = []
    try:
        with urllib.request.urlopen(req, timeout=12) as r:
            data = json.loads(r.read().decode("utf-8"))
        for item in data.get("results", []):
            for photo in item.get("photos", []):
                p_url = photo["url"].replace("square", "medium")
                obs_id = item.get("id")
                photos.append((obs_id, p_url))
                if len(photos) >= count:
                    return photos
    except Exception as e:
        print(f"Error querying {taxon_name}: {e}")
    return photos

def evaluate_specimen(title: str, obs_id: int, img_url: str, expected_match: str):
    print(f"\n--- Testing: {title} (Obs #{obs_id}) ---")
    print(f"URL: {img_url}")
    try:
        req = urllib.request.Request(img_url, headers={"User-Agent": "FloraResearchBot/2.0"})
        with urllib.request.urlopen(req, timeout=10) as r:
            img = Image.open(io.BytesIO(r.read())).convert("RGB")

        res = identify_botanical_species(img, top_k=5)
        top_sp = res["top_species"]
        conf = res["confidence"]
        candidates = res["candidates"]

        is_match = expected_match.lower() in top_sp.lower()
        symbol = "✅ PASS" if is_match else "❌ FAIL"

        print(f"Result: {symbol} | Top Prediction: {top_sp} | Confidence: {conf:.2f}%")
        print("Top 3 Candidates:")
        for c in candidates[:3]:
            print(f"  #{c['rank']}: {c['species']} ({c['confidence']:.2f}%)")
        return is_match, top_sp, conf
    except Exception as e:
        print(f"Evaluation error: {e}")
        return False, str(e), 0.0

def main():
    import urllib.parse
    print("=" * 72)
    print("   FLORANET-251 RIGOROUS INTERNET BENCHMARK (UNSEEN IMAGES)")
    print("=" * 72)

    # 1. Test Pandan (Pandanus amaryllifolius)
    print("\n[GROUP 1] Testing Pandan (Pandanus amaryllifolius) - Target: Pandan")
    pandan_photos = fetch_inaturalist_photos("Pandanus amaryllifolius", count=5, offset=60)
    pandan_results = []
    for obs_id, p_url in pandan_photos:
        r = evaluate_specimen("Pandan (Pandanus amaryllifolius)", obs_id, p_url, "Pandan")
        pandan_results.append(r)

    # 2. Test Dracaena (Corn Plant / Dracaena fragrans)
    print("\n[GROUP 2] Testing Dracaena / Corn Plant - Target: Dracaena")
    drac_photos = fetch_inaturalist_photos("Dracaena fragrans", count=3, offset=15)
    drac_results = []
    for obs_id, p_url in drac_photos:
        r = evaluate_specimen("Corn Plant (Dracaena fragrans)", obs_id, p_url, "Dracaena")
        drac_results.append(r)

    # 3. Test Chili Pepper (Capsicum frutescens)
    print("\n[GROUP 3] Testing Chili Pepper - Target: Chili Pepper")
    chili_photos = fetch_inaturalist_photos("Capsicum frutescens", count=3, offset=10)
    chili_results = []
    for obs_id, p_url in chili_photos:
        r = evaluate_specimen("Chili Pepper (Capsicum frutescens)", obs_id, p_url, "Chili Pepper")
        chili_results.append(r)

    # 4. Test Tomato (Solanum lycopersicum)
    print("\n[GROUP 4] Testing Farm Tomato - Target: Tomato")
    tomato_photos = fetch_inaturalist_photos("Solanum lycopersicum", count=3, offset=10)
    tomato_results = []
    for obs_id, p_url in tomato_photos:
        r = evaluate_specimen("Tomato (Solanum lycopersicum)", obs_id, p_url, "Tomato")
        tomato_results.append(r)

    print("\n" + "=" * 72)
    print("                      BENCHMARK ACCURACY SUMMARY")
    print("=" * 72)
    p_pass = sum(1 for m, _, _ in pandan_results if m)
    p_conf = sum(c for _, _, c in pandan_results) / max(1, len(pandan_results))
    print(f"🌿 Pandan Identification: {p_pass}/{len(pandan_results)} PASS | Mean Confidence: {p_conf:.2f}%")

    d_pass = sum(1 for m, _, _ in drac_results if m)
    d_conf = sum(c for _, _, c in drac_results) / max(1, len(drac_results))
    print(f"🎋 Dracaena Identification: {d_pass}/{len(drac_results)} PASS | Mean Confidence: {d_conf:.2f}%")

    c_pass = sum(1 for m, _, _ in chili_results if m)
    c_conf = sum(c for _, _, c in chili_results) / max(1, len(chili_results))
    print(f"🌶️ Chili Pepper Identification: {c_pass}/{len(chili_results)} PASS | Mean Confidence: {c_conf:.2f}%")

    t_pass = sum(1 for m, _, _ in tomato_results if m)
    t_conf = sum(c for _, _, c in tomato_results) / max(1, len(tomato_results))
    print(f"🍅 Tomato Farm Veggie Identification: {t_pass}/{len(tomato_results)} PASS | Mean Confidence: {t_conf:.2f}%")
    print("=" * 72)

if __name__ == "__main__":
    main()
