import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/models/plant_diagnosis_model.dart';

class PlantDiagnosticScreen extends StatelessWidget {
  final XFile? image;
  final PlantDiagnosisResponse? diagnosis;

  const PlantDiagnosticScreen({
    super.key,
    this.image,
    this.diagnosis,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Fallback default values if screen opened without live scan
    final isHealthy = diagnosis?.diagnosis.isHealthy ?? true;
    final plantName = diagnosis?.species.name.replaceAll('_', ' ') ?? "Monstera Deliciosa";
    final conditionName = diagnosis?.diagnosis.conditionName.replaceAll('_', ' ') ?? "Healthy Foliage";
    final category = diagnosis?.diagnosis.category ?? "General Health";
    final severity = diagnosis?.diagnosis.severity ?? "None";
    final confidence = diagnosis?.diagnosis.confidence ?? 95.0;

    final careGuide = diagnosis?.careGuide;
    final spots = diagnosis?.spots;
    final pdi = diagnosis?.pdiRating;
    final abiotic = diagnosis?.abiotic;
    final coAlerts = diagnosis?.coAlerts ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Plant Pathology Diagnostics"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(kDefaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Visual Inspection / Annotated Lesion Preview
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _buildVisualPreview(spots?.annotatedImageBase64),
              ),
            ),
            const SizedBox(height: 16),

            // Non-Plant Notice Banner (if applicable)
            if (diagnosis?.isPlant == false) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFB74D)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Advisory: The AI determined this photo does not contain plant foliage. Pathology results below may not be applicable.",
                        style: TextStyle(
                          color: Color(0xFFE65100),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Plant & Condition Title
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plantName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        conditionName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isHealthy ? const Color(0xFF2E7D32) : Colors.redAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isHealthy
                        ? const Color(0xFF2E7D32).withOpacity(0.12)
                        : Colors.redAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isHealthy ? "Healthy" : severity,
                    style: TextStyle(
                      color: isHealthy ? const Color(0xFF2E7D32) : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Quantitative PDI Severity Meter (if available)
            if (pdi != null) ...[
              _buildSectionTitle(context, "Pathology Severity Index (EPPO/USDA)"),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _parseColor(pdi.colorHex).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _parseColor(pdi.colorHex).withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.speed, color: _parseColor(pdi.colorHex)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            pdi.label,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _parseColor(pdi.colorHex),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      pdi.clinicalAction,
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Lesion Localization Stats (OpenCV Spot Detector)
            if (spots != null && spots.hasSpots) ...[
              _buildSectionTitle(context, "Lesion Localization (Computer Vision)"),
              const SizedBox(height: 8),
              _buildInfoCard(
                context,
                "• ${spots.spotsCount} active lesion spots detected.\n"
                "• ${spots.infectedAreaPct.toStringAsFixed(1)}% of foliar tissue shows necrosis or chlorosis.\n"
                "• Status: ${spots.statusMessage}",
              ),
              const SizedBox(height: 16),
            ],

            // Secondary Co-Infection Alerts
            if (coAlerts.isNotEmpty) ...[
              _buildSectionTitle(context, "Co-Infection & Physiological Alerts"),
              const SizedBox(height: 8),
              ...coAlerts.map(
                (alert) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade700),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber, color: Colors.amber.shade900),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alert.badge,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              alert.message,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Summary / Clinical Diagnosis
            _buildSectionTitle(context, "Clinical Assessment"),
            const SizedBox(height: 8),
            _buildInfoCard(
              context,
              careGuide?.summary.isNotEmpty == true
                  ? careGuide!.summary
                  : "Specimen evaluated with PhytoCare Ultra neural ensemble. "
                      "Diagnostic confidence: ${confidence.toStringAsFixed(1)}%. Category: $category.",
            ),

            const SizedBox(height: 16),

            // Immediate Actions
            if (careGuide?.immediateActions.isNotEmpty == true) ...[
              _buildSectionTitle(context, "Immediate Actions Required"),
              const SizedBox(height: 8),
              ...careGuide!.immediateActions.asMap().entries.map(
                    (entry) => _buildTreatmentStep(
                      context,
                      "${entry.key + 1}",
                      "Action Step",
                      entry.value,
                    ),
                  ),
              const SizedBox(height: 16),
            ],

            // Organic Treatments
            if (careGuide?.organicTreatments.isNotEmpty == true) ...[
              _buildSectionTitle(context, "Organic & Bio-Control Treatments"),
              const SizedBox(height: 8),
              ...careGuide!.organicTreatments.asMap().entries.map(
                    (entry) => _buildTreatmentStep(
                      context,
                      "${entry.key + 1}",
                      "Organic Intervention",
                      entry.value,
                    ),
                  ),
              const SizedBox(height: 16),
            ],

            // Chemical Treatments
            if (careGuide?.chemicalTreatments.isNotEmpty == true) ...[
              _buildSectionTitle(context, "Chemical & Conventional Treatments"),
              const SizedBox(height: 8),
              ...careGuide!.chemicalTreatments.asMap().entries.map(
                    (entry) => _buildTreatmentStep(
                      context,
                      "${entry.key + 1}",
                      "Chemical Control",
                      entry.value,
                    ),
                  ),
              const SizedBox(height: 16),
            ],

            // Prevention Guidelines
            if (careGuide?.prevention.isNotEmpty == true) ...[
              _buildSectionTitle(context, "Long-term Prevention Guidelines"),
              const SizedBox(height: 8),
              ...careGuide!.prevention.asMap().entries.map(
                    (entry) => _buildTreatmentStep(
                      context,
                      "${entry.key + 1}",
                      "Preventive Care",
                      entry.value,
                    ),
                  ),
              const SizedBox(height: 16),
            ],

            // Abiotic Stress Assessment
            if (abiotic != null) ...[
              _buildSectionTitle(context, "Abiotic & Environmental Stress"),
              const SizedBox(height: 8),
              _buildInfoCard(
                context,
                "• Stress Level: ${abiotic.stressLevel} (${abiotic.stressType})\n"
                "• Chlorosis Score: ${abiotic.chlorosisScore.toStringAsFixed(1)}\n"
                "• Necrosis Score: ${abiotic.necrosisScore.toStringAsFixed(1)}\n"
                "• Recommendation: ${abiotic.recommendation}",
              ),
              const SizedBox(height: 16),
            ],

            // Top AI Candidates (Differential Diagnosis)
            if (diagnosis?.predictions.isNotEmpty == true) ...[
              _buildSectionTitle(context, "Differential Diagnosis Candidates"),
              const SizedBox(height: 8),
              ...diagnosis!.predictions.take(4).map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              p.conditionName,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          Text(
                            "${p.confidence.toStringAsFixed(1)}%",
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualPreview(String? base64Str) {
    if (base64Str != null && base64Str.isNotEmpty) {
      try {
        final cleanB64 = base64Str.contains(',')
            ? base64Str.split(',')[1]
            : base64Str;
        final Uint8List bytes = base64Decode(cleanB64);
        return Image.memory(
          bytes,
          height: 250,
          width: double.infinity,
          fit: BoxFit.cover,
        );
      } catch (_) {}
    }

    if (image != null) {
      return Image.file(
        File(image!.path),
        height: 250,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }

    return Image.asset(
      'assets/images/image_1.png',
      height: 250,
      width: double.infinity,
      fit: BoxFit.cover,
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(kDefaultPadding),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.06),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
      ),
    );
  }

  Widget _buildTreatmentStep(
      BuildContext context, String step, String title, String description) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(kDefaultPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
              child: Text(
                step,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF10b981);
    }
  }
}
