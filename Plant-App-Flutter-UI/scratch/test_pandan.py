import sys, io, urllib.request, json
from PIL import Image

sys.path.insert(0, r'c:\Users\user\Desktop\FYP\AppIntegration\CoreTech\Plant_Disease_Experiment')
from src.botanical_identifier import identify_botanical_species

# Fetch authentic iNaturalist Pandanus amaryllifolius photos
url = 'https://api.inaturalist.org/v1/observations?taxon_name=Pandanus+amaryllifolius&quality_grade=research&photos=true&per_page=5'
req = urllib.request.Request(url, headers={'User-Agent': 'FloraResearchBot/2.0'})
with urllib.request.urlopen(req, timeout=10) as r:
    data = json.loads(r.read().decode('utf-8'))

for i, res in enumerate(data['results'][:3]):
    photo_url = res['photos'][0]['url'].replace('square', 'medium')
    print(f'=== Testing Pandan specimen {i+1} ===')
    print(f'Photo: {photo_url}')
    img_req = urllib.request.Request(photo_url, headers={'User-Agent': 'FloraResearchBot/2.0'})
    with urllib.request.urlopen(img_req, timeout=10) as ir:
        img = Image.open(io.BytesIO(ir.read())).convert('RGB')
    
    pred = identify_botanical_species(img, top_k=5)
    print(f'  Top species: {pred["top_species"]} ({pred["confidence"]}%)')
    for c in pred['candidates']:
        print(f'    Rank {c["rank"]}: {c["species"]} ({c["confidence"]}%)')
