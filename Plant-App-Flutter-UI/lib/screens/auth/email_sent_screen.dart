import 'package:flutter/material.dart';
import 'package:urbangreen/screens/auth/login_screen.dart';

class EmailSentScreen extends StatelessWidget {
  const EmailSentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Sent'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.email,
                size: 48.0 * 2,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 32.0),
              Text(
                'A password reset link has been sent to your email address.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32.0),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 16.0 * 2.5),
                ),
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                    (Route<dynamic> route) => false,
                  );
                },
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
