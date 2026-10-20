import 'package:urbangreen/screens/shop/cart_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urbangreen/models/cart_model.dart';
import 'package:urbangreen/models/cart_item_model.dart';
import 'package:urbangreen/models/product_model.dart'; // Import the Product model

class ShopScreen extends StatelessWidget {
  ShopScreen({super.key});

  final List<Product> _mockProducts = [
    Product(
      id: '1',
      name: 'Angel Plant',
      price: 25.00,
      imageUrl: 'assets/images/image_1.png',
    ),
    Product(
      id: '2',
      name: 'Cactus',
      price: 15.00,
      imageUrl: 'assets/images/image_2.png',
    ),
    Product(
      id: '3',
      name: 'Fiddle-leaf Fig',
      price: 30.00,
      imageUrl: 'assets/images/image_3.png',
    ),
    Product(
      id: '4',
      name: 'Snake Plant',
      price: 20.00,
      imageUrl: 'assets/images/image_1.png',
    ),
    Product(
      id: '5',
      name: 'Pothos',
      price: 12.00,
      imageUrl: 'assets/images/image_2.png',
    ),
    Product(
      id: '6',
      name: 'ZZ Plant',
      price: 28.00,
      imageUrl: 'assets/images/image_3.png',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          bottom: const TabBar(
            labelColor: Colors.black,
            indicatorColor: Colors.green,
            tabs: [
              Tab(text: "Plants"),
              Tab(text: "Equipment"),
              Tab(text: "Fertilizer"),
              Tab(text: "IoT"),
            ],
          ),
          title: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search products...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.shopping_cart, color: Colors.black),
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
            _buildProductGrid(context), // Pass context
            _buildProductGrid(context),
            _buildProductGrid(context),
            _buildProductGrid(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProductGrid(BuildContext context) {
    // Accept context
    final cart = Provider.of<CartModel>(context, listen: false);
    return GridView.builder(
      padding: const EdgeInsets.all(10.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10.0,
        mainAxisSpacing: 10.0,
        childAspectRatio: 0.75,
      ),
      itemCount: _mockProducts.length, // Use actual product count
      itemBuilder: (context, index) {
        final product = _mockProducts[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Image.asset(
                  product.imageUrl, // Use product image
                  fit: BoxFit.cover,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text("\$${product.price.toStringAsFixed(2)}"),
                  ],
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.green,
                ),
                onPressed: () {
                  cart.addItem(
                    CartItem(
                      productId: product.id,
                      name: product.name,
                      price: product.price,
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${product.name} added to cart!'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                child: const Text("Add to Cart"),
              ),
            ],
          ),
        );
      },
    );
  }
}
