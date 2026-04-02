import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:joma/services/analytics.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models/hospitals.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';





class HospitalListView extends StatefulWidget {
  // Receive coordinates from main.dart
  final double userLat;
  final double userLng;
  final String lguCode;

  const HospitalListView({
    super.key,
    required this.userLat,
    required this.userLng,
    required this.lguCode
  });

  @override
  State<HospitalListView> createState() => _HospitalListViewState();
}

class _HospitalListViewState extends State<HospitalListView> {
  late Future<List<Hospital>> futureHospitals;

  // final String apiBaseUrl = "http://192.168.1.11:3000";
  final String apiBaseUrl = "https://ems.qalertapp.com";
  final String _apiKey = dotenv.env['MOBILE_API_KEY'] ?? '';


  @override
  void initState() {
    super.initState();
    futureHospitals = fetchHospitals();
  }

  // If the user's location updates while this widget is alive,
  // you might want to re-sort or re-fetch.
  @override
  void didUpdateWidget(HospitalListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh if Location OR LGU Code changes
    if (oldWidget.lguCode != widget.lguCode ||
        oldWidget.userLat != widget.userLat ||
        oldWidget.userLng != widget.userLng) {
      setState(() {
        futureHospitals = fetchHospitals();
      });
    }
  }

  Future<List<Hospital>> fetchHospitals() async {
    print('this hospital lguCode: ${widget.lguCode}');

    final uri = Uri.parse('$apiBaseUrl/api/v2/hospitals/?lguCode=${widget.lguCode}');

    final response = await http.get(
      uri,
      headers: {
        'x-api-key': _apiKey, // store this in a constants/env file
        'Content-Type': 'application/json',
      },
    );

   if (response.statusCode == 200) {
      final Map<String, dynamic> body = json.decode(response.body);
      final List<dynamic> hospitalList = body['data'];

      List<Hospital> hospitals = hospitalList.map((data) => Hospital.fromJson(data)).toList();

      // Sort by distance using the passed-in widget coordinates
      hospitals.sort((a, b) {
        double distA = a.calculateDistance(widget.userLat, widget.userLng);
        double distB = b.calculateDistance(widget.userLat, widget.userLng);
        return distA.compareTo(distB);
      });

      return hospitals;
    } else {
      throw Exception('Failed to load hospitals');
    }
  }

  void _openUrl(String url) async {
    final Uri uri = Uri.parse(url);

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch $url");
    }
  }



  Widget _buildHospitalSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Shimmering Header Placeholder
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(width: 12),
              Container(
                width: 140, height: 20,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
              ),
            ],
          ),
        ),
        // Horizontal Scroll of Skeleton Cards
        SizedBox(
          height: 220,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: 3, // Show 3 placeholder cards
            itemBuilder: (context, index) {
              return Container(
                width: 280,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(12))),
                          Container(width: 60, height: 24, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(20))),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(width: 180, height: 18, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 8),
                      Container(width: 120, height: 14, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(child: Container(height: 40, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(12)))),
                          const SizedBox(width: 8),
                          Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(12))),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }


 @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Hospital>>(
      future: futureHospitals,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {

          return _buildHospitalSkeleton();

        } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        return _buildHospitalsNearby(snapshot.data!);
      },
    );
  }

  Widget _buildHospitalsNearby(List<Hospital> hospitals) {
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
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_hospital_rounded, color: Color(0xFF10B981), size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Nearby Private Hospitals',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: Color(0xFF1A1A1A)),
              ),
              const Spacer(),
              Text('${hospitals.length} found', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600])),
            ],
          ),
        ),

        // Horizontal List
        SizedBox(
          height: 220,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: hospitals.length,
            itemBuilder: (context, index) {
              final hospital = hospitals[index];
              // Use widget coordinates for calculation
              final distance = hospital.calculateDistance(widget.userLat, widget.userLng);

              return Container(
                width: 280,
                margin: EdgeInsets.only(right: index < hospitals.length - 1 ? 12 : 0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    // Maps deep link using hospital's coordinates

                    onTap: () {

                      AnalyticsService.trackEvent(
                        eventName: hospital.name,
                        lguCode: widget.lguCode,
                        screen: 'PrivateHospitalScreen',
                      );

                      _openUrl(hospital.facebookURI!);
                    } ,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.local_hospital, color: Colors.white, size: 24),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.near_me_rounded, color: Colors.white, size: 12),
                                    const SizedBox(width: 4),
                                    Text(
                                      distance < 1
                                          ? '${(distance * 1000).toStringAsFixed(0)}m'
                                          : '${distance.toStringAsFixed(1)}km',
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            hospital.name,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, height: 1.3),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hospital.address,
                            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _openUrl('tel:${hospital.phone}'),
                                      borderRadius: BorderRadius.circular(12),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 10),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.phone_rounded, color: Color(0xFF10B981), size: 16),
                                            SizedBox(width: 6),
                                            Text('Dial Now', style: TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.w700)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildSocialIcon(Icons.map_rounded, () => _openUrl('https://www.google.com/maps/search/?api=1&query=${hospital.coordinates['lat']},${hospital.coordinates['lng']}')),
                              if (hospital.facebookURI != null)
                                const SizedBox(width: 4),
                              if (hospital.facebookURI != null)
                                _buildSocialIcon(Icons.facebook, () => _openUrl(hospital.facebookURI!)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSocialIcon(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(padding: const EdgeInsets.all(10), child: Icon(icon, color: Colors.white, size: 18)),
        ),
      ),
    );
  }
}