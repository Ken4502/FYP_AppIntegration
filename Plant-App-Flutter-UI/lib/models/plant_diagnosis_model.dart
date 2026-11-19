import 'package:flutter/material.dart';

class PlantDiagnosisResponse {
  final String status;
  final bool isPlant;
  final double inferenceTimeMs;
  final bool diseaseAvailable;
  final SpeciesInfo species;
  final DiagnosisInfo diagnosis;
  final SpotsInfo spots;
  final PdiRating? pdiRating;
  final List<CoAlert> coAlerts;
  final CareGuide careGuide;
  final List<PredictionItem> predictions;
  final AbioticInfo? abiotic;
  final String? preprocessedImageBase64;
  final MultiCategoryDiagnosis multiCategory;

  PlantDiagnosisResponse({
    required this.status,
    this.isPlant = true,
    required this.inferenceTimeMs,
    required this.diseaseAvailable,
    required this.species,
    required this.diagnosis,
    required this.spots,
    this.pdiRating,
    required this.coAlerts,
    required this.careGuide,
    required this.predictions,
    this.abiotic,
    this.preprocessedImageBase64,
    MultiCategoryDiagnosis? multiCategory,
  }) : multiCategory = multiCategory ??
            MultiCategoryDiagnosis.fromSynthesized(
              diagnosis: diagnosis,
              species: species,
              spots: spots,
              careGuide: careGuide,
              pdiRating: pdiRating,
              coAlerts: coAlerts,
              predictions: predictions,
              abiotic: abiotic,
            );

