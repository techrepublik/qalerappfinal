// lib/services/analytics_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AnalyticsService {
  static const String _baseUrl = 'https://ems.qalertapp.com'; // 🔁 change this

  static Future<void> trackEvent({
    required String eventName,
    required String lguCode,
    required String screen,
  }) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/analytics'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'lguCode': lguCode,
          'eventName': eventName,
          'screen': screen,
        }),
      );
    } catch (e) {
      debugPrint('Analytics tracking error: $e');
    }
  }
}