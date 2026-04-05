import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// POSTs the stored FCM token to `/api/v2/fcm/register` when `fcm_token`,
/// `user_id`, and `lguCode` are all present (e.g. after login or LGU change).
Future<void> registerFcmTokenWithBackend() async {
  final prefs = await SharedPreferences.getInstance();
  final String? token = prefs.getString('fcm_token');
  final String? userId = prefs.getString('user_id');
  final String? lguCode = prefs.getString('lguCode');

  if (token == null || token.isEmpty) return;
  if (userId == null ||
      userId.isEmpty ||
      lguCode == null ||
      lguCode.isEmpty) {
    // Normal before login; after login we call this again from GoogleSignUp / MainScreen.
    return;
  }

  final String apiKey = dotenv.env['MOBILE_API_KEY'] ?? '';
  try {
    final http.Response response = await http.post(
      Uri.parse('https://ems.qalertapp.com/api/v2/fcm/register'),
      headers: {'Content-Type': 'application/json', 'x-api-key': apiKey},
      body: jsonEncode({
        'userId': userId,
        'lguCode': lguCode,
        'token': token,
      }),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      debugPrint('FCM token registered with backend');
    } else {
      debugPrint('FCM register HTTP ${response.statusCode}: ${response.body}');
    }
  } catch (e, st) {
    debugPrint('FCM register failed: $e');
    debugPrint('$st');
  }
}
