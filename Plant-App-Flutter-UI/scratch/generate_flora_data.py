import json
import re

with open(r'C:\Users\user\Desktop\FYP\AppIntegration\CoreTech\Plant_Identification_Experiment\artifacts\class_indices.json', 'r', encoding='utf-8') as f:
    raw_classes = json.load(f)['classes']

FERNS = {
    'Asparagus Fern (Asparagus setaceus)': ('Feathery, climbing perennial vine with delicate needle-like cladodes.', 35, 60, 4, 'Water when top 1 inch feels dry; mist regularly.', 'Bright indirect light', '18°C - 24°C', 'Mildly toxic to dogs & cats', 'Rich, well-draining potting soil'),
    'Birds Nest Fern (Asplenium nidus)': ('Epiphytic fern with broad, apple-green arching fronds resembling a bird nest.', 38, 65, 4, 'Keep soil consistently moist; water soil around base, not crown.', 'Medium to low indirect light', '18°C - 26°C', 'Non-toxic / Pet friendly', 'Peat-based moisture retentive mix'),
    'Boston Fern (Nephrolepis exaltata)': ('Graceful, arching sword-like fronds known for superior indoor air purification.', 40, 68, 3, 'Maintain continuous soil moisture; never let root ball dry completely.', 'Filtered indirect light or dappled shade', '16°C - 24°C', 'Non-toxic / Pet friendly', 'Rich organic peat and perlite potting mix'),
    'Kangaroo Paw Fern (Microsorum diversifolium)': ('Hardy Australian fern with unique irregularly lobed dark green glossy fronds.', 32, 58, 5, 'Water when topsoil begins drying; drought-tolerant for a fern.', 'Bright indirect to moderate light', '16°C - 24°C', 'Non-toxic / Pet friendly', 'Well-aerated porous fern compost'),
    'Maidenhair Fern (Adiantum capillus-veneris)': ('Delicate fan-shaped foliage on wiry black stems that loves high humidity.', 42, 70, 3, 'Keep evenly damp at all times; highly sensitive to dry soil.', 'Gentle filtered morning light or shade', '18°C - 24°C', 'Non-toxic / Pet friendly', 'Moisture-retentive humus-rich potting mix'),
    'Staghorn Fern (Platycerium bifurcatum)': ('Sculptural epiphytic fern with broad shield fronds and antler-like fertile fronds.', 30, 55, 6, 'Soak thoroughly once weekly; allow moss or bark to dry slightly between soakings.', 'Bright indirect filtered light', '15°C - 26°C', 'Non-toxic / Pet friendly', 'Mounted on sphagnum moss or orchid bark'),
}

SUCCULENTS = {
    'Aloe Vera': ('Succulent with fleshy, serrated leaves filled with soothing medicinal gel.', 15, 35, 14, 'Water deeply only when soil is completely bone dry.', 'Full sun to bright indirect light', '15°C - 28°C', 'Toxic to cats & dogs (aloin)', 'Cactus & succulent gritty coarse mix'),
    'Bunny Ears Cactus (Opuntia microdasys)': ('Branching desert cactus with pad-shaped segments covered in fine golden glochids.', 10, 25, 21, 'Water very sparingly; monthly in winter, biweekly in hot summer.', 'Full direct sun (6+ hours)', '18°C - 32°C', 'Non-toxic (glochids cause irritation)', 'Fast-draining mineral-rich cactus grit'),
    'Christmas Cactus (Schlumbergera bridgesii)': ('Epiphytic forest cactus with arching segmented stems that blooms vibrant flowers in winter.', 22, 45, 8, 'Water when top 2 inches dry out; more moisture than desert cacti.', 'Bright indirect to partial shade', '15°C - 22°C', 'Non-toxic / Pet friendly', 'Well-draining potting mix with perlite and bark'),
    'Columnar Cactus (Pachycereus pringlei)': ('Iconic majestic columnar cactus adapted to harsh arid climates.', 10, 25, 21, 'Allow soil to dry out completely between soakings.', 'Full direct sun', '18°C - 35°C', 'Non-toxic / Pet friendly', 'Extremely porous coarse sandy soil'),
    'Cylindrical Snake Plant (Dracaena angolensis)': ('Hardy architectural succulent with upright cylindrical spear-shaped leaves.', 14, 30, 14, 'Thrives on neglect; water only when pot feels lightweight and dry.', 'Low light to bright indirect sunlight', '15°C - 29°C', 'Toxic to pets (saponins)', 'Well-draining sandy loam'),
    'Echeveria Elegans (Echeveria elegans)': ('Mexican snow ball succulent forming compact geometric rosettes of pale blue-green leaves.', 12, 28, 12, 'Soak and dry method; avoid water sitting inside rosette center.', 'Bright direct sunlight', '16°C - 27°C', 'Non-toxic / Pet friendly', 'Fast-draining gritty succulent mix'),
    'Fishbone Cactus (Disocactus anguliger)': ('Trailing zig-zag epiphytic cactus native to tropical rainforests with fragrant night blooms.', 20, 42, 8, 'Water when top 50% of soil dries out; prefers moderate humidity.', 'Bright indirect sunlight', '16°C - 26°C', 'Non-toxic / Pet friendly', 'Orchid bark, perlite, and potting peat mix'),
    'Ghost Plant (Graptopetalum paraguayense)': ('Drought-hardy succulent with opalescent silvery-gray leaves in trailing rosettes.', 12, 28, 12, 'Water when leaves begin to soften slightly and soil is completely dry.', 'Full sun to partial afternoon shade', '15°C - 28°C', 'Non-toxic / Pet friendly', 'Porous gravelly succulent mix'),
    'Golden Barrel Cactus (Echinocactus grusonii)': ('Globe-shaped desert cactus ringed with brilliant yellow spines.', 10, 24, 21, 'Water deeply once every 3-4 weeks in spring/summer; keep dry in winter.', 'Full direct sunlight', '18°C - 32°C', 'Non-toxic / Pet friendly (sharp spines)', 'Porous sandy desert mix'),
    'Hoya Kerrii (Hoya kerrii)': ('Sweetheart succulent vine known for fleshy emerald heart-shaped leaves.', 18, 38, 10, 'Allow soil to dry out almost completely between waterings.', 'Bright indirect to gentle direct morning sun', '18°C - 27°C', 'Non-toxic / Pet friendly', 'Chunky epiphytic mix with orchid bark and perlite'),
    'Jade plant (Crassula ovata)': ('Popular lucky succulent with miniature tree-like woody stems and glossy oval leaves.', 15, 32, 12, 'Water when soil is dry to the touch; prune to encourage branching.', 'Bright sunlight with 4+ hours direct', '15°C - 24°C', 'Toxic to cats & dogs', 'Quick-draining succulent soil mix'),
    'Kalanchoe': ('Flowering succulent with glossy scalloped leaves and clusters of long-lasting colorful blooms.', 16, 35, 10, 'Water when top 2 inches dry out; do not let pot sit in excess drainage.', 'Bright natural light to partial sun', '16°C - 24°C', 'Toxic to cats & dogs (bufadienolides)', 'Well-draining potting soil with perlite'),
    'Snake plant (Sanseviera)': ('Indestructible indoor air-purifying champion with upright sword leaves.', 14, 30, 14, 'Water every 2-3 weeks; highly tolerant of drought and low light.', 'Low light to full sun', '15°C - 30°C', 'Toxic to pets (saponins)', 'Gritty fast-draining potting blend'),
    'Wax Plant (Hoya carnosa)': ('Vining tropical succulent with porcelain-like fragrant star-shaped flower clusters.', 18, 40, 9, 'Let top 2 inches dry out before watering; loves climbing on trellises.', 'Bright indirect sunlight', '18°C - 27°C', 'Non-toxic / Pet friendly', 'Airy bark, perlite, and peat potting medium'),
    'Yucca': ('Architectural drought-resistant plant with woody cane stems and sword-shaped foliage.', 15, 32, 12, 'Allow top half of soil to dry out; avoid waterlogged roots.', 'Full sun to bright indirect light', '15°C - 28°C', 'Toxic to dogs and cats (saponins)', 'Coarse sandy well-draining soil'),
    'Zebra Haworthia (Haworthiopsis fasciata)': ('Compact succulent featuring dark green rosettes with striking white raised bands.', 12, 28, 12, 'Water thoroughly when soil is dry; keep dry during dormant periods.', 'Bright indirect light or partial shade', '15°C - 26°C', 'Non-toxic / Pet friendly', 'Gritty mineral succulent mix'),
}

