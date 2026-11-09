import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:urbangreen/models/cart_item_model.dart';
import 'package:urbangreen/models/plant_model.dart';
import 'package:urbangreen/models/product_model.dart';
import 'package:urbangreen/services/platform/web_hardware_bridge.dart';
import 'package:urbangreen/services/plant_service.dart';

class RecommendedProduct {
  final Product product;
  final double score;
  final String reason;
  final String badge;

  const RecommendedProduct({
    required this.product,
    required this.score,
    required this.reason,
    required this.badge,
  });
}

class RecommendationService {
  static final RecommendationService _instance =
      RecommendationService._internal();
  factory RecommendationService() => _instance;
  RecommendationService._internal();

  static const String _storageKey = 'store_user_interactions_v1';

  /// Records a user interaction in the app (e.g. viewed product, added to cart, search keyword)
  void recordInteraction({
    required String type,
    List<String> categories = const [],
    String? speciesName,
    String action = 'view',
  }) {
    try {
      final existingJson = WebHardwareBridge.loadStorage(_storageKey);
      List<dynamic> history = [];
      if (existingJson != null && existingJson.isNotEmpty) {
        history = jsonDecode(existingJson) as List<dynamic>;
      }

      final interaction = {
        'type': type,
        'categories': categories,
        'speciesName': speciesName,
        'action': action,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      history.insert(0, interaction);
      // Keep up to 30 most recent interactions
      if (history.length > 30) {
        history = history.sublist(0, 30);
      }

      WebHardwareBridge.saveStorage(_storageKey, jsonEncode(history));
    } catch (e) {
      debugPrint('Error recording interaction: $e');
    }
  }

  /// Clears interaction history (useful for reset or tests)
  void clearInteractions() {
    WebHardwareBridge.removeStorage(_storageKey);
  }

  /// Retrieves recent interaction types and categories
  List<Map<String, dynamic>> getRecentInteractions() {
    try {
      final jsonStr = WebHardwareBridge.loadStorage(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        return list.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return [];
  }

  /// Computes personalized recommendations across all products
  List<RecommendedProduct> getRecommendations({
    required List<Product> allProducts,
    List<Plant>? userPlants,
    List<CartItem>? cartItems,
    bool onlyAvailable = false,
  }) {
    if (allProducts.isEmpty) return [];

    final plants = userPlants ?? PlantService().myPlants;
    final cart = cartItems ?? [];
    final interactions = getRecentInteractions();

    final List<RecommendedProduct> scoredList = [];

    for (final product in allProducts) {
      if (onlyAvailable && product.isSoldOut) continue;

      double score = 10.0;
      String reason = 'Popular curated item for urban indoor gardens';
      String badge = 'Trending';

      // 0. Availability weighting: in-stock items receive heavy priority
      if (product.isAvailable) {
        score += 80.0;
      } else {
        score -= 40.0;
      }

      // 1. Garden Plants Affinity (Signal A: What plants does the user own?)
      if (plants.isNotEmpty) {
        // IoT telemetry check: Does the user have specimens without IoT sensors?
        final unmonitored = plants.where((p) => !p.hasIot).toList();
        final isMonitoring = product.categories.any((c) =>
                c.toLowerCase().contains('monitoring') ||
                c.toLowerCase().contains('grow equipment') ||
                c.toLowerCase().contains('diagnostic')) ||
            product.type == 'Accessories' ||
            product.name.toLowerCase().contains('meter') ||
            product.name.toLowerCase().contains('probe');

        if (unmonitored.isNotEmpty && isMonitoring) {
          score += 55.0;
          final targetPlant = unmonitored.first.name;
          reason = 'Connect & monitor soil moisture for your $targetPlant';
          badge = 'IoT Upgrade';
        }

        // Species-specific plant care matches
        for (final plant in plants) {
          final s = plant.species.toLowerCase();
          final pName = product.name.toLowerCase();

          // Tropical & Broadleaf foliage (Monstera, Pandan, Fiddle Leaf, Pothos, Snake Plant)
          final isFoliage = s.contains('monstera') ||
              s.contains('pandan') ||
              s.contains('fig') ||
              s.contains('pothos') ||
              s.contains('snake') ||
              s.contains('fern');

          if (isFoliage) {
            if (product.type == 'Fertilizer' || pName.contains('seaweed')) {
              score += 46.0;
              reason = 'Foliage tonic & micronutrients for your ${plant.name}';
              badge = 'Sanctuary Match';
              break;
            } else if (product.type == 'Pots & Planters') {
              score += 40.0;
              reason = 'Optimal root breathing & drainage for ${plant.name}';
              badge = 'Pottery Match';
              break;
            } else if (product.type == 'Tool' && pName.contains('shear')) {
              score += 38.0;
              reason =
                  'Precision pruning shears to trim stems on ${plant.name}';
              badge = 'Care Essential';
              break;
            }
          }

          // Edible herbs & vegetables (Curry Leaf, Kesum, Kangkung, Chili, Bitter Gourd, Turmeric)
          final isEdible = s.contains('curry') ||
              s.contains('kesum') ||
              s.contains('kangkung') ||
              s.contains('chili') ||
              s.contains('gourd') ||
              s.contains('turmeric') ||
              s.contains('coriander');

          if (isEdible) {
            if (product.type == 'Pest Control' || pName.contains('neem')) {
              score += 48.0;
              reason = 'Safe organic pest repellent for edible ${plant.name}';
              badge = 'Organic Shield';
              break;
            } else if (pName.contains('grow light') ||
                product.categories.contains('Timer Control')) {
              score += 42.0;
              reason = 'Enhances indoor photosynthetic yield for ${plant.name}';
              badge = 'Yield Booster';
              break;
            }
          }
        }
      } else {
        // If garden is empty: suggest hardy starter plants & beginner watering essentials
        if (product.type == 'Plant') {
          if (product.name.contains('Pothos') ||
              product.name.contains('Snake')) {
            score += 50.0;
            reason =
                'Resilient, low-maintenance beginner specimen for new growers';
            badge = 'Starter Pick';
          }
        } else if (product.type == 'Tool' &&
            product.name.contains('Watering Can')) {
          score += 42.0;
          reason =
              'Essential long-spout watering can for precise root hydration';
          badge = 'Must-Have';
        }
      }

      // 2. Shopping Cart Complementarity (Signal B: Cross-selling complementary gear)
      if (cart.isNotEmpty) {
        final hasPlant = cart.any((c) =>
            allProducts.any((p) => p.id == c.productId && p.type == 'Plant'));
        final hasTool = cart.any((c) =>
            allProducts.any((p) => p.id == c.productId && p.type == 'Tool'));

        if (hasPlant &&
            (product.type == 'Pots & Planters' ||
                product.type == 'Fertilizer')) {
          score += 35.0;
          reason = 'Complementary potting & nutrients for plants in your cart';
          badge = 'Pairs with Cart';
        } else if (hasTool &&
            (product.type == 'Plant' || product.type == 'Accessories')) {
          score += 30.0;
          reason = 'Ideal companion supplies for your selected tools';
          badge = 'Tool Match';
        }
      }

      // 3. User Browsing & Interaction Affinity (Signal C: What categories did they explore?)
      if (interactions.isNotEmpty) {
        for (final item in interactions) {
          final t = item['type']?.toString();
          final cats = (item['categories'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];

          if (t != null && t == product.type) {
            score += 22.0;
            if (badge == 'Trending') {
              reason = 'Curated based on your interest in ${product.type}s';
              badge = 'For You';
            }
            break;
          }

          if (cats.any((c) => product.categories.contains(c))) {
            score += 18.0;
            if (badge == 'Trending') {
              reason = 'Curated matching your recent browsing history';
              badge = 'Discovered';
            }
            break;
          }
        }
      }

      scoredList.add(RecommendedProduct(
        product: product,
        score: score,
        reason: reason,
        badge: badge,
      ));
    }

    // Sort by score descending
    scoredList.sort((a, b) => b.score.compareTo(a.score));

    // Sort in-stock items first, sold out items after available ones
    final inStockRecs = scoredList.where((r) => r.product.isAvailable).toList();
    final soldOutRecs = scoredList.where((r) => r.product.isSoldOut).toList();

    return [...inStockRecs, ...soldOutRecs];
  }
}
