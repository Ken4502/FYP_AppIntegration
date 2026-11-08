import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:urbangreen/components/standard_app_bar.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/models/cart_model.dart';
import 'package:urbangreen/models/order_model.dart';
import 'package:urbangreen/screens/shop/cart_screen.dart';
import 'package:urbangreen/services/order_service.dart';

class OrderHistoryDetailScreen extends StatelessWidget {
  final OrderModel? order;
  final String? orderId;

  const OrderHistoryDetailScreen({
    super.key,
    this.order,
    this.orderId,
  }) : assert(order != null || orderId != null, 'Either order or orderId must be provided');

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year;
    final hr = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hr:$min';
  }

  @override
  Widget build(BuildContext context) {
    if (order != null) {
      return _buildContent(context, order!);
    }

    // Direct query to Firebase Cloud Firestore if only orderId is provided
    return FutureBuilder<OrderModel?>(
      future: OrderService().getOrderById(orderId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: kBackgroundColor,
            appBar: StandardAppBar(title: 'Order $orderId', toolbarHeight: 68),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Retrieving order from Firebase...', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
          );
        }

        final fetchedOrder = snapshot.data;
        if (snapshot.hasError || fetchedOrder == null) {
          final errorDetails = snapshot.hasError
              ? OrderService.formatDatabaseError(snapshot.error, 'orders/$orderId')
              : 'Order record #$orderId could not be located in your Firebase Firestore database.';

          return Scaffold(
            backgroundColor: kBackgroundColor,
            appBar: StandardAppBar(title: 'Order $orderId', toolbarHeight: 68),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off_rounded, size: 72, color: Colors.orange.shade800),
                    const SizedBox(height: 18),
                    const Text(
                      'Unable to Query Firebase Order',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: kTextPrimary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      errorDetails,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                      label: const Text('Return to Order History', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return _buildContent(context, fetchedOrder);
      },
    );
  }

  Widget _buildContent(BuildContext context, OrderModel order) {
    final theme = Theme.of(context);
    final dateStr = order.createdAt != null
        ? 'Placed on ${order.createdAt!.toLocal().toString().split(" ")[0]}'
        : 'Order Details';

    final isCancellable = order.status.toLowerCase() == 'processing' || order.status.toLowerCase() == 'pending';

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: StandardAppBar(
        title: 'Order #${order.id}',
        subtitle: dateStr,
        toolbarHeight: 68,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(kDefaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Tracking Timeline
            _buildStatusTracker(context, order.status),
            const SizedBox(height: 20),

            // Order Metadata
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order Placed',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(order.createdAt),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Status',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.status.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: order.status.toLowerCase() == 'cancelled' ? Colors.redAccent : theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Ordered Items List
            Text(
              'Items Ordered (${order.totalItemCount})',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 1,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: order.items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = order.items[index];
                  final isNetwork = item.imageUrl.startsWith('http');

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: isNetwork
                            ? Image.network(
                                item.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.spa, size: 24),
                                ),
                              )
                            : Image.asset(
                                item.imageUrl.isNotEmpty
                                    ? item.imageUrl
                                    : 'assets/images/image_1.png',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.spa, size: 24),
                                ),
                              ),
                      ),
                    ),
                    title: Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text('Qty: ${item.quantity} × RM ${item.price.toStringAsFixed(2)}'),
                    trailing: Text(
                      'RM ${(item.price * item.quantity).toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Delivery Address
            Text(
              'Delivery Address',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.location_on_outlined, color: kPrimaryColor),
                title: Text(order.formattedAddress),
              ),
            ),
            const SizedBox(height: 20),

            // Payment Method
            Text(
              'Payment Method',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.payment_outlined, color: kPrimaryColor),
                title: Text(order.paymentMethod),
                subtitle: const Text('Secured Payment'),
              ),
            ),
            const SizedBox(height: 20),

            // Pricing Summary Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal'),
                        Text('RM ${order.subtotal.toStringAsFixed(2)}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Delivery Fee'),
                        Text(order.deliveryFee == 0 ? 'FREE' : 'RM ${order.deliveryFee.toStringAsFixed(2)}'),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Paid',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'RM ${order.totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Buy Again Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.replay_rounded, size: 20),
                label: const Text('Buy Again (Re-add to Cart)', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final cart = Provider.of<CartModel>(context, listen: false);
                  for (final item in order.items) {
                    cart.addItem(item);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🛒 Added ${order.totalItemCount} items from ${order.id} back to Cart!'),
                      backgroundColor: kPrimaryColor,
                      action: SnackBarAction(
                        label: 'View Cart',
                        textColor: Colors.white,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CartScreen()),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            // Copy Digital Receipt Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.receipt_rounded, size: 20),
                label: const Text('Copy Digital Receipt'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kTextPrimary,
                  side: const BorderSide(color: kBorderSubtle),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final receipt = StringBuffer();
                  receipt.writeln('==============================');
                  receipt.writeln('       URBANGREEN RECEIPT     ');
                  receipt.writeln('==============================');
                  receipt.writeln('Order ID: ${order.id}');
                  receipt.writeln('Date: ${_formatDate(order.createdAt)}');
                  receipt.writeln('Status: ${order.status}');
                  receipt.writeln('Payment: ${order.paymentMethod}');
                  receipt.writeln('Address: ${order.formattedAddress}');
                  receipt.writeln('------------------------------');
                  for (final item in order.items) {
                    receipt.writeln('${item.name} x${item.quantity} - RM ${(item.price * item.quantity).toStringAsFixed(2)}');
                  }
                  receipt.writeln('------------------------------');
                  receipt.writeln('Delivery Fee: RM ${order.deliveryFee.toStringAsFixed(2)}');
                  receipt.writeln('TOTAL PAID: RM ${order.totalAmount.toStringAsFixed(2)}');
                  receipt.writeln('==============================');

                  Clipboard.setData(ClipboardData(text: receipt.toString()));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('📋 Receipt copied to clipboard!'),
                      backgroundColor: Colors.black87,
                    ),
                  );
                },
              ),
            ),

            // Cancel Order in Firebase Button (if Processing/Pending)
            if (isCancellable) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cancel_outlined, size: 20, color: Colors.redAccent),
                  label: const Text('Cancel Order in Firebase', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _confirmCancelOrder(context, order),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _confirmCancelOrder(BuildContext context, OrderModel order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Order in Firebase?'),
        content: Text('Are you sure you want to cancel Order #${order.id}? This will immediately update the status in Firebase Firestore and release inventory.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Order'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await OrderService().cancelOrder(order.id, order.userId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Order #${order.id} cancelled in Firebase Firestore.'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  Navigator.pop(context);
                }
              } catch (e) {
                if (context.mounted) {
                  final explanation = OrderService.formatDatabaseError(e, 'cancelOrder');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to cancel order: $explanation'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Yes, Cancel Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTracker(BuildContext context, String currentStatus) {
    final statusLower = currentStatus.toLowerCase();

    if (statusLower == 'cancelled') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red.shade700, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order Cancelled in Firebase', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900)),
                  const SizedBox(height: 2),
                  Text('This order was cancelled in Firestore and will not be fulfilled.', style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final steps = ['Processing', 'Shipped', 'Delivered'];
    int activeIndex = 0;
    if (statusLower == 'shipped') {
      activeIndex = 1;
    } else if (statusLower == 'delivered' || statusLower == 'completed') {
      activeIndex = 2;
    }

    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(steps.length, (idx) {
          final isCompleted = idx <= activeIndex;
          final isCurrent = idx == activeIndex;

          IconData icon;
          if (idx == 0) {
            icon = Icons.receipt;
          } else if (idx == 1) {
            icon = Icons.local_shipping;
          } else {
            icon = Icons.check_circle;
          }

          return Column(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: isCompleted
                    ? theme.colorScheme.primary
                    : Colors.grey.shade300,
                child: Icon(
                  icon,
                  size: 18,
                  color: isCompleted ? Colors.white : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                steps[idx],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isCompleted ? theme.colorScheme.primary : Colors.grey,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
