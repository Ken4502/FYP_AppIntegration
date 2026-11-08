import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urbangreen/firebase_options.dart';
import 'package:urbangreen/models/cart_model.dart';
import 'package:urbangreen/screens/auth/login_screen.dart';
import 'package:urbangreen/screens/main/main_screen.dart';
import 'package:urbangreen/services/care_log_service.dart';
import 'package:urbangreen/services/low_moisture_decision_service.dart';
import 'package:urbangreen/services/platform/web_hardware_bridge.dart';
import 'package:urbangreen/services/plant_service.dart';
import 'package:urbangreen/theme.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Preload local storage into memory so synchronous reads work instantly
  await WebHardwareBridge.init();
  // Restore user's garden plants before launching UI
  await PlantService().init();
  // Restore user's hydration care logs
  await CareLogService().init();
  // Initialize Low Moisture Decision & Notification service with navigator key
  LowMoistureDecisionService().init(appNavigatorKey);

  // Custom user-friendly error widget builder across the app
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 54),
              const SizedBox(height: 12),
              const Text(
                'Interface Notice',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString(),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CartModel>(
      create: (context) => CartModel(),
      child: MaterialApp(
        navigatorKey: appNavigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'UrbanGreen',
        theme: AppTheme.lightTheme,
        themeMode: ThemeMode.light,
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    const Text('Authentication Notice', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                      child: const Text('Go to Login'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          return const MainScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
