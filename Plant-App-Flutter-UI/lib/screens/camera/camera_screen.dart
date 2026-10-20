import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
    final serverController =
        TextEditingController(text: PlantApiService.serverUrl);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Diagnosis Error'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                errorMsg,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                'AI Backend Server Address:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: serverController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'e.g. http://10.0.2.2:8001 or Cloud Run URL',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Note:\n'
                '• Android Emulator: http://10.0.2.2:8001\n'
                '• Physical Phone (Wi-Fi): http://<Your-PC-IP>:8001\n'
                '• Firebase / Cloud Run: https://<your-service>.a.run.app',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              PlantApiService.setServerUrl(serverController.text.trim());
              Navigator.pop(context);
              _startDiagnosis();
            },
            child: const Text('Update & Retry'),
          ),
        ],
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Plant Snapshot Preview"),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Server Settings',
            onPressed: () {
              final controller =
                  TextEditingController(text: PlantApiService.serverUrl);
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('AI Backend URL'),
                  content: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Server URL',
                      hintText: 'http://10.0.2.2:8001',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        PlantApiService.setServerUrl(controller.text.trim());
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Updated to: ${PlantApiService.serverUrl}'),
                          ),
                        );
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              );
            },
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
                    Colors.black.withOpacity(0.9),
                    Colors.black.withOpacity(0.5),
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
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white70),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
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
                            fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 14),
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
                color: Colors.black.withOpacity(0.75),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Diagnosing Plant...',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _statusMessage,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
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
