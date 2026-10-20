import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urbangreen/models/cart_item_model.dart';
import 'package:urbangreen/models/cart_model.dart';
import 'package:urbangreen/screens/shop/checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartModel>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Cart"),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: cart.items.isEmpty
          ? const Center(
              child:
                  Text("Your cart is empty.", style: TextStyle(fontSize: 18)),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return CartListItem(item: item);
                    },
                  ),
                ),
                const CartTotal(),
              ],
            ),
    );
  }
}

class CartListItem extends StatelessWidget {
  const CartListItem({
    super.key,
    required this.item,
  });

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartModel>();
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            // You might want to add an image here later
            // Image.asset(item.imageUrl, width: 60, height: 60, fit: BoxFit.cover),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'RM ${item.price.toStringAsFixed(2)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () {
                    cart.decrementItem(item.productId);
                  },
                ),
                Text(item.quantity.toString(),
                    style: theme.textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () {
                    cart.addItem(item);
                  },
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                cart.removeItem(item.productId);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class CartTotal extends StatelessWidget {
  const CartTotal({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartModel>();
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.1).round()),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Total", style: theme.textTheme.titleLarge),
              Text(
                'RM ${cart.totalPrice.toStringAsFixed(2)}',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CheckoutScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            child: const Text('Proceed to Checkout'),
          ),
        ],
      ),
    );
  }
}