HERBS = {
    'Bay Laurel (Laurus nobilis)': ('Aromatic evergreen shrub producing culinary bay leaves for stews and soups.', 26, 48, 6, 'Water when top inch of soil dries; drought tolerant once established.', 'Full sun to partial shade', '15°C - 25°C', 'Mildly toxic to pets in high quantities', 'Well-draining loamy potting soil'),
    'Borage (Borago officinalis)': ('Medicinal edible herb with starry celestial blue blossoms and cucumber-flavored foliage.', 28, 52, 4, 'Keep soil moderately moist; water during prolonged dry spells.', 'Full sun to light shade', '15°C - 22°C', 'Toxic to dogs & cats (pyrrolizidine alkaloids)', 'Fertile, well-draining garden soil'),
    'Catnip (Nepeta cataria)': ('Hardy perennial mint relative loved by felines for its nepetalactone aromatic oils.', 25, 48, 5, 'Water when top inch feels dry; drought tolerant once roots settle.', 'Full sun', '15°C - 24°C', 'Non-toxic to cats & dogs (sedative effect)', 'Ordinary well-draining garden soil'),
    'Chamomile (Matricaria chamomilla)': ('Daisy-like edible herbal flowers prized for calming herbal tea infusions.', 26, 50, 5, 'Water moderately; allow surface to dry slightly between waterings.', 'Full sun to light afternoon shade', '15°C - 22°C', 'Mildly toxic to cats & dogs in large doses', 'Light, sandy, well-drained soil'),
    'Chives (Allium schoenoprasum)': ('Grass-like culinary allium with delicate onion flavor and purple pom-pom blossoms.', 30, 54, 4, 'Keep soil consistently moist; water regularly throughout the growing season.', 'Full sun to partial shade', '15°C - 22°C', 'Toxic to dogs & cats (allium genus)', 'Rich, moist, well-draining organic soil'),
    'Cilantro (Coriandrum sativum)': ('Pungent fresh culinary herb essential in salsa, guacamole, and curries.', 30, 55, 3, 'Water regularly to prevent early bolting in warm weather.', 'Full sun to partial morning shade', '15°C - 21°C', 'Non-toxic / Pet friendly', 'Moist, fertile, fast-draining loamy soil'),
    'Common Sage (Salvia officinalis)': ('Woody perennial herb with velvety gray-green foliage used in roasted dishes.', 22, 42, 6, 'Allow top 1-2 inches to dry; drought resistant once established.', 'Full direct sun (6+ hours)', '15°C - 25°C', 'Non-toxic / Pet friendly', 'Well-drained gritty or sandy garden soil'),
    'Dill (Anethum graveolens)': ('Feathery aromatic herb ideal for pickling, dressings, and pairing with seafood.', 28, 52, 4, 'Water regularly; keep soil damp but avoid waterlogging.', 'Full direct sun', '15°C - 24°C', 'Non-toxic / Pet friendly', 'Rich, loose, well-draining garden soil'),
    'Fennel (Foeniculum vulgare)': ('Anise-flavored Mediterranean herb with feathery fronds and a crunchy bulb.', 28, 50, 4, 'Water deeply once or twice weekly; maintain moderate moisture.', 'Full direct sun', '16°C - 24°C', 'Essential oil toxic; foliage non-toxic in small doses', 'Fertile, well-draining, slightly acidic soil'),
    'Flat-Leaf Parsley (Petroselinum crispum)': ('Nutrient-packed culinary staple providing bright herbal notes and fresh garnish.', 30, 55, 3, 'Water consistently to keep soil evenly moist; do not allow root zone to bake.', 'Full sun to partial shade', '15°C - 22°C', 'Large quantities toxic to pets; culinary garnish safe', 'Deep, rich, moisture-retaining loam'),
    'French Tarragon (Artemisia dracunculus)': ('Refined French culinary herb with sweet anise notes essential in béarnaise sauce.', 24, 46, 5, 'Allow top inch to dry between waterings; dislikes soggy roots.', 'Full sun to light shade', '15°C - 24°C', 'Mildly toxic to dogs & cats in excess', 'Sandy, well-draining soil with neutral pH'),
    'Garden Sorrel (Rumex acetosa)': ('Tart, lemony perennial leafy green prized in salads, soups, and spring cooking.', 32, 58, 3, 'Keep soil evenly damp; drought triggers premature flowering and bitterness.', 'Full sun to partial shade', '15°C - 21°C', 'Toxic to pets in large amounts (soluble oxalates)', 'Moist, fertile, slightly acidic loam'),
    'Garden Thyme (Thymus vulgaris)': ('Classic Mediterranean woody herb with tiny intensely fragrant aromatic leaves.', 20, 40, 7, 'Water only when soil is thoroughly dry; highly drought-adapted.', 'Full direct sun (6+ hours)', '15°C - 25°C', 'Non-toxic / Pet friendly', 'Light, poor to average, rocky well-drained soil'),
    'Lavender (Lavandula angustifolia)': ('English lavender famous for fragrant purple floral spikes and calming essential oil.', 18, 38, 8, 'Water deeply then let soil dry out completely; needs excellent drainage.', 'Full direct sun (6-8 hours daily)', '15°C - 27°C', 'Toxic to cats & dogs (linalool/linalyl acetate)', 'Lean, sandy, alkaline fast-draining soil'),
    'Lemon Balm (Melissa officinalis)': ('Vigorous citrus-scented perennial herb that makes relaxing herbal infusions.', 28, 52, 4, 'Water when top inch of soil feels dry; thrives in moist ground.', 'Full sun to partial shade', '15°C - 24°C', 'Non-toxic / Pet friendly', 'Rich, well-drained, moist garden soil'),
    'Lemongrass (Cymbopogon citratus)': ('Tropical aromatic grass with citrus flavor prized in Southeast Asian cooking.', 32, 58, 3, 'Keep soil rich and consistently moist; loves warm humid environments.', 'Full direct sun (6+ hours)', '20°C - 32°C', 'Toxic to cats & dogs (essential oils)', 'Rich, loamy, moisture-retentive potting mix'),
    'Lovage (Levisticum officinale)': ('Tall vigorous culinary perennial tasting like concentrated aromatic celery.', 32, 56, 4, 'Water regularly to maintain moist soil; deep roots drink generously.', 'Full sun to partial afternoon shade', '15°C - 22°C', 'Mildly toxic in large doses (volatile oils)', 'Deep, fertile, humus-rich soil'),
    'Marjoram (Origanum majorana)': ('Sweet, floral cousin of oregano with delicate warm aromatic leaves.', 22, 44, 6, 'Allow soil to dry slightly between waterings; avoid overwatering.', 'Full direct sun', '16°C - 25°C', 'Toxic to dogs & cats (gastrointestinal upset)', 'Light, well-drained sandy loam'),
    'Oregano (Origanum vulgare)': ('Robust Mediterranean culinary herb with pungent earthy flavor for pizza and pasta.', 22, 42, 6, 'Let soil dry out between waterings; extremely drought tolerant.', 'Full sun', '15°C - 26°C', 'Toxic to dogs & cats (essential oils)', 'Gritty, moderately fertile, fast-draining soil'),
    'Pandan (Pandanus amaryllifolius)': ('Beloved Southeast Asian fragrant culinary plant with upright spiral-arranged linear leaves. Prized for its natural sweet vanilla-like aromatic foliage used in baking, teas, and rice dishes.', 32, 60, 3, 'Keep soil consistently damp; enjoys warm humid conditions and generous watering.', 'Bright indirect to filtered sunlight (protect from harsh midday scorch)', '22°C - 32°C', 'Non-toxic / Pet friendly', 'Rich, moisture-retentive organic loamy potting soil'),
    'Peppermint (Mentha piperita)': ('Invigorating high-menthol culinary mint that spreads vigorously in gardens.', 35, 62, 3, 'Keep soil consistently damp; benefits from pot cultivation to contain roots.', 'Full sun to partial shade', '15°C - 24°C', 'Toxic to dogs & cats in large quantities', 'Moist, rich, organic-rich soil'),
    'Purple Coneflower (Echinacea purpurea)': ('Stately perennial with daisy-like purple petals and prominent spiky seed cones.', 24, 46, 6, 'Water during dry spells; very drought tolerant once established.', 'Full direct sun', '16°C - 26°C', 'Non-toxic / Pet friendly', 'Well-draining ordinary garden soil'),
    'Rosemary (Salvia rosmarinus)': ('Resin-rich piney evergreen shrub used extensively in Mediterranean culinary dishes.', 18, 38, 8, 'Allow soil to dry out between waterings; susceptible to root rot in soggy soil.', 'Full direct sun (6-8 hours daily)', '15°C - 27°C', 'Non-toxic / Pet friendly', 'Gritty, poor to medium, sharply draining soil'),
    'Spearmint (Mentha spicata)': ('Sweet, refreshing aromatic mint ideal for mojitos, iced teas, and salads.', 34, 60, 3, 'Water frequently to keep soil moist; best kept in standalone pots.', 'Full sun to partial shade', '15°C - 24°C', 'Toxic to dogs & cats in large quantities', 'Moist, fertile, well-draining garden soil'),
    'Stevia (Stevia rebaudiana)': ('Natural zero-calorie sweetener plant whose leaves are 30x sweeter than sugar.', 28, 52, 4, 'Water regularly when surface dries; sensitive to bone-dry soil.', 'Full sun (6+ hours daily)', '18°C - 28°C', 'Non-toxic / Pet friendly', 'Loamy, organic-rich, well-drained soil'),
    'Sweet Basil (Ocimum basilicum)': ('Beloved annual culinary herb with sweet aromatic tender leaves for pesto and Italian dishes.', 28, 50, 4, 'Water every 3-4 days when topsoil feels dry; avoid splashing water on foliage.', 'Full direct sun (6+ hours)', '18°C - 27°C', 'Non-toxic / Pet friendly', 'Rich, moist, well-draining garden loam'),
}

