import 'package:flutter/material.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/models/address_model.dart';
import 'package:urbangreen/services/user_service.dart';

class AddAddressScreen extends StatefulWidget {
  final String uid;
  final Function(Address)? onAdd;

  const AddAddressScreen({
    super.key,
    required this.uid,
    this.onAdd,
  });

  @override
  AddAddressScreenState createState() => AddAddressScreenState();
}

class AddAddressScreenState extends State<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();
  final UserService _userService = UserService();
  bool _isDefault = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  Future<void> _submitAddress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final newAddress = Address(
      street: _streetController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      zipCode: _zipController.text.trim(),
      isDefault: _isDefault,
    );

    try {
      await _userService.addAddress(widget.uid, newAddress);
      if (widget.onAdd != null) {
        widget.onAdd!(newAddress);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Address added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add address: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Address'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(kDefaultPadding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _streetController,
                enabled: !_isLoading,
                decoration: const InputDecoration(labelText: 'Street Address'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a street address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: kDefaultPadding),
              TextFormField(
                controller: _cityController,
                enabled: !_isLoading,
                decoration: const InputDecoration(labelText: 'City'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a city';
                  }
                  return null;
                },
              ),
              const SizedBox(height: kDefaultPadding),
              TextFormField(
                controller: _stateController,
                enabled: !_isLoading,
                decoration: const InputDecoration(labelText: 'State / Province'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a state';
                  }
                  return null;
                },
              ),
              const SizedBox(height: kDefaultPadding),
              TextFormField(
                controller: _zipController,
                enabled: !_isLoading,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Zip / Postal Code'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a zip code';
                  }
                  return null;
                },
              ),
              const SizedBox(height: kDefaultPadding),
              CheckboxListTile(
                value: _isDefault,
                title: const Text('Set as default address'),
                onChanged: _isLoading
                    ? null
                    : (val) {
                        setState(() {
                          _isDefault = val ?? false;
                        });
                      },
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: kDefaultPadding),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitAddress,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add Address'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
