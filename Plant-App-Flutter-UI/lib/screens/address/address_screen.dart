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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
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
            const SnackBar(
              content: Text('Address removed successfully.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete address: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
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
          const SnackBar(
            content: Text('Set as default delivery address.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set default address: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
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
        backgroundColor: kBackgroundColor,
        appBar: AppBar(title: const Text('My Addresses')),
        body: const Center(child: Text('Please log in to manage addresses.')),
      );
    }

    final uid = currentUser.uid;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text('Saved Addresses'),
        backgroundColor: kSurfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: StreamBuilder<List<Address>>(
        stream: _userService.getAddressesStream(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final addresses = snapshot.data ?? [];

          if (addresses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.location_on_outlined, size: 64, color: kPrimaryColor),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Addresses Saved',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Save your delivery address for instant checkout on plant supplies and botanicals.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Delivery Address'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => _addAddress(uid),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            itemCount: addresses.length,
            itemBuilder: (context, index) {
              final address = addresses[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: address.isDefault ? kPrimaryColor : Colors.grey.shade200,
                    width: address.isDefault ? 1.5 : 1,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _setDefaultAddress(uid, address),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: address.isDefault
                              ? kPrimaryColor.withValues(alpha: 0.12)
                              : Colors.grey.shade100,
                          child: Icon(
                            address.isDefault ? Icons.location_on : Icons.location_on_outlined,
                            color: address.isDefault ? kPrimaryColor : Colors.grey.shade600,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      address.street,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                  ),
                                  if (address.isDefault)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: kPrimaryColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'DEFAULT',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: kPrimaryColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${address.city}, ${address.state} ${address.zipCode}',
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                              ),
                              if (!address.isDefault) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Tap to set as default address',
                                  style: TextStyle(fontSize: 11, color: kPrimaryColor.withValues(alpha: 0.8), fontWeight: FontWeight.w500),
                                ),
                              ],
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                          onSelected: (val) {
                            if (val == 'edit') {
                              _editAddress(uid, address);
                            } else if (val == 'delete') {
                              _deleteAddress(uid, address);
                            } else if (val == 'default') {
                              _setDefaultAddress(uid, address);
                            }
                          },
                          itemBuilder: (ctx) => [
                            if (!address.isDefault)
                              const PopupMenuItem(
                                value: 'default',
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle_outline, size: 18, color: kPrimaryColor),
                                    SizedBox(width: 8),
                                    Text('Set Default', style: TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 18, color: Colors.black87),
                                  SizedBox(width: 8),
                                  Text('Edit Address', style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete', style: TextStyle(color: Colors.red, fontSize: 13)),
                                ],
                              ),
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
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Add Address', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _addAddress(uid),
      ),
    );
  }
}
