import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _retypePasswordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureRetype = true;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _retypePasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.registerWithEmailAndPassword(
        email: _emailController.text,
        username: _usernameController.text,
        password: _passwordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful! Welcome to UrbanGreen.'),
            backgroundColor: kPrimaryColor,
          ),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String message = e.message ?? 'Registration failed.';
        if (e.code == 'email-already-in-use') {
          message = 'The email address is already in use by another account.';
        } else if (e.code == 'weak-password') {
          message = 'The password provided is too weak (minimum 6 characters).';
        } else if (e.code == 'invalid-email') {
          message = 'The email address is invalid.';
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
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Brand Emblem
                  Container(
                    width: 64,
                    height: 64,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: kPrimaryColor.withValues(alpha: 0.22),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 64,
                        height: 64,
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
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Card Container
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
                          'Join UrbanGreen',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Start monitoring your smart urban plants & pathology telemetry',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 22),

                        // Email
                        TextFormField(
                          controller: _emailController,
                          enabled: !_isLoading,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon: Icon(Icons.email_outlined, size: 20),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your email';
                            }
                            final emailRegex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
                            if (!emailRegex.hasMatch(value.trim())) {
                              return 'Please enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Username
                        TextFormField(
                          controller: _usernameController,
                          enabled: !_isLoading,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            prefixIcon: Icon(Icons.person_outline, size: 20),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your username';
                            }
                            if (value.trim().length < 3) {
                              return 'Username must be at least 3 characters long';
                            }
                            if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value.trim())) {
                              return 'Letters, numbers, and underscores only';
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
                            prefixIcon: const Icon(Icons.lock_outline, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 20,
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
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters long';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Retype Password
                        TextFormField(
                          controller: _retypePasswordController,
                          obscureText: _obscureRetype,
                          enabled: !_isLoading,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            prefixIcon: const Icon(Icons.lock_outline, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureRetype ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureRetype = !_obscureRetype;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please retype your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Register Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _register,
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
                                : const Text('Complete Registration', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Already have an account
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Already have an account?', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
