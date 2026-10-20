import 'package:flutter/material.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/models/address_model.dart';
import 'package:urbangreen/services/user_service.dart';

class EditAddressScreen extends StatefulWidget {
  final String uid;
  final Address address;
  final Function(Address)? onEdit;

  const EditAddressScreen({
    super.key,
    required this.uid,
    required this.address,
    this.onEdit,
  });

  @override
  EditAddressScreenState createState() => EditAddressScreenState();
}

class EditAddressScreenState extends State<EditAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _streetController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _zipController;
  final UserService _userService = UserService();
  late bool _isDefault;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _streetController = TextEditingController(text: widget.address.street);
    _cityController = TextEditingController(text: widget.address.city);
    _stateController = TextEditingController(text: widget.address.state);
    _zipController = TextEditingController(text: widget.address.zipCode);
    _isDefault = widget.address.isDefault;
  }

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

    final updatedAddress = Address(
      id: widget.address.id,
      street: _streetController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      zipCode: _zipController.text.trim(),
      isDefault: _isDefault,
    );

    try {
      await _userService.updateAddress(widget.uid, updatedAddress);
      if (widget.onEdit != null) {
        widget.onEdit!(updatedAddress);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Address updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update address: $e'),
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
        title: const Text('Edit Address'),
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
                    : const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
