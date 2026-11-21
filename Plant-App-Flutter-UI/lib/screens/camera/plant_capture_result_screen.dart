import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/models/plant_diagnosis_model.dart';
import 'package:urbangreen/models/plant_model.dart';
import 'package:urbangreen/screens/camera/plant_diagnostic_screen.dart';
import 'package:urbangreen/services/plant_service.dart';
import 'package:urbangreen/services/plant_api_service.dart';

class PlantCaptureResultScreen extends StatefulWidget {
  final XFile image;
  final XFile? macroImage;
  final PlantDiagnosisResponse diagnosis;

  const PlantCaptureResultScreen({
    super.key,
    required this.image,
    this.macroImage,
    required this.diagnosis,
  });

  @override
  State<PlantCaptureResultScreen> createState() => _PlantCaptureResultScreenState();
}

class _PlantCaptureResultScreenState extends State<PlantCaptureResultScreen> {
  bool _isAdded = false;
  String? _userSoilStatus;
  SpeciesCandidate? _selectedCandidate;
  bool _isConfirmed = false;
  bool _isReanalyzing = false;

  String _getActiveSpeciesName() {
    if (_selectedCandidate != null) {
      if (_selectedCandidate!.displayName.isNotEmpty) {
        return _selectedCandidate!.displayName.replaceAll('_', ' ');
      }
      if (_selectedCandidate!.speciesName.isNotEmpty) {
        return _selectedCandidate!.speciesName.replaceAll('_', ' ');
      }
    }
    return widget.diagnosis.species.name.replaceAll('_', ' ');
  }

  List<SymptomDetection> _getTriageAdjustedDetections(List<SymptomDetection> detections) {
    if (_userSoilStatus == null) return detections;
    return detections.map((det) {
      final cls = det.class_.toLowerCase();
      if (cls == 'crispy_brown_edges' ||
          cls == 'yellowing_chlorosis' ||
          cls == 'foliar_wilting_droop' ||
          cls == 'wilting_drooping') {
        List<String> newCauses;
        String newCheck;
        if (_userSoilStatus == 'dry') {
          newCauses = [
            "Underwatering / Low Humidity (Confirmed by dry soil test)",
            "Root-ball moisture deficit & accelerated transpiration",
            ...det.probableCauses.where((c) => !c.toLowerCase().contains("overwatering")),
          ];
          newCheck = "Water thoroughly until water drains from the bottom; perform a 30-min bottom soak.";
        } else if (_userSoilStatus == 'soggy') {
          newCauses = [
            "Overwatering / Root Rot (Confirmed by waterlogged soil test)",
            "Anaerobic root hypoxia and root suffocation",
            ...det.probableCauses.where((c) => !c.toLowerCase().contains("underwatering")),
          ];
          newCheck = "Pause watering immediately, unblock drainage holes, and aerate potting mix.";
        } else {
          // damp
          newCauses = [
            "Soil moisture optimal (Balanced hydration)",
            "Check ambient humidity levels or tap water mineral sensitivity",
            "Natural lower leaf aging / environmental acclimation",
          ];
          newCheck = "Maintain routine care; avoid over-fertilizing.";
        }
        return det.copyWith(
          probableCauses: newCauses.toSet().toList(),
          recommendedCheck: newCheck,
        );
      }
      return det;
    }).toList();
  }

