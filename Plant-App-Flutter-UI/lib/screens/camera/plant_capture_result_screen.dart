import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/models/plant_diagnosis_model.dart';
import 'package:urbangreen/screens/camera/plant_diagnostic_screen.dart';
import 'package:urbangreen/screens/garden/add_plant_screen.dart';

class PlantCaptureResultScreen extends StatelessWidget {
  final XFile image;
  final PlantDiagnosisResponse diagnosis;

  const PlantCaptureResultScreen({
    super.key,
    required this.image,
    required this.diagnosis,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final isHealthy = diagnosis.diagnosis.isHealthy;
    final speciesName = diagnosis.species.name.replaceAll('_', ' ');
    final conditionName = diagnosis.diagnosis.conditionName.replaceAll('_', ' ');

    final healthColor = isHealthy ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F);
    final healthBgColor = isHealthy
        ? const Color(0xFF2E7D32).withOpacity(0.12)
        : const Color(0xFFD32F2F).withOpacity(0.12);

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Header Image Container
            SizedBox(
              height: size.height * 0.45,
              child: Stack(
                children: <Widget>[
                  Container(
                    height: size.height * 0.42,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(40),
                        bottomRight: Radius.circular(40),
                      ),
                      boxShadow: [
                        BoxShadow(
                          offset: const Offset(0, 10),
                          blurRadius: 30,
                          color: theme.colorScheme.primary.withOpacity(0.2),
                        ),
                      ],
                      image: DecorationImage(
                        alignment: Alignment.center,
                        fit: BoxFit.cover,
                        image: FileImage(File(image.path)),
                      ),
                    ),
                  ),
                  // Back Arrow Button
                  Positioned(
                    top: 50,
                    left: 20,
                    child: CircleAvatar(
                      backgroundColor: Colors.black.withOpacity(0.5),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                  // AI Badge
                  Positioned(
                    bottom: 15,
                    right: 25,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: diagnosis.isPlant ? theme.colorScheme.primary : const Color(0xFFE65100),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            diagnosis.isPlant ? Icons.auto_awesome : Icons.warning_amber_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            diagnosis.isPlant
                                ? '${diagnosis.species.confidence.toStringAsFixed(0)}% AI Match'
                                : 'No Plant Detected',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Plant Species Title & Subtitle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kDefaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    diagnosis.isPlant ? speciesName : "No Plant Detected",
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: diagnosis.isPlant ? null : const Color(0xFFD32F2F),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        diagnosis.isPlant ? Icons.spa : Icons.info_outline,
                        size: 16,
                        color: diagnosis.isPlant ? theme.colorScheme.primary : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          diagnosis.isPlant
                              ? diagnosis.species.detectedMode
                              : "No recognizable plant foliage or stem found in this photo",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            if (!diagnosis.isPlant) ...[
              // Non-Plant Warning Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kDefaultPadding),
                child: Container(
                  padding: const EdgeInsets.all(kDefaultPadding),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFB74D)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(
                        Icons.image_not_supported_outlined,
                        color: Color(0xFFE65100),
                        size: 32,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Non-Plant Subject Detected",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE65100),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              diagnosis.diagnosis.conditionName.isNotEmpty
                                  ? diagnosis.diagnosis.conditionName
                                  : "The AI could not identify botanical structures in this image.",
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 13,
                              ),
                            ),
                            if (diagnosis.careGuide.summary.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                diagnosis.careGuide.summary,
                                style: TextStyle(
                                  color: Colors.grey[800],
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Tips for Retaking Photo Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kDefaultPadding),
                child: Container(
                  padding: const EdgeInsets.all(kDefaultPadding),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.tips_and_updates_outlined, size: 20, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            "Tips for Accurate Plant Diagnosis",
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "• Center the camera directly on plant leaves, stems, or flowers.\n"
                        "• Ensure bright, even lighting and minimize glare or shadows.\n"
                        "• Keep the camera steady to avoid blurriness.\n"
                        "• Avoid taking photos of background objects, animals, or furniture.",
                        style: TextStyle(
                          color: Colors.black87,
                          height: 1.5,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Retake Photo Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kDefaultPadding),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text(
                      "Retake Photo",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ] else ...[
              // Health Status Banner Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kDefaultPadding),
              child: Container(
                padding: const EdgeInsets.all(kDefaultPadding),
                decoration: BoxDecoration(
                  color: healthBgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: healthColor.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      isHealthy ? Icons.check_circle : Icons.warning_amber_rounded,
                      color: healthColor,
                      size: 32,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isHealthy ? "Plant is Healthy" : conditionName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: healthColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isHealthy
                                ? "No signs of active pathogens, lesions, or pest infestation detected."
                                : "Severity: ${diagnosis.diagnosis.severity} • Confidence: ${diagnosis.diagnosis.confidence.toStringAsFixed(1)}%",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.black87,
                            ),
                          ),
                          if (diagnosis.spots.hasSpots) ...[
                            const SizedBox(height: 6),
                            Text(
                              "• ${diagnosis.spots.spotsCount} spot(s) localized (${diagnosis.spots.infectedAreaPct.toStringAsFixed(1)}% leaf area)",
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Summary Care Card
            if (diagnosis.careGuide.summary.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kDefaultPadding),
                child: Container(
                  padding: const EdgeInsets.all(kDefaultPadding),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.menu_book, size: 20, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            "Clinical Summary",
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        diagnosis.careGuide.summary,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // "See Full Diagnostics" Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kDefaultPadding),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PlantDiagnosticScreen(
                          image: image,
                          diagnosis: diagnosis,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.analytics_outlined),
                  label: const Text(
                    "View Detailed Diagnosis & Treatments",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // "Add to My Garden" Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kDefaultPadding),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddPlantScreen(),
                      ),
                    );
                  },
                  icon: Icon(Icons.add_circle_outline, color: theme.colorScheme.primary),
                  label: Text(
                    "Add $speciesName to My Garden",
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: theme.colorScheme.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ],
        ),
      ),
    );
  }
}
