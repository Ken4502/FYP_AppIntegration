import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:urbangreen/components/standard_app_bar.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/models/plant_diagnosis_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:urbangreen/models/cart_item_model.dart';
import 'package:urbangreen/models/cart_model.dart';
import 'package:urbangreen/models/product_model.dart';
import 'package:urbangreen/screens/shop/cart_screen.dart';
import 'package:urbangreen/services/achievement_service.dart';


class PlantDiagnosticScreen extends StatefulWidget {
  final XFile? image;
  final PlantDiagnosisResponse? diagnosis;

  const PlantDiagnosticScreen({
    super.key,
    this.image,
    this.diagnosis,
  });

  @override
  State<PlantDiagnosticScreen> createState() => _PlantDiagnosticScreenState();
}

class _PlantDiagnosticScreenState extends State<PlantDiagnosticScreen> {
  int _cardQuarterTurns = 0;

  @override
  void initState() {
    super.initState();
    if (widget.diagnosis != null) {
      AchievementService().recordDiagnosticScan();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final diagnosis = widget.diagnosis;

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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? kDarkBackgroundColor : kBackgroundColor,
      appBar: StandardAppBar(
        title: 'Pathology Diagnostics',
        subtitle: 'AI disease detection & care regimen',
        toolbarHeight: 68,
        actions: [
          Consumer<CartModel>(
            builder: (context, cart, child) {
              return Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isDark ? kDarkSurfaceColor : kBackgroundColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle, width: 1.2),
                        ),
                        child: Icon(Icons.shopping_cart_outlined, size: 19, color: isDark ? kDarkTextPrimary : kTextPrimary),
                      ),
                      tooltip: 'View Cart',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CartScreen(),
                          ),
                        );
                      },
                    ),
                    if (cart.items.isNotEmpty)
                      Positioned(
                        right: 4,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: kStatusDanger,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            '${cart.items.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(kDefaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Visual Inspection / Annotated Lesion Preview (Tap to zoom & 90° rotation)
            _buildInteractiveCardPreview(spots?.annotatedImageBase64),
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
                        ? const Color(0xFF2E7D32).withValues(alpha: 0.12)
                        : Colors.redAccent.withValues(alpha: 0.12),
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
                  color: _parseColor(pdi.colorHex).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _parseColor(pdi.colorHex).withValues(alpha: 0.4)),
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
                    color: Colors.amber.withValues(alpha: 0.12),
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

            // AI-Prescribed Treatment & Growth Supplies Loop
            _buildRecommendedSuppliesSection(
              context,
              isHealthy: isHealthy,
              conditionName: conditionName,
              category: category,
            ),
            const SizedBox(height: 20),

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

  Widget _buildInteractiveCardPreview(String? base64Str) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Tappable main image
              InkWell(
                onTap: () => _openFullScreenPreview(base64Str),
                child: RotatedBox(
                  quarterTurns: _cardQuarterTurns,
                  child: _buildVisualPreview(base64Str),
                ),
              ),

              // Top-Right: Quick 90° Rotate Button
              Positioned(
                top: 10,
                right: 10,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _cardQuarterTurns = (_cardQuarterTurns + 1) % 4;
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.rotate_right_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            "Rotate 90°",
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom-Center: Tap to zoom & inspect banner
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _openFullScreenPreview(base64Str),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.70),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 0.8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_in_rounded, color: Colors.white, size: 17),
                            SizedBox(width: 6),
                            Text(
                              "Tap to zoom & inspect image",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openFullScreenPreview(String? base64Str) async {
    Uint8List? bytes;
    if (base64Str != null && base64Str.isNotEmpty) {
      try {
        final cleanB64 = base64Str.contains(',')
            ? base64Str.split(',')[1]
            : base64Str;
        bytes = base64Decode(cleanB64);
      } catch (_) {}
    }

    final File? file = widget.image != null ? File(widget.image!.path) : null;
    final plantName = widget.diagnosis?.species.name.replaceAll('_', ' ') ?? "Plant Specimen";
    final conditionName = widget.diagnosis?.diagnosis.conditionName.replaceAll('_', ' ') ?? "Pathology Diagnostics";

    final updatedTurns = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => DiagnosticFullScreenImageViewer(
          imageBytes: bytes,
          imageFile: file,
          plantName: plantName,
          conditionName: conditionName,
          initialQuarterTurns: _cardQuarterTurns,
        ),
      ),
    );

    if (updatedTurns != null && mounted) {
      setState(() {
        _cardQuarterTurns = updatedTurns;
      });
    }
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

    if (widget.image != null) {
      return Image.file(
        File(widget.image!.path),
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
            color: theme.shadowColor.withValues(alpha: 0.06),
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
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
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

  Widget _buildRecommendedSuppliesSection(
    BuildContext context, {
    required bool isHealthy,
    required String conditionName,
    required String category,
  }) {
    final theme = Theme.of(context);
    final title = isHealthy
        ? "Recommended Nutrition & Maintenance"
        : "Prescribed Treatments & Supplies";
    final subtitle = isHealthy
        ? "Essential organic fertilizers and tools to keep your foliage thriving"
        : "Targeted bio-controls, treatments, and tools for $conditionName";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isHealthy ? Icons.eco : Icons.medical_services_outlined,
              color: isHealthy ? const Color(0xFF2E7D32) : Colors.redAccent,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isHealthy ? const Color(0xFF2E7D32) : Colors.redAccent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 230,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('plant_supplies').snapshots(),
            builder: (context, snapshot) {
              List<Product> products = [];

              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                final all = snapshot.data!.docs
                    .map((doc) => Product.fromFirestore(doc))
                    .toList();

                if (!isHealthy) {
                  final condLower = conditionName.toLowerCase();
                  products = all.where((p) {
                    final t = p.type;
                    final n = p.name.toLowerCase();
                    final c = p.categories.map((x) => x.toLowerCase()).toList();
                    return t == 'Pest Control' ||
                        t == 'Fertilizer' ||
                        t == 'Tool' ||
                        c.contains('pest control') ||
                        c.contains('organic') ||
                        n.contains('neem') ||
                        n.contains('fungicide') ||
                        n.contains('spray') ||
                        n.contains('prun');
                  }).toList();

                  products.sort((a, b) {
                    int scoreA = 0;
                    int scoreB = 0;
                    if (condLower.contains('blight') || condLower.contains('spot') || condLower.contains('rust') || condLower.contains('mildew')) {
                      if (a.name.toLowerCase().contains('fungicide') || a.name.toLowerCase().contains('copper')) scoreA += 5;
                      if (b.name.toLowerCase().contains('fungicide') || b.name.toLowerCase().contains('copper')) scoreB += 5;
                    }
                    if (condLower.contains('mite') || condLower.contains('aphid') || condLower.contains('pest')) {
                      if (a.name.toLowerCase().contains('neem') || a.type == 'Pest Control') scoreA += 5;
                      if (b.name.toLowerCase().contains('neem') || b.type == 'Pest Control') scoreB += 5;
                    }
                    if (a.type == 'Pest Control') scoreA += 2;
                    if (b.type == 'Pest Control') scoreB += 2;
                    return scoreB.compareTo(scoreA);
                  });
                } else {
                  products = all.where((p) {
                    final t = p.type;
                    return t == 'Fertilizer' ||
                        t == 'Soil & Substrate' ||
                        t == 'Tool' ||
                        t == 'Pots & Planters';
                  }).toList();
                }
              }

              if (products.isEmpty) {
                products = isHealthy
                    ? [
                        Product(
                          id: 'fb_f1',
                          name: 'Organic Seaweed Plant Tonic',
                          price: 24.50,
                          imageUrl: 'https://images.unsplash.com/photo-1585336261026-613d9646b9a8?auto=format&fit=crop&w=400&q=80',
                          type: 'Fertilizer',
                          categories: ['Organic', 'Fertilizer'],
                        ),
                        Product(
                          id: 'fb_f2',
                          name: 'Digital Soil Moisture & pH Sensor',
                          price: 49.90,
                          imageUrl: 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?auto=format&fit=crop&w=400&q=80',
                          type: 'Tool',
                          categories: ['Smart Garden', 'Sensors'],
                        ),
                      ]
                    : [
                        Product(
                          id: 'fb_t1',
                          name: 'Organic Cold-Pressed Neem Oil Spray',
                          price: 28.50,
                          imageUrl: 'https://images.unsplash.com/photo-1608571423902-eed4a5ad8108?auto=format&fit=crop&w=400&q=80',
                          type: 'Pest Control',
                          categories: ['Organic', 'Pest Control'],
                        ),
                        Product(
                          id: 'fb_t2',
                          name: 'Liquid Copper Bio-Fungicide',
                          price: 36.90,
                          imageUrl: 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?auto=format&fit=crop&w=400&q=80',
                          type: 'Pest Control',
                          categories: ['Treatment', 'Bio-Control'],
                        ),
                        Product(
                          id: 'fb_t3',
                          name: 'SK-5 Titanium Pruning Shears',
                          price: 39.90,
                          imageUrl: 'https://images.unsplash.com/photo-1592417817098-8f3d69109853?auto=format&fit=crop&w=400&q=80',
                          type: 'Tool',
                          categories: ['Pruning', 'Hardware'],
                        ),
                      ];
              }

              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: products.take(8).length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = products[index];
                  return _buildProductCard(context, item);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    final theme = Theme.of(context);
    final isNetwork = product.imageUrl.startsWith('http://') || product.imageUrl.startsWith('https://');

    return Container(
      width: 165,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  height: 95,
                  width: double.infinity,
                  child: isNetwork
                      ? Image.network(
                          product.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade200,
                            child: Icon(Icons.spa, color: Colors.grey.shade400, size: 28),
                          ),
                        )
                      : Image.asset(
                          product.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade200,
                            child: Icon(Icons.spa, color: Colors.grey.shade400, size: 28),
                          ),
                        ),
                ),
              ),
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    product.type,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'RM ${product.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 28,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        final cart = Provider.of<CartModel>(context, listen: false);
                        cart.addItem(
                          CartItem(
                            productId: product.id,
                            name: product.name,
                            price: product.price,
                            imageUrl: product.imageUrl,
                          ),
                        );
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${product.name} added to cart!'),
                            duration: const Duration(seconds: 4),
                            action: SnackBarAction(
                              label: 'VIEW CART',
                              textColor: Colors.amberAccent,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const CartScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_shopping_cart, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Add to Cart', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen high-resolution zoomable viewer for Pathology Diagnostics.
/// Features:
///   1. Smooth pinch-to-zoom & pan via InteractiveViewer (up to 6×)
///   2. Double-tap to zoom in / reset
///   3. Prominent 'X' exit button
///   4. Interactive 90° rotation controls
///   5. Reset orientation & zoom controls
class DiagnosticFullScreenImageViewer extends StatefulWidget {
  final Uint8List? imageBytes;
  final File? imageFile;
  final String plantName;
  final String conditionName;
  final int initialQuarterTurns;

  const DiagnosticFullScreenImageViewer({
    super.key,
    this.imageBytes,
    this.imageFile,
    required this.plantName,
    required this.conditionName,
    this.initialQuarterTurns = 0,
  });

  @override
  State<DiagnosticFullScreenImageViewer> createState() =>
      _DiagnosticFullScreenImageViewerState();
}

class _DiagnosticFullScreenImageViewerState
    extends State<DiagnosticFullScreenImageViewer> {
  late TransformationController _transformationController;
  late int _quarterTurns;
  Offset? _doubleTapPosition;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _quarterTurns = widget.initialQuarterTurns;
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      _transformationController.value = Matrix4.identity();
    } else {
      final pos = _doubleTapPosition ?? Offset.zero;
      final Matrix4 matrix = Matrix4.identity();
      matrix.setEntry(0, 3, -pos.dx * 1.5);
      matrix.setEntry(1, 3, -pos.dy * 1.5);
      matrix.setEntry(0, 0, 2.5);
      matrix.setEntry(1, 1, 2.5);
      _transformationController.value = matrix;
    }
  }

  void _rotate() {
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
    });
  }

  void _reset() {
    setState(() {
      _transformationController.value = Matrix4.identity();
      _quarterTurns = 0;
    });
  }

  Widget _buildImage() {
    if (widget.imageBytes != null && widget.imageBytes!.isNotEmpty) {
      return Image.memory(
        widget.imageBytes!,
        fit: BoxFit.contain,
      );
    }

    if (widget.imageFile != null) {
      return Image.file(
        widget.imageFile!,
        fit: BoxFit.contain,
      );
    }

    return Image.asset(
      'assets/images/image_1.png',
      fit: BoxFit.contain,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Center Zoomable & Pannable Image Area
            Positioned.fill(
              child: GestureDetector(
                onDoubleTapDown: (details) => _doubleTapPosition = details.localPosition,
                onDoubleTap: _handleDoubleTap,
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  clipBehavior: Clip.none,
                  minScale: 0.5,
                  maxScale: 6.0,
                  boundaryMargin: const EdgeInsets.all(40),
                  child: Center(
                    child: RotatedBox(
                      quarterTurns: _quarterTurns,
                      child: _buildImage(),
                    ),
                  ),
                ),
              ),
            ),

            // Top Control Bar with 'X' Exit Button & Controls
            Positioned(
              top: 12,
              left: 14,
              right: 14,
              child: Row(
                children: [
                  // Prominent 'X' Close Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(_quarterTurns),
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                        ),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title and Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.conditionName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.plantName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Rotate Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _rotate,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                        ),
                        child: const Icon(Icons.rotate_right_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                  // Reset Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _reset,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                        ),
                        child: const Icon(Icons.restart_alt_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Floating Instruction Pill
            Positioned(
              bottom: 18,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pinch_rounded, color: Colors.white70, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        _quarterTurns != 0
                            ? "Pinch / double-tap to zoom • Rotated ${_quarterTurns * 90}°"
                            : "Pinch or double-tap to zoom • Drag to pan",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