FRUITS_VEG = {
    'Apple Tree (Malus domestica)': ('Classic orchard fruit tree producing crisp, sweet and tart dessert apples.', 28, 52, 6, 'Deep weekly watering during fruit swell; taper off in winter dormancy.', 'Full direct sun (6-8 hours)', '10°C - 25°C', 'Seeds contain cyanide (toxic to pets); flesh is safe', 'Deep, well-drained loamy garden soil'),
    'Asparagus (Asparagus officinalis)': ('Perennial vegetable harvested for tender early spring edible spears.', 30, 55, 4, 'Provide consistent moisture during the harvest and fern growth stages.', 'Full sun to light shade', '15°C - 26°C', 'Berries are toxic to pets; cooked spears are safe', 'Deep, fertile, sandy-loam with plenty of compost'),
    'Avocado Tree (Persea americana)': ('Subtropical fruit tree prized for buttery nutrient-dense green avocados.', 26, 48, 6, 'Water deeply when top 2-3 inches dry; highly sensitive to waterlogged roots.', 'Full direct sun', '18°C - 30°C', 'Toxic to birds, horses, dogs & cats (persin)', 'Coarse, well-aerated, fast-draining potting loam'),
    'Beetroot (Beta vulgaris)': ('Vibrant root vegetable celebrated for earthy sweet red roots and edible leafy greens.', 30, 54, 3, 'Maintain steady moisture to prevent woody or cracked taproots.', 'Full sun', '15°C - 22°C', 'Non-toxic / Pet friendly in moderate amounts', 'Loose, stone-free, fertile sandy loam'),
    'Bell Pepper (Capsicum annuum)': ('Sweet crisp pepper in vibrant red, yellow, orange and green bell varieties.', 32, 58, 3, 'Water regularly; ensure consistent moisture to prevent blossom-end rot.', 'Full direct sun (6-8 hours daily)', '20°C - 29°C', 'Leaves/stems mildly toxic (solanine); fruit is safe', 'Rich, well-drained garden soil amended with compost'),
    'Blackberry (Rubus fruticosus)': ('Vigorous bramble bearing clusters of juicy, sweet-tart deep black summer berries.', 30, 55, 4, 'Water regularly, especially during bloom and berry set.', 'Full sun to partial shade', '15°C - 25°C', 'Non-toxic / Pet friendly (thorns may scratch)', 'Moist, fertile, acidic well-draining soil'),
    'Blueberry (Vaccinium corymbosum)': ('Acid-loving deciduous shrub yielding antioxidant-rich plump indigo berries.', 35, 62, 3, 'Keep soil consistently damp; requires acidic rainwater or ericaceous irrigation.', 'Full direct sun (6+ hours)', '15°C - 25°C', 'Non-toxic / Pet friendly', 'Acidic (pH 4.5-5.5) peat and pine bark ericaceous mix'),
    'Broccoli (Brassica oleracea var. italica)': ('Cool-season brassica bearing dense emerald florets packed with vitamins.', 32, 58, 3, 'Water steadily to avoid heat stress and premature head bolting.', 'Full sun (6+ hours)', '15°C - 20°C', 'Non-toxic / Pet friendly (excess causes gas)', 'Rich, moisture-retentive, fertile garden loam'),
    'Cabbage (Brassica oleracea var. capitata)': ('Hardy vegetable producing tightly packed leafy green or red heads.', 32, 56, 3, 'Consistent irrigation prevents heads from splitting and cracking.', 'Full sun to partial shade', '15°C - 20°C', 'Non-toxic / Pet friendly (in moderation)', 'Heavy, fertile, moisture-retentive garden soil'),
    'Cantaloupe (Cucumis melo)': ('Sprawling warm-season vine producing aromatic, sweet orange-fleshed muskmelons.', 32, 58, 3, 'Water generously until fruit ripens, then reduce to concentrate sweetness.', 'Full direct sun (8+ hours)', '22°C - 32°C', 'Non-toxic / Pet friendly (remove rinds)', 'Warm, fertile, well-drained sandy loam'),
    'Carrot (Daucus carota)': ('Crisp sweet orange root crop that thrives in deep stone-free soil.', 28, 52, 4, 'Keep soil evenly damp until germination; avoid dry-and-drench cycles.', 'Full sun to light shade', '15°C - 22°C', 'Non-toxic / Pet friendly (crunchy healthy treat)', 'Deep, loose, rock-free sandy loam'),
    'Celery (Apium graveolens)': ('Moisture-loving vegetable prized for crisp, crunchy, ribbed stalks.', 38, 68, 2, 'Never let soil dry out; needs constant high moisture to prevent stringy bitterness.', 'Full sun to partial shade', '15°C - 22°C', 'Non-toxic / Pet friendly', 'Rich, muck or humus-heavy moisture-rich soil'),
    'Chili Pepper (Capsicum frutescens)': ('Spicy hot pepper producing fiery pods packed with metabolism-boosting capsaicin.', 28, 52, 4, 'Allow top inch to dry between waterings; slight stress enhances capsaicin heat.', 'Full direct sun', '20°C - 32°C', 'Capsaicin irritates pet eyes and stomach; keep away', 'Warm, well-drained loamy garden soil'),
    'Cucumber (Cucumis sativus)': ('Fast-growing vining vegetable producing crisp, refreshing, hydrating green cucumbers.', 34, 60, 3, 'Water deeply and regularly; uneven moisture leads to bitter fruit.', 'Full direct sun (6-8 hours)', '20°C - 29°C', 'Non-toxic / Pet friendly', 'Warm, fertile, well-draining composted soil'),
    'Eggplant (Solanum melongena)': ('Warm-weather crop with glossy deep purple fruits loved in Mediterranean cooking.', 32, 56, 3, 'Water steadily to sustain continuous flower blossom and fruit production.', 'Full direct sun (6+ hours)', '21°C - 30°C', 'Leaves and stems toxic (solanine); fruit is safe', 'Rich, well-draining soil with abundant organic matter'),
    'Fig Tree (Ficus carica)': ('Ancient fruit tree bearing luscious honey-sweet figs with unique crunchy seeds.', 24, 46, 6, 'Water moderately; drought-hardy once established, but fruits need moisture.', 'Full direct sun (8 hours daily)', '18°C - 30°C', 'Sap mildly irritates pet skin; fruit safe in moderation', 'Well-draining, moderately fertile garden loam'),
    'Garden Pea (Pisum sativum)': ('Cool-season legume bearing sweet crunchy pods that fix nitrogen in garden soil.', 30, 54, 3, 'Keep soil evenly moist especially during blossom and pod fill.', 'Full sun to partial shade', '13°C - 20°C', 'Non-toxic / Pet friendly (do not confuse with sweet pea)', 'Loose, well-drained fertile loam'),
    'Garlic (Allium sativum)': ('Pungent underground bulb consisting of aromatic cloves essential in world cuisine.', 26, 48, 5, 'Water during spring foliage growth; cease watering when leaves turn yellow.', 'Full direct sun', '15°C - 24°C', 'Toxic to dogs and cats (thiosulfate in allium genus)', 'Loose, rich, fertile well-draining garden soil'),
    'Ginger (Zingiber officinale)': ('Tropical reed-like perennial cultivated for fragrant spicy culinary rhizomes.', 35, 62, 3, 'Keep soil continuously damp and warm; mist foliage in dry indoor air.', 'Filtered shade to dappled morning sun', '22°C - 30°C', 'Non-toxic / Pet friendly in small quantities', 'Loose, rich, moisture-retaining organic compost'),
    'Grapevine (Vitis vinifera)': ('Vigorous climbing woody vine producing table grapes, raisins, and fine wine berries.', 24, 46, 7, 'Deep watering every 1-2 weeks; roots penetrate deep into soil substrate.', 'Full direct sun (7-8 hours)', '18°C - 30°C', 'Grapes are highly toxic to dogs and cats', 'Deep, rocky, gravelly well-draining soil'),
    'Green Bean (Phaseolus vulgaris)': ('Fast-producing garden legume bearing crisp, tender green snap pods.', 30, 55, 3, 'Water regularly; keep soil damp while flowering to prevent blossom drop.', 'Full direct sun (6+ hours)', '18°C - 27°C', 'Raw beans contain lectins; cooked pods safe for pets', 'Warm, well-drained loamy soil with neutral pH'),
    'Kale (Brassica oleracea var. sabellica)': ('Hardy superfood brassica with crinkled antioxidant-rich dark green leaves.', 30, 54, 4, 'Consistent moisture keeps kale leaves tender, sweet, and succulent.', 'Full sun to partial shade', '13°C - 21°C', 'Non-toxic / Pet friendly (small amounts)', 'Rich, well-drained soil with plenty of compost'),
    'Lemon Tree (Citrus limon)': ('Citrus tree producing fragrant white blossoms and juicy tart yellow lemons.', 26, 50, 6, 'Water deeply when top 2 inches dry out; do not let root ball stay waterlogged.', 'Full direct sun (8 hours daily)', '18°C - 29°C', 'Toxic to cats & dogs (psoralens and essential oils)', 'Well-draining citrus and palm potting soil'),
    'Lettuce (Lactuca sativa)': ('Crisp leafy salad staple that matures quickly in cool temperate gardens.', 34, 60, 2, 'Shallow roots require frequent, light watering to avoid wilting.', 'Full sun to partial afternoon shade', '12°C - 20°C', 'Non-toxic / Pet friendly', 'Loose, fertile, moisture-retentive garden soil'),
    'Lime Tree (Citrus aurantiifolia)': ('Evergreen citrus bearing fragrant blossoms and zesty acidic green limes.', 26, 50, 6, 'Water when top 2 inches dry; maintain steady humidity around pot.', 'Full direct sun (8+ hours)', '18°C - 30°C', 'Toxic to pets (citrus essential oils)', 'Slightly acidic fast-draining gritty loam'),
    'Olive Tree (Olea europaea)': ('Iconic Mediterranean evergreen tree with silvery foliage and savory olives.', 18, 38, 10, 'Allow soil to dry out deeply between waterings; extremely drought tolerant.', 'Full direct sun (6-8 hours daily)', '15°C - 28°C', 'Non-toxic / Pet friendly', 'Gritty, lean, sharply draining sandy soil'),
    'Onion (Allium cepa)': ('Culinary bulb forming concentric sweet or pungent layers below ground.', 28, 50, 4, 'Water regularly during bulb enlargement; cease watering when foliage falls.', 'Full direct sun (6+ hours)', '15°C - 24°C', 'Toxic to dogs and cats (allium thiosulfate)', 'Loose, rich, crumbly well-draining garden soil'),
    'Orange Tree (Citrus sinensis)': ('Sweet orange citrus tree bearing fragrant blossoms and juicy citrus spheres.', 26, 50, 6, 'Water thoroughly when top 2 inches dry out; ensure container drains freely.', 'Full direct sun (8 hours daily)', '18°C - 30°C', 'Toxic to cats and dogs (citrus oils & psoralens)', 'Well-draining citrus and palm sandy mix'),
    'Peach Tree (Prunus persica)': ('Deciduous stone-fruit tree bearing luscious velvety sweet summer peaches.', 26, 48, 6, 'Water regularly during fruit formation; reduce before harvest.', 'Full direct sun', '15°C - 28°C', 'Pits contain amygdalin (toxic to pets); flesh is safe', 'Deep, fertile, sandy-loam with excellent drainage'),
    'Potato (Solanum tuberosum)': ('Starchy underground tuber providing one of the world\'s core staple foods.', 30, 54, 4, 'Keep soil consistently moist; hill up soil to keep tubers covered from light.', 'Full sun', '15°C - 22°C', 'Green parts & raw eyes toxic (solanine); cooked safe', 'Deep, loose, well-drained acidic sandy soil'),
    'Pumpkin (Cucurbita maxima)': ('Vigorous vining winter squash famous for jack-o-lanterns and pumpkin pie.', 32, 58, 3, 'Water deeply at base; large leaves transpire immense amounts of water.', 'Full direct sun (6-8 hours)', '18°C - 30°C', 'Flesh and seeds non-toxic / safe for pets', 'Warm, heavily composted, fertile loamy soil'),
    'Radish (Raphanus sativus)': ('Fast-growing crunchy peppery root ready for harvest in under 30 days.', 32, 56, 3, 'Water regularly; drought causes woody, hollow, and overly pungent roots.', 'Full sun to partial shade', '13°C - 20°C', 'Non-toxic / Pet friendly', 'Loose, stone-free, well-drained garden soil'),
    'Raspberry (Rubus idaeus)': ('Perennial cane fruit yielding delicate, sweet, hollow-cored red summer berries.', 32, 58, 4, 'Keep root zone evenly moist; mulch heavily with organic woodchips.', 'Full sun to partial afternoon shade', '15°C - 24°C', 'Foliage and berries non-toxic / Pet friendly', 'Moist, fertile, acidic (pH 6.0) well-drained loam'),
    'Spinach (Spinacia oleracea)': ('Cool-season leafy green packed with iron, folate, and essential vitamins.', 32, 58, 3, 'Water frequently; dry soil triggers bolting and bitter taste.', 'Full sun to partial shade', '10°C - 18°C', 'High oxalates; safe in very small amounts for pets', 'Rich, moist, nitrogen-fertilized garden soil'),
    'Strawberry (Fragaria ananassa)': ('Perennial trailing groundcover producing sweet, fragrant, succulent red berries.', 32, 58, 3, 'Water when top inch dries; keep strawberries elevated away from wet dirt.', 'Full direct sun (6-8 hours)', '15°C - 26°C', 'Non-toxic / Pet friendly', 'Rich, well-drained sandy loam amended with compost'),
    'Sweet Corn (Zea mays)': ('Towering grass crop producing golden sweet cobs enclosed in protective husks.', 34, 60, 3, 'Provide heavy water during silking and ear development.', 'Full direct sun (8 hours daily)', '18°C - 32°C', 'Cobs are intestinal choking hazard; kernels safe', 'Deep, fertile, nitrogen-rich well-drained soil'),
    'Sweet Potato (Ipomoea batatas)': ('Warm-season sprawling vine producing nutritious sweet orange-fleshed tubers.', 28, 52, 4, 'Water steadily throughout summer; taper off 2 weeks prior to harvest.', 'Full direct sun', '20°C - 30°C', 'Tubers non-toxic; raw skins should be peeled for pets', 'Loose, well-drained, sandy loam with compost'),
    'Tomato (Solanum lycopersicum)': ('Most popular home garden crop bearing juicy, umami-rich red culinary fruits.', 32, 58, 3, 'Water deeply and consistently at soil level to prevent blossom end rot.', 'Full direct sun (6-8 hours)', '18°C - 28°C', 'Green leaves & unripened fruit toxic (solanine)', 'Deep, rich, loamy garden soil with compost'),
    'Watermelon (Citrullus lanatus)': ('Sun-loving sprawling annual vine bearing giant sweet hydrating summer fruits.', 32, 58, 3, 'Heavy water during vine and fruit development; reduce as sugar sets.', 'Full direct sun (8+ hours daily)', '22°C - 32°C', 'Flesh safe for pets; seeds/rinds cause blockages', 'Warm, sandy, nutrient-rich well-draining soil'),
    'Zucchini (Cucurbita pepo)': ('Prolific summer squash producing tender, versatile green cylindrical fruits.', 32, 58, 3, 'Deep watering 2-3 times per week; avoid wetting broad leaves directly.', 'Full direct sun (6+ hours)', '18°C - 28°C', 'Non-toxic / Pet friendly', 'Rich, moisture-retentive, fertile organic loam'),
}

