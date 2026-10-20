import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:urbangreen/models/plant_diagnosis_model.dart';

class PlantApiService {
  // Singleton pattern
  static final PlantApiService _instance = PlantApiService._internal();
  factory PlantApiService() => _instance;
  PlantApiService._internal();

  /// Default API endpoint:
  /// - 127.0.0.1:8001 for Physical Phone with ADB reverse, Web, Desktop, iOS
  /// - 192.168.1.23:8001 for Host PC Wi-Fi IP
  /// - 10.0.2.2:8001 for Android Emulator
  static String _serverUrl = 'http://127.0.0.1:8001';

  static String get serverUrl => _serverUrl;

  static void setServerUrl(String url) {
    if (url.endsWith('/')) {
      _serverUrl = url.substring(0, url.length - 1);
    } else {
      _serverUrl = url;
    }
  }

  /// Candidate backend URLs for auto-discovery across physical phone, emulator, and local Wi-Fi
  static const List<String> _candidateUrls = [
    'http://127.0.0.1:8001',
    'http://192.168.1.23:8001',
    'http://10.0.2.2:8001',
  ];

  /// Auto-discover an active backend server if the current address is unreachable
  static Future<String> ensureActiveServerUrl() async {
    if (await _testEndpoint(_serverUrl)) {
      return _serverUrl;
    }

    for (final candidate in _candidateUrls) {
      if (candidate != _serverUrl && await _testEndpoint(candidate)) {
        _serverUrl = candidate;
        return _serverUrl;
      }
    }

    return _serverUrl;
  }

  static Future<bool> _testEndpoint(String baseUrl) async {
    try {
      final uri = Uri.parse('$baseUrl/api/info');
      final res = await http.get(uri).timeout(const Duration(seconds: 2));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Sends a captured plant photo to the CoreTech AI backend (/api/predict)
  Future<PlantDiagnosisResponse> diagnosePlant(
    XFile imageFile, {
    String plantGroup = 'auto',
  }) async {
    // Auto-discover active server URL before uploading photo
    await ensureActiveServerUrl();

    final uri = Uri.parse('$_serverUrl/api/predict');

    try {
      final request = http.MultipartRequest('POST', uri);

      // Add the plant target group (defaults to auto-identification)
      request.fields['plant'] = plantGroup;

      // Attach the captured image file
      final bytes = await imageFile.readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: imageFile.name.isNotEmpty ? imageFile.name : 'plant_capture.jpg',
      );
      request.files.add(multipartFile);

      // Send request with 45-second timeout for model inference
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          throw Exception(
            'Connection timed out while waiting for AI diagnosis. Please verify the AI backend server is running at $_serverUrl',
          );
        },
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final Map<String, dynamic> data = jsonDecode(decodedBody) as Map<String, dynamic>;

        if (data['status'] == 'error') {
          throw Exception(data['message'] ?? 'AI diagnosis returned an error.');
        }

        return PlantDiagnosisResponse.fromJson(data);
      } else {
        throw Exception(
          'Server returned HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } on SocketException catch (e) {
      throw Exception(
        'Unable to connect to CoreTech AI backend at $_serverUrl. Please ensure the backend is started (run_backend.bat) and accessible. Details: $e',
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Check if the AI backend is currently online and responding
  Future<bool> checkHealth() async {
    return _testEndpoint(_serverUrl);
  }
}


