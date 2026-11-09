import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urbangreen/components/standard_app_bar.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/models/cart_item_model.dart';
import 'package:urbangreen/models/cart_model.dart';
import 'package:urbangreen/screens/shop/checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartModel>();
    final theme = Theme.of(context);
    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? kDarkBackgroundColor : kBackgroundColor,
      appBar: StandardAppBar(
        title: 'Your Cart',
        subtitle: '${cart.itemCount} item${cart.itemCount == 1 ? "" : "s"} ready for checkout',
        toolbarHeight: 68,
        actions: [
          if (cart.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: IconButton(
                icon: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark ? kDarkCardColor : kBackgroundColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? kDarkBorderSubtle : kBorderSubtle,
                      width: 1.2,
                    ),
                  ),
                  child: const Icon(Icons.delete_sweep_outlined, size: 20, color: kStatusDanger),
                ),
                tooltip: 'Clear Cart',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Clear Cart'),
                      content: const Text('Are you sure you want to remove all items from your cart?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel', style: TextStyle(color: kTextSecondary)),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            cart.clearCart();
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: kStatusDanger),
                          child: const Text('Clear', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      body: cart.isLoading && cart.items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : cart.items.isEmpty
              ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Your cart is empty",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Explore our botanical catalog and add supplies!",
                    style: TextStyle(color: isDark ? kDarkTextSecondary : Colors.grey.shade700),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.shopping_cart, color: Colors.white),
                    label: const Text('Start Shopping', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Free Delivery Progress Banner
                _buildDeliveryBanner(context, cart.totalPrice),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
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

  Widget _buildDeliveryBanner(BuildContext context, double total) {
    final isDark = context.isDarkMode;
    final qualifiesForFree = total >= 50.00;
    final diff = 50.00 - total;

    final bannerBg = isDark
        ? (qualifiesForFree ? const Color(0xFF1B3828) : const Color(0xFF382315))
        : (qualifiesForFree ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0));
    final bannerFg = isDark
        ? (qualifiesForFree ? const Color(0xFF81C784) : const Color(0xFFFFB74D))
        : (qualifiesForFree ? const Color(0xFF2E7D32) : const Color(0xFFE65100));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: bannerBg,
      child: Row(
        children: [
          Icon(
            qualifiesForFree ? Icons.local_shipping : Icons.info_outline,
            size: 20,
            color: bannerFg,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              qualifiesForFree
                  ? '🎉 You qualify for FREE Delivery across Malaysia!'
                  : 'Add RM ${diff.toStringAsFixed(2)} more to unlock FREE Delivery (orders RM 50+)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: bannerFg,
              ),
            ),
          ),
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
    final isDark = context.isDarkMode;
    final isNetwork = item.imageUrl.startsWith('http');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isDark ? const BorderSide(color: kDarkBorderSubtle, width: 1) : BorderSide.none,
      ),
      color: isDark ? kDarkCardColor : kSurfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Row(
          children: [
            // Product Thumbnail Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 64,
                height: 64,
                child: isNetwork
                    ? Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: isDark ? kDarkSurfaceColor : Colors.grey.shade200,
                          child: Icon(Icons.spa, color: isDark ? kDarkTextSecondary : Colors.grey.shade400, size: 28),
                        ),
                      )
                    : Image.asset(
                        item.imageUrl.isNotEmpty ? item.imageUrl : 'assets/images/image_1.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: isDark ? kDarkSurfaceColor : Colors.grey.shade200,
                          child: Icon(Icons.spa, color: isDark ? kDarkTextSecondary : Colors.grey.shade400, size: 28),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? kDarkTextPrimary : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'RM ${item.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Item Total: RM ${(item.price * item.quantity).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? kDarkTextSecondary : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            // Quantity Counter
            Container(
              decoration: BoxDecoration(
                color: isDark ? kDarkSurfaceColor : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  IconButton(
                    iconSize: 18,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    icon: Icon(Icons.remove, color: isDark ? kDarkTextPrimary : null),
                    onPressed: () {
                      cart.decrementItem(item.productId);
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      item.quantity.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? kDarkTextPrimary : null,
                      ),
                    ),
                  ),
                  IconButton(
                    iconSize: 18,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    icon: Icon(Icons.add, color: isDark ? kDarkTextPrimary : null),
                    onPressed: () {
                      cart.addItem(item);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              iconSize: 20,
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
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
  const CartTotal({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartModel>();
    final theme = Theme.of(context);
    final isDark = context.isDarkMode;
    final deliveryFee = cart.totalPrice >= 50.00 || cart.totalPrice == 0 ? 0.00 : 5.00;
    final grandTotal = cart.totalPrice + deliveryFee;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDark ? kDarkSurfaceColor : theme.cardColor,
        border: isDark ? const Border(top: BorderSide(color: kDarkBorderSubtle, width: 1)) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Subtotal", style: TextStyle(color: isDark ? kDarkTextSecondary : Colors.grey.shade700, fontSize: 14)),
                Text(
                  'RM ${cart.totalPrice.toStringAsFixed(2)}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? kDarkTextPrimary : null),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Estimated Delivery", style: TextStyle(color: isDark ? kDarkTextSecondary : Colors.grey.shade700, fontSize: 14)),
                Text(
                  deliveryFee == 0 ? 'FREE' : 'RM ${deliveryFee.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: deliveryFee == 0
                        ? (isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32))
                        : (isDark ? kDarkTextPrimary : Colors.black87),
                  ),
                ),
              ],
            ),
            Divider(height: 16, color: isDark ? kDarkBorderSubtle : null),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Estimated Total",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? kDarkTextPrimary : null,
                  ),
                ),
                Text(
                  'RM ${grandTotal.toStringAsFixed(2)}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Proceed to Checkout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