  factory PlantDiagnosisResponse.fromJson(Map<String, dynamic> json) {
    final species = SpeciesInfo.fromJson(json['species'] as Map<String, dynamic>? ?? {});
    final diagnosis = DiagnosisInfo.fromJson(json['diagnosis'] as Map<String, dynamic>? ?? {});
    final spots = SpotsInfo.fromJson(json['spots'] as Map<String, dynamic>? ?? {});
    final pdiRating = json['pdi_rating'] != null ? PdiRating.fromJson(json['pdi_rating'] as Map<String, dynamic>) : null;
    final coAlerts = (json['co_alerts'] as List<dynamic>?)
            ?.map((e) => CoAlert.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final careGuide = CareGuide.fromJson(json['care_guide'] as Map<String, dynamic>? ?? {});
    final predictions = (json['predictions'] as List<dynamic>?)
            ?.map((e) => PredictionItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final abiotic = json['abiotic'] != null ? AbioticInfo.fromJson(json['abiotic'] as Map<String, dynamic>) : null;

    final multiCategory = MultiCategoryDiagnosis.fromJson(
      json['multi_category_diagnosis'] as Map<String, dynamic>?,
      diagnosis: diagnosis,
      species: species,
      spots: spots,
      careGuide: careGuide,
      pdiRating: pdiRating,
      coAlerts: coAlerts,
      predictions: predictions,
      abiotic: abiotic,
    );

    return PlantDiagnosisResponse(
      status: json['status']?.toString() ?? '',
      isPlant: json['is_plant'] as bool? ?? true,
      inferenceTimeMs: (json['inference_time_ms'] as num?)?.toDouble() ?? 0.0,
      diseaseAvailable: json['disease_available'] as bool? ?? false,
      species: species,
      diagnosis: diagnosis,
      spots: spots,
      pdiRating: pdiRating,
      coAlerts: coAlerts,
      careGuide: careGuide,
      predictions: predictions,
      abiotic: abiotic,
      preprocessedImageBase64: json['preprocessed_image_base64']?.toString(),
      multiCategory: multiCategory,
    );
  }
}

class SpeciesInfo {
  final String name;
  final double confidence;
  final String detectedMode;
  final List<SpeciesCandidate> topCandidates;

  SpeciesInfo({
    required this.name,
    required this.confidence,
    required this.detectedMode,
    required this.topCandidates,
  });

  factory SpeciesInfo.fromJson(Map<String, dynamic> json) {
    return SpeciesInfo(
      name: json['name']?.toString() ?? 'Unknown Plant',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      detectedMode: json['detected_mode']?.toString() ?? '',
      topCandidates: (json['top_candidates'] as List<dynamic>?)
              ?.map((e) => SpeciesCandidate.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class SpeciesCandidate {
  final String species;
  final double confidence;

  SpeciesCandidate({required this.species, required this.confidence});

  factory SpeciesCandidate.fromJson(Map<String, dynamic> json) {
    return SpeciesCandidate(
      species: json['species']?.toString() ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DiagnosisInfo {
  final String conditionName;
  final String category;
  final bool isHealthy;
  final double confidence;
  final String severity;

  DiagnosisInfo({
    required this.conditionName,
    required this.category,
    required this.isHealthy,
    required this.confidence,
    required this.severity,
  });

  factory DiagnosisInfo.fromJson(Map<String, dynamic> json) {
    return DiagnosisInfo(
      conditionName: json['condition_name']?.toString() ?? 'Unknown Condition',
      category: json['category']?.toString() ?? 'General',
      isHealthy: json['is_healthy'] as bool? ?? false,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      severity: json['severity']?.toString() ?? 'None',
    );
  }
}

class SpotsInfo {
  final bool hasSpots;
  final int spotsCount;
  final double infectedAreaPct;
  final String statusMessage;
  final String? annotatedImageBase64;

  SpotsInfo({
    required this.hasSpots,
    required this.spotsCount,
    required this.infectedAreaPct,
    required this.statusMessage,
    this.annotatedImageBase64,
  });

  factory SpotsInfo.fromJson(Map<String, dynamic> json) {
    return SpotsInfo(
      hasSpots: json['has_spots'] as bool? ?? false,
      spotsCount: (json['spots_count'] as num?)?.toInt() ?? 0,
      infectedAreaPct: (json['infected_area_pct'] as num?)?.toDouble() ?? 0.0,
      statusMessage: json['status_message']?.toString() ?? '',
      annotatedImageBase64: json['annotated_image_base64']?.toString(),
    );
  }
}

class PdiRating {
  final int grade;
  final String label;
  final double infectedPct;
  final String colorHex;
  final String clinicalAction;

  PdiRating({
    required this.grade,
    required this.label,
    required this.infectedPct,
    required this.colorHex,
    required this.clinicalAction,
  });

  factory PdiRating.fromJson(Map<String, dynamic> json) {
    return PdiRating(
      grade: (json['grade'] as num?)?.toInt() ?? 0,
      label: json['label']?.toString() ?? '',
      infectedPct: (json['infected_pct'] as num?)?.toDouble() ?? 0.0,
      colorHex: json['color']?.toString() ?? '#10b981',
      clinicalAction: json['clinical_action']?.toString() ?? '',
    );
  }
}

class CoAlert {
  final String type;
  final String badge;
  final String message;

  CoAlert({
    required this.type,
    required this.badge,
    required this.message,
  });

  factory CoAlert.fromJson(Map<String, dynamic> json) {
    return CoAlert(
      type: json['type']?.toString() ?? '',
      badge: json['badge']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
    );
  }
}

class CareGuide {
  final String plantName;
  final String conditionName;
  final bool isHealthy;
  final String severity;
  final String category;
  final String summary;
  final List<String> immediateActions;
  final List<String> organicTreatments;
  final List<String> chemicalTreatments;
  final List<String> prevention;
  final List<String> symptoms;
  final List<String> causes;

  CareGuide({
    required this.plantName,
    required this.conditionName,
    required this.isHealthy,
    required this.severity,
    required this.category,
    required this.summary,
    required this.immediateActions,
    required this.organicTreatments,
    required this.chemicalTreatments,
    required this.prevention,
    required this.symptoms,
    required this.causes,
  });

  factory CareGuide.fromJson(Map<String, dynamic> json) {
    final treatment = json['treatment'] as Map<String, dynamic>? ?? {};
    return CareGuide(
      plantName: json['plant_name']?.toString() ?? '',
      conditionName: json['condition_name']?.toString() ?? '',
      isHealthy: json['is_healthy'] as bool? ?? false,
      severity: json['severity']?.toString() ?? 'None',
      category: json['category']?.toString() ?? 'General',
      summary: json['summary']?.toString() ?? '',
      immediateActions: (json['immediate_actions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      organicTreatments: (treatment['organic'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      chemicalTreatments: (treatment['chemical'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      prevention: (json['prevention'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      symptoms: (json['symptoms'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      causes: (json['causes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class PredictionItem {
  final int rank;
  final String className;
  final String conditionName;
  final double confidence;
  final bool isHealthy;
  final String severity;
  final String category;

  PredictionItem({
    required this.rank,
    required this.className,
    required this.conditionName,
    required this.confidence,
    required this.isHealthy,
    required this.severity,
    required this.category,
  });

  factory PredictionItem.fromJson(Map<String, dynamic> json) {
    return PredictionItem(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      className: json['class_name']?.toString() ?? '',
      conditionName: json['condition_name']?.toString() ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      isHealthy: json['is_healthy'] as bool? ?? false,
      severity: json['severity']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
    );
  }
}

class AbioticInfo {
  final double chlorosisScore;
  final double necrosisScore;
  final String stressLevel;
  final String stressType;
  final String recommendation;
  final bool isUnderwatered;
  final bool isOverwatered;
  final bool isSunburned;
  final bool isPest;
  final String waterStatus;

  AbioticInfo({
    required this.chlorosisScore,
    required this.necrosisScore,
    required this.stressLevel,
    required this.stressType,
    required this.recommendation,
    this.isUnderwatered = false,
    this.isOverwatered = false,
    this.isSunburned = false,
    this.isPest = false,
    this.waterStatus = 'Normal',
  });

  factory AbioticInfo.fromJson(Map<String, dynamic> json) {
    final stype = json['stress_type']?.toString().toLowerCase() ?? '';
    final wstat = json['water_status']?.toString().toLowerCase() ?? '';

    final isUnder = json['is_underwatered'] as bool? ??
        (stype.contains('underwater') || stype.contains('dehydrat') || wstat.contains('underwater'));
    final isOver = json['is_overwatered'] as bool? ??
        (stype.contains('overwater') || stype.contains('waterlog') || stype.contains('edema') || wstat.contains('overwater'));
    final isSun = json['is_sunburned'] as bool? ??
        (stype.contains('sunburn') || stype.contains('scorch'));
    final isP = json['is_pest'] as bool? ??
        (stype.contains('pest') || stype.contains('biotic') || stype.contains('bite'));

    return AbioticInfo(
      chlorosisScore: (json['chlorosis_score'] as num?)?.toDouble() ?? 0.0,
      necrosisScore: (json['necrosis_score'] as num?)?.toDouble() ?? 0.0,
      stressLevel: json['stress_level']?.toString() ?? 'Low',
      stressType: json['stress_type']?.toString() ?? 'None',
      recommendation: json['recommendation']?.toString() ?? '',
      isUnderwatered: isUnder,
      isOverwatered: isOver,
      isSunburned: isSun,
      isPest: isP,
      waterStatus: json['water_status']?.toString() ?? 'Normal',
    );
  }
}

/// 4-Category Plant Pathology Audit Model
/// Explicitly separates and evaluates:
/// 1. Microorganism Infestation (Rank 1 - Critical Severity)
/// 2. Pest / Insect Infestation (Rank 2 - High Urgency)
/// 3. Rust Fungal Infection (Rank 3 - Moderate Severity)
/// 4. Under / Overwatering (Rank 4 - Physiological / Manageable)
class MultiCategoryDiagnosis {
  final CategoryDiagnosisItem microorganism; // Rank 1
  final CategoryDiagnosisItem pestInsect;     // Rank 2
  final CategoryDiagnosisItem rust;           // Rank 3
  final CategoryDiagnosisItem watering;       // Rank 4

  MultiCategoryDiagnosis({
    required this.microorganism,
    required this.pestInsect,
    required this.rust,
    required this.watering,
  });

  /// The 4 categories arranged in strict descending order of biological severity and urgency:
  List<CategoryDiagnosisItem> get orderedBySeverity => [
        microorganism,
        pestInsect,
        rust,
        watering,
      ];

  int get activeThreatCount =>
      orderedBySeverity.where((item) => item.isDetected).length;

  bool get isEntirelyClear => activeThreatCount == 0;

  CategoryDiagnosisItem get primaryThreat => orderedBySeverity.firstWhere(
        (item) => item.isDetected,
        orElse: () => microorganism,
      );

  factory MultiCategoryDiagnosis.fromJson(
    Map<String, dynamic>? json, {
    required DiagnosisInfo diagnosis,
    required SpeciesInfo species,
    required SpotsInfo spots,
    required CareGuide careGuide,
    required PdiRating? pdiRating,
    required List<CoAlert> coAlerts,
    required List<PredictionItem> predictions,
    required AbioticInfo? abiotic,
  }) {
    if (json != null &&
        json['microorganism'] is Map<String, dynamic> &&
        json['pest_insect'] is Map<String, dynamic> &&
        json['rust'] is Map<String, dynamic> &&
        json['watering'] is Map<String, dynamic>) {
      return MultiCategoryDiagnosis(
        microorganism: CategoryDiagnosisItem.fromJson(json['microorganism'] as Map<String, dynamic>),
        pestInsect: CategoryDiagnosisItem.fromJson(json['pest_insect'] as Map<String, dynamic>),
        rust: CategoryDiagnosisItem.fromJson(json['rust'] as Map<String, dynamic>),
        watering: CategoryDiagnosisItem.fromJson(json['watering'] as Map<String, dynamic>),
      );
    }

    return MultiCategoryDiagnosis.fromSynthesized(
      diagnosis: diagnosis,
      species: species,
      spots: spots,
      careGuide: careGuide,
      pdiRating: pdiRating,
      coAlerts: coAlerts,
      predictions: predictions,
      abiotic: abiotic,
    );
  }

  factory MultiCategoryDiagnosis.fromSynthesized({
    required DiagnosisInfo diagnosis,
    required SpeciesInfo species,
    required SpotsInfo spots,
    required CareGuide careGuide,
    required PdiRating? pdiRating,
    required List<CoAlert> coAlerts,
    required List<PredictionItem> predictions,
    required AbioticInfo? abiotic,
  }) {
    final condLower = diagnosis.conditionName.toLowerCase();
    final catLower = diagnosis.category.toLowerCase();
    final allPredsLower = predictions.map((p) => '${p.className.toLowerCase()} ${p.conditionName.toLowerCase()}').join(' ');
    final alertTextLower = coAlerts.map((a) => '${a.type.toLowerCase()} ${a.badge.toLowerCase()} ${a.message.toLowerCase()}').join(' ');

    // -------------------------------------------------------------------------
    // CATEGORY 1 (RANK 1 - CRITICAL SEVERITY): MICROORGANISM INFESTATION
    // -------------------------------------------------------------------------
    final hasMicroorganism = condLower.contains('bacterial') ||
        condLower.contains('blight') ||
        condLower.contains('anthracnose') ||
        condLower.contains('leaf spot') ||
        condLower.contains('mildew') ||
        condLower.contains('mold') ||
        condLower.contains('rot') ||
        condLower.contains('canker') ||
        condLower.contains('wilt') ||
        condLower.contains('mosaic') ||
        catLower.contains('bacterial') ||
        catLower.contains('fungal') ||
        allPredsLower.contains('bacterial') ||
        allPredsLower.contains('anthracnose');

    final isMicrobialDetected = hasMicroorganism &&
        !condLower.contains('healthy') &&
        (!condLower.contains('rust') || condLower.contains('spot') || condLower.contains('bacterial'));

    final CategoryDiagnosisItem microItem;
    if (isMicrobialDetected) {
      final sev = diagnosis.severity.isNotEmpty && diagnosis.severity != 'None'
          ? diagnosis.severity
          : 'High';
      microItem = CategoryDiagnosisItem(
        id: 'microorganism',
        title: 'Microorganism Infestation',
        severityRank: 1,
        severityRankLabel: 'Rank 1 • Critical Severity',
        severityLevel: sev,
        isDetected: true,
        statusLabel: diagnosis.conditionName,
        confidence: diagnosis.confidence,
        summary: careGuide.summary.isNotEmpty
            ? careGuide.summary
            : 'Pathogenic bacterial or fungal microorganisms detected invading foliar tissue, causing water-soaked cellular decay and necrotic lesions.',
        symptoms: careGuide.symptoms.isNotEmpty
            ? careGuide.symptoms
            : [
                'Water-soaked translucent foliar lesions',
                'Expanding necrotic spotting with chlorotic yellow halos',
                'Foliar blighting or soft tissue rot',
                'Premature leaflet abscission',
              ],
        immediateActions: careGuide.immediateActions.isNotEmpty
            ? careGuide.immediateActions
            : [
                'Isolate specimen at least 1.5 meters away from all other plants immediately.',
                'Sterilize shears with 70% isopropyl alcohol and excise heavily infected leaflets showing yellow halos.',
                'Water strictly at the soil base; do not wet or mist leaf surfaces.',
              ],
        organicTreatments: careGuide.organicTreatments.isNotEmpty
            ? careGuide.organicTreatments
            : [
                'Apply copper octanoate (copper soap) fungicidal bactericide to foliage every 7-10 days.',
                'Spray cold-pressed pure neem oil solution (0.5% concentration) to boost systemic foliar defenses.',
                'Bio-fungicide root drench with Bacillus subtilis to suppress soil-borne pathogens.',
              ],
        chemicalTreatments: careGuide.chemicalTreatments.isNotEmpty
            ? careGuide.chemicalTreatments
            : [
                'Apply fixed copper hydroxide spray at 1.5g per liter of water for persistent bacterial lesions.',
                'Broad-spectrum systemic fungicide (Chlorothalonil or Azoxystrobin) for fungal blights.',
              ],
        prevention: careGuide.prevention.isNotEmpty
            ? careGuide.prevention
            : [
                'Ensure morning watering so leaf moisture dries thoroughly before evening.',
                'Maintain minimum 30cm spacing between indoor pots for continuous laminar airflow.',
                'Sterilize pruning tools between cuts with 70% isopropyl alcohol.',
              ],
        badges: ['High Contagion', 'Vascular Pathogen', 'Immediate Quarantine'],
      );
    } else {
      microItem = CategoryDiagnosisItem(
        id: 'microorganism',
        title: 'Microorganism Infestation',
        severityRank: 1,
        severityRankLabel: 'Rank 1 • Critical Severity',
        severityLevel: 'Optimal',
        isDetected: false,
        statusLabel: 'Clear • No Microbial Pathogens',
        confidence: 96.5,
        summary: 'No active bacterial leaf spot, fungal blights, soft rot, powdery mildew mycelium, or viral lesions identified on foliar surfaces.',
        symptoms: [
          'Uniform leaf lamina with intact cuticle wax barrier.',
          'No water-soaked margins, target rings, or bacterial ooze.',
        ],
        immediateActions: [
          'Maintain clean foliage and keep leaves dry during watering.',
        ],
        organicTreatments: [
          'Routine preventive foliar wiping with a clean damp microfiber cloth.',
        ],
        chemicalTreatments: [
          'No chemical bactericides or fungicides needed.',
        ],
        prevention: [
          'Water strictly at soil level and ensure adequate room ventilation.',
        ],
        badges: ['Clean Epidermis', 'Pathogen-Free'],
      );
    }

    // -------------------------------------------------------------------------
    // CATEGORY 2 (RANK 2 - HIGH URGENCY): PEST / INSECT INFESTATION
    // -------------------------------------------------------------------------
    final hasPest = condLower.contains('pest') ||
        condLower.contains('insect') ||
        condLower.contains('aphid') ||
        condLower.contains('mealybug') ||
        condLower.contains('scale') ||
        condLower.contains('thrip') ||
        condLower.contains('mite') ||
        condLower.contains('whitefl') ||
        condLower.contains('miner') ||
        condLower.contains('chew') ||
        condLower.contains('bite') ||
        condLower.contains('hole') ||
        alertTextLower.contains('pest') ||
        alertTextLower.contains('aphid') ||
        alertTextLower.contains('mite') ||
        alertTextLower.contains('scale') ||
        alertTextLower.contains('bite') ||
        (abiotic?.isPest == true);

    final isPestDetected = hasPest && !condLower.contains('healthy');

    final CategoryDiagnosisItem pestItem;
    if (isPestDetected) {
      String pestName = 'Biotic Pest Infestation';
      if (condLower.contains('mealybug')) {
        pestName = 'Mealybugs (Cochineal Wax)';
      } else if (condLower.contains('aphid')) {
        pestName = 'Aphids (Plant Lice Colony)';
      } else if (condLower.contains('scale')) {
        pestName = 'Scale Insects (Armored Shell)';
      } else if (condLower.contains('mite')) {
        pestName = 'Spider Mites (Tetranychidae)';
      } else if (condLower.contains('thrip')) {
        pestName = 'Thrips (Foliar Rasping)';
      } else if (condLower.contains('miner')) {
        pestName = 'Leaf Miners (Mesophyll Tunnels)';
      } else if (condLower.contains('chew') || condLower.contains('bite')) {
        pestName = 'Chewing Pests (Insect Bite Holes)';
      }

      pestItem = CategoryDiagnosisItem(
        id: 'pest_insect',
        title: 'Pest & Insect Infestation',
        severityRank: 2,
        severityRankLabel: 'Rank 2 • High Urgency',
        severityLevel: 'High',
        isDetected: true,
        statusLabel: pestName,
        confidence: diagnosis.confidence > 0 ? diagnosis.confidence : 88.5,
        summary: 'Active biotic insect or mite pest activity identified. Pests puncture cellular membranes, drain vascular sap, and create open lesions that invite secondary bacterial infections.',
        symptoms: [
          'Sap-sucking stippling, chlorotic spotting, and foliar bronzing',
          'Cottony waxy fluff, fine silky webbing, or armored shell bumps',
          'Chewed leaf margins, irregular holes, or serpentine mining trails',
          'Sticky honeydew excretions prone to black sooty mold',
        ],
        immediateActions: [
          'Isolate the plant immediately away from all other houseplants to halt pest migration.',
          'Dab cotton swabs soaked in 70% isopropyl alcohol directly onto mealybugs or armored scales.',
          'Rinse aphid clusters off shoots with a firm lukewarm spray in the shower or sink.',
          'Inspect leaf undersides, petiole crotches, and tender new buds with a bright light.',
        ],
        organicTreatments: [
          'Spray cold-pressed pure neem oil solution (0.5% concentration with mild horticultural soap) every 4-5 days.',
          'Apply potassium salt insecticidal soap spray covering upper and lower leaf surfaces.',
          'Dust food-grade diatomaceous earth around the potting soil rim to deter crawling nymphs.',
        ],
        chemicalTreatments: [
          'Pyrethrin contact insecticide spray for rapid knockdown of heavy aphid, whitefly, or thrip swarms.',
          'Spinosad foliar spray for thrips, leaf miners, and chewing caterpillars.',
          'Systemic insecticide drench (Acetamiprid) for persistent root or armored scale infestations.',
        ],
        prevention: [
          'Conduct weekly leaf checks using a magnifying glass on leaf undersides.',
          'Wipe foliage monthly to prevent dust buildup where spider mites thrive.',
          'Quarantine newly purchased plants for 14 days before integrating into garden.',
        ],
        badges: ['Sap Sucker', 'Spreads Across Plants', 'Isolation Required'],
      );
    } else {
      pestItem = CategoryDiagnosisItem(
        id: 'pest_insect',
        title: 'Pest & Insect Infestation',
        severityRank: 2,
        severityRankLabel: 'Rank 2 • High Urgency',
        severityLevel: 'Optimal',
        isDetected: false,
        statusLabel: 'Clear • No Active Pests',
        confidence: 95.0,
        summary: 'No sap-sucking insects, webbing, scale armor shells, mealybug wax clusters, or chewing bite perforations detected on foliage.',
        symptoms: [
          'Intact leaf margins and unblemished foliar surfaces.',
          'No sticky honeydew, webbing, or crawling nymphs observed.',
        ],
        immediateActions: [
          'Continue routine weekly visual checks of leaf undersides.',
        ],
        organicTreatments: [
          'Preventive foliage wipe with clean damp cloth once a month.',
        ],
        chemicalTreatments: [
          'No chemical insecticides needed.',
        ],
        prevention: [
          'Maintain balanced ambient humidity to discourage spider mite reproduction.',
        ],
        badges: ['Pest-Free', 'Optimal Vigor'],
      );
    }

    // -------------------------------------------------------------------------
    // CATEGORY 3 (RANK 3 - MODERATE SEVERITY): RUST FUNGAL INFECTION
    // -------------------------------------------------------------------------
    final hasRust = condLower.contains('rust') ||
        allPredsLower.contains('rust') ||
        alertTextLower.contains('rust');

    final isRustDetected = hasRust && !condLower.contains('healthy');

    final CategoryDiagnosisItem rustItem;
    if (isRustDetected) {
      rustItem = CategoryDiagnosisItem(
        id: 'rust',
        title: 'Rust Fungal Infection',
        severityRank: 3,
        severityRankLabel: 'Rank 3 • Moderate Severity',
        severityLevel: 'Moderate',
        isDetected: true,
        statusLabel: 'Active Rust Pustules (Pucciniales)',
        confidence: diagnosis.confidence > 0 ? diagnosis.confidence : 86.0,
        summary: 'Foliar rust infection (Pucciniales) detected. Specialized obligate fungal parasite producing raised powdery spore pustules (uredinia) that reduce photosynthesis and cause localized chlorosis.',
        symptoms: [
          'Raised orange, cinnamon, or rust-brown powdery spore pustules (uredinia) on leaf undersides',
          'Corresponding pale yellow or chlorotic flecks on the upper leaf surface',
          'Localized foliar chlorosis, curling, and premature leaf drop',
        ],
        immediateActions: [
          'Carefully prune heavily rusted leaves directly into a plastic bag to avoid releasing airborne spores.',
          'Cease overhead misting and leaf wetting immediately; rust spores require water films to germinate.',
          'Wipe nearby leaves with a damp cloth to capture stray spores before they take hold.',
        ],
        organicTreatments: [
          'Spray wettable sulfur powder spray across upper and lower foliar surfaces (stops spore germination).',
          'Apply copper octanoate (copper soap) fungicide to inhibit fungal hyphal penetration.',
          'Cold-pressed neem oil spray (0.5% concentration) to suffocate developing pustules.',
        ],
        chemicalTreatments: [
          'Systemic triazole fungicide (e.g. Myclobutanil or Propiconazole) for persistent foliar rust.',
          'Mancozeb or Chlorothalonil contact protective barrier spray.',
        ],
        prevention: [
          'Water strictly at soil base in early morning so foliage dries before nightfall.',
          'Ensure minimum 30cm spacing between plants for constant air circulation.',
          'Keep relative humidity under control and avoid dense foliage crowding.',
        ],
        badges: ['Spore Producing', 'Foliar Pustules', 'Pruning Required'],
      );
    } else {
      rustItem = CategoryDiagnosisItem(
        id: 'rust',
        title: 'Rust Fungal Infection',
        severityRank: 3,
        severityRankLabel: 'Rank 3 • Moderate Severity',
        severityLevel: 'Optimal',
        isDetected: false,
        statusLabel: 'Clear • No Rust Pustules',
        confidence: 98.0,
        summary: 'No orange, cinnamon, or brown Pucciniales spore pustules, uredinia clusters, or localized rust chlorosis detected.',
        symptoms: [
          'Clean foliar undersides with smooth texture and uniform pigmentation.',
          'No powdery spore dust or chlorotic spore flecking.',
        ],
        immediateActions: [
          'Keep foliar canopy dry to maintain high resistance against fungal spores.',
        ],
        organicTreatments: [
          'No fungicidal treatments required.',
        ],
        chemicalTreatments: [
          'No chemical fungicides needed.',
        ],
        prevention: [
          'Avoid overhead spraying; ensure continuous gentle room airflow.',
        ],
        badges: ['Pustule-Free', 'Zero Spores'],
      );
    }

    // -------------------------------------------------------------------------
    // CATEGORY 4 (RANK 4 - MANAGEABLE HYDRATION): UNDER / OVERWATERING
    // -------------------------------------------------------------------------
    final isUnder = (abiotic?.isUnderwatered == true) ||
        condLower.contains('underwater') ||
        condLower.contains('dehydrat') ||
        condLower.contains('desiccat') ||
        (abiotic?.stressType.toLowerCase().contains('underwater') ?? false) ||
        (abiotic?.stressType.toLowerCase().contains('dehydrat') ?? false) ||
        (abiotic?.waterStatus.toLowerCase().contains('underwater') ?? false);

    final isOver = (abiotic?.isOverwatered == true) ||
        condLower.contains('overwater') ||
        condLower.contains('waterlog') ||
        condLower.contains('edema') ||
        (abiotic?.stressType.toLowerCase().contains('overwater') ?? false) ||
        (abiotic?.stressType.toLowerCase().contains('waterlog') ?? false) ||
        (abiotic?.waterStatus.toLowerCase().contains('overwater') ?? false);

    final CategoryDiagnosisItem waterItem;
    if (isUnder) {
      final sev = (abiotic?.stressLevel == 'High' || (abiotic?.necrosisScore ?? 0) > 20)
          ? 'High'
          : 'Moderate';
      waterItem = CategoryDiagnosisItem(
        id: 'watering',
        title: 'Under / Overwatering Balance',
        severityRank: 4,
        severityRankLabel: 'Rank 4 • Physiological / Manageable',
        severityLevel: sev,
        isDetected: true,
        statusLabel: 'Underwatering • Acute Moisture Deficit',
        confidence: 91.5,
        summary: 'Foliage exhibits acute moisture deficit and loss of cellular turgor. The root zone is depleted of moisture, causing leaf blade wrinkling, curled margins, and dry crispy tips.',
        symptoms: [
          'Loss of foliar cellular turgor (leaf drooping / wilting)',
          'Crispy, brittle brown leaf tips and margins',
          'Wrinkled, folded, or inward-curled leaf blades',
          'Dry, crumbly, and pulled-away potting soil substrate',
        ],
        immediateActions: [
          'Perform a deep bottom-soak: place pot in a basin of lukewarm water for 25-35 minutes.',
          'Do NOT apply chemical pesticides or fertilizers; dehydrated root hairs will burn.',
          'Carefully trim completely desiccated, papery brown tips with clean shears, leaving a thin dry buffer to protect healthy live tissue.',
          'Empty drainage saucer completely after soaking so the pot never sits in stagnant water.',
        ],
        organicTreatments: [
          'Bottom-watering deep soak with tepid non-chlorinated water.',
          'Elevate ambient humidity with a pebble tray to slow foliar transpiration.',
        ],
        chemicalTreatments: [
          'Withhold chemical fertilizers until plant regains full turgor and produces active shoots.',
        ],
        prevention: [
          'Water thoroughly until water drains from the base whenever the top 2 inches of soil feel dry.',
          'Cross-reference with UrbanGreen IoT capacitive soil sensor for real-time moisture targets.',
        ],
        badges: ['Dehydration Stress', 'Deep Soak Needed', 'Reversible'],
      );
    } else if (isOver) {
      final sev = (abiotic?.stressLevel == 'High') ? 'High' : 'Moderate';
      waterItem = CategoryDiagnosisItem(
        id: 'watering',
        title: 'Under / Overwatering Balance',
        severityRank: 4,
        severityRankLabel: 'Rank 4 • Physiological / Manageable',
        severityLevel: sev,
        isDetected: true,
        statusLabel: 'Overwatering • Saturated Substrate & Edema',
        confidence: 89.0,
        summary: 'Foliage shows signs of root hypoxia and edema from waterlogged potting substrate. Roots are suffocating from lack of oxygen, resulting in diffuse yellowing and soft translucent tissue.',
        symptoms: [
          'Diffuse yellowing of lower or older leaves (soggy chlorosis)',
          'Translucent, water-soaked leaf patches with loss of firmness',
          'Raised corky edema blister bumps on leaf undersides',
          'Soft, soggy petiole bases and damp, foul-smelling potting substrate',
        ],
        immediateActions: [
          'Cease watering immediately and allow the top 50% of the potting mix to dry out.',
          'Empty pooled standing water from the drainage saucer and verify bottom holes are open.',
          'Gently aerate potting soil by poking 4-5 holes around root perimeter with a clean chopstick.',
          'Inspect root system: if roots smell sour or are mushy/black, prune dead roots and repot in fresh, perlite-rich substrate.',
        ],
        organicTreatments: [
          'Substrate aeration and amendment with perlite, pumice, or orchid bark for fast drainage.',
          'Hydrogen peroxide (3% diluted 1:4 with water) soil flush to oxygenate anaerobic root zones.',
        ],
        chemicalTreatments: [
          'No chemical fungicides required for non-infected edema; focus on soil drainage and aeration.',
        ],
        prevention: [
          'Always test soil moisture 2 inches deep before watering.',
          'Use pots with functional drainage holes and well-aerated potting soil.',
        ],
        badges: ['Root Hypoxia', 'Substrate Saturated', 'Aeration Needed'],
      );
    } else {
      waterItem = CategoryDiagnosisItem(
        id: 'watering',
        title: 'Under / Overwatering Balance',
        severityRank: 4,
        severityRankLabel: 'Rank 4 • Physiological / Manageable',
        severityLevel: 'Optimal',
        isDetected: false,
        statusLabel: 'Optimal • Balanced Soil Hydration',
        confidence: 94.5,
        summary: 'Foliage demonstrates ideal cellular turgidity and water balance. No symptoms of drought wilting, desiccation, or waterlogged edema detected.',
        symptoms: [
          'Firm, upright leaf blades with natural spring and vibrant luster.',
          'Healthy foliar hydration without crispy tips or translucent water-soaked spots.',
        ],
        immediateActions: [
          'Maintain current watering schedule; check soil dryness or IoT probe before next watering.',
        ],
        organicTreatments: [
          'Routine balanced organic liquid kelp fertilizer during active growing phase.',
        ],
        chemicalTreatments: [
          'None needed.',
        ],
        prevention: [
          'Adhere to recommended species moisture threshold and monitor with IoT probe.',
        ],
        badges: ['Optimal Turgor', 'Hydration Equilibrium'],
      );
    }

    return MultiCategoryDiagnosis(
      microorganism: microItem,
      pestInsect: pestItem,
      rust: rustItem,
      watering: waterItem,
    );
  }
}

/// Detailed diagnosis record for a single diagnostic dimension
class CategoryDiagnosisItem {
  final String id; // 'microorganism', 'pest_insect', 'rust', 'watering'
  final String title;
  final int severityRank; // 1, 2, 3, 4
  final String severityRankLabel;
  final String severityLevel; // 'Critical', 'High', 'Moderate', 'Low', 'Optimal'
  final bool isDetected;
  final String statusLabel;
  final double confidence;
  final String summary;
  final List<String> symptoms;
  final List<String> immediateActions;
  final List<String> organicTreatments;
  final List<String> chemicalTreatments;
  final List<String> prevention;
  final List<String> badges;

  CategoryDiagnosisItem({
    required this.id,
    required this.title,
    required this.severityRank,
    required this.severityRankLabel,
    required this.severityLevel,
    required this.isDetected,
    required this.statusLabel,
    required this.confidence,
    required this.summary,
    this.symptoms = const [],
    this.immediateActions = const [],
    this.organicTreatments = const [],
    this.chemicalTreatments = const [],
    this.prevention = const [],
    this.badges = const [],
  });

  factory CategoryDiagnosisItem.fromJson(Map<String, dynamic> json) {
    return CategoryDiagnosisItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      severityRank: (json['severity_rank'] as num?)?.toInt() ?? 1,
      severityRankLabel: json['severity_rank_label']?.toString() ?? '',
      severityLevel: json['severity_level']?.toString() ?? 'None',
      isDetected: json['is_detected'] as bool? ?? false,
      statusLabel: json['status_label']?.toString() ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      summary: json['summary']?.toString() ?? '',
      symptoms: (json['symptoms'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      immediateActions: (json['immediate_actions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      organicTreatments: (json['organic_treatments'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      chemicalTreatments: (json['chemical_treatments'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      prevention: (json['prevention'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      badges: (json['badges'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'severity_rank': severityRank,
      'severity_rank_label': severityRankLabel,
      'severity_level': severityLevel,
      'is_detected': isDetected,
      'status_label': statusLabel,
      'confidence': confidence,
      'summary': summary,
      'symptoms': symptoms,
      'immediate_actions': immediateActions,
      'organic_treatments': organicTreatments,
      'chemical_treatments': chemicalTreatments,
      'prevention': prevention,
      'badges': badges,
    };
  }

  Color get severityColor {
    if (!isDetected) {
      return const Color(0xFF10B981); // Emerald green for clear / optimal
    }
    switch (severityLevel.toLowerCase()) {
      case 'critical':
      case 'severe':
        return const Color(0xFFDC2626); // Bright red
      case 'high':
        return const Color(0xFFEA580C); // Deep orange
      case 'moderate':
        return const Color(0xFFD97706); // Amber
      case 'low':
      case 'mild':
        return const Color(0xFF2563EB); // Royal blue
      case 'optimal':
      case 'clean':
      case 'none':
      default:
        return const Color(0xFF10B981); // Emerald green
    }
  }

  IconData get categoryIcon {
    switch (id) {
      case 'microorganism':
        return Icons.biotech_rounded;
      case 'pest_insect':
        return Icons.pest_control_rounded;
      case 'rust':
        return Icons.grain_rounded;
      case 'watering':
        return Icons.water_drop_rounded;
      default:
        return Icons.health_and_safety_outlined;
    }
  }
}

