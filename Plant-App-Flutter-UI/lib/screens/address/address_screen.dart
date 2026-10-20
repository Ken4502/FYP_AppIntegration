import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/models/address_model.dart';
import 'package:urbangreen/screens/address/add_address_screen.dart';
import 'package:urbangreen/screens/address/edit_address_screen.dart';
import 'package:urbangreen/services/user_service.dart';

class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});

  @override
  AddressScreenState createState() => AddressScreenState();
}

class AddressScreenState extends State<AddressScreen> {
  final UserService _userService = UserService();

  void _addAddress(String uid) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddAddressScreen(uid: uid),
      ),
    );
  }

  void _editAddress(String uid, Address address) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditAddressScreen(
          uid: uid,
          address: address,
        ),
      ),
    );
  }

  Future<void> _deleteAddress(String uid, Address address) async {
    if (address.id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Address'),
        content: const Text('Are you sure you want to delete this address?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _userService.deleteAddress(uid, address.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Address deleted.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete address: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _setDefaultAddress(String uid, Address address) async {
    if (address.id == null || address.isDefault) return;

    try {
      await _userService.setDefaultAddress(uid, address.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Set as default address.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set default address: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Addresses')),
        body: const Center(child: Text('Please log in to manage addresses.')),
      );
    }

    final uid = currentUser.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Addresses'),
      ),
      body: StreamBuilder<List<Address>>(
        stream: _userService.getAddressesStream(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final addresses = snapshot.data ?? [];

          if (addresses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_off_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No addresses saved yet.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _addAddress(uid),
                    child: const Text('Add New Address'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: addresses.length,
            itemBuilder: (context, index) {
              final address = addresses[index];
              return Card(
                margin: const EdgeInsets.all(kDefaultPaddingSmall),
                child: ListTile(
                  title: Row(
                    children: [
                      Expanded(child: Text(address.street)),
                      if (address.isDefault)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Default',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text('${address.city}, ${address.state} ${address.zipCode}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _editAddress(uid, address),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteAddress(uid, address),
                      ),
                    ],
                  ),
                  onTap: () => _setDefaultAddress(uid, address),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addAddress(uid),
        child: const Icon(Icons.add),
      ),
    );
  }
}
