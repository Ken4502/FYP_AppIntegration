import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/models/cart_item_model.dart';
import 'package:urbangreen/models/cart_model.dart';
import 'package:urbangreen/models/product_model.dart';
import 'package:urbangreen/screens/shop/cart_screen.dart';

class PlantEcommerceScreen extends StatelessWidget {
  PlantEcommerceScreen({super.key});

  final List<Product> plants = [
    Product(
        id: 'p1',
        name: 'Snake Plant',
        price: 25.00,
        imageUrl: 'assets/images/image_1.png'),
    Product(
        id: 'p2',
        name: 'Monstera',
        price: 45.00,
        imageUrl: 'assets/images/image_2.png'),
    Product(
        id: 'p3',
        name: 'Fiddle Leaf Fig',
        price: 60.00,
        imageUrl: 'assets/images/image_3.png'),
    Product(
        id: 'p4',
        name: 'Spider Plant',
        price: 15.00,
        imageUrl: 'assets/images/img_main.png'),
    Product(
        id: 'p5',
        name: 'ZZ Plant',
        price: 30.00,
        imageUrl: 'assets/images/bottom_img_1.png'),
    Product(
        id: 'p6',
        name: 'Pothos',
        price: 20.00,
        imageUrl: 'assets/images/bottom_img_2.png'),
  ];

  final List<Product> equipment = [
    Product(
        id: 'e1',
        name: 'Watering Can',
        price: 12.00,
        imageUrl: 'assets/images/img.png'),
    Product(
        id: 'e2',
        name: 'Pruning Shears',
        price: 18.00,
        imageUrl: 'assets/images/image_1.png'),
  ];

  final List<Product> fertilizer = [
    Product(
        id: 'f1',
        name: 'All-Purpose Fertilizer',
        price: 8.00,
        imageUrl: 'assets/images/image_2.png'),
  ];

  final List<Product> iot = [
    Product(
        id: 'i1',
        name: 'Smart Plant Sensor',
        price: 50.00,
        imageUrl: 'assets/images/image_3.png'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Plants'),
              Tab(text: 'Equipment'),
              Tab(text: 'Fertilizer'),
              Tab(text: 'IoT'),
            ],
          ),
          
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              color: theme.colorScheme.primary,
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.shopping_cart),
              color: theme.colorScheme.primary,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CartScreen()),
                );
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildProductGrid(context, plants),
            _buildProductGrid(context, equipment),
            _buildProductGrid(context, fertilizer),
            _buildProductGrid(context, iot),
          ],
        ),
      ),
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
        childAspectRatio: 0.75,
      ),
      itemBuilder: (context, index) {
        final product = products[index];
        return Card(
          elevation: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                    image: DecorationImage(
                      image: AssetImage(product.imageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RM ${product.price.toStringAsFixed(2)}',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ElevatedButton.icon(
                      onPressed: () {
                        final cartItem = CartItem(
                          productId: product.id,
                          name: product.name,
                          price: product.price,
                        );
                        cart.addItem(cartItem);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${product.name} added to cart'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_shopping_cart, size: 16),
                      label: const Text('Add to Cart'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 36),
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
