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

  Future<void> _startDiagnosis() async {
    setState(() {
      _isAnalyzing = true;
      _statusMessage = 'Connecting to PhytoCare CoreTech AI...';
    });

    try {
      // Step 1: Update status for user feedback
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Identifying botanical species & pathology...';
      });

      // Step 2: Call the CoreTech AI backend
      final diagnosis = await PlantApiService().diagnosePlant(widget.image);

      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
      });

      // Step 3: Navigate to capture result screen with live diagnosis
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PlantCaptureResultScreen(
            image: widget.image,
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

  void _showErrorDialog(String errorMsg) {
    _showServerConfigSheet(errorMsg: errorMsg);
  }

  void _showServerConfigSheet({String? errorMsg}) {
    final serverController = TextEditingController(text: PlantApiService.serverUrl);
    bool isTesting = false;
    String? testResult;
    bool? isOnline;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
                              'Could not reach AI server at ${PlantApiService.serverUrl}.\n\nTo host on your laptop, run either:\n• "run_ai_backend.bat" (Local Wi-Fi at 192.168.1.9:8001)\n• "start_online_tunnel.bat" (Cloudflare Online Tunnel)\n\nOr tap "Host PC Wi-Fi" below to connect:',
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
                          label: const Text('Online Cloud Tunnel (HTTPS)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                          backgroundColor: const Color(0xFFF0F9FF),
                          onPressed: () {
                            serverController.text = 'https://backed-strengthening-oecd-pos.trycloudflare.com';
                            runTest('https://backed-strengthening-oecd-pos.trycloudflare.com');
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
                          avatar: const Icon(Icons.wifi_rounded, size: 15, color: kPrimaryColor),
                          label: const Text('Host PC Wi-Fi (192.168.1.9:8001)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          backgroundColor: kBackgroundColor,
                          onPressed: () {
                            serverController.text = 'http://192.168.1.9:8001';
                            runTest('http://192.168.1.9:8001');
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.cloud_done_rounded, size: 15, color: Color(0xFF0284C7)),
                          label: const Text('Google Cloud Run (Online)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          backgroundColor: const Color(0xFFF0F9FF),
                          onPressed: () {
                            serverController.text = 'https://phytonet-ai-792382083515.us-central1.run.app';
                            runTest('https://phytonet-ai-792382083515.us-central1.run.app');
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.phone_android_rounded, size: 15, color: Color(0xFFD97706)),
                          label: const Text('Emulator (10.0.2.2:8001)', style: TextStyle(fontSize: 11)),
                          backgroundColor: kBackgroundColor,
                          onPressed: () {
                            serverController.text = 'http://10.0.2.2:8001';
                            runTest('http://10.0.2.2:8001');
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.usb_rounded, size: 15, color: Colors.grey),
                          label: const Text('ADB Reverse (127.0.0.1:8001)', style: TextStyle(fontSize: 11)),
                          backgroundColor: kBackgroundColor,
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
                        hintText: 'http://192.168.1.9:8001 or Cloud Run URL',
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
                            icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                            label: const Text('Offline Demo Mode'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0284C7),
                              side: const BorderSide(color: Color(0xFF0284C7)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              final demoDiagnosis = PlantApiService.generateOfflineDemoDiagnosis(widget.image);
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PlantCaptureResultScreen(
                                    image: widget.image,
                                    diagnosis: demoDiagnosis,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Save & Retry'),
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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CameraScreen(image: newImage),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Plant Snapshot Preview",
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
          // Captured Image Preview
          Positioned.fill(
            child: Image.file(
              File(widget.image.path),
              fit: BoxFit.contain,
            ),
          ),

          // Bottom Action Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.9),
                    Colors.black.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Retake Button
                    OutlinedButton.icon(
                      onPressed: _isAnalyzing ? null : _retakePhoto,
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      label: const Text(
                        "Retake",
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70, width: 1.5),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),

                    // Diagnose Button
                    ElevatedButton.icon(
                      onPressed: _isAnalyzing ? null : _startDiagnosis,
                      icon: const Icon(Icons.biotech, color: Colors.white),
                      label: const Text(
                        "Diagnose",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
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
