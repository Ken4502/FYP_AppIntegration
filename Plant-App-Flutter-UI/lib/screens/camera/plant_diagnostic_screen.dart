import 'dart:math' as math;
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
import 'package:urbangreen/services/iot_firestore_service.dart';
import 'package:urbangreen/models/iot_device_model.dart';
import 'package:urbangreen/screens/iot/iot_connection_setup_screen.dart';

class PlantDiagnosticScreen extends StatefulWidget {
  final XFile? image;
  final XFile? macroImage;
  final PlantDiagnosisResponse? diagnosis;

  const PlantDiagnosticScreen({
    super.key,
    this.image,
    this.macroImage,
    this.diagnosis,
  });

  @override
  State<PlantDiagnosticScreen> createState() => _PlantDiagnosticScreenState();
}

class _PlantDiagnosticScreenState extends State<PlantDiagnosticScreen> {
  int _cardQuarterTurns = 0;
  int _selectedVisualTab = 0; // 0 = Canopy Shot 1 (Annotated Lesions), 1 = Macro Shot 2 (Symptom Detail)
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _microorganismKey = GlobalKey();
  final GlobalKey _pestKey = GlobalKey();
  final GlobalKey _rustKey = GlobalKey();
  final GlobalKey _wateringKey = GlobalKey();
  final GlobalKey _holeKey = GlobalKey();
  final GlobalKey _previewKey = GlobalKey();
  String _selectedCategoryFilter = 'all'; // 'all', 'microorganism', 'pestInsect', 'rust', 'watering'

