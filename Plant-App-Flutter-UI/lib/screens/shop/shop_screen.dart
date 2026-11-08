import 'package:urbangreen/constants.dart';
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
        backgroundColor: kBackgroundColor,
        appBar: AppBar(
          backgroundColor: kSurfaceColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: 68,
          titleSpacing: 16,
          title: Container(
            height: 42,
            decoration: BoxDecoration(
              color: kBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorderSubtle),
            ),
            child: const TextField(
              decoration: InputDecoration(
                hintText: "Search botanicals & gear...",
                hintStyle: TextStyle(fontSize: 13, color: kTextSecondary),
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: kPrimaryColor),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: TextStyle(fontSize: 13, color: kTextPrimary),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: IconButton(
                icon: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: kBackgroundColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: kBorderSubtle, width: 1.2),
                  ),
                  child: const Icon(Icons.shopping_cart_outlined, color: kTextPrimary, size: 20),
                ),
                tooltip: 'Shopping Cart',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CartScreen()),
                  );
                },
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(54),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: kBackgroundColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kBorderSubtle),
              ),
              child: TabBar(
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
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(text: "Plants"),
                  Tab(text: "Equipment"),
                  Tab(text: "Fertilizer"),
                  Tab(text: "IoT"),
                ],
              ),
            ),
          ),
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
                      duration: const Duration(seconds: 4),
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
