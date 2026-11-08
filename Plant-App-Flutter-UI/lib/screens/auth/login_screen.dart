import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/screens/auth/forgot_password_screen.dart';
import 'package:urbangreen/screens/auth/register_screen.dart';
import 'package:urbangreen/screens/main/main_screen.dart';
import 'package:urbangreen/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _autofillTestAccount() {
    _usernameController.text = 'test@urbangreen.com';
    _passwordController.text = 'Password123!';
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⚡ Test Account credentials autofilled!'),
        backgroundColor: kPrimaryColor,
        duration: Duration(seconds: 4),
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.loginWithEmailOrUsername(
        identifier: _usernameController.text,
        password: _passwordController.text,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String message = e.message ?? 'Authentication failed.';
        if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
          message = 'Invalid email/username or password.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: kStatusDanger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: kStatusDanger,
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
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Botanical Brand Header
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: kPrimaryColor.withValues(alpha: 0.28),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 78,
                        height: 78,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [kPrimaryLight, kPrimaryColor],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Icon(
                            Icons.spa_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'UrbanGreen',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Smart Botanical Intelligence & Pathology',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Login Card Container
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: kBorderSubtle),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome Back',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sign in to sync your garden & smart sensors',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 20),

                        // Username / Email
                        TextFormField(
                          controller: _usernameController,
                          enabled: !_isLoading,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email or Username',
                            prefixIcon: Icon(Icons.alternate_email, size: 20, color: Colors.grey.shade600),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your email or username';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Password
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          enabled: !_isLoading,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline, size: 20, color: Colors.grey.shade600),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 20,
                                color: Colors.grey.shade600,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),

                        // Forgot password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                            onPressed: _isLoading
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                                    );
                                  },
                            child: const Text('Forgot Password?', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Sign In Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Sign In to UrbanGreen', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Quick Demo Autofill Chip
                  OutlinedButton.icon(
                    onPressed: _autofillTestAccount,
                    icon: const Icon(Icons.bolt, color: Colors.amber, size: 18),
                    label: const Text(
                      'Autofill Demo Test Account',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Register link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("New to UrbanGreen?", style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const RegisterScreen()),
                                );
                              },
                        child: const Text(
                          'Create Account',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
