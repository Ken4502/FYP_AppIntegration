import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:urbangreen/components/achievements_sheet.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/models/theme_provider.dart';
import 'package:urbangreen/models/user_model.dart';
import 'package:urbangreen/screens/account/change_password_screen.dart';
import 'package:urbangreen/screens/account/change_username_screen.dart';
import 'package:urbangreen/screens/account/order_history_screen.dart';
import 'package:urbangreen/screens/address/address_screen.dart';
import 'package:urbangreen/screens/auth/login_screen.dart';
import 'package:urbangreen/screens/garden/plant_list_screen.dart';
import 'package:urbangreen/screens/iot/iot_management_screen.dart';
import 'package:urbangreen/screens/reports/reports_screen.dart';
import 'package:urbangreen/services/achievement_service.dart';
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
      AuthService.setGuestMode(false);
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscurePassword = true;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: kStatusDanger, size: 28),
                  SizedBox(width: 8),
                  Text('Delete Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'This action is irreversible. All your profile information, cloud-synchronized garden plants, and saved delivery addresses will be permanently deleted.',
                      style: TextStyle(fontSize: 13, color: kTextPrimary, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Please confirm your password to proceed:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextPrimary),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        hintText: 'Current password',
                        isDense: true,
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 20,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Enter password to confirm' : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(dialogCtx, true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kStatusDanger,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Permanently Delete'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    final enteredPassword = passwordController.text;

    try {
      await _authService.deleteAccount(currentPassword: enteredPassword);
      AuthService.setGuestMode(false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your UrbanGreen account has been permanently deleted.'),
            backgroundColor: kStatusDanger,
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String msg = e.message ?? 'Failed to delete account.';
        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          msg = 'Incorrect password. Account deletion cancelled.';
        } else if (e.code == 'requires-recent-login') {
          msg = 'Security timeout. Please sign out, log back in, and try deleting again.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: kStatusDanger),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: kStatusDanger),
        );
      }
    }
  }

  ImageProvider? _getAvatarImage(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) {
      return null;
    }
    if (photoUrl.startsWith('http')) {
      return NetworkImage(photoUrl);
    }
    if (File(photoUrl).existsSync()) {
      return FileImage(File(photoUrl));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;

    if (currentUser == null) {
      return _buildGuestAccountView();
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
                              child: _getAvatarImage(photoUrl) == null
                                  ? const Icon(Icons.person, size: 44, color: kPrimaryColor)
                                  : null,
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
                      // Achievements & Milestones Group
                      _buildAchievementsCard(),
                      const SizedBox(height: 18),

                      // Appearance & Theme Group
                      _buildAppearanceSection(),
                      const SizedBox(height: 18),

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
                            const Divider(height: 1, indent: 56),
                            _buildOptionTile(
                              icon: Icons.delete_forever_outlined,
                              color: kStatusDanger,
                              title: 'Delete Account',
                              subtitle: 'Permanently remove your account & all data',
                              onTap: _confirmDeleteAccount,
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
                      const SizedBox(height: 24),

                      // App Info & Version Branding Footer
                      _buildBrandFooter(),
                      const SizedBox(height: 36),
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

  Widget _buildBrandFooter() {
    return Center(
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 20,
                  height: 20,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.spa_rounded,
                    size: 18,
                    color: kPrimaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'UrbanGreen',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: kTextPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Version 1.0.0 (Flagship AI & IoT Ecosystem)',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestAccountView() {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: CustomScrollView(
        slivers: [
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
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: kPrimaryColor.withValues(alpha: 0.15),
                      child: const Icon(Icons.person_outline_rounded, size: 44, color: kPrimaryColor),
                    ),
                    const SizedBox(height: 10),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Guest Explorer',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: kTextPrimary,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.explore_outlined, color: kPrimaryColor, size: 18),
                      ],
                    ),
                    Text(
                      'Browsing offline & local mode • No account linked',
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sign In / Create Account Callout Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: kPrimaryColor.withValues(alpha: 0.3)),
                    ),
                    color: kSurfaceColor,
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: kPrimaryColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.cloud_upload_outlined, color: kPrimaryColor, size: 22),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Sync Garden with UrbanGreen Cloud',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: kTextPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Create an account to backup your plants to the cloud, enable multi-device sync, receive push moisture notifications, and save shipping addresses.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                                );
                              },
                              icon: const Icon(Icons.login, size: 18, color: Colors.white),
                              label: const Text('Sign In or Create Account', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimaryColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Achievements & Milestones Group (Guest mode supported)
                  _buildAchievementsCard(),
                  const SizedBox(height: 18),

                  // Appearance & Theme Group
                  _buildAppearanceSection(),
                  const SizedBox(height: 18),

                  // Garden & Features Group
                  _buildSectionHeader('Local Features'),
                  const SizedBox(height: 8),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        _buildOptionTile(
                          icon: Icons.yard_outlined,
                          color: Colors.teal.shade700,
                          title: 'My Garden Sanctuary',
                          subtitle: 'View local specimens, watering status & care profiles',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const PlantListScreen()),
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
                          icon: Icons.sensors,
                          color: Colors.indigo.shade700,
                          title: 'IoT Hardware Gateway',
                          subtitle: 'Connect ESP32 telemetry nodes & soil moisture sensors',
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

                  // Session Section
                  _buildSectionHeader('Guest Session'),
                  const SizedBox(height: 8),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: _buildOptionTile(
                      icon: Icons.exit_to_app,
                      color: kStatusDanger,
                      title: 'Exit Guest Mode',
                      subtitle: 'Return to login and registration screen',
                      onTap: () {
                        AuthService.setGuestMode(false);
                        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                          (route) => false,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // App Info & Version Branding Footer
                  _buildBrandFooter(),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsCard() {
    final achievements = AchievementService().getAchievements();
    final unlockedCount = achievements.where((a) => a.isUnlocked).length;
    final totalCount = achievements.length;
    final progress = totalCount > 0 ? unlockedCount / totalCount : 0.0;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: const Color(0xFFE9C46A).withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      color: isDark ? kDarkCardColor : const Color(0xFFFFFDF5),
      child: InkWell(
        onTap: () => AchievementsSheet.show(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9C46A).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: Color(0xFFD4A373),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Gardener Milestones',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$unlockedCount of $totalCount Unlocked • Tap to view badges',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: isDark ? kDarkBorderSubtle : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 1.0 ? Colors.green.shade600 : const Color(0xFFD4A373),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: achievements.map((a) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: a.isUnlocked
                            ? a.color.withValues(alpha: 0.12)
                            : (isDark ? kDarkSurfaceColor : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: a.isUnlocked
                              ? a.color.withValues(alpha: 0.3)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            a.icon,
                            size: 13,
                            color: a.isUnlocked ? a.color : Colors.grey.shade400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            a.title,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: a.isUnlocked ? FontWeight.bold : FontWeight.normal,
                              color: a.isUnlocked ? a.color : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppearanceSection() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Appearance & Display'),
        const SizedBox(height: 8),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SwitchListTile(
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.amber.withValues(alpha: 0.15)
                    : Colors.blueGrey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: isDark ? Colors.amber : Colors.blueGrey.shade700,
                size: 20,
              ),
            ),
            title: const Text(
              'Botanical Dark Mode',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              isDark
                  ? 'Night obsidian theme active'
                  : 'Daylight porcelain theme active',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            value: isDark,
            onChanged: (val) => themeProvider.toggleTheme(),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
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
