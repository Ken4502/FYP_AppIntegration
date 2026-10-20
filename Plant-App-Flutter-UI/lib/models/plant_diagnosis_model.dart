class PlantDiagnosisResponse {
  final String status;
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

  PlantDiagnosisResponse({
    required this.status,
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
  });

  factory PlantDiagnosisResponse.fromJson(Map<String, dynamic> json) {
    return PlantDiagnosisResponse(
      status: json['status']?.toString() ?? '',
      inferenceTimeMs: (json['inference_time_ms'] as num?)?.toDouble() ?? 0.0,
      diseaseAvailable: json['disease_available'] as bool? ?? false,
      species: SpeciesInfo.fromJson(json['species'] as Map<String, dynamic>? ?? {}),
      diagnosis: DiagnosisInfo.fromJson(json['diagnosis'] as Map<String, dynamic>? ?? {}),
      spots: SpotsInfo.fromJson(json['spots'] as Map<String, dynamic>? ?? {}),
      pdiRating: json['pdi_rating'] != null ? PdiRating.fromJson(json['pdi_rating'] as Map<String, dynamic>) : null,
      coAlerts: (json['co_alerts'] as List<dynamic>?)
              ?.map((e) => CoAlert.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      careGuide: CareGuide.fromJson(json['care_guide'] as Map<String, dynamic>? ?? {}),
      predictions: (json['predictions'] as List<dynamic>?)
              ?.map((e) => PredictionItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      abiotic: json['abiotic'] != null ? AbioticInfo.fromJson(json['abiotic'] as Map<String, dynamic>) : null,
      preprocessedImageBase64: json['preprocessed_image_base64']?.toString(),
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

  AbioticInfo({
    required this.chlorosisScore,
    required this.necrosisScore,
    required this.stressLevel,
    required this.stressType,
    required this.recommendation,
  });

  factory AbioticInfo.fromJson(Map<String, dynamic> json) {
    return AbioticInfo(
      chlorosisScore: (json['chlorosis_score'] as num?)?.toDouble() ?? 0.0,
      necrosisScore: (json['necrosis_score'] as num?)?.toDouble() ?? 0.0,
      stressLevel: json['stress_level']?.toString() ?? 'Low',
      stressType: json['stress_type']?.toString() ?? 'None',
      recommendation: json['recommendation']?.toString() ?? '',
    );
  }
}

