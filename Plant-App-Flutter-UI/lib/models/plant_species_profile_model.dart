import 'package:urbangreen/data/flora_250_data.dart';

/// Model representing botanical care profiles for plant species.
/// Used to auto-tailor IoT moisture thresholds and watering parameters.
class PlantSpeciesProfile {
  final String speciesName;
  final String category;
  final int lowMoistureThreshold;  // % that triggers pump
  final int highMoistureThreshold; // % that stops pump
  final String recommendedCycle;
  final String sunlight;
  final String careSummary;

  const PlantSpeciesProfile({
    required this.speciesName,
    required this.category,
    required this.lowMoistureThreshold,
    required this.highMoistureThreshold,
    required this.recommendedCycle,
    required this.sunlight,
    required this.careSummary,
  });

  /// Comprehensive botanical species dictionary
  static final Map<String, PlantSpeciesProfile> profiles = {
    // 1. Succulents & Cacti (Drought-tolerant, prone to root rot)
    'Sansevieria trifasciata': const PlantSpeciesProfile(
      speciesName: 'Snake Plant (Sansevieria)',
      category: 'Succulent',
      lowMoistureThreshold: 15,
      highMoistureThreshold: 30,
      recommendedCycle: 'Allow soil to dry out deeply between cycles (10-14 days)',
      sunlight: 'Low to bright indirect light',
      careSummary: 'Tolerates low moisture; excess water causes root rot.',
    ),
    'Aloe barbadensis': const PlantSpeciesProfile(
      speciesName: 'Aloe Vera',
      category: 'Succulent',
      lowMoistureThreshold: 15,
      highMoistureThreshold: 35,
      recommendedCycle: 'Deep soaking every 2-3 weeks',
      sunlight: 'Bright direct to indirect sunlight',
      careSummary: 'Requires well-draining soil and dry intervals.',
    ),
    'Cactus': const PlantSpeciesProfile(
      speciesName: 'Desert Cactus',
      category: 'Succulent',
      lowMoistureThreshold: 12,
      highMoistureThreshold: 28,
      recommendedCycle: 'Monthly watering or when fully parched',
      sunlight: 'Full direct sunlight',
      careSummary: 'Very low water requirements; extreme drought adapted.',
    ),

    // 2. Moisture Loving & Tropical (High humidity & damp soil)
    'Monstera deliciosa': const PlantSpeciesProfile(
      speciesName: 'Monstera Deliciosa (Swiss Cheese Plant)',
      category: 'Tropical',
      lowMoistureThreshold: 30,
      highMoistureThreshold: 55,
      recommendedCycle: 'Keep soil evenly moist, water every 5-7 days',
      sunlight: 'Medium to bright indirect light',
      careSummary: 'Loves consistent mild dampness without waterlogging.',
    ),
    'Spathiphyllum': const PlantSpeciesProfile(
      speciesName: 'Peace Lily',
      category: 'Tropical',
      lowMoistureThreshold: 35,
      highMoistureThreshold: 60,
      recommendedCycle: 'Water as soon as topsoil begins drying (every 4-5 days)',
      sunlight: 'Low to medium indirect light',
      careSummary: 'Highly sensitive to under-watering; foliage wilts quickly.',
    ),
    'Nephrolepis exaltata': const PlantSpeciesProfile(
      speciesName: 'Boston Fern',
      category: 'Fern',
      lowMoistureThreshold: 40,
      highMoistureThreshold: 65,
      recommendedCycle: 'Maintain continuous moisture, mist frequently',
      sunlight: 'Filtered shade / indirect light',
      careSummary: 'Roots must never dry out completely.',
    ),

    // 3. Culinary Herbs & Vegetables
    'Ocimum basilicum': const PlantSpeciesProfile(
      speciesName: 'Sweet Basil',
      category: 'Herb',
      lowMoistureThreshold: 28,
      highMoistureThreshold: 50,
      recommendedCycle: 'Water every 3-4 days when soil feels dry to touch',
      sunlight: 'Full sun (6+ hours daily)',
      careSummary: 'Fast-growing herb needing regular hydration.',
    ),
    'Solanum lycopersicum': const PlantSpeciesProfile(
      speciesName: 'Tomato Plant',
      category: 'Vegetable',
      lowMoistureThreshold: 32,
      highMoistureThreshold: 58,
      recommendedCycle: 'Consistent deep watering during fruit development',
      sunlight: 'Full direct sun',
      careSummary: 'Irregular watering can cause blossom end rot.',
    ),

    // 4. Common Houseplants (Default balanced)
    'Epipremnum aureum': const PlantSpeciesProfile(
      speciesName: 'Golden Pothos (Devil\'s Ivy)',
      category: 'Houseplant',
      lowMoistureThreshold: 22,
      highMoistureThreshold: 45,
      recommendedCycle: 'Water every 7-10 days',
      sunlight: 'Low to moderate indirect light',
      careSummary: 'Hardy and forgiving; tolerates slight underwatering.',
    ),
  };

  /// Fallback profile for general unrecognized plant species
  static const PlantSpeciesProfile defaultProfile = PlantSpeciesProfile(
    speciesName: 'Standard Botanical Houseplant',
    category: 'General',
    lowMoistureThreshold: 25,
    highMoistureThreshold: 45,
    recommendedCycle: 'Water weekly when top 2 inches dry out',
    sunlight: 'Moderate indirect light',
    careSummary: 'Balanced threshold calibration suitable for most indoor potted plants.',
  );

  /// Resolves matching profile by fuzzy species matching
  static PlantSpeciesProfile resolveForSpecies(String? speciesOrName) {
    if (speciesOrName == null || speciesOrName.trim().isEmpty) {
      return defaultProfile;
    }

    // 1. First check verified FloraNet-250 Encyclopedia
    final flora = Flora250Data.findByNameOrSpecies(speciesOrName);
    if (flora != null) {
      return flora.toProfile();
    }

    // 2. Check internal profile cache
    final query = speciesOrName.toLowerCase();
    for (final entry in profiles.entries) {
      if (entry.key.toLowerCase().contains(query) ||
          entry.value.speciesName.toLowerCase().contains(query) ||
          query.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }

    // Keyword matching fallbacks
    if (query.contains('snake') || query.contains('sansevieria') || query.contains('succulent') || query.contains('cactus') || query.contains('aloe')) {
      return profiles['Sansevieria trifasciata']!;
    }
    if (query.contains('fern')) {
      return profiles['Nephrolepis exaltata']!;
    }
    if (query.contains('lily') || query.contains('peace')) {
      return profiles['Spathiphyllum']!;
    }
    if (query.contains('monstera')) {
      return profiles['Monstera deliciosa']!;
    }
    if (query.contains('herb') || query.contains('basil') || query.contains('mint')) {
      return profiles['Ocimum basilicum']!;
    }
    if (query.contains('tomato')) {
      return profiles['Solanum lycopersicum']!;
    }

    return defaultProfile;
  }
}

