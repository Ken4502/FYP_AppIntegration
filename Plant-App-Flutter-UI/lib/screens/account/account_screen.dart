import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/models/user_model.dart';
import 'package:urbangreen/screens/account/change_password_screen.dart';
import 'package:urbangreen/screens/account/change_username_screen.dart';
import 'package:urbangreen/screens/account/order_history_screen.dart';
import 'package:urbangreen/screens/address/address_screen.dart';
import 'package:urbangreen/screens/auth/login_screen.dart';
import 'package:urbangreen/screens/garden/plant_list_screen.dart';
import 'package:urbangreen/screens/iot/iot_management_screen.dart';
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
            backgroundColor: kPrimaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update picture: $e'),
            backgroundColor: kStatusDanger,
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
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to log out of UrbanGreen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: kStatusDanger),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
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
      backgroundColor: kBackgroundColor,
      body: StreamBuilder<UserModel?>(
        stream: _userService.getUserProfileStream(currentUser.uid),
        builder: (context, snapshot) {
          final userModel = snapshot.data;
          final username = userModel?.username ?? currentUser.displayName ?? "Botanist";
          final email = userModel?.email ?? currentUser.email ?? "";
          final photoUrl = userModel?.photoUrl ?? currentUser.photoURL;

          return CustomScrollView(
            slivers: [
              // Header Profile Sliver
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: kSurfaceColor,
                surfaceTintColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          kAccentMint.withValues(alpha: 0.6),
                          kBackgroundColor,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 44,
                              backgroundColor: kPrimaryColor.withValues(alpha: 0.15),
                              backgroundImage: _getAvatarImage(photoUrl),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: InkWell(
                                onTap: _isUploadingImage
                                    ? null
                                    : () => _pickAndUploadProfileImage(currentUser.uid),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: kPrimaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                            if (_isUploadingImage)
                              const Positioned.fill(
                                child: CircularProgressIndicator(),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          username,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: kTextPrimary,
                          ),
                        ),
                        Text(
                          email,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Settings Options
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Garden & Activity Group
                      _buildSectionHeader('Garden & Orders'),
                      const SizedBox(height: 8),
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          children: [
                            _buildOptionTile(
                              icon: Icons.receipt_long_outlined,
                              color: kPrimaryColor,
                              title: 'Order History',
                              subtitle: 'View past supplies purchases, receipt & order tracking',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const OrderHistoryScreen()),
                                );
                              },
                            ),
                            const Divider(height: 1, indent: 56),
                            _buildOptionTile(
                              icon: Icons.analytics_outlined,
                              color: Colors.blue.shade700,
                              title: 'Health & Watering Reports',
                              subtitle: 'Foliage pathology, soil hydration & care analytics',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const ReportsScreen()),
                                );
                              },
                            ),
                            const Divider(height: 1, indent: 56),
                            _buildOptionTile(
                              icon: Icons.yard_outlined,
                              color: Colors.teal.shade700,
                              title: 'My Garden Sanctuary',
                              subtitle: 'Manage specimens, watering status & care profiles',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const PlantListScreen()),
                                );
                              },
                            ),
                            const Divider(height: 1, indent: 56),
                            _buildOptionTile(
                              icon: Icons.sensors,
                              color: Colors.indigo.shade700,
                              title: 'IoT Hardware Gateway',
                              subtitle: 'Telemetry nodes, live soil moisture & pump pulse',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const IotManagementScreen()),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Account Settings Group
                      _buildSectionHeader('Account & Security'),
                      const SizedBox(height: 8),
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          children: [
                            _buildOptionTile(
                              icon: Icons.badge_outlined,
                              color: Colors.teal.shade700,
                              title: 'Change Username',
                              subtitle: 'Update your display identifier',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChangeUsernameScreen(currentUsername: username),
                                  ),
                                );
                              },
                            ),
                            const Divider(height: 1, indent: 56),
                            _buildOptionTile(
                              icon: Icons.lock_outline,
                              color: Colors.indigo.shade700,
                              title: 'Change Password',
                              subtitle: 'Secure your account credentials',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
                                );
                              },
                            ),
                            const Divider(height: 1, indent: 56),
                            _buildOptionTile(
                              icon: Icons.location_on_outlined,
                              color: Colors.orange.shade800,
                              title: 'Delivery Addresses',
                              subtitle: 'Manage saved shipping destinations',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const AddressScreen()),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Sign Out
                      _buildSectionHeader('Session'),
                      const SizedBox(height: 8),
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: _buildOptionTile(
                          icon: Icons.logout,
                          color: kStatusDanger,
                          title: 'Sign Out',
                          subtitle: 'Log out of this device',
                          onTap: _logout,
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: kTextPrimary,
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
      onTap: onTap,
    );
  }
}
