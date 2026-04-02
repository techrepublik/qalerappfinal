import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:joma/google_oauth_config.dart';
import 'package:joma/mainscreen.dart';
import 'services/analytics.dart';

class GoogleSignUpPage extends StatefulWidget {
  const GoogleSignUpPage({super.key});

  @override
  State<GoogleSignUpPage> createState() => _GoogleSignUpPageState();
}

class _GoogleSignUpPageState extends State<GoogleSignUpPage> {
  // Brand Color
  static const Color mintGreen = Color(0xFF00BFA5);

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: (!kIsWeb &&
            defaultTargetPlatform == TargetPlatform.iOS &&
            kGoogleIosClientId.isNotEmpty)
        ? kGoogleIosClientId
        : null,
    serverClientId: kGoogleWebServerClientId.isNotEmpty
        ? kGoogleWebServerClientId
        : null,
  );

  final String _baseUrl = 'https://ems.qalertapp.com/api';

  // final String _baseUrl = 'http://192.168.1.11:3000/api';

  Future<void> _handleGoogleSignIn() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (!mounted) return;
      _showLoadingDialog('Verifying account...');

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': idToken,
          'role': 'user',
        }),
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final userData = responseData['data'];

        // Save all user data to SharedPreferences
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
        await prefs.setString('user_id', userData['id'] ?? '');
        await prefs.setString('name', userData['name'] ?? '');
        await prefs.setString('email', userData['email'] ?? '');
        await prefs.setString('role', userData['role'] ?? 'user');
        await prefs.setString('image', userData['image'] ?? '');

        // Save all profile fields if they exist in the response
        if (userData['phone'] != null && userData['phone'] != '') {
          await prefs.setString('phone', userData['phone']);
        }
        if (userData['lguCode'] != null) {
          await prefs.setString('lguCode', userData['lguCode']);
        }
        if (userData['municipality'] != null) {
          await prefs.setString('municipality', userData['municipality']);
        }
        if (userData['barangay'] != null) {
          await prefs.setString('barangay', userData['barangay']);
        }
        if (userData['province'] != null) {
          await prefs.setString('province', userData['province']);
        }

        AnalyticsService.trackEvent(
          eventName: 'SignUp',
          lguCode: userData['lguCode'],
          screen: 'GoogleSignUp',
        );

        _showSuccess('Welcome back, ${userData['name']}');

        // Check phone from API response first, then fallback to saved prefs
        final String phone = (userData['phone'] ?? '').toString().trim();

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainScreen()),
          );
        }
      } else {
        _showError('Server authentication failed (${response.statusCode})');
      }
    } catch (error) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      _showError('Connection Error: Check your internet $error');
      debugPrint("Login Error: $error");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Q-ALERT',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Secure Emergency Portal',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 60),

                    // Google Sign In Button
                    ElevatedButton.icon(
                      onPressed: _handleGoogleSignIn,
                      icon: const FaIcon(FontAwesomeIcons.google, size: 18),
                      label: const Text(
                        "Continue with Google",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mintGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                    const Divider(color: Color(0xFFEEEEEE), thickness: 1),
                    const SizedBox(height: 20),
                    const Text(
                      "By continuing, you agree to our terms of service. "
                      "Your data is protected by Google security protocols.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // UI Helpers
  void _showLoadingDialog(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              const CircularProgressIndicator(color: mintGreen),
              const SizedBox(width: 25),
              Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.teal.shade700,
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
      ),
    );
  }
}
