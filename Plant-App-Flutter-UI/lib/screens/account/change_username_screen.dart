import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/services/user_service.dart';

class ChangeUsernameScreen extends StatefulWidget {
  final String? currentUsername;

  const ChangeUsernameScreen({super.key, this.currentUsername});

  @override
  State<ChangeUsernameScreen> createState() => _ChangeUsernameScreenState();
}

class _ChangeUsernameScreenState extends State<ChangeUsernameScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  final UserService _userService = UserService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.currentUsername ?? '');
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User session expired. Please log in again.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _userService.updateUsername(user.uid, _usernameController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Username updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
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
        title: const Text("Change Username"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(kDefaultPadding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Enter your new username below.",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: kDefaultPadding),
              TextFormField(
                controller: _usernameController,
                enabled: !_isLoading,
                decoration: const InputDecoration(
                  labelText: "New Username",
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a username';
                  }
                  if (value.trim().length < 3) {
                    return 'Username must be at least 3 characters long';
                  }
                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value.trim())) {
                    return 'Username can only contain letters, numbers, and underscores';
                  }
                  return null;
                },
              ),
              const SizedBox(height: kDefaultPadding),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveChanges,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Save Changes"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
