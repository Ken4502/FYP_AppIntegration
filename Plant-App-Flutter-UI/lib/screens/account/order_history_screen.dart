import 'package:flutter/material.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/screens/account/order_history_detail_screen.dart';

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Order History"),
      ),
      body: ListView.builder(
        itemCount: 3, // Replace with actual order count
        itemBuilder: (context, index) {
          final orderId = '#${index + 1}';
          return Card(
            margin: const EdgeInsets.all(kDefaultPaddingSmall),
            child: ListTile(
              title: Text("Order $orderId"),
              subtitle: const Text("Date: 2024-07-21"),
              trailing: Text("\$${(index + 1) * 25.50}"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        OrderHistoryDetailScreen(orderId: orderId),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