  Widget _buildSoilCheckCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(kDefaultPadding),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.touch_app_rounded, color: Color(0xFF16A34A), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Interactive Triage: Soil Moisture Check",
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Touch the top 2 inches of soil: Is it dry, damp, or soggy?",
            style: TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildSoilChip("dry", "Dry (Crumbly)", Icons.water_drop_outlined, Colors.amber.shade800),
              const SizedBox(width: 8),
              _buildSoilChip("damp", "Damp (Optimal)", Icons.water_drop, Colors.green.shade700),
              const SizedBox(width: 8),
              _buildSoilChip("soggy", "Soggy (Wet)", Icons.waves, Colors.blue.shade800),
            ],
          ),
          if (_userSoilStatus != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Text(
                _userSoilStatus == 'dry'
                    ? "✓ Confirmed: Underwatering / Low humidity. Top probable cause updated. Recommended: Perform deep bottom-soak and increase ambient humidity."
                    : (_userSoilStatus == 'soggy'
                        ? "✓ Confirmed: Overwatering / Root hypoxia risk. Top probable cause updated. Recommended: Pause watering immediately, unblock drainage, and aerate potting mix."
                        : "✓ Confirmed: Soil moisture is optimal. Top probable cause updated. Yellowing / crispy tips may be due to natural lower leaf aging or light/mineral adjustments."),
                style: const TextStyle(fontSize: 12, color: Color(0xFF166534), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSoilChip(String key, String label, IconData icon, Color color) {
    final isSelected = _userSoilStatus == key;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _userSoilStatus = key;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.white : color),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSymptomsCard(BuildContext context, List<SymptomDetection> detections) {
    final theme = Theme.of(context);
    final activeDetections = _getTriageAdjustedDetections(detections);
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(kDefaultPadding),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              Icon(Icons.bubble_chart_outlined, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Visual Symptom Detections (${activeDetections.length})",
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_userSoilStatus != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _userSoilStatus == 'dry'
                        ? Colors.amber.shade100
                        : (_userSoilStatus == 'soggy' ? Colors.blue.shade100 : Colors.green.shade100),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "Triage: ${_userSoilStatus!.toUpperCase()}",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _userSoilStatus == 'dry'
                          ? Colors.amber.shade900
                          : (_userSoilStatus == 'soggy' ? Colors.blue.shade900 : Colors.green.shade900),
                    ),
                  ),
                ),
            ],
          ),
          if (_userSoilStatus != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _userSoilStatus == 'dry'
                    ? Colors.amber.shade50
                    : (_userSoilStatus == 'soggy' ? Colors.blue.shade50 : Colors.green.shade50),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _userSoilStatus == 'dry'
                      ? Colors.amber.shade300
                      : (_userSoilStatus == 'soggy' ? Colors.blue.shade300 : Colors.green.shade300),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _userSoilStatus == 'dry'
                        ? Icons.water_drop_outlined
                        : (_userSoilStatus == 'soggy' ? Icons.waves : Icons.check_circle_outline),
                    size: 15,
                    color: _userSoilStatus == 'dry'
                        ? Colors.amber.shade900
                        : (_userSoilStatus == 'soggy' ? Colors.blue.shade900 : Colors.green.shade900),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _userSoilStatus == 'dry'
                          ? "1-Tap Triage: Underwatering / Low Humidity set as top probable cause."
                          : (_userSoilStatus == 'soggy'
                              ? "1-Tap Triage: Overwatering / Root Rot set as top probable cause."
                              : "1-Tap Triage: Optimal soil moisture confirmed."),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _userSoilStatus == 'dry'
                            ? Colors.amber.shade900
                            : (_userSoilStatus == 'soggy' ? Colors.blue.shade900 : Colors.green.shade900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          ...activeDetections.map((det) {
            final isHigh = det.confidenceTier == 'high';
            final badgeColor = isHigh ? Colors.red.shade700 : Colors.amber.shade800;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: badgeColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "${(det.confidence * 100).toStringAsFixed(0)}%",
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          det.displayLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      ),
                      if (det.source == 'whole_plant_check')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "Whole-Plant",
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                          ),
                        ),
                    ],
                  ),
                  if (det.probableCauses.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Top Cause: ",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        Expanded(
                          child: Text(
                            det.probableCauses.first,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: _userSoilStatus != null ? FontWeight.bold : FontWeight.w600,
                              color: _userSoilStatus == 'dry'
                                  ? Colors.amber.shade900
                                  : (_userSoilStatus == 'soggy' ? Colors.blue.shade900 : Colors.black87),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (det.probableCauses.length > 1) ...[
                      const SizedBox(height: 3),
                      Text(
                        "Other possibilities: ${det.probableCauses.skip(1).join(' • ')}",
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                      ),
                    ],
                  ],
                  if (det.recommendedCheck.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      "Check: ${det.recommendedCheck}",
                      style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade700),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _pickSecondaryAndReanalyze() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: kPrimaryColor),
              title: const Text('Take Close-Up Photo (Camera)'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: kPrimaryColor),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;
    final picked = await picker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;

    if (!mounted) return;
    setState(() => _isReanalyzing = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Refining identification with 2-shot multi-photo logit averaging...'),
          ],
        ),
        duration: Duration(seconds: 4),
      ),
    );

    try {
      final updatedDiag = await PlantApiService().diagnosePlant(
        widget.image,
        secondaryImageFile: picked,
      );
      if (!mounted) return;
      setState(() => _isReanalyzing = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (ctx) => PlantCaptureResultScreen(
            image: widget.image,
            macroImage: picked,
            diagnosis: updatedDiag,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isReanalyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Re-analysis failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildConfirmPlantCard(BuildContext context) {
    final theme = Theme.of(context);
    final candidates = widget.diagnosis.topCandidates.isNotEmpty
        ? widget.diagnosis.topCandidates.take(3).toList()
        : widget.diagnosis.species.topCandidates.take(3).toList();

    if (candidates.isEmpty) return const SizedBox.shrink();

    final isConfirmed = _isConfirmed;
    final activeSpec = _getActiveSpeciesName();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isConfirmed ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConfirmed ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              Icon(
                isConfirmed ? Icons.verified_rounded : Icons.help_outline_rounded,
                color: isConfirmed ? const Color(0xFF16A34A) : const Color(0xFF0284C7),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isConfirmed ? 'Plant Confirmed by You' : 'Confirm Your Plant (Top AI Candidates)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isConfirmed ? const Color(0xFF166534) : const Color(0xFF0F172A),
                  ),
                ),
              ),
              if (widget.diagnosis.needsUserConfirmation && !isConfirmed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Text(
                    'Tap to select',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isConfirmed
                ? 'Selected match is active for this plant\'s profile and garden records.'
                : 'Our botanical ensemble returned multiple close matches. Tap the best visual match or add a close-up photo:',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade700, fontSize: 11),
          ),
          const SizedBox(height: 12),
          // Top Candidates List
          ...candidates.map((cand) {
            final candDisplayName = cand.displayName.isNotEmpty ? cand.displayName : (cand.speciesName.isNotEmpty ? cand.speciesName : cand.species);
            final isSelected = (_selectedCandidate != null && _selectedCandidate!.speciesName == cand.speciesName) ||
                (_selectedCandidate == null && activeSpec.toLowerCase() == candDisplayName.toLowerCase());

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedCandidate = cand;
                    _isConfirmed = true;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.1) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? theme.colorScheme.primary : Colors.grey.shade300,
                      width: isSelected ? 1.8 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: isSelected ? theme.colorScheme.primary : Colors.grey.shade400,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              candDisplayName,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                fontSize: 13,
                                color: isSelected ? theme.colorScheme.primary : const Color(0xFF1E293B),
                              ),
                            ),
                            if (cand.genus.isNotEmpty || cand.family.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                [
                                  if (cand.genus.isNotEmpty) 'Genus: ${cand.genus}',
                                  if (cand.family.isNotEmpty) cand.family,
                                ].join(' • '),
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary.withValues(alpha: 0.15)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${cand.confidence.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? theme.colorScheme.primary : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 6),
          // Add 2nd Photo (Close-Up) Button
          OutlinedButton.icon(
            onPressed: _isReanalyzing ? null : _pickSecondaryAndReanalyze,
            icon: _isReanalyzing
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add_a_photo_outlined, size: 16),
            label: Text(
              widget.macroImage != null ? 'Retake 2nd Photo (Close-Up)' : 'Add 2nd Photo (Close-Up)',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 38),
              side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.5)),
              foregroundColor: theme.colorScheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddToGardenSheet(BuildContext context) {
    final speciesName = _getActiveSpeciesName();
    final conditionName = widget.diagnosis.diagnosis.conditionName.replaceAll('_', ' ');
    final isHealthy = widget.diagnosis.diagnosis.isHealthy;
    final nameController = TextEditingController(text: 'My $speciesName');
    final notesController = TextEditingController(
      text: widget.diagnosis.careGuide.summary.isNotEmpty
          ? widget.diagnosis.careGuide.summary
          : 'Identified via AI diagnosis: $conditionName.',
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? kDarkCardColor : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      File(widget.image.path),
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 60,
                        height: 60,
                        color: kPrimaryColor.withValues(alpha: 0.1),
                        child: const Icon(Icons.eco, color: kPrimaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add to Garden',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextPrimary),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: kPrimaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  speciesName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kPrimaryColor),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isHealthy
                                    ? const Color(0xFF2E7D32).withValues(alpha: 0.1)
                                    : const Color(0xFFD32F2F).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isHealthy ? 'Healthy' : conditionName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isHealthy ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Plant Nickname',
                  hintText: 'e.g. My $speciesName',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.drive_file_rename_outline_rounded, color: kPrimaryColor),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Care Notes / Pathology',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.notes_rounded, color: kPrimaryColor),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                label: const Text(
                  'Confirm & Save to Garden',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final newPlant = Plant(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text.trim().isNotEmpty
                        ? nameController.text.trim()
                        : speciesName,
                    species: speciesName,
                    imageUrl: widget.image.path,
                    description: notesController.text.trim().isNotEmpty
                        ? notesController.text.trim()
                        : (widget.diagnosis.careGuide.summary.isNotEmpty
                            ? widget.diagnosis.careGuide.summary
                            : 'Diagnosed as $conditionName.'),
                  );

                  PlantService().addPlant(newPlant);
                  Navigator.pop(ctx);

                  setState(() {
                    _isAdded = true;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🌿 Added "${newPlant.name}" to your Garden!'),
                      backgroundColor: kPrimaryColor,
                      behavior: SnackBarBehavior.floating,
                      action: SnackBarAction(
                        label: 'View Garden',
                        textColor: Colors.white,
                        onPressed: () {
                          Navigator.popUntil(context, (route) => route.isFirst);
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final diagnosis = widget.diagnosis;
    final image = widget.image;
    final isHealthy = diagnosis.diagnosis.isHealthy;
    final speciesName = _getActiveSpeciesName();
    final conditionName = diagnosis.diagnosis.conditionName.replaceAll('_', ' ');

    final healthColor = isHealthy ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F);
    final healthBgColor = isHealthy
        ? const Color(0xFF2E7D32).withValues(alpha: 0.12)
        : const Color(0xFFD32F2F).withValues(alpha: 0.12);

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
                          color: theme.colorScheme.primary.withValues(alpha: 0.2),
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
                      backgroundColor: Colors.black.withValues(alpha: 0.5),
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
                            color: Colors.black.withValues(alpha: 0.25),
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
                        color: diagnosis.isPlant ? theme.colorScheme.primary : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          diagnosis.isPlant
                              ? diagnosis.species.detectedMode
                              : "No recognizable plant foliage or stem found in this photo",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade700,
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

            if (diagnosis.isPlant && (diagnosis.needsUserConfirmation || diagnosis.topCandidates.isNotEmpty || diagnosis.species.topCandidates.isNotEmpty)) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kDefaultPadding),
                child: _buildConfirmPlantCard(context),
              ),
              const SizedBox(height: 16),
            ],

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
                        color: Colors.black.withValues(alpha: 0.04),
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
                    icon: const Icon(Icons.camera_alt_outlined, color: Colors.white),
                    label: const Text(
                      "Retake Photo",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
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
                  border: Border.all(color: healthColor.withValues(alpha: 0.3)),
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

            const SizedBox(height: 14),

            // Two-Shot Inspection Summary Banner (if macro photo was provided)
            if (widget.macroImage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kDefaultPadding),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(widget.macroImage!.path),
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Two-Shot Inspection Active",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF047857),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "Shot 1 (Canopy Species ID) + Shot 2 (Macro Surface Pathology) cross-analyzed.",
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF065F46),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 4-Category Multi-Dimension Quick Scorecard
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kDefaultPadding),
              child: _buildMultiCategoryQuickCard(
                context,
                diagnosis.multiCategory,
                holeAnalysis: diagnosis.holeAnalysis,
              ),
            ),

            // Soil Moisture Interactive Triage Prompt (Touch the top 2 inches of soil)
            if (diagnosis.needsUserSoilCheck)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kDefaultPadding),
                child: _buildSoilCheckCard(context),
              ),

            // Visual Symptom Detections (5-Class YOLO11 Engine)
            if (diagnosis.detections.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kDefaultPadding),
                child: _buildSymptomsCard(context, diagnosis.detections),
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
                        color: Colors.black.withValues(alpha: 0.04),
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
                          macroImage: widget.macroImage,
                          diagnosis: diagnosis,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.analytics_outlined, color: Colors.white),
                  label: const Text(
                    "View Detailed Diagnosis & Treatments",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
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
                child: _isAdded
                    ? ElevatedButton.icon(
                        onPressed: () {
                          Navigator.popUntil(context, (route) => route.isFirst);
                        },
                        icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                        label: const Text(
                          "Added to Garden — View in Garden",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: () => _showAddToGardenSheet(context),
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

  Widget _buildMultiCategoryQuickCard(
    BuildContext context,
    MultiCategoryDiagnosis multiCategory, {
    FoliarHoleAnalysis? holeAnalysis,
  }) {
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? kDarkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: multiCategory.isEntirelyClear
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : Colors.amber.shade700.withValues(alpha: 0.3),
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
          Row(
            children: [
              Icon(Icons.health_and_safety_rounded, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                "4-Category Pathology Overview",
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "Ranked by Severity",
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: kPrimaryColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 4 summary chips in order of severity
          ...multiCategory.orderedBySeverity.map((item) {
            final color = item.severityColor;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(item.categoryIcon, size: 16, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
                    ),
                    child: Text(
                      item.isDetected ? item.statusLabel : "Optimal (Clear)",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Optional Foliar Hole status row
          if (holeAnalysis != null && holeAnalysis.hasHoles) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: holeAnalysis.causeColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: holeAnalysis.causeColor.withValues(alpha: 0.25), width: 0.8),
              ),
              child: Row(
                children: [
                  Icon(holeAnalysis.causeIcon, size: 14, color: holeAnalysis.causeColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Foliar Holes: ${holeAnalysis.causeTitle}",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: holeAnalysis.causeColor,
                      ),
                    ),
                  ),
                  Text(
                    holeAnalysis.holeCountEstimate,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: holeAnalysis.causeColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
