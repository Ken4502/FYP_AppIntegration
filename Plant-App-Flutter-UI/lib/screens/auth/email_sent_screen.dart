import 'package:flutter/material.dart';
import 'package:urbangreen/constants.dart';
import 'package:urbangreen/screens/auth/login_screen.dart';

class EmailSentScreen extends StatelessWidget {
  const EmailSentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? kDarkBackgroundColor : kBackgroundColor,
      appBar: AppBar(
        title: const Text('Check Your Inbox'),
        backgroundColor: isDark ? kDarkSurfaceColor : kSurfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_read_rounded,
                  size: 64,
                  color: kPrimaryColor,
                ),
              ),
              const SizedBox(height: 28.0),
              Text(
                'Recovery Link Dispatched',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: isDark ? kDarkTextPrimary : kTextPrimary),
              ),
              const SizedBox(height: 12.0),
              Text(
                'We have sent a secure password reset link to your email address. Please follow the instructions in the email to restore account access.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: isDark ? kDarkTextSecondary : Colors.grey.shade600, height: 1.5),
              ),
              const SizedBox(height: 36.0),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                  ),
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (Route<dynamic> route) => false,
                    );
                  },
                  child: const Text('Back to Login', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