TREES_PALMS = {
    'Areca Palm (Dypsis lutescens)': ('Feather palm featuring clustering golden-green arching graceful fronds.', 24, 46, 7, 'Water when top 1-2 inches feel dry; sensitive to fluoride and minerals.', 'Bright indirect filtered light', '18°C - 26°C', 'Non-toxic / Pet friendly', 'Peat-based palm potting mix with perlite'),
    'Common Boxwood (Buxus sempervirens)': ('Dense evergreen hedge shrub ideal for formal topiaries and landscape borders.', 22, 44, 7, 'Water weekly during establishment; drought hardy once roots mature.', 'Full sun to partial shade', '15°C - 25°C', 'Toxic to cats and dogs (alkaloids)', 'Well-draining, neutral to alkaline garden soil'),
    'Dwarf Umbrella Tree (Heptapleurum arboricola)': ('Compact indoor tree with palmately compound glossy emerald leaflets.', 24, 48, 7, 'Allow top inch to dry between waterings; avoid overwatering.', 'Bright indirect light', '16°C - 26°C', 'Toxic to pets (calcium oxalate crystals)', 'Aerated, well-draining potting soil'),
    'English Holly (Ilex aquifolium)': ('Traditional holiday evergreen tree with spiny glossy leaves and scarlet berries.', 24, 46, 8, 'Water regularly during dry spells; hardy once established.', 'Full sun to partial shade', '12°C - 22°C', 'Berries and leaves toxic to pets (saponins)', 'Moist, well-draining, slightly acidic soil'),
    'English Yew (Taxus baccata)': ('Ancient slow-growing conifer with dark green needle-like foliage and red arils.', 20, 42, 9, 'Drought tolerant; avoid waterlogged or poorly draining ground.', 'Full sun to full shade', '10°C - 22°C', 'Highly toxic to pets and humans (taxine alkaloids)', 'Well-drained chalky, sandy, or loamy soil'),
    'European Privet (Ligustrum vulgare)': ('Fast-growing dense deciduous to semi-evergreen shrub used for privacy screens.', 22, 44, 7, 'Water moderately; thrives in diverse conditions once established.', 'Full sun to partial shade', '12°C - 25°C', 'Berries and leaves toxic to pets', 'Adaptable to almost all well-drained soils'),
    'Ficus Audrey (Ficus benghalensis)': ('National tree of India featuring velvety oval foliage and pale architectural bark.', 24, 46, 7, 'Water when top 2-3 inches are dry; less finicky than fiddle leaf figs.', 'Bright indirect to partial direct sun', '18°C - 27°C', 'Toxic to cats and dogs (ficus latex)', 'Chunky, well-draining indoor aroid mix'),
    'Fiddle Leaf Fig (Ficus lyrata)': ('Showstopping houseplant with giant violin-shaped sculptural leaves.', 25, 48, 7, 'Water when top 2 inches dry; sensitive to drafts and location changes.', 'Bright filtered indirect light', '18°C - 27°C', 'Toxic to cats and dogs (calcium oxalates)', 'Rich, well-draining peat and bark soil'),
    'Fishtail Palm (Caryota mitis)': ('Unique tropical palm with jagged leaflets resembling swimming fish tails.', 28, 52, 6, 'Keep soil consistently damp; benefits from warm ambient humidity.', 'Bright indirect sunlight', '18°C - 27°C', 'Non-toxic fronds (fruit contains irritant oxalates)', 'Rich, moisture-retentive palm potting mix'),
    'Japanese Maple (Acer palmatum)': ('Prized ornamental tree renowned for delicate palmate leaves and fiery autumn colors.', 26, 48, 6, 'Keep root zone evenly moist; mulch to shield delicate roots from heat.', 'Dappled sunlight to morning sun', '15°C - 24°C', 'Non-toxic to cats & dogs (horses sensitive to wilted)', 'Moist, fertile, well-drained acidic to neutral soil'),
    'Kentia Palm (Howea forsteriana)': ('Elegant, durable palm featuring slender trunks and arching dark green fronds.', 22, 44, 8, 'Water when top 2 inches dry; remarkably tolerant of low light.', 'Low to bright indirect light', '16°C - 24°C', 'Non-toxic / Pet friendly', 'Fast-draining palm potting mix'),
    'Majesty Palm (Ravenea rivularis)': ('Regal feather palm native to wet riverbanks of Madagascar.', 32, 58, 4, 'Keep soil moist at all times; requires abundant water and light.', 'Bright direct to indirect sunlight', '18°C - 27°C', 'Non-toxic / Pet friendly', 'Rich, moisture-holding potting mix with peat'),
    'Money Tree (Pachira aquatica)': ('Prosperity plant featuring a braided woody trunk and vibrant palm-like leaves.', 24, 48, 7, 'Water when top 2-3 inches dry; avoid standing water in saucer.', 'Medium to bright indirect light', '16°C - 26°C', 'Non-toxic / Pet friendly', 'Peat-based potting mix with plenty of perlite'),
    'Parlor Palm (Chamaedorea elegans)': ('Victorian favorite compact palm that thrives in dim, low-humidity indoor spaces.', 22, 45, 8, 'Water when top inch of soil dries; forgiving of occasional dry spells.', 'Low to medium indirect light', '16°C - 24°C', 'Non-toxic / Pet friendly', 'Standard well-draining potting soil'),
    'Ponytail Palm (Beaucarnea recurvata)': ('Unique succulent tree with bulbous swollen water-storing caudex and curly leaves.', 14, 30, 14, 'Water every 2-3 weeks; stores copious water inside swollen trunk.', 'Bright indirect to full direct sun', '15°C - 28°C', 'Non-toxic / Pet friendly', 'Gritty cactus and succulent fast-draining blend'),
    'Rubber Plant (Ficus elastica)': ('Robust indoor tree with thick glossy burgundy or dark green leathery leaves.', 24, 46, 7, 'Water when top 2 inches dry out; wipe foliage with damp cloth to remove dust.', 'Medium to bright indirect light', '16°C - 27°C', 'Toxic to cats and dogs (latex sap)', 'Well-aerated potting mix with perlite and pine bark'),
    'Sago Palm (Cycas revoluta)': ('Living fossil cycad forming symmetrical rosette of stiff glossy feather foliage.', 16, 34, 12, 'Allow top half of soil to dry out completely before watering.', 'Bright indirect to direct sunlight', '16°C - 28°C', 'Extremely toxic to all pets (cycasin)', 'Fast-draining gritty sandy potting soil'),
    'Schefflera': ('Sturdy tropical tree with circular umbrella-shaped dark glossy leaf clusters.', 24, 48, 7, 'Water thoroughly when top inch dries; trim growing tips to promote bushiness.', 'Bright indirect sunlight', '16°C - 26°C', 'Toxic to cats and dogs (calcium oxalate)', 'Well-draining potting mix with peat moss'),
    'Weeping Fig (Ficus benjamina)': ('Graceful indoor tree with slender arching branches and glossy pointed leaves.', 24, 46, 7, 'Water when top inch dries; maintain consistent light and temperature.', 'Bright indirect light', '18°C - 26°C', 'Toxic to pets (ficus sap)', 'Rich, well-draining loamy potting mix'),
}

