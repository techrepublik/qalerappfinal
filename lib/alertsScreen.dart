import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import '../models/alertModel.dart';

class AlertScreen extends StatefulWidget {
  final String lguCode;
  final double userLat;
  final double userLng;

  const AlertScreen({
    super.key,
    required this.lguCode,
    required this.userLat,
    required this.userLng,
  });

  @override
  State<AlertScreen> createState() => _AlertScreenState();
}

class _AlertScreenState extends State<AlertScreen> {
  late Future<List<Alert>> _alertsFuture;

  // final String apiBaseUrl = "http://192.168.1.7:3000";

  final String apiBaseUrl = "https://ems.qalertapp.com";
  final String _apiKey = dotenv.env['MOBILE_API_KEY'] ?? '';

  @override
  void initState() {
    super.initState();
    _alertsFuture = fetchAlerts();
  }

  // Re-fetch if lguCode changes (mirrors didUpdateWidget in HospitalListView)
  @override
  void didUpdateWidget(AlertScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lguCode != widget.lguCode) {
      setState(() {
        _alertsFuture = fetchAlerts();
      });
    }
  }

  // ─── Fetch ───────────────────────────────────────────────────────────────────

  Future<List<Alert>> fetchAlerts() async {

    // 1. Properly attach the lguCode as a query parameter
    final uri = Uri.parse('$apiBaseUrl/api/v2/alerts/?lguCode=${widget.lguCode}');

    final response = await http.get(
      uri,
      headers: {
        'x-api-key': _apiKey,
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> body = json.decode(utf8.decode(response.bodyBytes));


      final List<dynamic> alertList = body['data'] ?? [];

      return alertList
          .map((data) => Alert.fromJson(data))
          .where((a) => a.status == 'published')
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      debugPrint(
        'Alerts API ${response.statusCode}: check MOBILE_API_KEY in .env matches ems.qalertapp.com',
      );
      return [];
    }

    debugPrint('Alerts API error: ${response.statusCode}');
    throw Exception('Failed to load alerts: ${response.reasonPhrase}');
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Alert>>(
      future: _alertsFuture,
      builder: (context, snapshot) {
        // ✅ Show skeleton while waiting
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildAlertSkeleton();
        }

        // ✅ Silently hide on error or empty — no red flash
        else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        // ✅ Show list
        return _buildAlertsList(snapshot.data!);
      },
    );
  }

  // ─── Skeleton (mirrors _buildHospitalSkeleton) ────────────────────────────────

  Widget _buildAlertSkeleton() {

    return Container(
      color: Colors.transparent, // ✅ explicit, not null
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header placeholder
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 140,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Spacer(),
              Container(
                width: 60,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),

        // Skeleton rows
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: List.generate(4, (index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    // Dot
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Title + time
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 140,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 80,
                            height: 11,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Location
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          width: 70,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 45,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    )
    );
  }

  // ─── Full List (mirrors _buildHospitalsNearby) ────────────────────────────────

  Widget _buildAlertsList(List<Alert> alerts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5252).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Color(0xFFFF5252),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Recent Alerts',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Count badge  (mirrors "3 found" in hospitals)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5252),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${alerts.length} alerts',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Alert rows card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: alerts.asMap().entries.map((entry) {
              final index = entry.key;
              final alert = entry.value;
              return Column(
                children: [
                  _buildAlertRow(alert),
                  // Divider between rows (not after last)
                  if (index < alerts.length - 1)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      indent: 34,
                      color: Color(0xFFF0F0F0),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ─── Single Row ───────────────────────────────────────────────────────────────

  Widget _buildAlertRow(Alert alert) {
    final dotColor = _getAlertColor(alert.emergencyType);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final lat = alert.location.latitude;
          final lng = alert.location.longitude;
          final label = Uri.encodeComponent(alert.emergencyType);

          // Opens Google Maps marker at exact alert coordinates
          final googleMapsUri = Uri.parse(
            'https://maps.google.com/maps?q=$lat,$lng&z=10',
          );

          // Falls back to geo: URI if Google Maps app isn't installed
          final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng($label)');

          if (await canLaunchUrl(googleMapsUri)) {
            await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
          } else if (await canLaunchUrl(geoUri)) {
            await launchUrl(geoUri, mode: LaunchMode.externalApplication);
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not open maps')),
              );
            }
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dot
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title + time (more flex than LGU column)
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      timeago.format(alert.createdAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),

              // Location — long LGU names (e.g. President Roxas)
              Flexible(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      alert.lguCode,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'location',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Color _getAlertColor(String emergencyType) {
    switch (emergencyType.toLowerCase()) {
      case 'Fire incident':
      case 'fire':
        return const Color(0xFFF44336);
      case 'Vehicular accident':
      case 'ambulance':
        return const Color(0xFFFF5722);
      case 'Flood advisory':
      case 'flood':
        return const Color(0xFF2196F3);
      case 'Heavy rain warning':
      case 'Typhoon warning':
        return const Color(0xFFFF9800);
      case 'Heat index warnings':
      case 'police':
        return const Color(0xFFFF7500);
      case 'Landslide warning':
      case 'landslide':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF9E9E9E);
    }
  }
}