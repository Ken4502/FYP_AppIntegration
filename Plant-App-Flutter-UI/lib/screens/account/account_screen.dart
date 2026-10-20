import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/models/user_model.dart';
import 'package:urbangreen/screens/account/change_password_screen.dart';
import 'package:urbangreen/screens/account/change_username_screen.dart';
import 'package:urbangreen/screens/address/address_screen.dart';
import 'package:urbangreen/screens/auth/login_screen.dart';
import 'package:urbangreen/screens/reports/reports_screen.dart';
import 'package:urbangreen/services/auth_service.dart';
import 'package:urbangreen/services/user_service.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();
  bool _isUploadingImage = false;

  Future<void> _pickAndUploadProfileImage(String uid) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      await _userService.updateProfilePicture(uid, pickedFile);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update picture: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  ImageProvider _getAvatarImage(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) {
      return const AssetImage('assets/images/user_placeholder.png');
    }
    if (photoUrl.startsWith('http')) {
      return NetworkImage(photoUrl);
    }
    if (File(photoUrl).existsSync()) {
      return FileImage(File(photoUrl));
    }
    return const AssetImage('assets/images/user_placeholder.png');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Not logged in.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: StreamBuilder<UserModel?>(
        stream: _userService.getUserProfileStream(currentUser.uid),
        builder: (context, snapshot) {
          final userModel = snapshot.data;
          final username = userModel?.username ?? currentUser.displayName ?? "User";
          final email = userModel?.email ?? currentUser.email ?? "";
          final photoUrl = userModel?.photoUrl ?? currentUser.photoURL;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(kDefaultPadding),
            child: Column(
              children: [
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundImage: _getAvatarImage(photoUrl),
                          ),
                          if (_isUploadingImage)
                            const Positioned.fill(
                              child: CircularProgressIndicator(),
                            ),
                        ],
                      ),
                      const SizedBox(height: kDefaultPadding / 2),
                      Text(
                        username,
                        style: theme.textTheme.titleLarge,
                      ),
                      Text(
                        email,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: kDefaultPadding * 2),
                _buildAccountOption(
                  context,
                  icon: Icons.person_outline,
                  text: "Change Username",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChangeUsernameScreen(
                          currentUsername: username,
                        ),
                      ),
                    );
                  },
                ),
                _buildAccountOption(
                  context,
                  icon: Icons.image_outlined,
                  text: "Change Profile Picture",
                  onTap: _isUploadingImage
                      ? null
                      : () => _pickAndUploadProfileImage(currentUser.uid),
                ),
                _buildAccountOption(
                  context,
                  icon: Icons.lock_outline,
                  text: "Change Password",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChangePasswordScreen(),
                      ),
                    );
                  },
                ),
                _buildAccountOption(
                  context,
                  icon: Icons.location_on_outlined,
                  text: "Change Address",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddressScreen(),
                      ),
                    );
                  },
                ),
                _buildAccountOption(
                  context,
                  icon: Icons.description_outlined,
                  text: "Reports",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ReportsScreen(),
                      ),
                    );
                  },
                ),
                _buildAccountOption(
                  context,
                  icon: Icons.logout,
                  text: "Logout",
                  onTap: _logout,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAccountOption(
    BuildContext context, {
    required IconData icon,
    required String text,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(text),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