FLOWERS = {
    'Black-Eyed Susan (Rudbeckia hirta)': ('Cheerful native wildflower with golden petals surrounding dark chocolate domes.', 25, 48, 6, 'Water during dry spells; highly drought tolerant once settled.', 'Full direct sun (6+ hours)', '16°C - 28°C', 'Non-toxic / Pet friendly', 'Well-draining average garden soil'),
    'Bleeding Heart (Lamprocapnos spectabilis)': ('Woodland perennial with arching stems dangling delicate heart-shaped pink blooms.', 32, 58, 4, 'Keep soil consistently moist; prefers cool shade in hot summers.', 'Partial shade to full shade', '12°C - 20°C', 'Toxic to pets and humans (isoquinoline alkaloids)', 'Rich, humusy, moisture-retentive soil'),
    'Butterfly Bush (Buddleja davidii)': ('Vigorous shrub bearing honey-scented cone spikes that magnetize butterflies.', 24, 46, 6, 'Water regularly during first season; very drought-tolerant later.', 'Full direct sun', '16°C - 27°C', 'Non-toxic / Pet friendly', 'Average, well-drained garden soil'),
    'Calla Lily (Zantedeschia aethiopica)': ('Stately trumpet-shaped white spathes rising above glossy arrow-shaped foliage.', 32, 58, 4, 'Keep soil damp while actively growing; reduce water in winter rest.', 'Bright indirect to gentle direct sun', '16°C - 24°C', 'Toxic to cats and dogs (insoluble calcium oxalates)', 'Rich, moist, organic-rich potting soil'),
    'Cape Leadwort (Plumbago auriculata)': ('Scrambling evergreen shrub with pale phlox-like sky-blue floral clusters.', 24, 48, 6, 'Water when top inch dries; drought tolerant once established.', 'Full direct sun to light shade', '16°C - 28°C', 'Mildly toxic to pets (sap may irritate skin)', 'Well-draining, slightly acidic soil'),
    'Chinese Hibiscus (Hibiscus rosa-sinensis)': ('Tropical beauty with oversized showy blossoms in crimson, yellow, and coral.', 30, 56, 4, 'Water regularly during flowering; never allow root ball to bake dry.', 'Full sun to bright indirect light', '18°C - 28°C', 'Non-toxic / Pet friendly', 'Rich, well-drained, slightly acidic potting mix'),
    'Chinese Peony (Paeonia lactiflora)': ('Beloved garden perennial bearing massive fragrant ruffled romantic blooms.', 28, 52, 5, 'Water deeply once weekly during spring; drought tolerant once root crown matures.', 'Full direct sun (6 hours daily)', '15°C - 24°C', 'Toxic to pets in large amounts (paeonol)', 'Deep, fertile, moisture-retentive well-drained loam'),
    'Chinese Wisteria (Wisteria sinensis)': ('Spectacular woody vine dripping with cascades of fragrant lavender pea-blossoms.', 25, 48, 6, 'Water during drought; requires sturdy arbor or pergola support.', 'Full direct sun', '15°C - 26°C', 'Seeds and pods toxic to pets (wisterin)', 'Moist, fertile, well-drained garden soil'),
    'Chrysanthemum': ('Autumn hallmark bearing dense spherical masses of rich colorful petals.', 28, 52, 4, 'Keep soil evenly damp; water at base to protect dense blooms.', 'Full sun (6 hours daily)', '15°C - 22°C', 'Toxic to cats and dogs (pyrethrins)', 'Rich, well-draining loamy potting soil'),
    'Clematis (Clematis)': ('Queen of climbers producing profuse star-like blossoms in vibrant jewel tones.', 28, 52, 4, 'Roots in cool shade, blooms in sun; keep root zone mulched and moist.', 'Full sun for foliage, shaded roots', '15°C - 24°C', 'Toxic to dogs and cats (anemonin)', 'Cool, moist, fertile well-draining soil'),
    'Common Columbine (Aquilegia vulgaris)': ('Charming woodland flower with unique spurred petals nodding in spring breezes.', 26, 50, 5, 'Water regularly during dry spells; loves cool moist roots.', 'Partial shade to full sun', '13°C - 22°C', 'Mildly toxic to pets if ingested in quantity', 'Rich, moist, well-drained garden soil'),
    'Common Foxglove (Digitalis purpurea)': ('Tall majestic woodland biennial bearing towering spires of spotted bell flowers.', 28, 52, 4, 'Keep soil moderately moist throughout growth and flowering.', 'Partial shade to full sun', '13°C - 22°C', 'Extremely toxic to humans & pets (cardiac glycosides)', 'Rich, moist, acidic to neutral soil'),
    'Common Gardenia (Gardenia jasminoides)': ('Creamy white intoxicatingly fragrant blossoms framed by deep glossy foliage.', 30, 56, 4, 'Keep soil consistently damp; requires acidic watering and high humidity.', 'Bright indirect light or gentle morning sun', '18°C - 24°C', 'Toxic to cats and dogs (geniposides)', 'Acidic (pH 5.0-6.0), organic, well-drained soil'),
    'Common Hollyhock (Alcea rosea)': ('Cottage garden classic bearing towering 8-foot floral stalks of saucer-like blooms.', 26, 48, 5, 'Water at ground level to discourage rust fungus on large lower leaves.', 'Full direct sun', '15°C - 26°C', 'Non-toxic / Pet friendly', 'Rich, moist, well-drained garden loam'),
    'Common Lilac (Syringa vulgaris)': ('Hardy spring shrub intoxicating gardens with clouds of intensely sweet lavender blooms.', 22, 44, 7, 'Water during summer drought; prefers cold winter chill to set blooms.', 'Full direct sun (6+ hours)', '12°C - 24°C', 'Non-toxic / Pet friendly', 'Neutral to slightly alkaline well-drained soil'),
    'Common Morning Glory (Ipomoea purpurea)': ('Fast-growing annual twining vine with brilliant funnel blossoms opening at sunrise.', 28, 52, 4, 'Water regularly; drought tolerant once established.', 'Full direct sun', '18°C - 28°C', 'Seeds contain lysergic alkaloids (toxic to pets)', 'Average, well-drained ordinary garden soil'),
    'Common Sunflower (Helianthus annuus)': ('Towering cheerful giant with golden rays tracking the sun across the sky.', 30, 55, 4, 'Water deeply at base; sturdy taproot seeks moisture deep underground.', 'Full direct sun (7-8 hours daily)', '18°C - 30°C', 'Non-toxic / Pet friendly', 'Deep, fertile, well-drained soil'),
    'Common Zinnia (Zinnia elegans)': ('Vibrant easy-to-grow annual producing colorful daisy blossoms until first frost.', 26, 48, 4, 'Water ground level in early morning; keep leaves dry to prevent mildew.', 'Full direct sun', '18°C - 29°C', 'Non-toxic / Pet friendly', 'Rich, warm, well-drained garden soil'),
    'Daffodils (Narcissus spp.)': ('Iconic bright yellow herald of spring featuring trumpet centers and reflexed petals.', 24, 46, 6, 'Water in spring; allow foliage to die back naturally to recharge bulb.', 'Full sun to partial spring shade', '10°C - 20°C', 'Toxic to cats and dogs (lycorine alkaloids in bulbs)', 'Well-draining, fertile garden soil'),
    'French Hydrangea (Hydrangea macrophylla)': ('Classic ornamental shrub with giant mophead blooms that shift pink or blue by soil pH.', 35, 62, 3, 'Provide copious moisture; leaves quickly flag and wilt in dry conditions.', 'Morning sun and afternoon dappled shade', '16°C - 24°C', 'Toxic to pets (cyanogenic glycosides)', 'Rich, moist, organic-rich well-drained soil'),
    'French Marigold (Tagetes patula)': ('Compact bedding annual with fiery orange/yellow ruffled petals that repel garden pests.', 26, 48, 4, 'Allow soil to dry slightly between waterings; avoid soggy roots.', 'Full direct sun', '18°C - 28°C', 'Mildly toxic to pets (sap irritates skin/mouth)', 'Average, well-drained garden soil'),
    'Garden Cosmos (Cosmos bipinnatus)': ('Graceful cottage annual with feathery lace foliage and pastel saucer-like flowers.', 22, 44, 5, 'Drought hardy; thrives in poor soil where rich fertilizers cause leggy leaves.', 'Full direct sun', '18°C - 28°C', 'Non-toxic / Pet friendly', 'Poor to average, well-drained sandy soil'),
    'Garden Dahlia (Dahlia pinnata)': ('Show-stopping tuberous floral royalty with complex geometric layers of velvety petals.', 30, 55, 3, 'Water regularly once sprouts emerge; deep irrigation during flowering.', 'Full direct sun (6-8 hours daily)', '16°C - 26°C', 'Toxic to dogs and cats (skin/digestive upset)', 'Rich, fertile, moisture-retentive well-drained soil'),
    'Garden Geranium (Pelargonium)': ('Stalwart container flower with aromatic foliage and clusters of bright vibrant blooms.', 22, 45, 6, 'Allow top inch to dry between waterings; avoid overwatering.', 'Full direct sun to partial afternoon shade', '16°C - 25°C', 'Toxic to cats and dogs (geraniol and linalool)', 'Well-draining potting soil with perlite'),
    'Garden Pansy (Viola tricolor)': ('Charming cool-weather flower featuring expressive velvety faces in multi-colors.', 30, 54, 3, 'Keep soil consistently damp; thrives in crisp spring and autumn air.', 'Full sun to partial afternoon shade', '10°C - 18°C', 'Non-toxic / Pet friendly in small amounts', 'Rich, fertile, moist well-drained potting mix'),
    'Garden Petunia (Petunia hybrida)': ('Prolific trumpet bloomer blanketing hanging baskets in nonstop colorful floral flushes.', 28, 52, 4, 'Water regularly; container petunias need daily watering during heatwaves.', 'Full direct sun (6+ hours)', '16°C - 26°C', 'Non-toxic / Pet friendly', 'Fertile, well-draining potting compost'),
    'Garden Phlox (Phlox paniculata)': ('Sweetly fragrant summer perennial bearing dense domes of pastel pink and purple blooms.', 28, 52, 4, 'Water at base; ensure good air movement to ward off powdery mildew.', 'Full direct sun to light shade', '15°C - 24°C', 'Non-toxic / Pet friendly', 'Rich, moist, well-drained garden soil'),
    'Garden Rose (Rosa)': ('The timeless queen of flowers celebrated for romantic fragrance and exquisite layers.', 28, 52, 4, 'Deep soaking at the roots weekly; keep foliage dry to ward off blackspot.', 'Full direct sun (6+ hours daily)', '15°C - 26°C', 'Non-toxic to pets (sharp thorns may scratch)', 'Rich, fertile, well-drained loamy soil with compost'),
    'Garden Verbena (Verbena hybrida)': ('Trailing heat-tolerant flowering plant producing dense vibrant clusters of starry blossoms.', 24, 46, 5, 'Water when topsoil feels dry; handles summer heat with ease.', 'Full direct sun (8 hours daily)', '18°C - 29°C', 'Non-toxic / Pet friendly', 'Average, well-drained garden soil'),
    'Great Bougainvillea (Bougainvillea spectabilis)': ('Vigorous woody climber bursting with cascades of papery, neon magenta floral bracts.', 18, 38, 8, 'Water deeply then let soil dry out; slight drought stress triggers heavier blooms.', 'Full direct sun (6+ hours)', '18°C - 32°C', 'Mildly toxic sap (thorns present puncture risk)', 'Sharply draining, gritty sandy potting mix'),
    'Hyacinth (Hyacinthus orientalis)': ('Spring bulb filling the air with intense, sweet perfume from tightly packed bell clusters.', 24, 46, 6, 'Keep soil moderately damp while flowering; allow bulb to dry during summer rest.', 'Full sun to bright indirect light', '10°C - 18°C', 'Toxic to cats & dogs (calcium oxalate in bulbs)', 'Loose, well-drained sandy garden soil'),
    'Indian Shot (Canna indica)': ('Tropical dramatic perennial with broad bronze or emerald foliage and fire-colored blooms.', 34, 62, 3, 'Loves plenty of water and heat; keep soil consistently wet and fertile.', 'Full direct sun', '20°C - 32°C', 'Non-toxic / Pet friendly', 'Rich, boggy to moist humus-packed garden soil'),
    'Japanese Camellia (Camellia japonica)': ('Aristocratic winter-to-spring evergreen shrub bearing flawless rose-like blossoms.', 26, 48, 6, 'Water consistently with acidic rainwater; never allow roots to desiccate.', 'Dappled morning light or partial shade', '15°C - 22°C', 'Non-toxic / Pet friendly', 'Acidic (pH 5.0-6.0), moist, humus-rich soil'),
    'Japanese Honeysuckle (Lonicera japonica)': ('Fragrant trailing vine whose creamy flowers fill evening breezes with sweet nectar.', 24, 48, 6, 'Water during dry spells; extremely vigorous climber.', 'Full sun to partial shade', '15°C - 26°C', 'Berries mildly toxic to dogs & cats', 'Adaptable to almost all well-drained soils'),
    'Japanese Spiraea (Spiraea japonica)': ('Hardy flowering shrub smothered in fuzzy domes of candy-pink floral heads.', 24, 46, 6, 'Water weekly during hot spells; low maintenance and forgiving.', 'Full direct sun', '15°C - 25°C', 'Non-toxic / Pet friendly', 'Moist, well-drained average garden loam'),
    'Lantana (Lantana camara)': ('Pollinator magnet with clusters of flowers that magically shift colors as they mature.', 20, 42, 7, 'Water when soil is dry; thrives in scorching sun and heat.', 'Full direct sun', '18°C - 32°C', 'Toxic to cats, dogs & livestock (triterpenoids)', 'Well-draining, poor to average garden soil'),
    'Lilium (Hemerocallis)': ('Daylily producing showy trumpet flowers that open fresh each morning.', 26, 50, 5, 'Water regularly during flower bud set; tolerant of drought once established.', 'Full sun to partial shade', '15°C - 25°C', 'TRUE LILIES DEADLY TO CATS; keep away from felines', 'Moist, fertile, well-drained soil'),
    'Lily of the valley (Convallaria majalis)': ('Woodland perennial with dangling pure-white fragrant bells nodding above green leaves.', 32, 58, 4, 'Keep soil moist and cool; thrives as a woodland groundcover in shade.', 'Partial shade to full shade', '12°C - 20°C', 'Extremely toxic to pets & humans (cardiac glycosides)', 'Rich, moist, humus-rich woodland soil'),
    'Old Fashioned Weigela (Weigela florida)': ('Flowering deciduous shrub bearing arching branches smothered in pink trumpet flowers.', 24, 46, 6, 'Water regularly in first year; tolerates dry spells once rooted.', 'Full direct sun', '15°C - 24°C', 'Non-toxic / Pet friendly', 'Moist, fertile, well-drained garden soil'),
    'Oleander (Nerium oleander)': ('Mediterranean shrub bearing clusters of pink or white flowers; extremely drought hardy.', 18, 38, 9, 'Allow soil to dry between waterings; extremely drought and salt tolerant.', 'Full direct sun', '18°C - 32°C', 'Extremely toxic to all animals & humans (oleandrin)', 'Adaptable, well-draining sandy or rocky soil'),
    'Orchid': ('Exotic tropical epiphyte producing long-lasting sculptured architectural blooms.', 20, 42, 7, 'Soak orchid bark thoroughly once weekly; drain all excess water completely.', 'Bright filtered indirect light', '18°C - 27°C', 'Non-toxic / Pet friendly', 'Pure coarse orchid pine bark with sphagnum moss'),
    'Peace lily': ('Elegant tropical houseplant with glossy dark foliage and white spathe flags.', 35, 60, 4, 'Water when topsoil feels slightly dry; droops gently to signal need for water.', 'Low to moderate indirect light', '18°C - 26°C', 'Toxic to cats & dogs (calcium oxalate crystals)', 'Moist, well-draining peat-based potting soil'),
    'Rose of Sharon (Hibiscus syriacus)': ('Hardy shrub flowering late in summer with large saucer blossoms and prominent stamens.', 26, 48, 6, 'Water during hot dry spells; hardy and low-maintenance once rooted.', 'Full direct sun', '16°C - 28°C', 'Non-toxic / Pet friendly', 'Moist, well-drained, organically rich loam'),
    'Shasta Daisy (Leucanthemum x superbum)': ('Classic perennial daisy with radiant pure-white ray petals and cheerful gold button center.', 26, 48, 5, 'Water weekly during summer; avoid waterlogged roots in winter.', 'Full direct sun', '15°C - 24°C', 'Non-toxic / Pet friendly', 'Fertile, moist, well-drained garden soil'),
    'Snapdragon (Antirrhinum majus)': ('Playful cool-weather flower whose blossoms snap open like dragon jaws when gently squeezed.', 28, 52, 4, 'Keep soil consistently damp; deadhead spent spikes for continuous blooms.', 'Full direct sun', '12°C - 21°C', 'Non-toxic / Pet friendly', 'Rich, well-draining garden soil with compost'),
    'Star Jasmine (Trachelospermum jasminoides)': ('Evergreen climbing vine smothered in clusters of heavenly scented white pinwheel blooms.', 24, 46, 6, 'Water when top 2 inches dry; drought hardy once established on trellises.', 'Full sun to partial shade', '15°C - 26°C', 'Non-toxic / Pet friendly', 'Rich, moist, well-drained loamy soil'),
    'Sweet Alyssum (Lobularia maritima)': ('Delicate honey-scented groundcover forming dense frothy carpets of tiny white blooms.', 26, 48, 4, 'Water when soil surface dries; shear back after flowering for rebloom.', 'Full sun to partial shade', '12°C - 22°C', 'Non-toxic / Pet friendly', 'Average, well-drained sandy loam'),
    'Sweet Pea (Lathyrus odoratus)': ('Vintage cottage garden annual vine prized for intoxicatingly sweet floral perfume.', 30, 54, 3, 'Keep root zone cool and moist; pick blooms frequently to prolong flowering.', 'Full sun for flowers, shaded root zone', '12°C - 20°C', 'Seeds and pods toxic to pets & humans (lathyrogens)', 'Deep, fertile, moisture-retentive garden soil'),
    'Tulip': ('Legendary spring-flowering bulb coming in virtually every vibrant shade and form.', 24, 46, 6, 'Keep moist during spring growth; allow bulb to dry out during summer dormancy.', 'Full direct sun to partial light shade', '10°C - 18°C', 'Toxic to cats and dogs (tulipalin in bulbs)', 'Sharply draining, sandy or gritty soil'),
    'Weeping Forsythia (Forsythia suspensa)': ('Early spring harbinger exploding in brilliant cascades of bright yellow blossoms.', 24, 46, 7, 'Water during summer dry spells; extremely tough and drought tolerant.', 'Full direct sun (6+ hours)', '12°C - 24°C', 'Non-toxic / Pet friendly', 'Adaptable, loose, well-drained garden soil'),
}

