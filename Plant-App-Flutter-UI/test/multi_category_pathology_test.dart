import 'package:flutter_test/flutter_test.dart';
import 'package:urbangreen/models/plant_diagnosis_model.dart';

void main() {
  group('4-Pillar Pathology Model Tests', () {
    test('Explicit healthy diagnosis produces 100% all-clear across all 4 pillars', () {
      final diag = DiagnosisInfo(
        conditionName: 'Healthy Foliage & Optimal Surface Condition',
        category: 'Healthy',
        isHealthy: true,
        confidence: 96.0,
        severity: 'None',
      );
      final species = SpeciesInfo(
        name: 'Mango Tree (Mangifera indica)',
        confidence: 0.95,
        detectedMode: 'Botanical Identification',
        topCandidates: [],
      );

      final res = MultiCategoryDiagnosis.fromSynthesized(
        diagnosis: diag,
        species: species,
        spots: SpotsInfo(hasSpots: false, spotsCount: 0, infectedAreaPct: 0.0, statusMessage: 'Clean'),
        careGuide: CareGuide(
          plantName: 'Mango',
          conditionName: 'Healthy',
          isHealthy: true,
          severity: 'None',
          category: 'Healthy',
          summary: 'Healthy',
          immediateActions: [],
          organicTreatments: [],
          chemicalTreatments: [],
          prevention: [],
          symptoms: [],
          causes: [],
        ),
        pdiRating: null,
        coAlerts: [
          CoAlert(type: 'Hydration Alert', badge: 'Optimal', message: 'No pest chew bites or rust spots detected.'),
        ],
        predictions: [
          PredictionItem(rank: 1, className: 'Mango___Healthy', conditionName: 'Healthy', confidence: 96.0, isHealthy: true, severity: 'None', category: 'Healthy'),
          PredictionItem(rank: 2, className: 'Mango___Bacterial_Canker', conditionName: 'Bacterial Canker', confidence: 2.0, isHealthy: false, severity: 'High', category: 'Pathology'),
          PredictionItem(rank: 3, className: 'Mango___Rust_Fungi', conditionName: 'Rust Fungi', confidence: 1.0, isHealthy: false, severity: 'Moderate', category: 'Pathology'),
        ],
        abiotic: AbioticInfo(
          chlorosisScore: 2.0,
          necrosisScore: 0.5,
          stressLevel: 'Low',
          stressType: 'Optimal',
          recommendation: 'Water normally',
          isUnderwatered: false,
          isOverwatered: false,
          isPest: false,
          waterStatus: 'Optimal',
        ),
      );

      expect(res.isEntirelyClear, isTrue);
      expect(res.activeThreatCount, equals(0));
      expect(res.microorganism.isDetected, isFalse);
      expect(res.pestInsect.isDetected, isFalse);
      expect(res.rust.isDetected, isFalse);
      expect(res.watering.isDetected, isFalse);
    });

    test('Chewing pest holes correctly flag pest_insect without false rust or microbial', () {
      final diag = DiagnosisInfo(
        conditionName: 'Insect Feeding Damage (Bug Bites & Chewed Holes)',
        category: 'Biotic Pest Infestation',
        isHealthy: false,
        confidence: 88.0,
        severity: 'High',
      );
      final species = SpeciesInfo(
        name: 'Mango Tree (Mangifera indica)',
        confidence: 0.92,
        detectedMode: 'Botanical Identification',
        topCandidates: [],
      );

      final res = MultiCategoryDiagnosis.fromSynthesized(
        diagnosis: diag,
        species: species,
        spots: SpotsInfo(hasSpots: false, spotsCount: 0, infectedAreaPct: 0.0, statusMessage: '2 bite holes'),
        careGuide: CareGuide(
          plantName: 'Mango',
          conditionName: 'Insect Damage',
          isHealthy: false,
          severity: 'High',
          category: 'Pests',
          summary: 'Chewing insects',
          immediateActions: [],
          organicTreatments: [],
          chemicalTreatments: [],
          prevention: [],
          symptoms: [],
          causes: [],
        ),
        pdiRating: null,
        coAlerts: [],
        predictions: [
          PredictionItem(rank: 1, className: 'Chewing_Pests_Bug_Bites_Holes', conditionName: 'Chewing Pests (Insect Bite Holes)', confidence: 88.0, isHealthy: false, severity: 'High', category: 'Biotic'),
          PredictionItem(rank: 2, className: 'Bacterial_Leaf_Spot', conditionName: 'Bacterial Leaf Spot', confidence: 5.0, isHealthy: false, severity: 'Moderate', category: 'Pathology'),
        ],
        abiotic: AbioticInfo(
          chlorosisScore: 0.0,
          necrosisScore: 0.0,
          stressLevel: 'None',
          stressType: 'Optimal',
          recommendation: 'Treat pests',
          isUnderwatered: false,
          isOverwatered: false,
          isPest: true,
          waterStatus: 'Optimal',
        ),
      );

      expect(res.microorganism.isDetected, isFalse);
      expect(res.pestInsect.isDetected, isTrue);
      expect(res.pestInsect.statusLabel, contains('Chewing Pests'));
      expect(res.rust.isDetected, isFalse);
      expect(res.watering.isDetected, isFalse);
      expect(res.activeThreatCount, equals(1));
    });

    test('Rust-immune plants (Monstera, Succulents, Palms) suppress false rust even if rust string appears in minor candidates', () {
      final diag = DiagnosisInfo(
        conditionName: 'Foliar Dehydration / Underwatering',
        category: 'Physiological Stress',
        isHealthy: false,
        confidence: 85.0,
        severity: 'Moderate',
      );
      final species = SpeciesInfo(
        name: 'Kalanchoe / Mother of Thousands (Kalanchoe daigremontiana)',
        confidence: 0.95,
        detectedMode: 'Botanical Identification',
        topCandidates: [],
      );

      final res = MultiCategoryDiagnosis.fromSynthesized(
        diagnosis: diag,
        species: species,
        spots: SpotsInfo(hasSpots: false, spotsCount: 0, infectedAreaPct: 0.0, statusMessage: 'Desiccation'),
        careGuide: CareGuide(
          plantName: 'Kalanchoe',
          conditionName: 'Dehydration',
          isHealthy: false,
          severity: 'Moderate',
          category: 'Watering',
          summary: 'Needs water',
          immediateActions: [],
          organicTreatments: [],
          chemicalTreatments: [],
          prevention: [],
          symptoms: [],
          causes: [],
        ),
        pdiRating: null,
        coAlerts: [
          CoAlert(type: 'Abiotic Alert', badge: 'Underwatering', message: 'Foliar wrinkling is abiotic, not rust or bug bite damage.'),
        ],
        predictions: [
          PredictionItem(rank: 1, className: 'Abiotic_Dehydration_Underwatering', conditionName: 'Foliar Dehydration / Underwatering', confidence: 85.0, isHealthy: false, severity: 'Moderate', category: 'Abiotic'),
          PredictionItem(rank: 2, className: 'Rust_Fungi', conditionName: 'Rust Fungi', confidence: 3.0, isHealthy: false, severity: 'Moderate', category: 'Pathology'),
        ],
        abiotic: AbioticInfo(
          chlorosisScore: 0.0,
          necrosisScore: 4.0,
          stressLevel: 'Moderate',
          stressType: 'Underwatering Dehydration',
          recommendation: 'Bottom soak',
          isUnderwatered: true,
          isOverwatered: false,
          isPest: false,
          waterStatus: 'Underwatering',
        ),
      );

      expect(res.microorganism.isDetected, isFalse);
      expect(res.pestInsect.isDetected, isFalse);
      expect(res.rust.isDetected, isFalse, reason: 'Succulents and Kalanchoe are biologically rust-immune');
      expect(res.watering.isDetected, isTrue);
      expect(res.watering.statusLabel, contains('Underwatering'));
    });

    test('Bacterial Leaf Spot diagnosis activates microorganism rank 1 and keeps other pillars clear', () {
      final diag = DiagnosisInfo(
        conditionName: 'Bacterial Leaf Spot (Xanthomonas)',
        category: 'Pathogenic Bacteria',
        isHealthy: false,
        confidence: 91.0,
        severity: 'High',
      );
      final species = SpeciesInfo(
        name: 'Monstera Deliciosa',
        confidence: 0.94,
        detectedMode: 'Botanical Identification',
        topCandidates: [],
      );

      final res = MultiCategoryDiagnosis.fromSynthesized(
        diagnosis: diag,
        species: species,
        spots: SpotsInfo(hasSpots: true, spotsCount: 4, infectedAreaPct: 6.5, statusMessage: '4 bacterial spots'),
        careGuide: CareGuide(
          plantName: 'Monstera',
          conditionName: 'Bacterial Spot',
          isHealthy: false,
          severity: 'High',
          category: 'Bacteria',
          summary: 'Bacterial spots',
          immediateActions: [],
          organicTreatments: [],
          chemicalTreatments: [],
          prevention: [],
          symptoms: [],
          causes: [],
        ),
        pdiRating: null,
        coAlerts: [],
        predictions: [
          PredictionItem(rank: 1, className: 'Bacterial_Leaf_Spot', conditionName: 'Bacterial Leaf Spot', confidence: 91.0, isHealthy: false, severity: 'High', category: 'Bacterial'),
        ],
        abiotic: AbioticInfo(
          chlorosisScore: 2.0,
          necrosisScore: 1.0,
          stressLevel: 'Low',
          stressType: 'Optimal',
          recommendation: 'Isolate',
          isUnderwatered: false,
          isOverwatered: false,
          isPest: false,
          waterStatus: 'Optimal',
        ),
      );

      expect(res.microorganism.isDetected, isTrue);
      expect(res.microorganism.statusLabel, contains('Bacterial'));
      expect(res.pestInsect.isDetected, isFalse);
      expect(res.rust.isDetected, isFalse);
      expect(res.watering.isDetected, isFalse);
      expect(res.activeThreatCount, equals(1));
    });

    test('Overwatering / Edema correctly triggers Category 4 with Saturated Substrate', () {
      final diag = DiagnosisInfo(
        conditionName: 'Abiotic Overwatering & Edema',
        category: 'Physiological Edema',
        isHealthy: false,
        confidence: 84.0,
        severity: 'Moderate',
      );
      final species = SpeciesInfo(
        name: 'Lady Palm (Rhapis excelsa)',
        confidence: 0.96,
        detectedMode: 'Botanical Identification',
        topCandidates: [],
      );

      final res = MultiCategoryDiagnosis.fromSynthesized(
        diagnosis: diag,
        species: species,
        spots: SpotsInfo(hasSpots: false, spotsCount: 0, infectedAreaPct: 0.0, statusMessage: 'Edema'),
        careGuide: CareGuide(
          plantName: 'Lady Palm',
          conditionName: 'Overwatering',
          isHealthy: false,
          severity: 'Moderate',
          category: 'Watering',
          summary: 'Root hypoxia',
          immediateActions: [],
          organicTreatments: [],
          chemicalTreatments: [],
          prevention: [],
          symptoms: [],
          causes: [],
        ),
        pdiRating: null,
        coAlerts: [],
        predictions: [
          PredictionItem(rank: 1, className: 'Abiotic_Overwatering_Edema', conditionName: 'Overwatering Edema', confidence: 84.0, isHealthy: false, severity: 'Moderate', category: 'Abiotic'),
        ],
        abiotic: AbioticInfo(
          chlorosisScore: 28.0,
          necrosisScore: 0.5,
          stressLevel: 'Moderate',
          stressType: 'Overwatering / Waterlogging',
          recommendation: 'Pause watering',
          isUnderwatered: false,
          isOverwatered: true,
          isPest: false,
          waterStatus: 'Overwatering',
        ),
      );

      expect(res.microorganism.isDetected, isFalse);
      expect(res.pestInsect.isDetected, isFalse);
      expect(res.rust.isDetected, isFalse);
      expect(res.watering.isDetected, isTrue);
      expect(res.watering.statusLabel, contains('Overwatering'));
    });
  });
}
