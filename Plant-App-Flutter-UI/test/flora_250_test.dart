import 'package:flutter_test/flutter_test.dart';
import 'package:urbangreen/data/flora_250_data.dart';
import 'package:urbangreen/models/plant_species_profile_model.dart';

void main() {
  group('FloraNet Botanical Encyclopedia Tests', () {
    test('Contains verified plant species including Pandan', () {
      expect(Flora250Data.speciesList.length, equals(251));
      expect(Flora250Data.findByNameOrSpecies('Pandan'), isNotNull);
    });

    test('Every species has complete, non-empty care metadata', () {
      final seenIds = <String>{};
      final seenRawNames = <String>{};

      for (final s in Flora250Data.speciesList) {
        expect(s.id, isNotEmpty);
        expect(seenIds.contains(s.id), isFalse, reason: 'Duplicate ID: ${s.id}');
        seenIds.add(s.id);

        expect(s.commonName, isNotEmpty);
        expect(s.scientificName, isNotEmpty);
        expect(s.rawName, isNotEmpty);
        expect(seenRawNames.contains(s.rawName), isFalse, reason: 'Duplicate species: ${s.rawName}');
        seenRawNames.add(s.rawName);

        expect(s.category, isNotEmpty);
        expect(s.description, isNotEmpty);
        expect(s.imageUrl, isNotEmpty);
        expect(s.lowMoistureThreshold, greaterThan(0));
        expect(s.highMoistureThreshold, greaterThan(s.lowMoistureThreshold));
        expect(s.wateringIntervalDays, greaterThan(0));
        expect(s.wateringRecommendation, isNotEmpty);
        expect(s.sunlight, isNotEmpty);
        expect(s.idealTemperature, isNotEmpty);
        expect(s.petToxicity, isNotEmpty);
        expect(s.soilType, isNotEmpty);
      }
    });

    test('Category distribution is accurate and covers all 251 plants', () {
      final categoryCounts = <String, int>{};
      for (final s in Flora250Data.speciesList) {
        categoryCounts[s.category] = (categoryCounts[s.category] ?? 0) + 1;
      }

      expect(categoryCounts['Ferns'], equals(6));
      expect(categoryCounts['Succulents & Cacti'], equals(16));
      expect(categoryCounts['Herbs & Aromatics'], equals(26)); // + Pandan
      expect(categoryCounts['Fruits & Vegetables'], equals(40));
      expect(categoryCounts['Trees & Palms'], equals(19));
      expect(categoryCounts['Flowers & Ornamentals'], equals(50));
      expect(categoryCounts['Wild & Urban Flora'], equals(35));
      expect(categoryCounts['Houseplants & Tropicals'], equals(59));

      final total = categoryCounts.values.reduce((a, b) => a + b);
      expect(total, equals(251));
    });

    test('toPlant() converts seamlessly with intact care parameters', () {
      final aloe = Flora250Data.findById('flora_005'); // Aloe Vera
      expect(aloe, isNotNull);
      final plant = aloe!.toPlant();

      expect(plant.id, equals('flora_005'));
      expect(plant.name, equals('Aloe Vera'));
      expect(plant.species, contains('Aloe barbadensis'));
      expect(plant.wateringIntervalDays, equals(14));
      expect(plant.sunlight, contains('Full sun'));
    });

    test('PlantSpeciesProfile.resolveForSpecies resolves accurately across classes including Pandan', () {
      final pandanProfile = PlantSpeciesProfile.resolveForSpecies('Pandan (Pandanus amaryllifolius)');
      expect(pandanProfile.speciesName, contains('Pandan'));
      expect(pandanProfile.lowMoistureThreshold, equals(32));
      expect(pandanProfile.highMoistureThreshold, equals(60));

      final tomatoProfile = PlantSpeciesProfile.resolveForSpecies('Tomato (Solanum lycopersicum)');
      expect(tomatoProfile.speciesName, contains('Tomato'));
      expect(tomatoProfile.lowMoistureThreshold, equals(32));
      expect(tomatoProfile.highMoistureThreshold, equals(58));

      final aloeProfile = PlantSpeciesProfile.resolveForSpecies('Aloe Vera');
      expect(aloeProfile.lowMoistureThreshold, equals(15));
      expect(aloeProfile.highMoistureThreshold, equals(35));

      final fernProfile = PlantSpeciesProfile.resolveForSpecies('Boston Fern (Nephrolepis exaltata)');
      expect(fernProfile.lowMoistureThreshold, equals(40));
      expect(fernProfile.highMoistureThreshold, equals(68));
    });

    test('findByNameOrSpecies performs robust case-insensitive lookups', () {
      expect(Flora250Data.findByNameOrSpecies('monstera'), isNotNull);
      expect(Flora250Data.findByNameOrSpecies('Monstera Deliciosa'), isNotNull);
      expect(Flora250Data.findByNameOrSpecies('Ocimum basilicum'), isNotNull);
      expect(Flora250Data.findByNameOrSpecies('Sweet Basil'), isNotNull);
      expect(Flora250Data.findByNameOrSpecies('Unknown Alien Plant XYZ'), isNull);
    });
  });
}