WILD_WEEDS = {
    'Annual Bluegrass (Poa annua)': ('Widespread cool-season annual turf grass that thrives in compacted urban turf.', 22, 44, 7, 'Highly adaptable grass needing minimal specialized water.', 'Full sun to partial shade', '10°C - 24°C', 'Non-toxic / Pet friendly', 'Compact urban turf and garden soil'),
    'Barnyard Grass (Echinochloa crus-galli)': ('Robust warm-season annual grass commonly found in moist agricultural fields.', 24, 48, 6, 'Thrives in damp soil and sunny flood-prone ditches.', 'Full direct sun', '15°C - 30°C', 'Non-toxic / Pet friendly', 'Moist, heavy agricultural soil'),
    'Bermuda Grass (Cynodon dactylon)': ('Aggressive warm-season lawn grass with deep creeping rhizomes and stolons.', 20, 40, 8, 'Extremely drought tolerant; turns brown in winter and greens in heat.', 'Full direct sun', '18°C - 35°C', 'Non-toxic / Pet friendly (may cause mild skin itching)', 'Sandy, clay, or loamy soil'),
    'Bittersweet Nightshade (Solanum dulcamara)': ('Climbing woody perennial vine with star purple flowers and glistening red berries.', 25, 48, 6, 'Thrives in moist wasteland and canal banks.', 'Partial shade to full sun', '12°C - 24°C', 'Toxic to pets & humans (solanine alkaloids)', 'Moist, rich, disturbed soil'),
    'Black Medick (Medicago lupulina)': ('Low-trailing clover relative bearing dense spherical heads of tiny yellow flowers.', 22, 42, 7, 'Drought hardy; fixes nitrogen into degraded soil.', 'Full direct sun', '12°C - 26°C', 'Non-toxic / Pet friendly', 'Dry, alkaline, gravelly urban ground'),
    'Black Nightshade (Solanum nigrum)': ('Annual herb bearing white starry blossoms followed by clusters of inky black berries.', 25, 50, 5, 'Grows in disturbed soil and warm gardens.', 'Full sun to partial shade', '15°C - 28°C', 'Unripened green berries toxic to pets (solanine)', 'Fertile, moist, cultivated ground'),
    'Broadleaf Plantain (Plantago major)': ('Tough perennial rosette with wide ribbed leaves and long slender seed spikes.', 22, 44, 7, 'Very resilient to heavy foot traffic and compacted soil.', 'Full sun to partial shade', '10°C - 26°C', 'Non-toxic / Pet friendly (soothing herbal use)', 'Compacted heavy soil and sidewalk cracks'),
    'Bull Thistle (Cirsium vulgare)': ('Prickly biennial thistle with sharp needle-spined foliage and purple flower heads.', 20, 40, 8, 'Deep taproot extracts water from arid subsoil.', 'Full direct sun', '12°C - 28°C', 'Sharp spines cause physical mouth injury to pets', 'Disturbed, dry, well-draining soil'),
    'Canada Thistle (Cirsium arvense)': ('Aggressive perennial weed forming deep extensive horizontal creeping root systems.', 20, 40, 8, 'Spreads tenaciously across roadsides and pastures.', 'Full direct sun', '10°C - 26°C', 'Spiny leaves cause physical irritation', 'Adaptable to almost all soils'),
    'Common Chickweed (Stellaria media)': ('Cool-season edible ground cover with tender leaves and tiny starry white petals.', 30, 54, 4, 'Prefers damp, cool, shaded soils.', 'Partial shade to full sun in spring', '10°C - 18°C', 'Non-toxic / Pet friendly (contains saponins)', 'Moist, fertile, loose garden soil'),
    'Common Dandelion (Taraxacum officinale)': ('Ubiquitous golden wildflower with deeply notched leaves and fluffy seed globes.', 22, 44, 6, 'Deep taproot absorbs nutrients; leaves and roots are edible.', 'Full sun to light shade', '10°C - 26°C', 'Non-toxic / Pet friendly (nutritious green)', 'Adaptable to all soil conditions'),
    'Common Lambsquarters (Chenopodium album)': ('Fast-growing edible wild green with goosefoot leaves covered in whitish meal.', 24, 46, 6, 'Highly resilient; leaves can be steamed like spinach.', 'Full direct sun', '12°C - 28°C', 'Contains oxalates; safe in small amounts', 'Disturbed, nutrient-rich agricultural ground'),
    'Common Mallow (Malva neglecta)': ('Sprawling weed with scalloped round leaves and tiny pale pink cheese-wheel fruits.', 22, 44, 7, 'Deep taproot allows high drought survival in lawns.', 'Full sun to partial shade', '12°C - 26°C', 'Non-toxic / Pet friendly', 'Disturbed dry soil and garden beds'),
    'Common Purslane (Portulaca oleracea)': ('Succulent prostrate wild herb with reddish stems and fleshy tart omega-rich leaves.', 16, 32, 10, 'Extremely drought tolerant; stores water in thick fleshy stems.', 'Full direct sun', '18°C - 32°C', 'Toxic to cats & dogs (soluble calcium oxalates)', 'Sandy, gravelly, hot poor soils'),
    'Common Ragweed (Ambrosia artemisiifolia)': ('Prolific annual producing feathery leaves and copious windblown allergenic pollen.', 22, 44, 7, 'Grows rapidly in vacant lots and roadsides.', 'Full direct sun', '15°C - 30°C', 'Pollen is a potent allergen; non-toxic ingestion', 'Dry, disturbed, gravelly soil'),
    'Creeping Charlie (Glechoma hederacea)': ('Aromatic creeping ground ivy with scalloped leaves and tubular violet flowers.', 28, 52, 4, 'Spreads aggressively in damp shaded lawns and borders.', 'Partial shade to full shade', '12°C - 22°C', 'Toxic to horses and pets in high quantities', 'Damp, fertile, shaded lawn soil'),
    'Field Bindweed (Convolvulus arvensis)': ('Deep-rooted perennial vine with twisting stems and pink-tinged trumpet flowers.', 20, 42, 8, 'Roots penetrate up to 20 feet deep into arid soil.', 'Full direct sun', '12°C - 28°C', 'Mildly toxic to pets (tropane alkaloids)', 'Dry, cultivated, agricultural ground'),
    'Giant Hogweed (Heracleum mantegazzianum)': ('Invasive massive biennial with towering white umbels up to 15 feet high.', 30, 56, 4, 'Sap causes severe phytophotodermatitis burns when exposed to sunlight.', 'Full sun to partial shade', '10°C - 22°C', 'EXTREMELY DANGEROUS TO PETS & HUMANS (phototoxic sap)', 'Moist riverbanks and disturbed roadsides'),
    'Goosegrass (Eleusine indica)': ('Tough warm-season annual grass with prostrate white-centered radiating clumps.', 20, 40, 8, 'Extremely resistant to foot traffic and mower blades.', 'Full direct sun', '18°C - 32°C', 'Non-toxic / Pet friendly', 'Compacted, heavy, dry turf soils'),
    'Green Foxtail (Setaria viridis)': ('Annual grassy weed producing upright bristly green seed spikes like fox tails.', 22, 44, 7, 'Spreads freely in grain crops and open waste ground.', 'Full direct sun', '15°C - 30°C', 'Seed awns can lodge into pet ears/paws', 'Loose, fertile, agricultural ground'),
    'Hairy Crabgrass (Digitaria sanguinalis)': ('Sprawling warm-season grass with hairy purplish stems and finger-like spikes.', 20, 40, 8, 'Emerges in summer bare spots; highly drought adapted.', 'Full direct sun', '18°C - 35°C', 'Non-toxic / Pet friendly', 'Dry, sandy, disturbed lawn soil'),
    'Henbit Deadnettle (Lamium amplexicaule)': ('Early spring weed with scalloped clasping leaves and tubular magenta flowers.', 26, 48, 5, 'Blooms in cool early spring; harmless non-stinging deadnettle.', 'Full sun to partial shade', '10°C - 20°C', 'Non-toxic / Pet friendly', 'Moist, fertile, loose garden soil'),
    'Japanese Knotweed (Reynoutria japonica)': ('Invasive bamboo-like perennial with hollow reddish stems and creamy tassels.', 26, 50, 6, 'Aggressive roots can damage pavement and foundations.', 'Full sun to partial shade', '12°C - 26°C', 'Young shoots edible; non-toxic to pets', 'Moist, disturbed, riverbank soil'),
    'Lesser Burdock (Arctium minus)': ('Stout biennial with giant rhubarb-like leaves and hooked burs that stick to fur.', 24, 46, 6, 'Roots used in herbal medicine; burs inspired invention of Velcro.', 'Full sun to partial shade', '12°C - 24°C', 'Burs cause hair tangling and mouth irritation', 'Rich, moist, disturbed ground'),
    'Narrowleaf Plantain (Plantago lanceolata)': ('Rosette perennial with ribbed lance-shaped leaves and dense brownish flower spikes.', 22, 44, 7, 'Hardy weed that survives heavy drought and compaction.', 'Full sun to light shade', '10°C - 26°C', 'Non-toxic / Pet friendly', 'Dry, compact, poor urban soils'),
    'Pacific Poison Oak (Toxicodendron diversilobum)': ('Deciduous woody shrub with glossy 3-lobed leaves turning vivid red in autumn.', 22, 44, 7, 'Contains urushiol; causes severe blistering allergic contact dermatitis.', 'Full sun to deep shade', '12°C - 26°C', 'Urushiol transfers on pet fur; toxic to humans', 'Adaptable, rocky, hillside ground'),
    'Poison Ivy (Toxicodendron radicans)': ('Trailing or climbing vine with characteristic three leaflets containing urushiol.', 22, 44, 7, 'Produces urushiol oil that causes intense itchy blistering rashes.', 'Full sun to full shade', '12°C - 26°C', 'Urushiol coats pet fur; toxic to humans', 'Woodlands, thickets, and disturbed borders'),
    'Prickly Lettuce (Lactuca serriola)': ('Wild lettuce relative with prickly spines along the lower leaf midrib.', 20, 42, 8, 'Exudes milky bitter latex when stems are broken.', 'Full direct sun', '12°C - 28°C', 'Mildly toxic in high amounts (lactucarium)', 'Dry, poor, disturbed urban ground'),
    'Prostrate Knotweed (Polygonum aviculare)': ('Wiry mat-forming annual weed growing in sidewalk cracks and trampled paths.', 20, 40, 8, 'Extreme resistance to wear and heavy soil compaction.', 'Full sun to light shade', '10°C - 26°C', 'Non-toxic / Pet friendly', 'Compacted gravel, packed dirt paths'),
    'Purple Deadnettle (Lamium purpureum)': ('Winter annual with fuzzy square stems and purple-tinted hooded floral clusters.', 26, 48, 5, 'Early pollinator food; non-stinging despite the nettle name.', 'Full sun to partial shade', '10°C - 20°C', 'Non-toxic / Pet friendly', 'Moist, fertile, loose garden soil'),
    'Red Clover (Trifolium pratense)': ('Beneficial forage legume with three-part leaves and fragrant reddish-purple globes.', 26, 48, 5, 'Enriches soil with atmospheric nitrogen; edible sweet blossoms.', 'Full direct sun', '12°C - 24°C', 'Contains phytoestrogens; safe in moderation', 'Moist, fertile, loamy soil'),
    'Shepherds Purse (Capsella bursa-pastoris)': ('Slender annual weed bearing flat triangular heart-shaped seed pouches.', 24, 46, 6, 'Name derives from seed pods resembling leather purses.', 'Full sun to partial shade', '10°C - 22°C', 'Non-toxic / Pet friendly', 'Disturbed garden soil and cultivated plots'),
    'Stinging Nettle (Urtica dioica)': ('Perennial herb with stinging hairs that inject histamine causing acute stinging.', 30, 55, 4, 'Nutritious edible green once cooked or dried into tea.', 'Full sun to partial shade', '12°C - 24°C', 'Stings pet paws/snouts; cooked greens non-toxic', 'Moist, rich, nitrogen-heavy woodland soil'),
    'White Clover (Trifolium repens)': ('Creeping perennial lawn groundcover bearing sweet-scented white ball blossoms.', 26, 48, 5, 'Popular pollinator-friendly eco-lawn alternative fixing nitrogen.', 'Full sun to partial shade', '12°C - 24°C', 'Non-toxic / Pet friendly (healthy forage)', 'Moist, fertile, well-drained lawn soil'),
    'Yellow Woodsorrel (Oxalis stricta)': ('Delicate clover-like perennial with heart leaflets and bright yellow flowers.', 26, 48, 5, 'Contains tart oxalic acid giving leaves a pleasant sour flavor.', 'Full sun to partial shade', '12°C - 24°C', 'Toxic to pets in large amounts (soluble oxalates)', 'Moist, fertile, cultivated ground'),
}

