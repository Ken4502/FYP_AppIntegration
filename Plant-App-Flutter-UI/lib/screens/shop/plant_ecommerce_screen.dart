import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/models/cart_item_model.dart';
import 'package:urbangreen/models/cart_model.dart';
import 'package:urbangreen/models/product_model.dart';
import 'package:urbangreen/screens/shop/cart_screen.dart';

class PlantEcommerceScreen extends StatelessWidget {
  PlantEcommerceScreen({super.key});

  final List<Product> _fallbackPlants = [
    Product(
      id: 'p1',
      name: 'Monstera Deliciosa',
      price: 48.00,
      imageUrl: 'assets/images/image_1.png',
      type: 'Plant',
    ),
    Product(
      id: 'p2',
      name: 'Snake Plant Laurentii',
      price: 28.00,
      imageUrl: 'assets/images/image_2.png',
      type: 'Plant',
    ),
    Product(
      id: 'p3',
      name: 'Fiddle Leaf Fig',
      price: 68.00,
      imageUrl: 'assets/images/image_3.png',
      type: 'Plant',
    ),
    Product(
      id: 'p4',
      name: 'Golden Pothos',
      price: 18.00,
      imageUrl: 'assets/images/img_main.png',
      type: 'Plant',
    ),
  ];

  final List<Product> _fallbackEquipment = [
    Product(
      id: 'e1',
      name: 'Long-Spout Nordic Watering Can',
      price: 46.00,
      imageUrl: 'assets/images/img.png',
      type: 'Tool',
    ),
    Product(
      id: 'e2',
      name: 'SK-5 Titanium Pruning Shears',
      price: 39.90,
      imageUrl: 'assets/images/image_1.png',
      type: 'Tool',
    ),
    Product(
      id: 'e3',
      name: 'Minimalist Matte Ceramic Pot',
      price: 39.00,
      imageUrl: 'assets/images/image_2.png',
      type: 'Pots & Planters',
    ),
  ];

  final List<Product> _fallbackFertilizer = [
    Product(
      id: 'f1',
      name: 'Cold-Pressed Seaweed Booster',
      price: 34.00,
      imageUrl: 'assets/images/image_2.png',
      type: 'Fertilizer',
    ),
    Product(
      id: 'f2',
      name: 'Cold-Pressed Neem Oil Spray',
      price: 26.50,
      imageUrl: 'assets/images/image_3.png',
      type: 'Pest Control',
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
    ),
    Product(
      id: 'i2',
      name: 'Full-Spectrum LED Grow Light',
      price: 58.00,
      imageUrl: 'assets/images/image_1.png',
      type: 'Accessories',
      categories: ['Timer Control', 'Grow Equipment'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cart = Provider.of<CartModel>(context);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('plant_supplies').snapshots(),
      builder: (context, snapshot) {
        List<Product> plantsList = _fallbackPlants;
        List<Product> equipmentList = _fallbackEquipment;
        List<Product> fertilizerList = _fallbackFertilizer;
        List<Product> iotList = _fallbackIot;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final allProducts = snapshot.data!.docs.map((doc) => Product.fromFirestore(doc)).toList();

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

        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: theme.colorScheme.surface,
              elevation: 0,
              title: const Text(
                'UrbanGreen Store',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              bottom: const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'Plants'),
                  Tab(text: 'Tools & Planters'),
                  Tab(text: 'Care & Fertilizers'),
                  Tab(text: 'Grow Tech & IoT'),
                ],
              ),
              actions: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shopping_cart_outlined),
                      color: theme.colorScheme.primary,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CartScreen()),
                        );
                      },
                    ),
                    if (cart.itemCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${cart.itemCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: TabBarView(
              children: [
                _buildProductGrid(context, plantsList),
                _buildProductGrid(context, equipmentList),
                _buildProductGrid(context, fertilizerList),
                _buildProductGrid(context, iotList),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductGrid(BuildContext context, List<Product> products) {
    final theme = Theme.of(context);
    final cart = Provider.of<CartModel>(context, listen: false);

    return GridView.builder(
      padding: const EdgeInsets.all(kDefaultPadding),
      itemCount: products.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: kDefaultPadding,
        mainAxisSpacing: kDefaultPadding,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (context, index) {
        final product = products[index];
        final isNetwork = product.imageUrl.startsWith('http');

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox(
                  width: double.infinity,
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              product.categories.first,
                              style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.bold,
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
                        onPressed: () {
                          final cartItem = CartItem(
                            productId: product.id,
                            name: product.name,
                            price: product.price,
                          );
                          cart.addItem(cartItem);
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${product.name} added to cart'),
                              duration: const Duration(seconds: 2),
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
                        icon: const Icon(Icons.add_shopping_cart, size: 14),
                        label: const Text(
                          'Add to Cart',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
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
        );
      },
    );
  }
}
