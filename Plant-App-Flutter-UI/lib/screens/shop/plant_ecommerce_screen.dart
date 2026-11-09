import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/models/cart_item_model.dart';
import 'package:urbangreen/models/cart_model.dart';
import 'package:urbangreen/models/product_model.dart';
import 'package:urbangreen/screens/shop/cart_screen.dart';
import 'package:urbangreen/services/achievement_service.dart';
import 'package:urbangreen/services/plant_service.dart';
import 'package:urbangreen/services/recommendation_service.dart';

class PlantEcommerceScreen extends StatefulWidget {
  const PlantEcommerceScreen({super.key});

  @override
  State<PlantEcommerceScreen> createState() => _PlantEcommerceScreenState();
}

class _PlantEcommerceScreenState extends State<PlantEcommerceScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _onlyInStock = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  final List<Product> _fallbackPlants = [
    Product(
      id: 'p1',
      name: 'Monstera Deliciosa',
      price: 48.00,
      imageUrl: 'assets/images/image_1.png',
      type: 'Plant',
      description: 'Lush indoor tropical plant with striking split leaves.',
      stock: 12,
    ),
    Product(
      id: 'p2',
      name: 'Snake Plant Laurentii',
      price: 28.00,
      imageUrl: 'assets/images/image_2.png',
      type: 'Plant',
      description: 'Hardy air-purifying succulent, ideal for indoor corners.',
      stock: 15,
    ),
    Product(
      id: 'p3',
      name: 'Fiddle Leaf Fig',
      price: 68.00,
      imageUrl: 'assets/images/image_3.png',
      type: 'Plant',
      description: 'Popular architectural houseplant with violin-shaped foliage.',
      stock: 8,
    ),
    Product(
      id: 'p4',
      name: 'Golden Pothos',
      price: 18.00,
      imageUrl: 'assets/images/img_main.png',
      type: 'Plant',
      description: 'Fast-growing trailing vine tolerant of low-light spaces.',
      stock: 20,
    ),
    Product(
      id: 'p_soldout',
      name: 'Variegated Monstera Albo',
      price: 188.00,
      imageUrl: 'assets/images/image_1.png',
      type: 'Plant',
      description: 'Rare highly sought-after variegated specimen with pure white fenestrated leaves.',
      stock: 0,
      categories: ['Rare Specimen'],
    ),
  ];

  final List<Product> _fallbackEquipment = [
    Product(
      id: 'e1',
      name: 'Long-Spout Nordic Watering Can',
      price: 46.00,
      imageUrl: 'assets/images/img.png',
      type: 'Tool',
      description: 'Stainless steel long-stem watering can for precise root hydration.',
      stock: 14,
    ),
    Product(
      id: 'e2',
      name: 'SK-5 Titanium Pruning Shears',
      price: 39.90,
      imageUrl: 'assets/images/image_1.png',
      type: 'Tool',
      description: 'Sharp precision bypassed pruning shears for pruning dead leaves.',
      stock: 9,
    ),
    Product(
      id: 'e3',
      name: 'Minimalist Matte Ceramic Pot',
      price: 39.00,
      imageUrl: 'assets/images/image_2.png',
      type: 'Pots & Planters',
      description: 'Drainage-enabled glazed ceramic pot with saucer.',
      stock: 18,
    ),
    Product(
      id: 'e_soldout',
      name: 'Solid Copper Misting Wand',
      price: 79.00,
      imageUrl: 'assets/images/img.png',
      type: 'Tool',
      description: 'Handcrafted solid copper extension watering wand with ultra-fine misting nozzle.',
      stock: 0,
    ),
  ];

  final List<Product> _fallbackFertilizer = [
    Product(
      id: 'f1',
      name: 'Cold-Pressed Seaweed Booster',
      price: 34.00,
      imageUrl: 'assets/images/image_2.png',
      type: 'Fertilizer',
      description: 'Organic micronutrient tonic for vibrant green foliage.',
      stock: 25,
    ),
    Product(
      id: 'f2',
      name: 'Cold-Pressed Neem Oil Spray',
      price: 26.50,
      imageUrl: 'assets/images/image_3.png',
      type: 'Pest Control',
      description: 'Ready-to-use botanical insecticide & fungicide for spider mites & scale.',
      stock: 16,
    ),
    Product(
      id: 'f_soldout',
      name: 'Osmocote Slow-Release Prills',
      price: 24.00,
      imageUrl: 'assets/images/image_2.png',
      type: 'Fertilizer',
      description: 'Controlled 6-month nutrient release polymer-coated granules.',
      stock: 0,
    ),
  ];

  final List<Product> _fallbackIot = [
    Product(
      id: 'i1',
      name: '3-in-1 Soil Hydration & pH Meter',
      price: 29.00,
      imageUrl: 'assets/images/image_3.png',
      type: 'Accessories',
      categories: ['Monitoring'],
      description: 'Battery-free probe for soil moisture, pH, and ambient light level.',
      stock: 7,
    ),
    Product(
      id: 'i2',
      name: 'Full-Spectrum LED Grow Light',
      price: 58.00,
      imageUrl: 'assets/images/image_1.png',
      type: 'Accessories',
      categories: ['Timer Control', 'Grow Equipment'],
      description: 'Indoor plant grow light with automated timer controller.',
      stock: 5,
    ),
    Product(
      id: 'i_soldout',
      name: 'Smart LoRaWAN Sub-GHz Hub',
      price: 139.00,
      imageUrl: 'assets/images/image_3.png',
      type: 'Accessories',
      categories: ['Monitoring', 'Gateway'],
      description: 'Long-range low-power gateway connecting up to 64 soil sensors across mesh.',
      stock: 0,
    ),
  ];

  List<Product> _filterAndSort(List<Product> products) {
    var list = products;
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      list = list.where((p) {
        final name = p.name.toLowerCase();
        final type = p.type.toLowerCase();
        final desc = p.description.toLowerCase();
        final cats = p.categories.map((c) => c.toLowerCase()).join(' ');
        return name.contains(query) ||
            type.contains(query) ||
            desc.contains(query) ||
            cats.contains(query);
      }).toList();
    }

    if (_onlyInStock) {
      return list.where((p) => p.isAvailable).toList();
    }

    // Strictly order available products first, and sold out products at the bottom
    final available = list.where((p) => p.isAvailable).toList();
    final soldOut = list.where((p) => p.isSoldOut).toList();
    return [...available, ...soldOut];
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartModel>(context);

    Stream<QuerySnapshot>? firestoreStream;
    try {
      firestoreStream = FirebaseFirestore.instance.collection('plant_supplies').snapshots();
    } catch (_) {
      firestoreStream = null;
    }

    return StreamBuilder<QuerySnapshot>(
      stream: firestoreStream,
      builder: (context, snapshot) {
        List<Product> allProducts = [];
        List<Product> plantsList = _fallbackPlants;
        List<Product> equipmentList = _fallbackEquipment;
        List<Product> fertilizerList = _fallbackFertilizer;
        List<Product> iotList = _fallbackIot;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          allProducts = snapshot.data!.docs.map((doc) => Product.fromFirestore(doc)).toList();

          final livePlants = allProducts.where((p) => p.type == 'Plant').toList();
          final liveEquipment = allProducts.where((p) =>
              p.type == 'Tool' || p.type == 'Pots & Planters' || p.type == 'Accessories').toList();
          final liveFertilizer = allProducts.where((p) =>
              p.type == 'Fertilizer' || p.type == 'Soil & Substrate' || p.type == 'Pest Control' || p.type == 'Seeds').toList();
          final liveIot = allProducts.where((p) =>
              p.categories.any((c) => c == 'Monitoring' || c == 'Timer Control' || c == 'Grow Equipment' || c == 'Diagnostic')).toList();

          if (livePlants.isNotEmpty) plantsList = livePlants;
          if (liveEquipment.isNotEmpty) equipmentList = liveEquipment;
          if (liveFertilizer.isNotEmpty) fertilizerList = liveFertilizer;
          if (liveIot.isNotEmpty) iotList = liveIot;
        } else {
          allProducts = [
            ..._fallbackPlants,
            ..._fallbackEquipment,
            ..._fallbackFertilizer,
            ..._fallbackIot,
          ];
        }

        // Calculate AI Recommendations based on Sanctuary, Cart, and Browsing
        final recommendations = RecommendationService().getRecommendations(
          allProducts: allProducts,
          userPlants: PlantService().myPlants,
          cartItems: cart.items,
          onlyAvailable: _onlyInStock,
        );

        final Map<String, RecommendedProduct> recMap = {
          for (final r in recommendations) r.product.id: r,
        };

        final recommendedProducts = _filterAndSort(recommendations.map((r) => r.product).toList());
        final filteredPlants = _filterAndSort(plantsList);
        final filteredEquipment = _filterAndSort(equipmentList);
        final filteredFertilizer = _filterAndSort(fertilizerList);
        final filteredIot = _filterAndSort(iotList);

        return DefaultTabController(
          length: 5,
          child: Scaffold(
            backgroundColor: kBackgroundColor,
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Standardized Botanical Header (Uniform with Garden & Sensors)
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          kAccentMint.withValues(alpha: 0.55),
                          kBackgroundColor,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Botanical Marketplace 🪴',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'UrbanGreen Store',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: kTextPrimary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                            // Shopping Cart Action Button
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: kSurfaceColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: kBorderSubtle, width: 1.2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.shopping_cart_outlined, color: kTextPrimary, size: 21),
                                    tooltip: 'View Cart',
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const CartScreen()),
                                      );
                                    },
                                  ),
                                ),
                                if (cart.itemCount > 0)
                                  Positioned(
                                    right: 2,
                                    top: 2,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: kStatusDanger,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                                      child: Text(
                                        '${cart.itemCount}',
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
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Search Bar
                        Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: kSurfaceColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: kBorderSubtle),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val.trim();
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Search plants, fertilizers, tools...',
                              hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: kPrimaryColor),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 18, color: kTextSecondary),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {
                                          _searchQuery = '';
                                        });
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            style: const TextStyle(fontSize: 13, color: kTextPrimary),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Filter & Stock Control Bar
                        Row(
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _onlyInStock = !_onlyInStock;
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _onlyInStock ? kPrimaryColor : kSurfaceColor,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _onlyInStock ? kPrimaryColor : kBorderSubtle,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _onlyInStock ? Icons.check_circle : Icons.tune_rounded,
                                      size: 13,
                                      color: _onlyInStock ? Colors.white : kTextSecondary,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      _onlyInStock ? 'In-Stock Only' : 'Available First (Sold Out at Bottom)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _onlyInStock ? Colors.white : kTextPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: kPrimaryColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.auto_awesome, size: 11, color: kPrimaryColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    'AI Ranked',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: kPrimaryColor.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Capsule TabBar matching Garden & Sensors
                        Container(
                          height: 42,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: kSurfaceColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: kBorderSubtle),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: TabBar(
                            dividerColor: Colors.transparent,
                            dividerHeight: 0,
                            isScrollable: true,
                            tabAlignment: TabAlignment.start,
                            indicatorSize: TabBarIndicatorSize.tab,
                            indicator: BoxDecoration(
                              color: kPrimaryColor,
                              borderRadius: BorderRadius.circular(11),
                              boxShadow: [
                                BoxShadow(
                                  color: kPrimaryColor.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            labelColor: Colors.white,
                            unselectedLabelColor: kTextSecondary,
                            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            tabs: [
                              Tab(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.auto_awesome, size: 13),
                                    const SizedBox(width: 5),
                                    Text('Recommended (${recommendedProducts.length})'),
                                  ],
                                ),
                              ),
                              Tab(text: 'Plants (${filteredPlants.length})'),
                              Tab(text: 'Tools (${filteredEquipment.length})'),
                              Tab(text: 'Care (${filteredFertilizer.length})'),
                              Tab(text: 'Grow Tech (${filteredIot.length})'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // TabBarView Content
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildProductTab(context, recommendedProducts, 0, recMap: recMap),
                        _buildProductTab(context, filteredPlants, 1, recMap: recMap),
                        _buildProductTab(context, filteredEquipment, 2, recMap: recMap),
                        _buildProductTab(context, filteredFertilizer, 3, recMap: recMap),
                        _buildProductTab(context, filteredIot, 4, recMap: recMap),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductTab(
    BuildContext context,
    List<Product> products,
    int tabIndex, {
    Map<String, RecommendedProduct>? recMap,
  }) {
    return Column(
      children: [
        _buildPromoBanner(context, tabIndex),
        Expanded(
          child: _buildProductGrid(context, products, recMap: recMap),
        ),
      ],
    );
  }

  Widget _buildPromoBanner(BuildContext context, int tabIndex) {
    String title;
    String subtitle;
    IconData icon;
    Color color;

    switch (tabIndex) {
      case 0:
        title = 'AI Botanical Recommendations';
        subtitle = 'Personalized for your garden sanctuary, telemetry sensors & shopping habits';
        icon = Icons.auto_awesome;
        color = const Color(0xFF1B5E20);
        break;
      case 1:
        title = 'Specimen Houseplants';
        subtitle = 'Living botanicals with root integrity and acclimatization guarantee';
        icon = Icons.spa_outlined;
        color = kPrimaryColor;
        break;
      case 2:
        title = 'Precision Hardware & Pottery';
        subtitle = 'Japanese SK-5 bypass shears, long-spout cans & glazed ceramic planters';
        icon = Icons.handyman_outlined;
        color = Colors.teal.shade700;
        break;
      case 3:
        title = 'Organic Feeds & Biocontrols';
        subtitle = 'Targeted neem oil sprays, seaweed tonics & mineral fertilizers';
        icon = Icons.science_outlined;
        color = const Color(0xFF2E7D32);
        break;
      default:
        title = 'Smart Botanical Mesh & IoT';
        subtitle = 'Hydration probes, auto-irrigation valves & timer grow lamps';
        icon = Icons.sensors;
        color = Colors.indigo.shade700;
        break;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(
    BuildContext context,
    List<Product> products, {
    Map<String, RecommendedProduct>? recMap,
  }) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No supplies matching "$_searchQuery"'
                  : (_onlyInStock
                      ? 'No in-stock items currently available'
                      : 'No items currently in this section'),
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    final available = products.where((p) => p.isAvailable).toList();
    final soldOut = products.where((p) => p.isSoldOut).toList();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // 1. Available Products Section
        if (available.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.all(kDefaultPadding),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: kDefaultPadding,
                mainAxisSpacing: kDefaultPadding,
                childAspectRatio: 0.69,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final product = available[index];
                  return _buildProductCard(
                    context,
                    product,
                    rec: recMap?[product.id],
                  );
                },
                childCount: available.length,
              ),
            ),
          ),

        // 2. Sold Out Section (Only shown when _onlyInStock is false and sold-out items exist)
        if (soldOut.isNotEmpty && !_onlyInStock) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.remove_shopping_cart, size: 13, color: Colors.red.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Sold Out (${soldOut.length})',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Divider(color: Colors.grey.shade300, thickness: 1),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Restocking soon',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(kDefaultPadding, 6, kDefaultPadding, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: kDefaultPadding,
                mainAxisSpacing: kDefaultPadding,
                childAspectRatio: 0.69,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final product = soldOut[index];
                  return _buildProductCard(
                    context,
                    product,
                    rec: recMap?[product.id],
                  );
                },
                childCount: soldOut.length,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    Product product, {
    RecommendedProduct? rec,
  }) {
    final theme = Theme.of(context);
    final cart = Provider.of<CartModel>(context, listen: false);
    final isNetwork = product.imageUrl.startsWith('http');
    final isOutOfStock = product.isSoldOut;
    final isLowStock = product.stock > 0 && product.stock <= 5;

    return InkWell(
      onTap: () {
        // Record user interaction for smart recommendations
        RecommendationService().recordInteraction(
          type: product.type,
          categories: product.categories,
          speciesName: product.name,
          action: 'view',
        );
        _showProductDetailsModal(context, product, rec: rec);
      },
      borderRadius: BorderRadius.circular(14),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: isNetwork
                        ? Image.network(
                            product.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade200,
                              child: Icon(Icons.spa, color: Colors.grey.shade400, size: 36),
                            ),
                          )
                        : Image.asset(
                            product.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade200,
                              child: Icon(Icons.spa, color: Colors.grey.shade400, size: 36),
                            ),
                          ),
                  ),
                  if (rec != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B5E20),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome, size: 9, color: Color(0xFFA5D6A7)),
                            const SizedBox(width: 4),
                            Text(
                              rec.badge,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (isOutOfStock)
                    Container(
                      color: Colors.black.withValues(alpha: 0.55),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'OUT OF STOCK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  else if (isLowStock && rec == null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade800,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Only ${product.stock} left',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'RM ${product.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (product.categories.isNotEmpty)
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              product.categories.first,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 34,
                    child: ElevatedButton.icon(
                      onPressed: isOutOfStock
                          ? null
                          : () {
                              final cartItem = CartItem(
                                productId: product.id,
                                name: product.name,
                                price: product.price,
                                imageUrl: product.imageUrl,
                              );
                              cart.addItem(cartItem);
                              AchievementService().recordStoreAction();
                              RecommendationService().recordInteraction(
                                type: product.type,
                                categories: product.categories,
                                speciesName: product.name,
                                action: 'add_to_cart',
                              );
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${product.name} added to cart'),
                                  duration: const Duration(seconds: 4),
                                  action: SnackBarAction(
                                    label: 'VIEW CART',
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
                      icon: Icon(
                        isOutOfStock ? Icons.block : Icons.add_shopping_cart,
                        size: 14,
                        color: isOutOfStock ? Colors.grey.shade600 : Colors.white,
                      ),
                      label: Text(
                        isOutOfStock ? 'Sold Out' : 'Add to Cart',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isOutOfStock ? Colors.grey.shade600 : Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOutOfStock ? Colors.grey.shade200 : kPrimaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProductDetailsModal(
    BuildContext context,
    Product product, {
    RecommendedProduct? rec,
  }) {
    final theme = Theme.of(context);
    final cart = Provider.of<CartModel>(context, listen: false);
    final isNetwork = product.imageUrl.startsWith('http');
    final isOutOfStock = product.isSoldOut;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: isNetwork
                        ? Image.network(product.imageUrl, fit: BoxFit.cover)
                        : Image.asset(product.imageUrl, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 16),
                if (rec != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFA5D6A7)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF2E7D32)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'RECOMMENDED FOR YOU • ${rec.badge.toUpperCase()}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF2E7D32),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                rec.reason,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1B5E20),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      'RM ${product.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(
                      label: Text(
                        product.type,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                    ),
                    ...product.categories.map(
                      (c) => Chip(
                        label: Text(
                          c,
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        backgroundColor: Colors.grey.shade100,
                      ),
                    ),
                    Chip(
                      label: Text(
                        isOutOfStock ? 'Out of Stock' : '${product.stock} in Stock',
                        style: TextStyle(
                          color: isOutOfStock ? Colors.red.shade900 : Colors.green.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      backgroundColor: isOutOfStock ? Colors.red.shade50 : Colors.green.shade50,
                    ),
                  ],
                ),
                if (product.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    product.description,
                    style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: isOutOfStock
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            cart.addItem(
                              CartItem(
                                productId: product.id,
                                name: product.name,
                                price: product.price,
                                imageUrl: product.imageUrl,
                              ),
                            );
                            AchievementService().recordStoreAction();
                            RecommendationService().recordInteraction(
                              type: product.type,
                              categories: product.categories,
                              speciesName: product.name,
                              action: 'add_to_cart',
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${product.name} added to cart!'),
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          },
                    icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
                    label: Text(
                      isOutOfStock ? 'Out of Stock' : 'Add to Cart',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