def parse_name(raw):
    m = re.match(r'^(.*?)\s*\((.*?)\)$', raw)
    if m:
        return m.group(1).strip(), m.group(2).strip()
    special = {
        'Aloe Vera': ('Aloe Vera', 'Aloe barbadensis'),
        'Calathea': ('Calathea', 'Calathea spp.'),
        'Chrysanthemum': ('Chrysanthemum', 'Chrysanthemum morifolium'),
        'Ctenanthe': ('Ctenanthe', 'Ctenanthe spp.'),
        'Dracaena': ('Dracaena', 'Dracaena spp.'),
        'Kalanchoe': ('Kalanchoe', 'Kalanchoe blossfeldiana'),
        'Orchid': ('Orchid', 'Orchidaceae'),
        'Peace lily': ('Peace Lily', 'Spathiphyllum wallisii'),
        'Schefflera': ('Schefflera', 'Schefflera arboricola'),
        'Tradescantia': ('Tradescantia', 'Tradescantia zebrina'),
        'Tulip': ('Tulip', 'Tulipa gesneriana'),
        'Venus Flytrap': ('Venus Flytrap', 'Dionaea muscipula'),
        'Yucca': ('Yucca', 'Yucca elephantipes'),
    }
    if raw in special:
        return special[raw]
    return raw, raw

def get_houseplant_care(raw, common, sci):
    c_low = common.lower()
    s_low = sci.lower()

    if 'alocasia' in c_low or 'alocasia' in s_low or 'elephant ear' in c_low:
        return ('Houseplants & Tropicals', 'Dramatic tropical statement plant featuring architectural arrowhead leaves with prominent veining.', 30, 55, 6, 'Keep soil evenly moist; never let dry out completely or sit in water.', 'Bright indirect light', '18°C - 27°C', 'Toxic to cats and dogs (calcium oxalate)', 'Chunky, airy aroid mix with bark and perlite')
    if 'begonia' in c_low:
        return ('Houseplants & Tropicals', 'Stunning foliage plant with asymmetric leaves and intricate colorful spots and patterns.', 28, 52, 5, 'Water when top inch dries; keep water off fuzzy leaves.', 'Medium to bright indirect light', '18°C - 24°C', 'Toxic to pets (calcium oxalate crystals in tubers)', 'Light, porous peat and perlite potting mix')
    if 'calathea' in c_low or 'ctenanthe' in c_low or 'maranta' in c_low or 'prayer' in c_low or 'stromanthe' in c_low or 'rattlesnake' in c_low:
        return ('Houseplants & Tropicals', 'Fascinating prayer plant with striking patterned leaves that fold upward at night.', 32, 58, 4, 'Keep soil consistently damp using filtered or distilled water.', 'Medium filtered indirect light', '18°C - 26°C', 'Non-toxic / Pet friendly', 'Moist, well-draining peat-rich potting mix')
    if 'monstera' in c_low or 'swiss cheese' in c_low:
        return ('Houseplants & Tropicals', 'Iconic tropical plant with architectural fenestrated foliage.', 28, 52, 6, 'Water when top 2 inches dry out; provide moss pole for climbing.', 'Bright indirect sunlight', '18°C - 27°C', 'Toxic to pets (calcium oxalate crystals)', 'Chunky, well-aerated aroid potting mix')
    if 'philodendron' in c_low:
        return ('Houseplants & Tropicals', 'Lush, adaptable tropical foliage plant with elegant heart-shaped or variegated leaves.', 26, 50, 6, 'Water when top inch of soil feels dry to the touch.', 'Medium to bright indirect light', '18°C - 27°C', 'Toxic to pets (insoluble calcium oxalates)', 'Loose, well-draining peat and perlite mix')
    if 'pothos' in c_low:
        return ('Houseplants & Tropicals', 'Virtually unkillable trailing vine with variegated heart-shaped leaves.', 24, 48, 7, 'Allow top half of soil to dry between waterings.', 'Low light to bright indirect light', '16°C - 27°C', 'Toxic to pets (calcium oxalate crystals)', 'Standard well-draining houseplant potting mix')
    if 'peperomia' in c_low:
        return ('Houseplants & Tropicals', 'Compact semi-succulent houseplant with unique textured ornamental leaves.', 22, 45, 8, 'Water when top 2 inches dry out; stores water in fleshy stems.', 'Medium to bright indirect light', '18°C - 26°C', 'Non-toxic / Pet friendly', 'Well-draining coarse potting mix with perlite')
    if 'pilea' in c_low or 'chinese money' in c_low:
        return ('Houseplants & Tropicals', 'Charming companion plant with coin-shaped circular foliage on slender petioles.', 24, 48, 7, 'Water when top 1-2 inches dry out; rotate pot for symmetrical growth.', 'Bright indirect sunlight', '16°C - 24°C', 'Non-toxic / Pet friendly', 'Well-draining rich potting soil with perlite')
    if 'anthurium' in c_low or 'flamingo' in c_low:
        return ('Houseplants & Tropicals', 'Exotic tropical plant known for glossy heart-shaped leaves and vivid spathes.', 30, 56, 5, 'Keep soil lightly moist; mist for high ambient humidity.', 'Bright indirect light', '18°C - 27°C', 'Toxic to cats and dogs (calcium oxalates)', 'Chunky orchid bark, peat moss, and perlite mix')
    if 'ficus' in c_low:
        return ('Houseplants & Tropicals', 'Architectural tree with deep emerald glossy leaves.', 24, 46, 7, 'Water when top 2 inches dry out; sensitive to moving or drafts.', 'Bright indirect light', '18°C - 27°C', 'Toxic to pets (latex sap)', 'Rich, well-draining potting soil')
    if 'dracaena' in c_low or 'corn plant' in c_low:
        return ('Houseplants & Tropicals', 'Statuesque indoor plant with strap-like foliage that purifies indoor air.', 22, 45, 9, 'Water when top 50% of soil dries out; sensitive to tap fluoride.', 'Low to bright indirect light', '18°C - 26°C', 'Toxic to cats and dogs (saponins)', 'Well-draining houseplant potting mix')
    if 'aglaonema' in c_low or 'chinese evergreen' in c_low:
        return ('Houseplants & Tropicals', 'Ultra-hardy foliage plant with silver, green, or pink variegated broad leaves.', 24, 48, 8, 'Allow soil to dry halfway between waterings; tolerates low light.', 'Low light to moderate indirect light', '18°C - 26°C', 'Toxic to pets (calcium oxalate crystals)', 'Moist, well-draining houseplant potting mix')
    if 'dieffenbachia' in c_low or 'dumb cane' in c_low:
        return ('Houseplants & Tropicals', 'Tropical foliage classic displaying broad leaves variegated in cream and green.', 26, 50, 6, 'Water when top 2 inches dry; maintain consistent warm temperature.', 'Medium to bright indirect light', '18°C - 26°C', 'Toxic to pets & humans (calcium oxalate crystals)', 'Rich, well-draining peat-based potting soil')
    if 'tradescantia' in c_low or 'spiderwort' in c_low or 'moses' in c_low:
        return ('Houseplants & Tropicals', 'Fast-growing trailing vine featuring purple, silver, and green striped foliage.', 24, 48, 6, 'Water when top inch dries; pinch stem tips to maintain dense bushy vines.', 'Bright indirect light (maintains color)', '16°C - 26°C', 'Mildly toxic to pets (skin irritation)', 'Standard well-draining houseplant potting mix')
    if 'zz plant' in c_low or 'zamioculcas' in s_low:
        return ('Houseplants & Tropicals', 'Glossy feather-like leaflets that thrive on neglect and store water in rhizomes.', 16, 32, 14, 'Water every 2-3 weeks; handles low light and drought with ease.', 'Low light to bright indirect light', '16°C - 27°C', 'Toxic to cats and dogs (calcium oxalate)', 'Fast-draining potting soil with perlite')
    if 'air plant' in c_low or 'tillandsia' in s_low:
        return ('Houseplants & Tropicals', 'Fascinating rootless epiphyte absorbing water and nutrients through leaf trichomes.', 20, 40, 7, 'Submerge in filtered water for 20 minutes once weekly; shake dry.', 'Bright indirect filtered light', '16°C - 27°C', 'Non-toxic / Pet friendly', 'No soil needed; display on driftwood or wire')
    if 'bromeliad' in c_low or 'guzmania' in s_low:
        return ('Houseplants & Tropicals', 'Tropical rosette with vivid long-lasting colorful central flowering bracts.', 26, 50, 7, 'Keep central leaf cup filled with rainwater; water soil sparingly.', 'Bright indirect light', '18°C - 27°C', 'Non-toxic / Pet friendly', 'Epiphytic orchid bark and peat mix')
    if 'cast iron' in c_low or 'aspidistra' in s_low:
        return ('Houseplants & Tropicals', 'Virtually indestructible deep green foliage plant tolerant of low light and neglect.', 20, 42, 10, 'Water when top 2 inches dry; thrives in dimly lit indoor spaces.', 'Low light to deep shade', '15°C - 24°C', 'Non-toxic / Pet friendly', 'Standard all-purpose potting soil')
    if 'coleus' in c_low:
        return ('Houseplants & Tropicals', 'Kaleidoscope foliage plant with dazzling combinations of crimson, lime, and magenta.', 30, 55, 4, 'Keep soil consistently moist; pinch flowers to focus energy on foliage.', 'Bright indirect light or gentle morning sun', '18°C - 26°C', 'Toxic to cats & dogs (essential oils)', 'Rich, moist, well-drained potting mix')
    if 'croton' in c_low:
        return ('Houseplants & Tropicals', 'Bold tropical shrub sporting thick glossy leaves splashed with yellow, orange, and red.', 28, 52, 5, 'Keep soil evenly moist; requires high light to retain vivid colors.', 'Bright direct sunlight (4+ hours daily)', '18°C - 27°C', 'Toxic to cats and dogs (terpenoid diterpenes)', 'Rich, moist, well-draining potting soil')
    if 'english ivy' in c_low or 'hedera' in s_low:
        return ('Houseplants & Tropicals', 'Classic vigorous evergreen climber featuring lobed foliage for baskets and walls.', 24, 46, 6, 'Water when top inch dries; mist leaves to deter spider mites.', 'Medium to bright indirect light', '15°C - 22°C', 'Toxic to pets (triterpenoid saponins)', 'Moist, well-drained potting soil')
    if 'fittonia' in c_low or 'nerve' in c_low:
        return ('Houseplants & Tropicals', 'Compact terrarium favorite with exquisite network of bright pink or white veins.', 34, 60, 3, 'Never let soil dry out; faints dramatically when thirsty.', 'Medium indirect light to partial shade', '18°C - 26°C', 'Non-toxic / Pet friendly', 'Moist, peat-based potting soil with perlite')
    if 'hypoestes' in c_low or 'polka dot' in c_low:
        return ('Houseplants & Tropicals', 'Colorful accent plant with leaves delightfully splattered in pink, white, or red spots.', 30, 54, 4, 'Water when top inch dries; pinch stems to encourage dense bushy growth.', 'Bright indirect sunlight', '18°C - 24°C', 'Non-toxic / Pet friendly', 'Rich, well-draining organic potting soil')
    if 'pitcher' in c_low or 'nepenthes' in s_low or 'venus flytrap' in c_low or 'sundew' in c_low or 'drosera' in s_low:
        return ('Houseplants & Tropicals', 'Fascinating carnivorous plant that traps insects in specialized pitfall pitchers or snap traps.', 38, 70, 3, 'Keep continuously wet with distilled or reverse-osmosis water only.', 'Bright indirect to partial direct sun', '18°C - 28°C', 'Non-toxic / Pet friendly', 'Mineral-free pure sphagnum moss and perlite')
    if 'poinsettia' in c_low or 'euphorbia' in s_low:
        return ('Houseplants & Tropicals', 'Holiday traditional plant showcasing velvety crimson floral bracts.', 24, 46, 6, 'Water when top 2 inches dry out; do not leave pot sitting in excess water.', 'Bright indirect light', '18°C - 24°C', 'Mildly toxic to pets (milky latex sap causes irritation)', 'Well-draining, peat-based potting soil')
    if 'syngonium' in c_low or 'arrowhead' in c_low:
        return ('Houseplants & Tropicals', 'Fast-growing climbing aroid displaying arrow-shaped leaves in shades of pink and green.', 26, 50, 6, 'Water when top inch dries; thrives on moss totems or trailing in hanging pots.', 'Medium to bright indirect light', '16°C - 26°C', 'Toxic to cats and dogs (calcium oxalate)', 'Aerated, well-draining peat and perlite mix')
    if 'ti plant' in c_low or 'cordyline' in s_low:
        return ('Houseplants & Tropicals', 'Tropical palm-like evergreen featuring striking broad sword leaves flushed with magenta.', 26, 50, 6, 'Keep soil evenly damp; sensitive to fluoride and dry indoor air.', 'Bright indirect sunlight', '18°C - 27°C', 'Toxic to pets (saponins)', 'Rich, well-draining potting soil')

    return ('Houseplants & Tropicals', 'Curated botanical specimen with ornamental foliage and steady indoor care needs.', 25, 48, 7, 'Water when top 1-2 inches feel dry to the touch.', 'Bright indirect sunlight', '18°C - 25°C', 'Consult pet safety guidelines for exotic flora', 'Balanced, well-draining indoor potting soil')

