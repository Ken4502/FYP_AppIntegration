import 'package:flutter/material.dart';
import 'package:urbangreen/constants.dart';

class OrderHistoryDetailScreen extends StatelessWidget {
  final String orderId;

  const OrderHistoryDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Order $orderId'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(kDefaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Items',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: kDefaultPaddingSmall),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3, // Replace with actual order item count
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.symmetric(
                      vertical: kDefaultPaddingSmall / 2),
                  child: ListTile(
                    leading: Image.asset(
                      'assets/images/image_1.png', // Replace with actual item image
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                    title: Text(
                        'Plant ${index + 1}'), // Replace with actual item name
                    trailing:
                        const Text('\$10.00'), // Replace with actual item price
                  ),
                );
              },
            ),
            const SizedBox(height: kDefaultPadding),
            Text(
              'Delivery Address',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: kDefaultPaddingSmall),
            const Card(
              child: ListTile(
                title: Text('No 1, Jalan Abc, 12345, Kuala Lumpur'),
              ),
            ),
            const SizedBox(height: kDefaultPadding),
            Text(
              'Payment Method',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: kDefaultPaddingSmall),
            const Card(
              child: ListTile(
                leading: Icon(Icons.credit_card),
                title: Text('**** **** **** 1234'),
              ),
            ),
            const SizedBox(height: kDefaultPadding),
            const Divider(),
            const SizedBox(height: kDefaultPaddingSmall),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  '\$30.00', // Replace with actual subtotal
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: kDefaultPaddingSmall),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Delivery',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  '\$5.00', // Replace with actual delivery fee
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: kDefaultPaddingSmall),
            const Divider(),
            const SizedBox(height: kDefaultPaddingSmall),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: theme.textTheme.titleLarge,
                ),
                Text(
                  '\$35.00', // Replace with actual total amount
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
