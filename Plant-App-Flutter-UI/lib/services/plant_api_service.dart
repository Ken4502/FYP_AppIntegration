import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:urbangreen/models/plant_diagnosis_model.dart';
import 'platform/web_hardware_bridge.dart';

class PlantApiService {
  // Singleton pattern
  static final PlantApiService _instance = PlantApiService._internal();
  factory PlantApiService() => _instance;
  PlantApiService._internal() {
    _loadStoredUrl();
  }

  /// Default API endpoint:
  /// - Host PC Wi-Fi IP: http://192.168.1.4:8001 (Port 8001 PhytoCare Ultra)
  /// - Cloudflare Tunnel: https://promotional-chocolate-born-zus.trycloudflare.com
  /// - Google Cloud Run: https://phytonet-ai-792382083515.us-central1.run.app
  /// - Android Emulator: http://10.0.2.2:8001
  static String _serverUrl = 'http://192.168.1.4:8001';

  static String get serverUrl => _serverUrl;

  static void _loadStoredUrl() {
    final saved = WebHardwareBridge.loadStorage('ai_server_url');
    if (saved != null && saved.trim().isNotEmpty) {
      final trimmed = saved.trim();
      // If phone has old 127.0.0.1 or expired tunnel/old IP in storage, auto-upgrade to host PC Wi-Fi IP
      if (!trimmed.contains('127.0.0.1') &&
          !trimmed.contains('backed-strengthening-oecd-pos') &&
          !trimmed.contains('192.168.1.9')) {
        _serverUrl = trimmed;
      } else {
        _serverUrl = 'http://192.168.1.4:8001';
      }
    }
  }