  @override
  void initState() {
    super.initState();
    if (widget.diagnosis != null) {
      AchievementService().recordDiagnosticScan();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCategory(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOutCubic,
        alignment: 0.05,
      );
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

    final multiCategory = diagnosis?.multiCategory ??
        MultiCategoryDiagnosis.fromSynthesized(
          diagnosis: diagnosis?.diagnosis ??
              DiagnosisInfo(
                conditionName: conditionName,
                category: category,
                isHealthy: isHealthy,
                confidence: confidence,
                severity: severity,
              ),
          species: diagnosis?.species ??
              SpeciesInfo(name: plantName, confidence: confidence, detectedMode: '', topCandidates: []),
          spots: spots ?? SpotsInfo(hasSpots: false, spotsCount: 0, infectedAreaPct: 0.0, statusMessage: ''),
          careGuide: careGuide ??
              CareGuide(
                plantName: plantName,
                conditionName: conditionName,
                isHealthy: isHealthy,
                severity: severity,
                category: category,
                summary: 'Healthy plant specimen with balanced foliage and no pathogen symptoms.',
                immediateActions: ['Maintain routine plant care.'],
                organicTreatments: [],
                chemicalTreatments: [],
                prevention: ['Ensure adequate lighting and appropriate watering.'],
                symptoms: [],
                causes: [],
              ),
          pdiRating: pdi,
          coAlerts: coAlerts,
          predictions: diagnosis?.predictions ?? [],
          abiotic: abiotic,
        );

    final holeAnalysis = diagnosis?.holeAnalysis ??
        PlantDiagnosisResponse.synthesizeHoleAnalysis(
          species: diagnosis?.species ??
              SpeciesInfo(name: plantName, confidence: confidence, detectedMode: '', topCandidates: []),
          diagnosis: diagnosis?.diagnosis ??
              DiagnosisInfo(
                conditionName: conditionName,
                category: category,
                isHealthy: isHealthy,
                confidence: confidence,
                severity: severity,
              ),
          spots: spots ?? SpotsInfo(hasSpots: false, spotsCount: 0, infectedAreaPct: 0.0, statusMessage: ''),
          abiotic: abiotic,
          predictions: diagnosis?.predictions ?? [],
          coAlerts: coAlerts,
        );

    final ruledOutConditions = diagnosis?.ruledOutConditions ??
        PlantDiagnosisResponse.synthesizeRuledOutConditions(
          species: diagnosis?.species ??
              SpeciesInfo(name: plantName, confidence: confidence, detectedMode: '', topCandidates: []),
          diagnosis: diagnosis?.diagnosis ??
              DiagnosisInfo(
                conditionName: conditionName,
                category: category,
                isHealthy: isHealthy,
                confidence: confidence,
                severity: severity,
              ),
          spots: spots ?? SpotsInfo(hasSpots: false, spotsCount: 0, infectedAreaPct: 0.0, statusMessage: ''),
          abiotic: abiotic,
          predictions: diagnosis?.predictions ?? [],
        );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? kDarkBackgroundColor : kBackgroundColor,
      appBar: StandardAppBar(
        title: 'Pathology Diagnostics',
        subtitle: '4-Category AI Disease & Care Regimen',
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
        controller: _scrollController,
        padding: const EdgeInsets.all(kDefaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Two-Shot Inspection Switcher (if macro image is attached)
            if (widget.macroImage != null) ...[
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? kDarkCardColor : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => setState(() => _selectedVisualTab = 0),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: _selectedVisualTab == 0 ? kPrimaryColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.eco_rounded,
                                size: 15,
                                color: _selectedVisualTab == 0 ? Colors.white : (isDark ? kDarkTextSecondary : kTextSecondary),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Canopy Overview (Shot 1)",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedVisualTab == 0 ? Colors.white : (isDark ? kDarkTextSecondary : kTextSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => setState(() => _selectedVisualTab = 1),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: _selectedVisualTab == 1 ? const Color(0xFF059669) : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.zoom_in_rounded,
                                size: 15,
                                color: _selectedVisualTab == 1 ? Colors.white : (isDark ? kDarkTextSecondary : kTextSecondary),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Macro Symptom (Shot 2)",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedVisualTab == 1 ? Colors.white : (isDark ? kDarkTextSecondary : kTextSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Visual Inspection / Annotated Lesion Preview (Tap to zoom & 90° rotation)
            _buildInteractiveCardPreview(spots?.annotatedImageBase64),
            _buildCategoryAreaFilterBar(context, multiCategory, isDark),
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

            const SizedBox(height: 20),

            // =================================================================
            // TOP SECTION: EXECUTIVE SUMMARY OF ALL 4 CATEGORIES (SEVERITY ORDER)
            // =================================================================
            _buildExecutiveSummaryScorecard(
              context,
              multiCategory,
              isDark,
              holeAnalysis: holeAnalysis,
            ),

            const SizedBox(height: 20),

            // =================================================================
            // FOLIAR HOLE DETECTION & CAUSE ATTRIBUTION (SHOT-HOLE, PEST, FENESTRATION)
            // =================================================================
            _buildFoliarHoleAnalysisCard(context, holeAnalysis, isDark),

            const SizedBox(height: 24),

            // =================================================================
            // BOTTOM SECTION: DETAILED BREAKDOWN FOR EACH OF THE 4 CATEGORIES
            // ORDERED BY LOGICAL BOTANICAL SEVERITY (RANK 1 -> RANK 4)
            // =================================================================
            Row(
              children: [
                Icon(Icons.format_list_bulleted_rounded, color: theme.colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  "Comprehensive Diagnostics & Regimen",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? kDarkTextPrimary : kTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "In-depth analysis across all 4 pathological dimensions in order of biological threat severity.",
              style: TextStyle(
                fontSize: 12,
                color: isDark ? kDarkTextSecondary : kTextSecondary,
              ),
            ),
            const SizedBox(height: 16),

            // DETAILED CARD 1: MICROORGANISM INFESTATION (RANK 1 - CRITICAL)
            KeyedSubtree(
              key: _microorganismKey,
              child: _buildMicroorganismDetailCard(context, multiCategory.microorganism, spots, isDark),
            ),
            const SizedBox(height: 18),

            // DETAILED CARD 2: PEST / INSECT INFESTATION (RANK 2 - HIGH URGENCY)
            KeyedSubtree(
              key: _pestKey,
              child: _buildPestInsectDetailCard(context, multiCategory.pestInsect, isDark),
            ),
            const SizedBox(height: 18),

            // DETAILED CARD 3: RUST FUNGAL INFECTION (RANK 3 - MODERATE SEVERITY)
            KeyedSubtree(
              key: _rustKey,
              child: _buildRustDetailCard(context, multiCategory.rust, spots, isDark),
            ),
            const SizedBox(height: 18),

            // DETAILED CARD 4: UNDER / OVERWATERING BALANCE (RANK 4 - MANAGEABLE)
            KeyedSubtree(
              key: _wateringKey,
              child: _buildWateringDetailCard(context, multiCategory.watering, abiotic, plantName, isDark),
            ),
            const SizedBox(height: 24),

            // =================================================================
            // OPTION 3: RULED-OUT CONDITIONS (EXPLAINABLE AI / DIFFERENTIAL ELIMINATION)
            // =================================================================
            if (ruledOutConditions.isNotEmpty) ...[
              _buildRuledOutConditionsSection(context, ruledOutConditions, isDark),
              const SizedBox(height: 24),
            ],

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

            // AI-Prescribed Treatment & Growth Supplies Loop
            _buildRecommendedSuppliesSection(
              context,
              isHealthy: isHealthy,
              conditionName: conditionName,
              category: category,
            ),
            const SizedBox(height: 20),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // EXECUTIVE SUMMARY SCORECARD (TOP SECTION - 4 CATEGORIES)
  // ===========================================================================
  Widget _buildExecutiveSummaryScorecard(
    BuildContext context,
    MultiCategoryDiagnosis multiCategory,
    bool isDark, {
    FoliarHoleAnalysis? holeAnalysis,
  }) {
    final isClear = multiCategory.isEntirelyClear;
    final threatCount = multiCategory.activeThreatCount;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? kDarkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isClear
              ? const Color(0xFF10B981).withValues(alpha: 0.35)
              : Colors.amber.shade700.withValues(alpha: 0.4),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isClear
                  ? const Color(0xFF10B981).withValues(alpha: 0.08)
                  : Colors.amber.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: isClear
                        ? const Color(0xFF10B981).withValues(alpha: 0.16)
                        : Colors.amber.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isClear ? Icons.verified_user_rounded : Icons.health_and_safety_rounded,
                    color: isClear ? const Color(0xFF10B981) : Colors.amber.shade900,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Diagnostic Overview (4 Categories)",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? kDarkTextPrimary : kTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "Severity Hierarchy: Microorganism → Pests → Rust → Watering",
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF059669),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isClear
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isClear ? "ALL CLEAR" : "$threatCount ALERT",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isClear ? const Color(0xFF047857) : Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4 Scorecard Tiles
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _buildSummaryTile(
                  context,
                  item: multiCategory.microorganism,
                  targetKey: _microorganismKey,
                  isDark: isDark,
                  subtitleText: "Bacterial wilts, blights, anthracnose, soft rot",
                ),
                const SizedBox(height: 10),
                _buildSummaryTile(
                  context,
                  item: multiCategory.pestInsect,
                  targetKey: _pestKey,
                  isDark: isDark,
                  subtitleText: "Spider mites, mealybugs, aphids, scale, chew holes",
                ),
                const SizedBox(height: 10),
                _buildSummaryTile(
                  context,
                  item: multiCategory.rust,
                  targetKey: _rustKey,
                  isDark: isDark,
                  subtitleText: "Pucciniales fungal uredinia spore pustules",
                ),
                const SizedBox(height: 10),
                _buildSummaryTile(
                  context,
                  item: multiCategory.watering,
                  targetKey: _wateringKey,
                  isDark: isDark,
                  subtitleText: "Soil moisture balance, cellular turgor & edema",
                ),
              ],
            ),
          ),

          // Optional Foliar Hole Status Link
          if (holeAnalysis != null && holeAnalysis.hasHoles) ...[
            InkWell(
              onTap: () => _scrollToCategory(_holeKey),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(19)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: holeAnalysis.causeColor.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(19)),
                  border: Border(
                    top: BorderSide(
                      color: isDark ? kDarkBorderSubtle : kBorderSubtle,
                      width: 0.8,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(holeAnalysis.causeIcon, size: 16, color: holeAnalysis.causeColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Foliar Perforations: ${holeAnalysis.causeTitle} (${holeAnalysis.holeCountEstimate})",
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: holeAnalysis.causeColor,
                        ),
                      ),
                    ),
                    Text(
                      "Inspect →",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: holeAnalysis.causeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryTile(
    BuildContext context, {
    required CategoryDiagnosisItem item,
    required GlobalKey targetKey,
    required bool isDark,
    required String subtitleText,
  }) {
    final color = item.severityColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _scrollToCategory(targetKey),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? kDarkSurfaceColor : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: item.isDetected ? color.withValues(alpha: 0.35) : (isDark ? kDarkBorderSubtle : kBorderSubtle),
              width: item.isDetected ? 1.3 : 1.0,
            ),
          ),
          child: Row(
            children: [
              // Circular icon
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.categoryIcon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              // Category Title and Status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? kDarkTextPrimary : kTextPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "Rank ${item.severityRank}",
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            item.statusLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: item.isDetected ? color : (isDark ? kDarkTextSecondary : kTextSecondary),
                            ),
                          ),
                        ),
                        if (item.isDetected && item.confidence > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            "(${item.confidence.toStringAsFixed(0)}%)",
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // "View Area" jump button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedCategoryFilter = item.id;
                    });
                    _scrollToCategory(_previewKey);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.4), width: 0.9),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.crop_free_rounded, size: 12, color: color),
                        const SizedBox(width: 4),
                        Text(
                          "View Area",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // "Details" jump pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.25), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Details",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.arrow_downward_rounded, size: 12, color: color),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // DETAILED CARD 1: MICROORGANISM INFESTATION (RANK 1 - CRITICAL)
  // ===========================================================================
  Widget _buildMicroorganismDetailCard(
    BuildContext context,
    CategoryDiagnosisItem item,
    SpotsInfo? spots,
    bool isDark,
  ) {
    return _buildDetailSectionContainer(
      context,
      item: item,
      isDark: isDark,
      severityRationale:
          "Rank 1 Threat Rationale: Microorganisms (bacterial wilts like Xanthomonas & Ralstonia, fungal leaf blights like Anthracnose & Botrytis, and viral pathogens) destroy vascular xylem/phloem vessels. Spreading rapidly via aerosolized micro-droplets, they cause irreversible necrosis and whole-plant collapse within 24–48 hours if not immediately isolated.",
      customChild: spots != null && spots.hasSpots
          ? Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lens_blur_rounded, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Computer Vision Localization: ${spots.spotsCount} active lesion zone(s) detected covering ${spots.infectedAreaPct.toStringAsFixed(1)}% of foliar tissue.",
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  // ===========================================================================
  // DETAILED CARD 2: PEST / INSECT INFESTATION (RANK 2 - HIGH URGENCY)
  // ===========================================================================
  Widget _buildPestInsectDetailCard(
    BuildContext context,
    CategoryDiagnosisItem item,
    bool isDark,
  ) {
    return _buildDetailSectionContainer(
      context,
      item: item,
      isDark: isDark,
      severityRationale:
          "Rank 2 Threat Rationale: Biotic insect and mite pests (spider mites, aphids, thrips, scale, mealybugs, chewing caterpillars) are mobile biological parasites. They pierce leaf epidermis, drain vital phloem sap, stunt growth, excrete honeydew that fosters black sooty mold, and act as vectors transmitting incurable viral pathogens to adjacent plants.",
    );
  }

  // ===========================================================================
  // DETAILED CARD 3: RUST FUNGAL INFECTION (RANK 3 - MODERATE SEVERITY)
  // ===========================================================================
  Widget _buildRustDetailCard(
    BuildContext context,
    CategoryDiagnosisItem item,
    SpotsInfo? spots,
    bool isDark,
  ) {
    return _buildDetailSectionContainer(
      context,
      item: item,
      isDark: isDark,
      severityRationale:
          "Rank 3 Threat Rationale: Rust fungi (Pucciniales) are obligate parasites specialized in foliar colonization. While contagious via windborne spores under high humidity, rust attacks leaf lamina with distinctive cinnamon/orange pustules rather than causing instant vascular collapse. Targeted leaf pruning and sulfur/copper fungicides reliably eradicate infections.",
    );
  }

  // ===========================================================================
  // DETAILED CARD 4: UNDER / OVERWATERING BALANCE (RANK 4 - MANAGEABLE)
  // ===========================================================================
  Widget _buildWateringDetailCard(
    BuildContext context,
    CategoryDiagnosisItem item,
    AbioticInfo? abiotic,
    String plantName,
    bool isDark,
  ) {
    return _buildDetailSectionContainer(
      context,
      item: item,
      isDark: isDark,
      severityRationale:
          "Rank 4 Threat Rationale: Under/overwatering is physiological (abiotic) stress rather than an infectious biological pathogen. It does not spread to adjacent plants and is readily reversible with irrigation adjustment. Monitored continuously by your UrbanGreen IoT capacitive soil sensor, moisture can be stabilized in real time.",
      customChild: _buildIotMoistureCrossCheck(context, plantName: plantName, abiotic: abiotic, isDark: isDark),
    );
  }

  // ===========================================================================
  // IOT SOIL MOISTURE CROSS-CHECK INTEGRATION FOR WATERING CARD
  // ===========================================================================
  Widget _buildIotMoistureCrossCheck(
    BuildContext context, {
    required String plantName,
    required AbioticInfo? abiotic,
    required bool isDark,
  }) {
    final iotService = IotFirestoreService();

    return StreamBuilder<List<IotDevice>>(
      stream: iotService.streamUserDevices(),
      builder: (context, snapshot) {
        final devices = snapshot.data ?? [];
        // Look for device linked to this plant name
        IotDevice? linkedDevice;
        if (devices.isNotEmpty) {
          final cleanName = plantName.toLowerCase();
          for (final d in devices) {
            if (d.linkedPlantName != null && cleanName.contains(d.linkedPlantName!.toLowerCase())) {
              linkedDevice = d;
              break;
            }
          }
          linkedDevice ??= devices.first; // Fallback to first active probe
        }

        if (linkedDevice != null) {
          final liveMoisture = (linkedDevice.moistureLevel ?? 0.0).round();
          final targetMin = linkedDevice.lowMoistureThreshold;
          final targetMax = linkedDevice.highMoistureThreshold;
          final isMoistureLow = liveMoisture < targetMin;
          final isMoistureHigh = liveMoisture > targetMax;

          Color stateColor = const Color(0xFF10B981);
          String stateText = "Optimal moisture equilibrium";
          if (isMoistureLow) {
            stateColor = const Color(0xFF2563EB);
            stateText = "Live moisture is below minimum threshold (Needs water)";
          } else if (isMoistureHigh) {
            stateColor = const Color(0xFF7C3AED);
            stateText = "Live moisture exceeds target (Waterlogging risk)";
          }

          return Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: stateColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: stateColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.sensors_rounded, color: stateColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Live IoT Probe: ${linkedDevice.name}${linkedDevice.wifiSsid != null ? ' (${linkedDevice.wifiSsid})' : ''}",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: stateColor),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: stateColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "$liveMoisture%",
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "• Target Specimen Zone: $targetMin% - $targetMax%\n• Probe Assessment: $stateText",
                  style: TextStyle(fontSize: 11, height: 1.4, color: isDark ? kDarkTextSecondary : kTextSecondary),
                ),
              ],
            ),
          );
        }

        // No IoT probe currently connected
        return Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0284C7).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.sensors_rounded, color: Color(0xFF0284C7), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Automate Hydration with UrbanGreen IoT Probe",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      "Connect a capacitive soil sensor to track live soil moisture in real time and trigger automatic smart watering watchdogs.",
                      style: TextStyle(fontSize: 11, color: kTextSecondary, height: 1.3),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const IotConnectionSetupScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_link_rounded, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              "Connect IoT Probe",
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // SHARED REUSABLE DETAILED SECTION CONTAINER
  // ===========================================================================
  Widget _buildDetailSectionContainer(
    BuildContext context, {
    required CategoryDiagnosisItem item,
    required bool isDark,
    required String severityRationale,
    Widget? customChild,
  }) {
    final color = item.severityColor;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? kDarkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: item.isDetected ? color.withValues(alpha: 0.45) : (isDark ? kDarkBorderSubtle : kBorderSubtle),
          width: item.isDetected ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Card Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.categoryIcon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? kDarkTextPrimary : kTextPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.severityRankLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedCategoryFilter = item.id;
                          });
                          _scrollToCategory(_previewKey);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.center_focus_strong_rounded, size: 13, color: color),
                              const SizedBox(width: 4),
                              Text(
                                "View in Photo",
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        item.isDetected ? item.severityLevel.toUpperCase() : "OPTIMAL",
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Botanical Severity Hierarchy Explanation Callout
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: isDark ? kDarkSurfaceColor : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? kDarkBorderSubtle : Colors.grey.shade300),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          severityRationale,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.4,
                            color: isDark ? kDarkTextSecondary : Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Diagnosis Finding Box
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Diagnostic Verdict:",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kTextSecondary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.statusLabel,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: item.isDetected ? color : (isDark ? kDarkTextPrimary : kTextPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (item.confidence > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: item.isDetected
                              ? color.withValues(alpha: 0.12)
                              : const Color(0xFF16A34A).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: item.isDetected
                                ? color.withValues(alpha: 0.3)
                                : const Color(0xFF16A34A).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!item.isDetected) ...[
                              const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF16A34A)),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              item.isDetected
                                  ? "Detected (${item.confidence.toStringAsFixed(0)}% Conf)"
                                  : "Clear (${item.confidence.toStringAsFixed(0)}% Certain)",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: item.isDetected ? color : const Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Summary
                Text(
                  item.summary,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: isDark ? kDarkTextPrimary : Colors.black87,
                  ),
                ),

                // Custom child (e.g. OpenCV spot localization or IoT moisture stream)
                if (customChild != null) ...[
                  customChild,
                ],

                const SizedBox(height: 14),

                // Clinical Symptoms & Indicators
                if (item.symptoms.isNotEmpty) ...[
                  const Text(
                    "Key Pathological Indicators & Symptoms:",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  ...item.symptoms.map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 14, color: color),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              s,
                              style: TextStyle(fontSize: 12, height: 1.3, color: isDark ? kDarkTextSecondary : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Immediate Actions Required
                if (item.immediateActions.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.flash_on_rounded, size: 15, color: color),
                      const SizedBox(width: 4),
                      Text(
                        "Immediate Actions Required:",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...item.immediateActions.asMap().entries.map(
                        (entry) => _buildTreatmentStep(
                          context,
                          "${entry.key + 1}",
                          "Step",
                          entry.value,
                        ),
                      ),
                  const SizedBox(height: 10),
                ],

                // Organic & Bio-Control Treatments
                if (item.organicTreatments.isNotEmpty) ...[
                  const Row(
                    children: [
                      Icon(Icons.eco_rounded, size: 15, color: Color(0xFF10B981)),
                      SizedBox(width: 4),
                      Text(
                        "Organic & Bio-Control Treatments:",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...item.organicTreatments.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.spa_outlined, size: 14, color: Color(0xFF10B981)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(t, style: TextStyle(fontSize: 12, height: 1.3, color: isDark ? kDarkTextSecondary : Colors.black87)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Chemical Treatments
                if (item.chemicalTreatments.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.science_outlined, size: 15, color: Colors.purple.shade700),
                      const SizedBox(width: 4),
                      Text(
                        "Chemical & Conventional Controls:",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple.shade700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...item.chemicalTreatments.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.medication_liquid_rounded, size: 14, color: Colors.purple.shade700),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(t, style: TextStyle(fontSize: 12, height: 1.3, color: isDark ? kDarkTextSecondary : Colors.black87)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Prevention
                if (item.prevention.isNotEmpty) ...[
                  const Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 15, color: Colors.blueAccent),
                      SizedBox(width: 4),
                      Text(
                        "Long-Term Prevention & Hygiene:",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...item.prevention.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.arrow_right_rounded, size: 18, color: Colors.blueAccent),
                          Expanded(
                            child: Text(p, style: TextStyle(fontSize: 12, height: 1.3, color: isDark ? kDarkTextSecondary : Colors.black87)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // FOLIAR HOLE DETECTION & INTELLIGENT CAUSE ATTRIBUTION CARD
  // ===========================================================================
  Widget _buildFoliarHoleAnalysisCard(
    BuildContext context,
    FoliarHoleAnalysis hole,
    bool isDark,
  ) {
    final color = hole.causeColor;
    final icon = hole.causeIcon;

    return Container(
      key: _holeKey,
      decoration: BoxDecoration(
        color: isDark ? kDarkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Foliar Hole & Perforation Analysis",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? kDarkTextPrimary : kTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hole.causeTitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "${hole.confidence.toStringAsFixed(1)}% Conf",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Perforations Stats Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withValues(alpha: 0.15) : const Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? kDarkBorderSubtle : kBorderSubtle,
                  width: 0.8,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.adjust_rounded, size: 14, color: color),
                      const SizedBox(width: 6),
                      Text(
                        "Perforations: ${hole.holeCountEstimate}",
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? kDarkTextPrimary : kTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: hole.hasHoles ? color.withValues(alpha: 0.12) : const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    hole.hasHoles ? "Holes Present" : "Zero Holes",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: hole.hasHoles ? color : const Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Body Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary
                Text(
                  hole.summary,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: isDark ? kDarkTextPrimary : kTextPrimary,
                  ),
                ),
                const SizedBox(height: 14),

                // Visual Clues Observed
                if (hole.visualClues.isNotEmpty) ...[
                  Text(
                    "Visual Micro-Indicators Observed:",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? kDarkTextPrimary : kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...hole.visualClues.map(
                    (clue) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 14, color: color),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              clue,
                              style: TextStyle(
                                fontSize: 11.5,
                                height: 1.3,
                                color: isDark ? kDarkTextSecondary : kTextSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Likely Culprits
                if (hole.likelyCulprits.isNotEmpty) ...[
                  Text(
                    "Likely Culprits / Biological Etiology:",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? kDarkTextPrimary : kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: hole.likelyCulprits.map(
                      (culprit) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
                        ),
                        child: Text(
                          culprit,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? kDarkTextPrimary : kTextPrimary,
                          ),
                        ),
                      ),
                    ).toList(),
                  ),
                  const SizedBox(height: 14),
                ],

                // Recommended Action
                if (hole.recommendedAction.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.tips_and_updates_rounded, size: 18, color: color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Recommended Care Protocol:",
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                hole.recommendedAction,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.35,
                                  color: isDark ? kDarkTextPrimary : kTextPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Badges
                if (hole.badges.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: hole.badges.map(
                      (badge) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // OPTION 3: RULED-OUT CONDITIONS (EXPLAINABLE AI / DIFFERENTIAL ELIMINATION)
  // ===========================================================================
  Widget _buildRuledOutConditionsSection(
    BuildContext context,
    List<RuledOutCondition> ruledOut,
    bool isDark,
  ) {
    if (ruledOut.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.fact_check_outlined, color: Color(0xFF0D9488), size: 22),
            const SizedBox(width: 8),
            Text(
              "Ruled-Out Conditions (Explainable AI)",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? kDarkTextPrimary : kTextPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "To eliminate misassumptions and symptom clashes, the AI systematically tested and eliminated these common mimic conditions:",
          style: TextStyle(
            fontSize: 12,
            color: isDark ? kDarkTextSecondary : kTextSecondary,
          ),
        ),
        const SizedBox(height: 14),

        ...ruledOut.map(
          (cond) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? kDarkCardColor : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? kDarkBorderSubtle : kBorderSubtle,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cond.conditionName,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? kDarkTextPrimary : kTextPrimary,
                            ),
                          ),
                          Text(
                            "Dimension: ${cond.category}",
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark ? kDarkTextSecondary : kTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        cond.rulingBadge,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Reason
                Text(
                  cond.reasonRuledOut,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: isDark ? kDarkTextPrimary : kTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),

                // Evidence Examined
                if (cond.evidenceExamined.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Clinical Evidence Checked:",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 3),
                        ...cond.evidenceExamined.map(
                          (ev) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.remove, size: 12, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    ev,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isDark ? kDarkTextSecondary : kTextSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }


  // ===========================================================================
  // CATEGORY-SPECIFIC DETECTED AREA SELECTOR BAR
  // ===========================================================================
  Widget _buildCategoryAreaFilterBar(
    BuildContext context,
    MultiCategoryDiagnosis? multiCategory,
    bool isDark,
  ) {
    final allDetections = widget.diagnosis?.detections ?? [];
    
    int countFor(String catId) {
      if (catId == 'all') return allDetections.length;
      return allDetections.where((d) => d.categoryId == catId).length;
    }

    final categories = [
      {'id': 'all', 'label': 'All Areas', 'icon': Icons.grid_view_rounded, 'color': kPrimaryColor},
      {'id': 'microorganism', 'label': 'Microorganisms', 'icon': Icons.coronavirus_outlined, 'color': const Color(0xFFDC2626)},
      {'id': 'pestInsect', 'label': 'Pests & Insects', 'icon': Icons.pest_control_rounded, 'color': const Color(0xFFD97706)},
      {'id': 'rust', 'label': 'Rust Fungi', 'icon': Icons.lens_blur_rounded, 'color': const Color(0xFFEA580C)},
      {'id': 'watering', 'label': 'Watering Balance', 'icon': Icons.water_drop_outlined, 'color': const Color(0xFF0284C7)},
    ];

    final activeCat = categories.firstWhere((c) => c['id'] == _selectedCategoryFilter, orElse: () => categories[0]);
    final activeCount = countFor(_selectedCategoryFilter);
    final activeColor = activeCat['color'] as Color;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? kDarkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? kDarkBorderSubtle : kBorderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.center_focus_strong_rounded, size: 18, color: kPrimaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Interactive Category Area Inspector",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? kDarkTextPrimary : kTextPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: activeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _selectedCategoryFilter == 'all' ? "${allDetections.length} Total Zones" : "$activeCount Detected",
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: activeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Tap a category below to highlight its detected foliar areas on the photo:",
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((cat) {
                final id = cat['id'] as String;
                final label = cat['label'] as String;
                final icon = cat['icon'] as IconData;
                final color = cat['color'] as Color;
                final isSelected = _selectedCategoryFilter == id;
                final count = countFor(id);

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedCategoryFilter = id;
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected ? color : (isDark ? kDarkSurfaceColor : const Color(0xFFF3F4F6)),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? color : (isDark ? kDarkBorderSubtle : Colors.grey.shade300),
                            width: isSelected ? 1.6 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 14, color: isSelected ? Colors.white : color),
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : (isDark ? kDarkTextPrimary : kTextPrimary),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white.withValues(alpha: 0.25) : color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                count > 0 ? "$count" : "Clear",
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          // Status Callout Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: activeCount > 0 ? activeColor.withValues(alpha: 0.08) : Colors.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: activeCount > 0 ? activeColor.withValues(alpha: 0.25) : Colors.green.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  activeCount > 0 ? Icons.remove_red_eye_rounded : Icons.check_circle_rounded,
                  size: 15,
                  color: activeCount > 0 ? activeColor : const Color(0xFF10B981),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    activeCount > 0
                        ? "Showing $activeCount detected zone(s) for ${activeCat['label']}. Tap photo above to zoom & rotate."
                        : "✓ Optimal: No lesions detected for ${activeCat['label']}.",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: activeCount > 0 ? activeColor : const Color(0xFF047857),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveCardPreview(String? base64Str) {
    final detections = widget.diagnosis?.detections ?? [];
    final imgW = widget.diagnosis?.imageWidth ?? 0;
    final imgH = widget.diagnosis?.imageHeight ?? 0;

    return Center(
      child: Container(
        key: _previewKey,
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
              // Tappable main image with category-specific detection bounding box overlay
              InkWell(
                onTap: () => _openFullScreenPreview(base64Str),
                child: RotatedBox(
                  quarterTurns: _cardQuarterTurns,
                  child: CategoryDetectionOverlay(
                    detections: detections,
                    selectedCategory: _selectedCategoryFilter,
                    imageWidth: imgW,
                    imageHeight: imgH,
                    child: _buildVisualPreview(base64Str),
                  ),
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
    // When macro tab is selected, open macro file directly without spots overlay
    if (_selectedVisualTab == 1 && widget.macroImage != null) {
      bytes = null;
    } else if (base64Str != null && base64Str.isNotEmpty) {
      try {
        final cleanB64 = base64Str.contains(',')
            ? base64Str.split(',')[1]
            : base64Str;
        bytes = base64Decode(cleanB64);
      } catch (_) {}
    }

    final File? file = (_selectedVisualTab == 1 && widget.macroImage != null)
        ? File(widget.macroImage!.path)
        : (widget.image != null ? File(widget.image!.path) : null);
    final plantName = widget.diagnosis?.species.name.replaceAll('_', ' ') ?? "Plant Specimen";
    final conditionName = _selectedVisualTab == 1
        ? "Macro Symptom Inspection (Shot 2)"
        : (widget.diagnosis?.diagnosis.conditionName.replaceAll('_', ' ') ?? "Pathology Diagnostics");

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
    // If user selected the Macro Symptom tab and macroImage is available, show macro shot
    if (_selectedVisualTab == 1 && widget.macroImage != null) {
      return Image.file(
        File(widget.macroImage!.path),
        height: 250,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }

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


// =============================================================================
// CATEGORY-SPECIFIC DETECTED AREA VISUALIZER OVERLAY
// =============================================================================

class CategoryDetectionOverlay extends StatelessWidget {
  final Widget child;
  final List<SymptomDetection> detections;
  final String selectedCategory; // 'all', 'microorganism', 'pestInsect', 'rust', 'watering'
  final int imageWidth;
  final int imageHeight;

  const CategoryDetectionOverlay({
    super.key,
    required this.child,
    required this.detections,
    required this.selectedCategory,
    this.imageWidth = 0,
    this.imageHeight = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (detections.isEmpty) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          foregroundPainter: DetectionBoxPainter(
            detections: detections,
            selectedCategory: selectedCategory,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
          ),
          child: child,
        );
      },
    );
  }
}

class DetectionBoxPainter extends CustomPainter {
  final List<SymptomDetection> detections;
  final String selectedCategory;
  final int imageWidth;
  final int imageHeight;

  DetectionBoxPainter({
    required this.detections,
    required this.selectedCategory,
    required this.imageWidth,
    required this.imageHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (detections.isEmpty || size.width <= 0 || size.height <= 0) return;

    final imgW = imageWidth > 0
        ? imageWidth.toDouble()
        : (detections.map((d) => d.bbox.length >= 3 ? d.bbox[2] : 0).fold<int>(0, math.max)).toDouble();
    final imgH = imageHeight > 0
        ? imageHeight.toDouble()
        : (detections.map((d) => d.bbox.length >= 4 ? d.bbox[3] : 0).fold<int>(0, math.max)).toDouble();

    if (imgW <= 0 || imgH <= 0) return;

    final scaleX = size.width / imgW;
    final scaleY = size.height / imgH;

    final filtered = selectedCategory == 'all'
        ? detections
        : detections.where((d) => d.categoryId == selectedCategory).toList();

    for (final det in filtered) {
      if (det.bbox.length < 4) continue;
      // Skip whole-image fallbacks [0,0,w,h] if there are other granular detections
      if (det.bbox[0] == 0 && det.bbox[1] == 0 && det.bbox[2] >= imgW && det.bbox[3] >= imgH && filtered.length > 1) {
        continue;
      }

      final x1 = det.bbox[0] * scaleX;
      final y1 = det.bbox[1] * scaleY;
      final x2 = det.bbox[2] * scaleX;
      final y2 = det.bbox[3] * scaleY;
      final rect = Rect.fromLTRB(x1, y1, x2, y2);

      final color = det.categoryColor;

      // 1. Shaded tinted fill
      final fillPaint = Paint()
        ..color = color.withValues(alpha: 0.20)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), fillPaint);

      // 2. High-visibility glowing border
      final borderPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), borderPaint);

      // 3. Corner tick accents
      final cornerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      final tick = math.min(10.0, math.min(rect.width, rect.height) / 3);
      if (tick > 2.0) {
        // Top-left
        canvas.drawLine(Offset(rect.left, rect.top), Offset(rect.left + tick, rect.top), cornerPaint);
        canvas.drawLine(Offset(rect.left, rect.top), Offset(rect.left, rect.top + tick), cornerPaint);
        // Top-right
        canvas.drawLine(Offset(rect.right, rect.top), Offset(rect.right - tick, rect.top), cornerPaint);
        canvas.drawLine(Offset(rect.right, rect.top), Offset(rect.right, rect.top + tick), cornerPaint);
        // Bottom-left
        canvas.drawLine(Offset(rect.left, rect.bottom), Offset(rect.left + tick, rect.bottom), cornerPaint);
        canvas.drawLine(Offset(rect.left, rect.bottom), Offset(rect.left, rect.bottom - tick), cornerPaint);
        // Bottom-right
        canvas.drawLine(Offset(rect.right, rect.bottom), Offset(rect.right - tick, rect.bottom), cornerPaint);
        canvas.drawLine(Offset(rect.right, rect.bottom), Offset(rect.right, rect.bottom - tick), cornerPaint);
      }

      // 4. Floating label pill
      final label = "${det.displayLabel} (${(det.confidence * 100).toStringAsFixed(0)}%)";
      final textSpan = TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: math.max(100.0, size.width - 20));

      final labelBgRect = Rect.fromLTWH(
        math.max(2.0, rect.left),
        math.max(2.0, rect.top - 18),
        textPainter.width + 10,
        17,
      );
      final labelBgPaint = Paint()
        ..color = color.withValues(alpha: 0.92)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(RRect.fromRectAndRadius(labelBgRect, const Radius.circular(5)), labelBgPaint);
      textPainter.paint(canvas, Offset(labelBgRect.left + 5, labelBgRect.top + 1.5));
    }
  }

  @override
  bool shouldRepaint(covariant DetectionBoxPainter oldDelegate) {
    return oldDelegate.selectedCategory != selectedCategory ||
        oldDelegate.detections != detections ||
        oldDelegate.imageWidth != imageWidth ||
        oldDelegate.imageHeight != imageHeight;
  }
}
