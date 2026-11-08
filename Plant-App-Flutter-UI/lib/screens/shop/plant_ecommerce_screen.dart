import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/models/cart_item_model.dart';
import 'package:urbangreen/models/cart_model.dart';
import 'package:urbangreen/models/product_model.dart';
import 'package:urbangreen/screens/shop/cart_screen.dart';

class PlantEcommerceScreen extends StatefulWidget {
  const PlantEcommerceScreen({super.key});

  @override
  State<PlantEcommerceScreen> createState() => _PlantEcommerceScreenState();
}

class _PlantEcommerceScreenState extends State<PlantEcommerceScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
  ];

  List<Product> _filterByQuery(List<Product> products) {
    if (_searchQuery.isEmpty) return products;
    final query = _searchQuery.toLowerCase();
    return products.where((p) {
      final name = p.name.toLowerCase();
      final type = p.type.toLowerCase();
      final desc = p.description.toLowerCase();
      final cats = p.categories.map((c) => c.toLowerCase()).join(' ');
      return name.contains(query) || type.contains(query) || desc.contains(query) || cats.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartModel>(context);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('plant_supplies').snapshots(),
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
        }

        final filteredPlants = _filterByQuery(plantsList);
        final filteredEquipment = _filterByQuery(equipmentList);
        final filteredFertilizer = _filterByQuery(fertilizerList);
        final filteredIot = _filterByQuery(iotList);

        return DefaultTabController(
          length: 4,
          child: Scaffold(
            backgroundColor: kBackgroundColor,
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Standardized Botanical Header (Uniform with Garden & Sensors)
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
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
                        const SizedBox(height: 14),

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
                        _buildProductTab(context, filteredPlants, 0),
                        _buildProductTab(context, filteredEquipment, 1),
                        _buildProductTab(context, filteredFertilizer, 2),
                        _buildProductTab(context, filteredIot, 3),
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

  Widget _buildProductTab(BuildContext context, List<Product> products, int tabIndex) {
    return Column(
      children: [
        _buildPromoBanner(context, tabIndex),
        Expanded(child: _buildProductGrid(context, products)),
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
        title = 'Specimen Houseplants';
        subtitle = 'Living botanicals with root integrity and acclimatization guarantee';
        icon = Icons.spa_outlined;
        color = kPrimaryColor;
        break;
      case 1:
        title = 'Precision Hardware & Pottery';
        subtitle = 'Japanese SK-5 bypass shears, long-spout cans & glazed ceramic planters';
        icon = Icons.handyman_outlined;
        color = Colors.teal.shade700;
        break;
      case 2:
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

  Widget _buildProductGrid(BuildContext context, List<Product> products) {
    final theme = Theme.of(context);
    final cart = Provider.of<CartModel>(context, listen: false);

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
                  : 'No items currently in this section',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(kDefaultPadding),
      itemCount: products.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: kDefaultPadding,
        mainAxisSpacing: kDefaultPadding,
        childAspectRatio: 0.70,
      ),
      itemBuilder: (context, index) {
        final product = products[index];
        final isNetwork = product.imageUrl.startsWith('http');
        final isOutOfStock = product.stock <= 0;
        final isLowStock = product.stock > 0 && product.stock <= 5;

        return InkWell(
          onTap: () => _showProductDetailsModal(context, product),
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
                      else if (isLowStock)
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
      },
    );
  }

  void _showProductDetailsModal(BuildContext context, Product product) {
    final theme = Theme.of(context);
    final cart = Provider.of<CartModel>(context, listen: false);
    final isNetwork = product.imageUrl.startsWith('http');
    final isOutOfStock = product.stock <= 0;

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
