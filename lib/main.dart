import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/confirm_account_screen.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const SnapItApp());
}

class SnapItApp extends StatelessWidget {
  const SnapItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SnapIt',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          background: const Color(0xFFF7F7F7), // SnowFlake color
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F7F7), // SnowFlake color
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/home': (context) => const MainNavigationScreen(),
        '/confirm': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>?;
          final email = args?['email'] as String?;
          return ConfirmAccountScreen(email: email ?? '');
        },
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkAuthentication(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.data == true) {
          return const MainNavigationScreen();
        }

        return const LoginScreen();
      },
    );
  }

  Future<bool> _checkAuthentication() async {
    try {
      // First check local storage for quick response
      final isLoggedInLocally = await AuthService.instance.isLoggedInLocally();

      if (!isLoggedInLocally) {
        return false;
      }

      // If locally logged in, validate with Cognito
      final isAuthenticated = await AuthService.instance.isAuthenticated();

      // If Cognito session is invalid, clear local storage
      if (!isAuthenticated) {
        await AuthService.instance.clearLoginState();
        return false;
      }

      return true;
    } catch (e) {
      // If any error occurs, clear local storage and return false
      try {
        await AuthService.instance.clearLoginState();
      } catch (_) {
        // Ignore errors when clearing storage
      }
      return false;
    }
  }
}
