import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:urbangreen/components/standard_app_bar.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/models/order_model.dart';
import 'package:urbangreen/screens/account/order_history_detail_screen.dart';
import 'package:urbangreen/screens/auth/login_screen.dart';
import 'package:urbangreen/screens/shop/plant_ecommerce_screen.dart';
import 'package:urbangreen/services/order_service.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final OrderService _orderService = OrderService();
  String _selectedFilter = 'All';
  bool _isCreatingSample = false;

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
      case 'completed':
        return const Color(0xFF2E7D32);
      case 'shipped':
        return Colors.blue.shade700;
      case 'processing':
        return Colors.orange.shade800;
      case 'cancelled':
        return Colors.red.shade700;
      default:
        return Colors.blueGrey;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Recent';
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year;
    final hr = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hr:$min';
  }

  Future<void> _generateSampleOrderInFirebase(String userId) async {
    setState(() => _isCreatingSample = true);
    try {
      final orderId = await _orderService.createSampleOrder(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📦 Sample demonstration order (#$orderId) saved directly to Firebase!'),
            backgroundColor: kPrimaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final explanation = OrderService.formatDatabaseError(e, 'sampleOrder');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save order to Firebase: $explanation'),
            backgroundColor: kStatusDanger,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreatingSample = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

    // 1. If not authenticated with Firebase Auth, guide user to login
    if (user == null) {
      return Scaffold(
        backgroundColor: kBackgroundColor,
        appBar: const StandardAppBar(
          title: 'Order History',
          subtitle: 'Past purchases, receipts & fulfillment status',
          toolbarHeight: 68,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_person_outlined, size: 76, color: Colors.blueGrey.shade400),
                const SizedBox(height: 20),
                const Text(
                  'Firebase Account Required',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your order history is stored securely in Firebase Cloud Firestore. Please sign in to view your orders and live tracking.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.login, color: Colors.white, size: 18),
                  label: const Text('Sign In to UrbanGreen', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    final userId = user.uid;

    // 2. Real-time Firebase Firestore Stream
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: StandardAppBar(
        title: 'Order History',
        subtitle: 'Stored directly in Firebase Cloud Firestore',
        toolbarHeight: 68,
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_done_outlined, color: kPrimaryColor),
            tooltip: 'Firebase Connected',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('☁️ Connected to Firebase Firestore for user: ${user.email ?? userId}'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 4),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: _orderService.getUserOrdersStream(userId),
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 14),
                  Text('Fetching orders from Firebase...', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            );
          }

          // Error state from Firebase query
          if (snapshot.hasError) {
            final explanation = OrderService.formatDatabaseError(snapshot.error, 'users/$userId/orders');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 68, color: Colors.red.shade600),
                    const SizedBox(height: 18),
                    const Text(
                      'Firebase Database Notice',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: kTextPrimary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      explanation,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                      label: const Text('Retry Firebase Query', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
                      onPressed: () => setState(() {}),
                    ),
                  ],
                ),
              ),
            );
          }

          final allOrders = snapshot.data ?? [];
          final filteredOrders = allOrders.where((o) {
            if (_selectedFilter == 'All') return true;
            return o.status.toLowerCase() == _selectedFilter.toLowerCase();
          }).toList();

          return Column(
            children: [
              // Filter Chips Strip
              Container(
                color: kSurfaceColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Processing', 'Shipped', 'Delivered', 'Cancelled'].map((filter) {
                      final isSelected = _selectedFilter == filter;
                      int count = 0;
                      if (filter == 'All') {
                        count = allOrders.length;
                      } else {
                        count = allOrders.where((o) => o.status.toLowerCase() == filter.toLowerCase()).length;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(
                            '$filter ($count)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : kTextPrimary,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: kPrimaryColor,
                          backgroundColor: kBackgroundColor,
                          showCheckmark: false,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          onSelected: (val) {
                            if (val) setState(() => _selectedFilter = filter);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Orders List or Empty State
              Expanded(
                child: allOrders.isEmpty
                    ? _buildEmptyOrdersView(userId)
                    : (filteredOrders.isEmpty
                        ? _buildFilterEmptyView()
                        : _buildOrdersList(filteredOrders, theme, userId)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyOrdersView(String userId) {
    return ListView(
      padding: const EdgeInsets.all(32.0),
      children: [
        const SizedBox(height: 40),
        Icon(
          Icons.receipt_long_outlined,
          size: 72,
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 16),
        const Text(
          'No Orders in Firebase',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Your Firebase orders collection is currently empty. Purchases made in the store will be written directly to your Firebase Firestore cloud account.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.storefront, size: 18, color: Colors.white),
            label: const Text('Discover Store', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PlantEcommerceScreen()),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: OutlinedButton.icon(
            icon: _isCreatingSample
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_upload_outlined, size: 16),
            label: const Text('Generate Demo Order in Firebase'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kPrimaryColor,
              side: BorderSide(color: kPrimaryColor.withValues(alpha: 0.5)),
            ),
            onPressed: _isCreatingSample ? null : () => _generateSampleOrderInFirebase(userId),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterEmptyView() {
    return ListView(
      padding: const EdgeInsets.all(32.0),
      children: [
        const SizedBox(height: 60),
        Icon(Icons.filter_list_off, size: 56, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        Text(
          'No $_selectedFilter Orders',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'No records in your Firebase database currently match the "$_selectedFilter" status.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(height: 18),
        Center(
          child: TextButton.icon(
            icon: const Icon(Icons.clear_all),
            label: const Text('Show All Orders'),
            onPressed: () {
              setState(() => _selectedFilter = 'All');
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersList(List<OrderModel> orders, ThemeData theme, String userId) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final statusColor = _getStatusColor(order.status);
        final firstItemName = order.items.isNotEmpty ? order.items.first.name : 'Plant Care Supplies';
        final additionalCount = order.items.length > 1 ? order.items.length - 1 : 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1.5,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderHistoryDetailScreen(order: order),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Order ID + Status Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Order #${order.id}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: kTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          order.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Item preview summary
                  Text(
                    additionalCount > 0 ? '$firstItemName + $additionalCount more' : firstItemName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: kTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Date
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(order.createdAt),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Bottom Row: Items count, Total Price, Chevron
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${order.totalItemCount} ${order.totalItemCount == 1 ? "item" : "items"}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            'RM ${order.totalAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
