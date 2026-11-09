import 'package:flutter_test/flutter_test.dart';
import 'package:urbangreen/data/flora_250_data.dart';
import 'package:urbangreen/models/plant_species_profile_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FloraNet-261 Botanical Encyclopedia Completeness', () {
    test('Encyclopedia contains at least 260 curated plant species', () {
      expect(Flora250Data.speciesList.length, greaterThanOrEqualTo(260));
    });

    test('Southeast Asian indigenous species exist in encyclopedia', () {
      final seaSpecies = [
        'Pandan',
        'Curry Leaf',
        'Kaffir Lime',
        'Calamansi',
        'Butterfly Pea',
        'Vietnamese Coriander',
        'Turmeric',
        'Torch Ginger',
        'Betel Leaf',
        'Water Spinach',
        'Bitter Gourd',
      ];

      for (final name in seaSpecies) {
        final match = Flora250Data.findByNameOrSpecies(name);
        expect(match, isNotNull, reason: 'Failed to find SEA species: $name');
      }
    });

    test('Invalid or null queries return null safely without throwing', () {
      expect(Flora250Data.findById('non_existent_id_9999'), isNull);
      expect(Flora250Data.findByNameOrSpecies(null), isNull);
      expect(Flora250Data.findByNameOrSpecies(''), isNull);
      expect(Flora250Data.findByNameOrSpecies('   '), isNull);
      expect(Flora250Data.findByNameOrSpecies('xyz_alien_flora_unknown'), isNull);
    });
  });

  // ==============================================================
  // Individual Test Generation across all 261+ Botanical Species
  // (Validation, Conversion, and Resolution Tests)
  // ==============================================================
  group('FloraNet-261 Species Metadata Validation Matrix', () {
    for (final species in Flora250Data.speciesList) {
      test('Validation [${species.id}]: ${species.commonName} attributes and threshold bounds', () {
        expect(species.id.trim(), isNotEmpty);
        expect(species.commonName.trim(), isNotEmpty);
        expect(species.scientificName.trim(), isNotEmpty);
        expect(species.category.trim(), isNotEmpty);
        expect(species.description.trim(), isNotEmpty);
        expect(species.imageUrl.trim(), isNotEmpty);

        // Physiological moisture bounds
        expect(species.lowMoistureThreshold, greaterThan(0),
            reason: '${species.commonName} low threshold must be positive');
        expect(species.lowMoistureThreshold, lessThan(species.highMoistureThreshold),
            reason: '${species.commonName} low threshold must be less than high threshold');
        expect(species.highMoistureThreshold, lessThanOrEqualTo(100),
            reason: '${species.commonName} high threshold cannot exceed 100%');

        // Agronomic care parameters
        expect(species.wateringIntervalDays, inInclusiveRange(1, 60),
            reason: '${species.commonName} watering interval must be 1-60 days');
        expect(species.wateringRecommendation.trim(), isNotEmpty);
        expect(species.sunlight.trim(), isNotEmpty);
        expect(species.idealTemperature.trim(), isNotEmpty);
        expect(species.petToxicity.trim(), isNotEmpty);
        expect(species.soilType.trim(), isNotEmpty);
      });
    }
  });

  group('FloraNet-261 Species to Plant Conversion Matrix', () {
    for (final species in Flora250Data.speciesList) {
      test('Conversion [${species.id}]: ${species.commonName} converts cleanly to Plant instance', () {
        final defaultPlant = species.toPlant();
        expect(defaultPlant.id, equals(species.id));
        expect(defaultPlant.name, equals(species.commonName));
        expect(defaultPlant.species, contains(species.commonName));
        expect(defaultPlant.wateringIntervalDays, equals(species.wateringIntervalDays));
        expect(defaultPlant.hasIot, isFalse);

        final customPlant = species.toPlant(
          customName: 'Sanctuary ${species.commonName}',
          iotDeviceId: 'probe_sensor_${species.id}',
        );
        expect(customPlant.name, equals('Sanctuary ${species.commonName}'));
        expect(customPlant.iotDeviceId, equals('probe_sensor_${species.id}'));
        expect(customPlant.hasIot, isTrue);
      });
    }
  });

  group('FloraNet-261 Species Search & Profile Resolution Matrix', () {
    for (final species in Flora250Data.speciesList) {
      test('Resolution [${species.id}]: ${species.commonName} is indexed and resolvable', () {
        final byId = Flora250Data.findById(species.id);
        expect(byId, isNotNull);
        expect(byId!.id, equals(species.id));

        final byCommonName = Flora250Data.findByNameOrSpecies(species.commonName);
        expect(byCommonName, isNotNull);

        // Botanical profile resolver lookup
        final profile = PlantSpeciesProfile.resolveForSpecies(species.commonName);
        expect(profile, isNotNull);
        expect(profile.lowMoistureThreshold, greaterThan(0));
        expect(profile.highMoistureThreshold, greaterThan(profile.lowMoistureThreshold));
      });
    }
  });
}
