import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// WEATHER SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class WeatherService {
  // static const String _baseUrl = 'http://192.168.1.7:3000';
  static const String apiBaseUrl = "https://ems.qalertapp.com";

  static Future<Map<String, dynamic>?> getWeather({
    required double lat,
    required double lon,
  }) async {
    try {
      final uri = Uri.parse('$apiBaseUrl/api/v2/weather?lat=$lat&lon=$lon');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));


      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (body['success'] == true) {
          return body['data'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// GREETING BANNER WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class GreetingBanner extends StatefulWidget {
  final String userName;
  final double? lat;
  final double? lon;

  const GreetingBanner({
    super.key,
    required this.userName,
    this.lat,
    this.lon,
  });

  @override
  State<GreetingBanner> createState() => _GreetingBannerState();
}

class _GreetingBannerState extends State<GreetingBanner> {
  Map<String, dynamic>? _weather;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final weather = await WeatherService.getWeather(
      lat: widget.lat ?? 0,
      lon: widget.lon ?? 0,
    );

    if (mounted) {
      setState(() {
        _weather = weather;
        _isLoading = false;
        _hasError = weather == null;
      });
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _getDisplayName(String fullName) {
    // Get first name only
    final firstName = fullName.trim().split(' ').first;

    // Truncate if longer than 10 characters
    const maxLength = 10;
    if (firstName.length > maxLength) {
      return '${firstName.substring(0, maxLength)}...';
    }

    return firstName;
  }



  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _getWeatherEmoji(String? condition) {
    switch (condition?.toLowerCase()) {
      case 'clear':
        return '☀️';
      case 'clouds':
        return '🌤️';
      case 'rain':
      case 'drizzle':
        return '🌧️';
      case 'thunderstorm':
        return '⛈️';
      case 'snow':
        return '❄️';
      case 'mist':
      case 'fog':
      case 'haze':
        return '🌫️';
      default:
        return '🌡️';
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _buildGreeting(),
          ),
          const SizedBox(width: 8),
          Flexible(
            fit: FlexFit.loose,
            child: Align(
              alignment: Alignment.centerRight,
              child: _buildWeather(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Greeting (left side) ───────────────────────────────────────────────────

  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _getGreeting(),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: Colors.grey[100],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _getDisplayName(widget.userName),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // ── Weather (right side) ───────────────────────────────────────────────────

  Widget _buildWeather() {
    if (_isLoading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      );
    }

    if (_hasError || _weather == null) {
      return GestureDetector(
        onTap: _loadWeather,
        child: Row(
          children: [
            Icon(Icons.refresh_rounded, size: 16, color: Colors.grey[100]),
            const SizedBox(width: 4),
            Text(
              'Retry',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      );
    }

    final int? temperature = _weather!['temperature'] as int?;
    final String? condition = _weather!['condition'] as String?;
    final int? humidity = _weather!['humidity'] as int?;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _getWeatherEmoji(condition),
          style: const TextStyle(fontSize: 28),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                temperature != null ? '$temperature°C' : '--°C',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      condition ?? '--',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey[200],
                      ),
                    ),
                  ),
                  if (humidity != null) ...[
                    Text(
                      '  •  $humidity%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}