import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/screens/camera/plant_capture_result_screen.dart';
import 'package:urbangreen/services/plant_api_service.dart';

class CameraScreen extends StatefulWidget {
  final XFile image;

  const CameraScreen({super.key, required this.image});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool _isAnalyzing = false;
  String _statusMessage = 'Preparing leaf image...';
  XFile? _macroImage;
  int _activePreviewIndex = 0; // 0 = Canopy Shot 1 (Primary), 1 = Macro Shot 2 (Optional)

  @override
  void initState() {
    super.initState();
    // Pre-emptively discover active AI server in the background
    PlantApiService.ensureActiveServerUrl();
  }

  Future<void> _startDiagnosis() async {
    setState(() {
      _isAnalyzing = true;
      _statusMessage = _macroImage != null
          ? 'Analyzing two-shot canopy & micro surface pathology...'
          : 'Connecting to PhytoCare CoreTech AI...';
    });

    try {
      // Step 1: Update status for user feedback
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() {
        _statusMessage = _macroImage != null
            ? 'Cross-referencing species canopy with macro symptoms...'
            : 'Identifying botanical species & pathology...';
      });

      // Step 2: Call the CoreTech AI backend (with optional macro photo)
      final diagnosis = await PlantApiService().diagnosePlant(
        widget.image,
        macroImageFile: _macroImage,
      );

      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
      });

      // Step 3: Navigate to capture result screen with live diagnosis
      // NOTE: widget.image (Canopy photo) is STRICTLY preserved as the primary photo
      // for plant identification and Add to Garden.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PlantCaptureResultScreen(
            image: widget.image,
            macroImage: _macroImage,
            diagnosis: diagnosis,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
      });

      _showErrorDialog(e.toString());
    }
  }

  void _openMacroCaptureSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.zoom_in_rounded, color: Color(0xFF10B981), size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Shot 2: Zoomed-In Macro Detail",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              "Take a close-up photo of a specific problem: a yellowish stem base, leaf hole/bite, rust pustules, or leaf underside to give the AI sub-millimeter symptom precision.",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _pickMacroPhoto(ImageSource.camera);
              },
              icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
              label: const Text(
                "Capture with Camera",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _pickMacroPhoto(ImageSource.gallery);
              },
              icon: const Icon(Icons.photo_library_outlined, color: Colors.white),
              label: const Text(
                "Choose from Gallery",
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white30),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMacroPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
      source: source,
      imageQuality: 95,
    );
    if (img != null && mounted) {
      setState(() {
        _macroImage = img;
        _activePreviewIndex = 1; // Switch preview to display the newly captured macro photo
      });
    }
  }

  void _removeMacroPhoto() {
    setState(() {
      _macroImage = null;
      _activePreviewIndex = 0;
    });
  }

  void _showErrorDialog(String errorMsg) {
    _showServerConfigSheet(errorMsg: errorMsg);
  }

  void _showServerConfigSheet({String? errorMsg}) {
    final serverController = TextEditingController(text: PlantApiService.serverUrl);
    bool isTesting = false;
    String? testResult;
    bool? isOnline;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? kDarkCardColor : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> runTest(String url) async {
            setSheetState(() {
              isTesting = true;
              testResult = null;
              isOnline = null;
            });
            final ok = await PlantApiService.testEndpoint(url);
            if (!context.mounted) return;
            setSheetState(() {
              isTesting = false;
              isOnline = ok;
              testResult = ok
                  ? 'Server is online and responding! 🟢'
                  : 'Cannot reach server at this address 🔴';
            });
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle Bar
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
                    const SizedBox(height: 14),

                    // Title
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: errorMsg != null
                                ? kStatusDanger.withValues(alpha: 0.12)
                                : kPrimaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            errorMsg != null ? Icons.cloud_off_rounded : Icons.cloud_queue_rounded,
                            color: errorMsg != null ? kStatusDanger : kPrimaryColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                errorMsg != null ? 'Diagnosis Connection Issue' : 'AI Server Configuration',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextPrimary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                errorMsg != null ? 'CoreTech AI server not reached' : 'Select cloud or local endpoint',
                                style: const TextStyle(fontSize: 12, color: kTextSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Auto-Discovery Button
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF059669), Color(0xFF10B981)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.28),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        icon: isTesting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.sensors_rounded, color: Colors.white, size: 20),
                        label: Text(
                          isTesting ? 'Auto-Discovering Server...' : 'Auto-Discover Active AI Server',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isTesting
                            ? null
                            : () async {
                                setSheetState(() {
                                  isTesting = true;
                                  testResult = 'Scanning cloud discovery channel & local network...';
                                  isOnline = null;
                                });
                                final discovered = await PlantApiService.ensureActiveServerUrl(forceRefresh: true);
                                final ok = await PlantApiService.testEndpoint(discovered);
                                if (!context.mounted) return;
                                setSheetState(() {
                                  isTesting = false;
                                  serverController.text = discovered;
                                  isOnline = ok;
                                  testResult = ok
                                      ? 'Discovered & Connected: $discovered 🟢'
                                      : 'No server detected. Please ensure launch.py or run_ai_online_tunnel.bat is active.';
                                });
                              },
                      ),
                    ),

                    if (errorMsg != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.info_outline, size: 16, color: Colors.red),
                                SizedBox(width: 6),
                                Text(
                                  'AI Diagnostic Server Offline',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Could not reach AI server at ${PlantApiService.serverUrl}.\n\n• Tap "Auto-Discover Active AI Server" above to automatically fetch the live Cloudflare/LAN address.\n• Or run "run_ai_online_tunnel.bat" on your PC if the server is stopped.',
                              style: TextStyle(fontSize: 11, color: Colors.red.shade900, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),
                    const Text('Quick Connection Presets:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: kTextSecondary)),
                    const SizedBox(height: 8),

                    // Preset Chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.public_rounded, size: 15, color: Color(0xFF0284C7)),
                          label: const Text('Auto-Fetch Cloud Tunnel', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                          backgroundColor: const Color(0xFFF0F9FF),
                          onPressed: () async {
                            setSheetState(() {
                              isTesting = true;
                              testResult = 'Querying active Cloudflare tunnel...';
                            });
                            final discovered = await PlantApiService.ensureActiveServerUrl(forceRefresh: true);
                            serverController.text = discovered;
                            await runTest(discovered);
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.wifi_rounded, size: 15, color: kPrimaryColor),
                          label: const Text('Host PC Wi-Fi (192.168.1.4:8001)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          backgroundColor: kBackgroundColor,
                          onPressed: () {
                            serverController.text = 'http://192.168.1.4:8001';
                            runTest('http://192.168.1.4:8001');
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.cloud_done_rounded, size: 15, color: Color(0xFF0284C7)),
                          label: const Text('Google Cloud Run (Online)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          backgroundColor: isDark ? const Color(0xFF0C243B) : const Color(0xFFF0F9FF),
                          onPressed: () {
                            serverController.text = 'https://phytonet-ai-792382083515.us-central1.run.app';
                            runTest('https://phytonet-ai-792382083515.us-central1.run.app');
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.phone_android_rounded, size: 15, color: Color(0xFFD97706)),
                          label: const Text('Emulator (10.0.2.2:8001)', style: TextStyle(fontSize: 11)),
                          backgroundColor: isDark ? kDarkSurfaceColor : kBackgroundColor,
                          onPressed: () {
                            serverController.text = 'http://10.0.2.2:8001';
                            runTest('http://10.0.2.2:8001');
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.usb_rounded, size: 15, color: Colors.grey),
                          label: const Text('ADB Reverse (127.0.0.1:8001)', style: TextStyle(fontSize: 11)),
                          backgroundColor: isDark ? kDarkSurfaceColor : kBackgroundColor,
                          onPressed: () {
                            serverController.text = 'http://127.0.0.1:8001';
                            runTest('http://127.0.0.1:8001');
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    TextField(
                      controller: serverController,
                      style: const TextStyle(fontSize: 13, color: kTextPrimary),
                      decoration: InputDecoration(
                        labelText: 'Active AI Server URL',
                        hintText: 'https://xxx.trycloudflare.com or http://192.168.1.4:8001',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                        suffixIcon: IconButton(
                          icon: isTesting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.network_ping_rounded, size: 20),
                          tooltip: 'Test Ping',
                          onPressed: isTesting ? null : () => runTest(serverController.text.trim()),
                        ),
                      ),
                    ),

                    if (testResult != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        testResult!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: (isOnline == true) ? kStatusSuccess : kStatusDanger,
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Action Buttons Row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            label: const Text('Cancel'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade700,
                              side: BorderSide(color: Colors.grey.shade400),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.pop(context);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Connect & Diagnose'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              PlantApiService.setServerUrl(serverController.text.trim());
                              Navigator.pop(ctx);
                              _startDiagnosis();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Cloud Deployment Info
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cloud_upload_outlined, size: 18, color: Color(0xFF0284C7)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'To deploy model permanently to Google Cloud Run, run "deploy_to_firebase.bat" on your PC.',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade700, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _retakePhoto() async {
    final picker = ImagePicker();
    final newImage = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 92,
    );

    if (newImage != null && mounted) {
      if (_activePreviewIndex == 1 && _macroImage != null) {
        setState(() {
          _macroImage = newImage;
        });
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CameraScreen(image: newImage),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeFile = _activePreviewIndex == 0 ? widget.image : (_macroImage ?? widget.image);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Clinical Snapshot Preview",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'Server Settings',
            onPressed: () => _showServerConfigSheet(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Captured Image Preview (Displays active shot: Canopy or Macro)
          Positioned.fill(
            child: Image.file(
              File(activeFile.path),
              fit: BoxFit.contain,
            ),
          ),

          // Active Preview Mode Badge on top of image
          Positioned(
            top: 14,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _activePreviewIndex == 0 ? const Color(0xFF10B981) : Colors.amberAccent,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _activePreviewIndex == 0 ? Icons.eco_rounded : Icons.zoom_in_rounded,
                        size: 15,
                        color: _activePreviewIndex == 0 ? const Color(0xFF10B981) : Colors.amberAccent,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        _activePreviewIndex == 0
                            ? "Shot 1: Plant Canopy (Species ID & Garden)"
                            : "Shot 2: Zoomed-In Macro Symptom",
                        style: TextStyle(
                          color: _activePreviewIndex == 0 ? const Color(0xFF10B981) : Colors.amberAccent,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Action Bar & 2-Shot Selector
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.95),
                    Colors.black.withValues(alpha: 0.65),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // TWO-SHOT PRO INSPECTION SELECTOR STRIP
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          // Shot 1 (Canopy / Whole Plant - Mandatory)
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _activePreviewIndex = 0;
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: _activePreviewIndex == 0
                                      ? const Color(0xFF10B981).withValues(alpha: 0.25)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _activePreviewIndex == 0
                                        ? const Color(0xFF10B981)
                                        : Colors.transparent,
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.file(
                                        File(widget.image.path),
                                        width: 28,
                                        height: 28,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            "🌿 Shot 1: Canopy",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            "ID & Garden Base",
                                            style: TextStyle(
                                              color: Colors.white60,
                                              fontSize: 9.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Shot 2 (Optional Macro Detail)
                          Expanded(
                            child: _macroImage == null
                                ? InkWell(
                                    onTap: _openMacroCaptureSheet,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.white24, width: 1),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.add_a_photo_outlined, color: Colors.amberAccent, size: 20),
                                          SizedBox(width: 6),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  "+ Shot 2 (Macro)",
                                                  style: TextStyle(
                                                    color: Colors.amberAccent,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  "Optional Detail",
                                                  style: TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 9.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : InkWell(
                                    onTap: () {
                                      setState(() {
                                        _activePreviewIndex = 1;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: _activePreviewIndex == 1
                                            ? Colors.amberAccent.withValues(alpha: 0.25)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _activePreviewIndex == 1
                                              ? Colors.amberAccent
                                              : Colors.transparent,
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: Image.file(
                                              File(_macroImage!.path),
                                              width: 28,
                                              height: 28,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  "🔍 Shot 2: Macro",
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  "Attached",
                                                  style: TextStyle(
                                                    color: Colors.amberAccent,
                                                    fontSize: 9.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          InkWell(
                                            onTap: _removeMacroPhoto,
                                            child: const Padding(
                                              padding: EdgeInsets.all(2),
                                              child: Icon(Icons.close_rounded, size: 16, color: Colors.white70),
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

                    // RETAKE & DIAGNOSE BUTTONS
                    Row(
                      children: [
                        // Retake Button
                        OutlinedButton.icon(
                          onPressed: _isAnalyzing ? null : _retakePhoto,
                          icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                          label: Text(
                            _activePreviewIndex == 1 ? "Retake Macro" : "Retake",
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white70, width: 1.4),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Diagnose Button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isAnalyzing ? null : _startDiagnosis,
                            icon: Icon(
                              _macroImage != null ? Icons.auto_awesome_rounded : Icons.biotech_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                            label: Text(
                              _macroImage != null ? "Diagnose (2-Shot Pro)" : "Diagnose Plant",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _macroImage != null ? const Color(0xFF059669) : kPrimaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Loading Overlay
          if (_isAnalyzing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.75),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: kPrimaryColor),
                        const SizedBox(height: 20),
                        const Text(
                          'Diagnosing Plant...',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: kTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _statusMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
