import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:urbangreen/models/plant_diagnosis_model.dart';
import 'platform/web_hardware_bridge.dart';
import 'app_logger_service.dart';

class PlantApiService {
  // Singleton pattern
  static final PlantApiService _instance = PlantApiService._internal();
  factory PlantApiService() => _instance;
  PlantApiService._internal() {
    _loadStoredUrl();
  }

  static const String discoveryTopic = 'urbangreen_coretech_ai_discovery';
  static const String discoveryCloudUrl = 'https://ntfy.sh/$discoveryTopic/json?poll=1';
  static const String discoveryGithubRawUrl =
      'https://raw.githubusercontent.com/Ken4502/FYP_AppIntegration/main/active_server_url.txt';

  static String _serverUrl = 'http://192.168.1.4:8001';
  static bool _isDiscovering = false;
  static DateTime? _lastDiscoverySuccess;

  static String get serverUrl => _serverUrl;

  static void _loadStoredUrl() {
    final saved = WebHardwareBridge.loadStorage('ai_server_url');
    if (saved != null && saved.trim().isNotEmpty) {
      final trimmed = saved.trim();
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

  /// Known candidate endpoints for fallback probing
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

    candidates.add('http://192.168.1.4:8001');
    candidates.add('https://phytonet-ai-792382083515.us-central1.run.app');
    candidates.add('http://10.0.2.2:8001');

    return candidates.toList();
  }

  /// Automatically discovers the active AI server across:
  /// 1. Real-time Cloud Discovery (ntfy.sh topic)
  /// 2. Local Wi-Fi UDP Broadcast Beacon (Port 8002)
  /// 3. Secondary GitHub raw sync
  /// 4. Local network IP / candidate probes
  static Future<String?> discoverActiveServer({bool forceRefresh = false}) async {
    if (!forceRefresh && _serverUrl.isNotEmpty && _lastDiscoverySuccess != null) {
      if (DateTime.now().difference(_lastDiscoverySuccess!).inSeconds < 45) {
        return _serverUrl;
      }
    }

    if (_isDiscovering) {
      // Avoid duplicate concurrent discovery calls
      await Future.delayed(const Duration(milliseconds: 300));
      return _serverUrl;
    }

    _isDiscovering = true;
    try {
      _loadStoredUrl();

      // Quick check: If current _serverUrl is already online and responsive, keep it
      if (!forceRefresh && await testEndpoint(_serverUrl, timeoutMs: 1500)) {
        _lastDiscoverySuccess = DateTime.now();
        return _serverUrl;
      }

      // Priority 1: Query Global Cloud Discovery Service (ntfy.sh)
      try {
        final uri = Uri.parse(discoveryCloudUrl);
        final res = await http.get(uri).timeout(const Duration(milliseconds: 2800));
        if (res.statusCode == 200) {
          final lines = res.body.trim().split('\n').where((l) => l.trim().isNotEmpty).toList();
          for (final line in lines.reversed) {
            try {
              final msgObj = jsonDecode(line) as Map<String, dynamic>;
              final rawContent = msgObj['message'] ?? msgObj['title'] ?? '';
              String? tunnelCandidate;
              String? localCandidate;

              if (rawContent.toString().startsWith('{')) {
                final payload = jsonDecode(rawContent.toString()) as Map<String, dynamic>;
                tunnelCandidate = payload['tunnel_url']?.toString();
                localCandidate = payload['local_url']?.toString();
              } else if (rawContent.toString().startsWith('http')) {
                tunnelCandidate = rawContent.toString().trim();
              }

              // Test tunnel URL first (works globally everywhere)
              if (tunnelCandidate != null && tunnelCandidate.isNotEmpty) {
                if (await testEndpoint(tunnelCandidate, timeoutMs: 2200)) {
                  setServerUrl(tunnelCandidate);
                  _lastDiscoverySuccess = DateTime.now();
                  return tunnelCandidate;
                }
              }

              // Test local URL next (if device happens to be on local Wi-Fi)
              if (localCandidate != null && localCandidate.isNotEmpty) {
                if (await testEndpoint(localCandidate, timeoutMs: 1500)) {
                  setServerUrl(localCandidate);
                  _lastDiscoverySuccess = DateTime.now();
                  return localCandidate;
                }
              }
            } catch (_) {}
          }
        }
      } catch (_) {}

      // Priority 2: Query Local UDP LAN Beacon (Port 8002) for instant Wi-Fi discovery
      if (!kIsWeb) {
        try {
          final rawSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
          rawSocket.broadcastEnabled = true;
          final pingBytes = utf8.encode('URBANGREEN_DISCOVERY_PING');
          rawSocket.send(pingBytes, InternetAddress('255.255.255.255'), 8002);

          final completer = Completer<String?>();
          late StreamSubscription sub;
          sub = rawSocket.listen((event) {
            if (event == RawSocketEvent.read) {
              final dg = rawSocket.receive();
              if (dg != null) {
                try {
                  final text = utf8.decode(dg.data);
                  final map = jsonDecode(text) as Map<String, dynamic>;
                  final discovered = map['tunnel_url'] ?? map['local_url'];
                  if (discovered != null && !completer.isCompleted) {
                    completer.complete(discovered.toString());
                  }
                } catch (_) {}
              }
            }
          });

          final udpDiscovered = await completer.future
              .timeout(const Duration(milliseconds: 1200), onTimeout: () => null);
          await sub.cancel();
          rawSocket.close();

          if (udpDiscovered != null && await testEndpoint(udpDiscovered, timeoutMs: 1500)) {
            setServerUrl(udpDiscovered);
            _lastDiscoverySuccess = DateTime.now();
            return udpDiscovered;
          }
        } catch (_) {}
      }

      // Priority 3: Query Secondary GitHub Raw sync
      try {
        final gitUri = Uri.parse(discoveryGithubRawUrl);
        final gitRes = await http.get(gitUri).timeout(const Duration(milliseconds: 2000));
        if (gitRes.statusCode == 200 && gitRes.body.trim().startsWith('http')) {
          final gitUrl = gitRes.body.trim().split('\n').first.trim();
          if (await testEndpoint(gitUrl, timeoutMs: 2000)) {
            setServerUrl(gitUrl);
            _lastDiscoverySuccess = DateTime.now();
            return gitUrl;
          }
        }
      } catch (_) {}

      // Priority 4: Test standard known candidate endpoints
      for (final candidate in candidateUrls) {
        if (await testEndpoint(candidate, timeoutMs: 1500)) {
          setServerUrl(candidate);
          _lastDiscoverySuccess = DateTime.now();
          return candidate;
        }
      }

      return _serverUrl;
    } finally {
      _isDiscovering = false;
    }
  }

  /// Ensure an active server URL is configured, discovering it if needed
  static Future<String> ensureActiveServerUrl({bool forceRefresh = false}) async {
    final discovered = await discoverActiveServer(forceRefresh: forceRefresh);
    return discovered ?? _serverUrl;
  }

  static Future<bool> testEndpoint(String baseUrl, {int timeoutMs = 2500}) async {
    try {
      var clean = baseUrl.trim();
      if (clean.endsWith('/')) {
        clean = clean.substring(0, clean.length - 1);
      }
      final uri = Uri.parse('$clean/api/info');
      final res = await http.get(uri).timeout(Duration(milliseconds: timeoutMs));
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
    AppLoggerService().info(
      'PhytoCareAI',
      'Sending plant diagnosis request to $_serverUrl (group: $plantGroup)',
      category: LogCategory.http,
      metadata: {'url': uri.toString(), 'filename': imageFile.name},
    );

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
          AppLoggerService().warning(
            'PhytoCareAI',
            'Connection timed out after 40s waiting for AI diagnosis at $_serverUrl',
            category: LogCategory.http,
          );
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
          final msg = data['message'] ?? 'AI diagnosis returned an error.';
          AppLoggerService().error('PhytoCareAI', 'AI Diagnosis Error: $msg', category: LogCategory.http);
          throw Exception(msg);
        }

        final result = PlantDiagnosisResponse.fromJson(data);
        AppLoggerService().info(
          'PhytoCareAI',
          'AI Diagnosis Success: ${result.species.name} (${(result.species.confidence * 100).toStringAsFixed(1)}% confidence)',
          category: LogCategory.http,
          metadata: {'species': result.species.name, 'confidence': result.species.confidence, 'diagnosis': result.diagnosis.conditionName},
        );
        return result;
      } else {
        AppLoggerService().error('PhytoCareAI', 'HTTP ${response.statusCode}: ${response.body}', category: LogCategory.http);
        throw Exception(
          'AI server responded with HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } on SocketException catch (e) {
      AppLoggerService().error('PhytoCareAI', 'Socket Exception connecting to $_serverUrl', category: LogCategory.http, error: e);
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
