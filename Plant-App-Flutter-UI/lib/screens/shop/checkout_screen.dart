import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urbangreen/components/standard_app_bar.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/models/address_model.dart';
import 'package:urbangreen/models/cart_model.dart';
import 'package:urbangreen/screens/address/add_address_screen.dart';
import 'package:urbangreen/screens/auth/login_screen.dart';
import 'package:urbangreen/screens/shop/order_confirmation_screen.dart';
import 'package:urbangreen/services/auth_service.dart';
import 'package:urbangreen/services/order_service.dart';
import 'package:urbangreen/services/user_service.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final UserService _userService = UserService();
  final OrderService _orderService = OrderService();

  Address? _selectedAddress;
  String _selectedPaymentMethod = 'Cash on Delivery';
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _paymentMethods = [
    'Cash on Delivery',
    'Credit / Debit Card',
    'Online Banking / FPX',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _showAddressPicker(List<Address> addresses, String uid) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Delivery Address',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add New'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddAddressScreen(uid: uid),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const Divider(),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: addresses.length,
                    itemBuilder: (context, idx) {
                      final addr = addresses[idx];
                      final isSelected = _selectedAddress?.id == addr.id;

                      return ListTile(
                        leading: Icon(
                          isSelected ? Icons.check_circle : Icons.location_on_outlined,
                          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade600,
                        ),
                        title: Text(
                          addr.street,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text('${addr.city}, ${addr.state} ${addr.zipCode}'),
                        onTap: () {
                          setState(() {
                            _selectedAddress = addr;
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handlePlaceOrder(CartModel cart, String uid) async {
    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or add a delivery address first.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your cart is empty.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final subtotal = cart.totalPrice;
      final deliveryFee = subtotal >= 50.00 ? 0.00 : 5.00;
      final totalAmount = subtotal + deliveryFee;

      final addressMap = {
        'street': _selectedAddress!.street,
        'city': _selectedAddress!.city,
        'state': _selectedAddress!.state,
        'zipCode': _selectedAddress!.zipCode,
      };

      final orderId = await _orderService.placeOrder(
        userId: uid,
        items: List.from(cart.items),
        subtotal: subtotal,
        deliveryFee: deliveryFee,
        totalAmount: totalAmount,
        shippingAddress: addressMap,
        paymentMethod: _selectedPaymentMethod,
      );

      // Clear Cart on successful order placement
      cart.clearCart();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OrderConfirmationScreen(
              orderId: orderId,
              totalAmount: totalAmount,
              shippingAddress: addressMap,
              paymentMethod: _selectedPaymentMethod,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final explanation = OrderService.formatDatabaseError(e, 'checkout');
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.redAccent),
                SizedBox(width: 8),
                Text('Order Processing Notice', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              'Unable to complete order placement:\n\n$explanation\n\nTechnical details: $e',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Dismiss'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _handlePlaceOrder(cart, uid);
                },
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
                child: const Text('Retry Placement', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cart = context.watch<CartModel>();
    final user = AuthService().currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: kBackgroundColor,
        appBar: const StandardAppBar(
          title: 'Checkout',
          subtitle: 'Sign in to complete order',
          toolbarHeight: 68,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_person_outlined, size: 64, color: kPrimaryColor),
                    const SizedBox(height: 16),
                    const Text(
                      'Account Required for Checkout',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextPrimary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please log in or create an UrbanGreen account to save your delivery address, track order dispatch, and complete payment.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginScreen()),
                          );
                        },
                        icon: const Icon(Icons.login, color: Colors.white, size: 18),
                        label: const Text('Sign In or Register', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final subtotal = cart.totalPrice;
    final deliveryFee = subtotal >= 50.00 || subtotal == 0 ? 0.00 : 5.00;
    final grandTotal = subtotal + deliveryFee;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: const StandardAppBar(
        title: 'Checkout',
        subtitle: 'Review & complete your botanical order',
        toolbarHeight: 68,
      ),
      body: cart.items.isEmpty && !_isSubmitting
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.remove_shopping_cart_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No items in cart to checkout', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Return to Cart', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(kDefaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. DELIVERY ADDRESS SECTION
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Delivery Address',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Icon(Icons.local_shipping_outlined, size: 20),
                    ],
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<List<Address>>(
                    stream: _userService.getAddressesStream(user.uid),
                    builder: (context, snapshot) {
                      final addresses = snapshot.data ?? [];

                      // Auto-select default or first address if none selected yet
                      if (addresses.isNotEmpty && _selectedAddress == null) {
                        final defaultAddr = addresses.firstWhere(
                          (a) => a.isDefault,
                          orElse: () => addresses.first,
                        );
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && _selectedAddress == null) {
                            setState(() {
                              _selectedAddress = defaultAddr;
                            });
                          }
                        });
                      }

                      if (addresses.isEmpty) {
                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          color: Colors.amber.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                const Text(
                                  'No delivery address found.',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Add your address so we know where to deliver your plants.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.add_location_alt, color: Colors.white),
                                  label: const Text('Add Address', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AddAddressScreen(uid: user.uid),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final addr = _selectedAddress ?? addresses.first;
                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 1,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                            child: Icon(Icons.location_on, color: theme.colorScheme.primary),
                          ),
                          title: Text(
                            addr.street,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('${addr.city}, ${addr.state} ${addr.zipCode}'),
                          trailing: TextButton(
                            onPressed: () => _showAddressPicker(addresses, user.uid),
                            child: const Text('Change'),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // 2. ORDERED ITEMS SECTION
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Items Summary (${cart.itemCount})',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'RM ${cart.totalPrice.toStringAsFixed(2)}',
                        style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 1,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: cart.items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = cart.items[index];
                        final isNetwork = item.imageUrl.startsWith('http');

                        return ListTile(
                          dense: true,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: isNetwork
                                  ? Image.network(
                                      item.imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.spa, size: 20),
                                      ),
                                    )
                                  : Image.asset(
                                      item.imageUrl.isNotEmpty
                                          ? item.imageUrl
                                          : 'assets/images/image_1.png',
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.spa, size: 20),
                                      ),
                                    ),
                            ),
                          ),
                          title: Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          subtitle: Text('Qty: ${item.quantity} × RM ${item.price.toStringAsFixed(2)}'),
                          trailing: Text(
                            'RM ${(item.price * item.quantity).toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. PAYMENT METHOD SECTION
                  Text(
                    'Payment Method',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 1,
                    child: RadioGroup<String>(
                      groupValue: _selectedPaymentMethod,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedPaymentMethod = val;
                          });
                        }
                      },
                      child: Column(
                        children: _paymentMethods.map((method) {
                          IconData icon;
                          if (method == 'Cash on Delivery') {
                            icon = Icons.payments_outlined;
                          } else if (method == 'Credit / Debit Card') {
                            icon = Icons.credit_card;
                          } else {
                            icon = Icons.account_balance;
                          }

                          return RadioListTile<String>(
                            value: method,
                            title: Row(
                              children: [
                                Icon(icon, size: 20, color: theme.colorScheme.primary),
                                const SizedBox(width: 12),
                                Text(method, style: const TextStyle(fontSize: 14)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. ORDER TOTAL BREAKDOWN
                  Text(
                    'Cost Breakdown',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Subtotal'),
                              Text('RM ${subtotal.toStringAsFixed(2)}'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Delivery Fee'),
                              Text(
                                deliveryFee == 0
                                    ? 'FREE'
                                    : 'RM ${deliveryFee.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: deliveryFee == 0 ? const Color(0xFF2E7D32) : Colors.black,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Grand Total',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'RM ${grandTotal.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 20,
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
                  const SizedBox(height: 28),

                  // 5. PLACE ORDER BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : () => _handlePlaceOrder(cart, user.uid),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'Place Order • RM ${grandTotal.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