images = ['assets/images/image_1.png', 'assets/images/image_2.png', 'assets/images/image_3.png', 'assets/images/img_main.png']

species_entries = []

for idx, raw in enumerate(raw_classes):
    c_id = f'flora_{idx+1:03d}'
    common, sci = parse_name(raw)
    img = images[idx % len(images)]

    if raw in FERNS:
        cat = 'Ferns'
        desc, low, high, days, rec, sun, temp, tox, soil = FERNS[raw]
    elif raw in SUCCULENTS:
        cat = 'Succulents & Cacti'
        desc, low, high, days, rec, sun, temp, tox, soil = SUCCULENTS[raw]
    elif raw in HERBS:
        cat = 'Herbs & Aromatics'
        desc, low, high, days, rec, sun, temp, tox, soil = HERBS[raw]
    elif raw in FRUITS_VEG:
        cat = 'Fruits & Vegetables'
        desc, low, high, days, rec, sun, temp, tox, soil = FRUITS_VEG[raw]
    elif raw in TREES_PALMS:
        cat = 'Trees & Palms'
        desc, low, high, days, rec, sun, temp, tox, soil = TREES_PALMS[raw]
    elif raw in FLOWERS:
        cat = 'Flowers & Ornamentals'
        desc, low, high, days, rec, sun, temp, tox, soil = FLOWERS[raw]
    elif raw in WILD_WEEDS:
        cat = 'Wild & Urban Flora'
        desc, low, high, days, rec, sun, temp, tox, soil = WILD_WEEDS[raw]
    else:
        cat, desc, low, high, days, rec, sun, temp, tox, soil = get_houseplant_care(raw, common, sci)

    species_entries.append({
        'id': c_id,
        'commonName': common,
        'scientificName': sci,
        'rawName': raw,
        'category': cat,
        'description': desc,
        'imageUrl': img,
        'lowMoistureThreshold': low,
        'highMoistureThreshold': high,
        'wateringIntervalDays': days,
        'wateringRecommendation': rec,
        'sunlight': sun,
        'idealTemperature': temp,
        'petToxicity': tox,
        'soilType': soil,
    })

print(f'Total compiled: {len(species_entries)}')

# Generate Dart file
dart_code = '''import 'package:urbangreen/models/plant_model.dart';
import 'package:urbangreen/models/plant_species_profile_model.dart';

/// Single curated botanical species in the FloraNet-250 Encyclopedia.
class FloraSpecies {
  final String id;
  final String commonName;
  final String scientificName;
  final String rawName;
  final String category;
  final String description;
  final String imageUrl;
  final int lowMoistureThreshold;
  final int highMoistureThreshold;
  final int wateringIntervalDays;
  final String wateringRecommendation;
  final String sunlight;
  final String idealTemperature;
  final String petToxicity;
  final String soilType;

  const FloraSpecies({
    required this.id,
    required this.commonName,
    required this.scientificName,
    required this.rawName,
    required this.category,
    required this.description,
    required this.imageUrl,
    required this.lowMoistureThreshold,
    required this.highMoistureThreshold,
    required this.wateringIntervalDays,
    required this.wateringRecommendation,
    required this.sunlight,
    required this.idealTemperature,
    required this.petToxicity,
    required this.soilType,
  });

  /// Converts this encyclopedia entry to a standard Garden [Plant].
  Plant toPlant({String? customName, String? iotDeviceId}) {
    return Plant(
      id: id,
      name: customName ?? commonName,
      species: '$commonName ($scientificName)',
      imageUrl: imageUrl,
      description: description,
      iotDeviceId: iotDeviceId,
      wateringIntervalDays: wateringIntervalDays,
      sunlight: sunlight,
      wateringRecommendation: wateringRecommendation,
      idealTemperature: idealTemperature,
      petToxicity: petToxicity,
      soilType: soilType,
      careNotes: 'Target soil moisture: $lowMoistureThreshold% - $highMoistureThreshold%. $wateringRecommendation',
    );
  }

  /// Converts this encyclopedia entry into an IoT Telemetry [PlantSpeciesProfile].
  PlantSpeciesProfile toProfile() {
    return PlantSpeciesProfile(
      speciesName: '$commonName ($scientificName)',
      category: category,
      lowMoistureThreshold: lowMoistureThreshold,
      highMoistureThreshold: highMoistureThreshold,
      recommendedCycle: wateringRecommendation,
      sunlight: sunlight,
      careSummary: description,
    );
  }
}

/// Official FloraNet-250 Botanical Encyclopedia Repository.
/// Contains all 250 verified plant species recognized by the AI vision system.
class Flora250Data {
  static const List<String> categories = [
    'All (250)',
    'Houseplants & Tropicals',
    'Flowers & Ornamentals',
    'Fruits & Vegetables',
    'Wild & Urban Flora',
    'Herbs & Aromatics',
    'Trees & Palms',
    'Succulents & Cacti',
    'Ferns',
  ];

  static final List<FloraSpecies> speciesList = [
'''

def escape_dart_str(s):
    return s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$')

for e in species_entries:
    dart_code += f'''    const FloraSpecies(
      id: '{e["id"]}',
      commonName: '{escape_dart_str(e["commonName"])}',
      scientificName: '{escape_dart_str(e["scientificName"])}',
      rawName: '{escape_dart_str(e["rawName"])}',
      category: '{escape_dart_str(e["category"])}',
      description: '{escape_dart_str(e["description"])}',
      imageUrl: '{e["imageUrl"]}',
      lowMoistureThreshold: {e["lowMoistureThreshold"]},
      highMoistureThreshold: {e["highMoistureThreshold"]},
      wateringIntervalDays: {e["wateringIntervalDays"]},
      wateringRecommendation: '{escape_dart_str(e["wateringRecommendation"])}',
      sunlight: '{escape_dart_str(e["sunlight"])}',
      idealTemperature: '{escape_dart_str(e["idealTemperature"])}',
      petToxicity: '{escape_dart_str(e["petToxicity"])}',
      soilType: '{escape_dart_str(e["soilType"])}',
    ),
'''

dart_code += '''  ];

  /// Fast ID lookup
  static FloraSpecies? findById(String id) {
    try {
      return speciesList.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Fuzzy query matcher for common or scientific name
  static FloraSpecies? findByNameOrSpecies(String? query) {
    if (query == null || query.trim().isEmpty) return null;
    final q = query.toLowerCase().trim();
    for (final s in speciesList) {
      if (s.rawName.toLowerCase() == q ||
          s.commonName.toLowerCase() == q ||
          s.scientificName.toLowerCase() == q ||
          s.rawName.toLowerCase().contains(q) ||
          q.contains(s.commonName.toLowerCase())) {
        return s;
      }
    }
    return null;
  }
}
'''

with open(r'c:\Users\user\Desktop\FYP\AppIntegration\Plant-App-Flutter-UI\lib\data\flora_250_data.dart', 'w', encoding='utf-8') as f:
    f.write(dart_code)

print('Wrote lib/data/flora_250_data.dart successfully!')
