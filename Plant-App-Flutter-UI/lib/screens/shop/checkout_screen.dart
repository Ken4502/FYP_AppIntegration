import 'package:flutter/material.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/screens/shop/order_confirmation_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: kPrimaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Items',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3, // Replace with actual cart item count
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 5),
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
            const SizedBox(height: 20),
            const Text(
              'Delivery Option',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Card(
              child: ListTile(
                title: Text('Standard Delivery'),
                trailing: Text('\$5.00'),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Payment Method',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Card(
              child: ListTile(
                leading: Icon(Icons.credit_card),
                title: Text('**** **** **** 1234'),
                trailing: Icon(Icons.arrow_forward_ios),
              ),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal',
                  style: TextStyle(fontSize: 16),
                ),
                Text(
                  '\$30.00', // Replace with actual subtotal
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Delivery',
                  style: TextStyle(fontSize: 16),
                ),
                Text(
                  '\$5.00', // Replace with actual delivery fee
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  '\$35.00', // Replace with actual total amount
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OrderConfirmationScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Place Order',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