  static void setServerUrl(String url) {
    var clean = url.trim();
    if (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    _serverUrl = clean;
    WebHardwareBridge.saveStorage('ai_server_url', clean);
  }

  /// Known candidates for auto-discovery across physical phone, emulator, and Cloud Run / Cloudflare
  static List<String> get candidateUrls {
    final saved = WebHardwareBridge.loadStorage('ai_server_url');
    final Set<String> candidates = {};

    if (saved != null &&
        saved.trim().isNotEmpty &&
        !saved.contains('127.0.0.1') &&
        !saved.contains('backed-strengthening-oecd-pos') &&
        !saved.contains('192.168.1.9')) {
      candidates.add(saved.trim());
    }

    // High priority: Current Host PC Wi-Fi IP (Port 8001) and active Cloudflare Tunnel
    candidates.add('https://promotional-chocolate-born-zus.trycloudflare.com');
    candidates.add('http://192.168.1.4:8001');
    // Google Cloud Run
    candidates.add('https://phytonet-ai-792382083515.us-central1.run.app');
    // Android Emulator Host Bridge
    candidates.add('http://10.0.2.2:8001');

    return candidates.toList();
  }

  /// Auto-discover an active backend server if the current address is unreachable
  static Future<String> ensureActiveServerUrl() async {
    _loadStoredUrl();

    if (await testEndpoint(_serverUrl)) {
      return _serverUrl;
    }

    for (final candidate in candidateUrls) {
      if (candidate != _serverUrl && await testEndpoint(candidate)) {
        setServerUrl(candidate);
        return _serverUrl;
      }
    }

    return _serverUrl;
  }

  static Future<bool> testEndpoint(String baseUrl) async {
    try {
      var clean = baseUrl.trim();
      if (clean.endsWith('/')) {
        clean = clean.substring(0, clean.length - 1);
      }
      final uri = Uri.parse('$clean/api/info');
      final res = await http.get(uri).timeout(const Duration(milliseconds: 2500));
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
    // Attempt auto-discovery if current URL is inactive
    await ensureActiveServerUrl();

    final uri = Uri.parse('$_serverUrl/api/predict');

    try {
      final request = http.MultipartRequest('POST', uri);
      request.fields['plant'] = plantGroup;

      final bytes = await imageFile.readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: imageFile.name.isNotEmpty ? imageFile.name : 'plant_capture.jpg',
      );
      request.files.add(multipartFile);

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 40),
        onTimeout: () {
          throw Exception(
            'Connection timed out after 40s waiting for AI diagnosis. Please verify the AI backend server is active at $_serverUrl',
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
          'AI server responded with HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } on SocketException catch (e) {
      final isLocalLoopback = _serverUrl.contains('127.0.0.1');
      final tip = isLocalLoopback
          ? 'Notice: "127.0.0.1" refers to this mobile device itself, not your host computer. For a physical phone, please switch to your PC Wi-Fi IP (http://192.168.1.4:8001) or use the Cloudflare Tunnel.'
          : 'Please ensure the CoreTech server is running (run_ai_models.bat or run_ai_online_tunnel.bat).';

      throw Exception(
        'Unable to connect to CoreTech AI backend at $_serverUrl.\n\n$tip\n\nSocket Details: $e',
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Provides an intelligent offline simulation response with high-fidelity clinical pathology
  /// data, allowing complete UI/UX testing and demonstration even when offline.
  static PlantDiagnosisResponse generateOfflineDemoDiagnosis(XFile imageFile) {
    return PlantDiagnosisResponse.fromJson({
      'status': 'success',
      'is_plant': true,
      'inference_time_ms': 142.5,
      'disease_available': true,
      'species': {
        'name': 'Monstera Deliciosa (Swiss Cheese Plant)',
        'confidence': 94.2,
        'detected_mode': 'FLAGSHIP_CLASSIFIER_V5',
        'top_candidates': [
          {'species': 'Monstera Deliciosa', 'confidence': 94.2},
          {'species': 'Philodendron Bipinnatifidum', 'confidence': 3.8},
          {'species': 'Epipremnum Aureum (Golden Pothos)', 'confidence': 1.2},
        ],
      },
      'diagnosis': {
        'condition_name': 'Bacterial Leaf Spot',
        'category': 'Pathogenic Bacteria (Xanthomonas / Pseudomonas)',
        'is_healthy': false,
        'confidence': 89.5,
        'severity': 'Moderate (PDI: 24.6%)',
      },
      'spots': {
        'has_spots': true,
        'spots_count': 4,
        'infected_area_pct': 5.8,
        'status_message': '4 localized chlorotic lesions with water-soaked halos detected',
      },
      'pdi_rating': {
        'grade': 2,
        'label': 'Grade 2 (Moderate)',
        'infected_pct': 24.6,
        'color': '#f59e0b',
        'clinical_action': 'Isolate specimen, excise infected leaflets, and treat with copper bactericide.',
      },
      'co_alerts': [
        {
          'type': 'Humidity Alert',
          'badge': 'RH > 75%',
          'message': 'Ambient humidity elevated. Increase laminar ventilation to suppress bacterial spread.',
        },
      ],
      'care_guide': {
        'plant_name': 'Monstera Deliciosa',
        'condition_name': 'Bacterial Leaf Spot',
        'is_healthy': false,
        'severity': 'Moderate',
        'category': 'Pathogenic Bacteria',
        'summary': 'Bacterial foliar infection characterized by water-soaked lesions with chlorotic yellow halos.',
        'immediate_actions': [
          'Isolate this specimen at least 1.5 meters away from other foliage to prevent aerosolized transmission.',
          'Sterilize shears with 70% isopropyl alcohol and excise heavily infected leaflets showing yellow halos.',
          'Water exclusively at the substrate soil base; avoid wetting leaf surfaces.',
        ],
        'treatment': {
          'organic': [
            'Apply copper octanoate (copper soap) fungicidal bactericide to foliage every 7-10 days.',
            'Spray cold-pressed pure neem oil solution (0.5% concentration) to boost systemic foliar defenses.',
          ],
          'chemical': [
            'For persistent lesions: Apply fixed copper hydroxide spray at 1.5g per liter of water.',
          ],
        },
        'prevention': [
          'Ensure morning watering so leaf moisture dries thoroughly before evening.',
          'Maintain minimum 30cm spacing between indoor pots for continuous airflow.',
        ],
        'symptoms': [
          'Water-soaked translucent lesions with chlorotic yellow halos concentrated along lower leaf margins.',
        ],
        'causes': [
          'Excessive ambient humidity, overhead droplet splashing, and poor air circulation facilitating bacterial entry via stomata.',
        ],
      },
      'predictions': [
        {
          'rank': 1,
          'class_name': 'Monstera___Bacterial_Leaf_Spot',
          'condition_name': 'Bacterial Leaf Spot',
          'confidence': 89.5,
          'is_healthy': false,
          'severity': 'Moderate',
          'category': 'Bacterial Pathogen',
        },
        {
          'rank': 2,
          'class_name': 'Monstera___Anthracnose',
          'condition_name': 'Anthracnose (Colletotrichum)',
          'confidence': 7.1,
          'is_healthy': false,
          'severity': 'Low',
          'category': 'Fungal Pathogen',
        },
        {
          'rank': 3,
          'class_name': 'Monstera___Healthy',
          'condition_name': 'Healthy Leaf',
          'confidence': 3.4,
          'is_healthy': true,
          'severity': 'None',
          'category': 'Healthy',
        },
      ],
      'abiotic': {
        'chlorosis_score': 18.4,
        'necrosis_score': 6.2,
        'stress_level': 'Moderate',
        'stress_type': 'Hydration Imbalance',
        'recommendation': 'Soil moisture is well-balanced within 35%-60% target range.',
      },
    });
  }

  /// Check if the AI backend is currently online and responding
  Future<bool> checkHealth() async {
    return testEndpoint(_serverUrl);
  }
}
