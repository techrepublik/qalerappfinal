import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:h3_flutter/h3_flutter.dart';
import 'package:joma/alertsScreen.dart';
import 'package:joma/newsScreen.dart';
import 'package:joma/route.dart';
import 'package:joma/takephotoOrig.dart';
import 'package:joma/weather.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'fallback_lgu_hotline.dart';
import 'models/facility.dart';
import 'models/lgucontact.dart';
import 'family_contacts.dart';
import 'services/analytics.dart';
import 'newHospital.dart'; // Make sure the file name matches


/// Q-ALERT with Professional UI/UX Design
class QAlertWithUpdates extends StatefulWidget {
  // final Function(String) onLguChanged; // Add this line

  const QAlertWithUpdates({super.key});
  @override
  State<QAlertWithUpdates> createState() => _QAlertWithUpdatesState();
}

class _QAlertWithUpdatesState extends State<QAlertWithUpdates> with SingleTickerProviderStateMixin,
    WidgetsBindingObserver {
  final H3 h3 = const H3Factory().load();
  final Location location = Location();

  // static const String SERVER_URL = 'http://10.169.208.5:3000/api/h3/manifest';

  // User location
  double? currentLat;
  double? currentLon;
  String h8Hex = '';
  String h4Hex = '';
  String lguCode = '';
  String barName = '';
  String userId = '';
  String userName = '';
  String userPhone = '';


  // Found LGU data
  List<LGUContact> foundLGUs = [];
  LGUContact? selectedLGU;

  bool isLoading = false;
  String statusMessage = '';

  // Update tracking
  bool updateAvailable = false;
  int pendingUpdates = 0;



  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // ADD THIS

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();

    _checkForUpdates();
    _getUserLocation();
    _loadUserData();

    AnalyticsService.trackEvent(
      eventName: 'Dashboard',
      lguCode: lguCode ?? 'NOT_SET',
      screen: 'Home Screen',
    );

  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _getUserLocation();
      _checkForUpdates();
    }
  }



  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // ADD THIS
    _animationController.dispose();
    super.dispose();
  }

  final String apiBaseUrl = "https://ems.qalertapp.com";

  // final String apiBaseUrl = "http://192.168.1.11:3000";


  Future<void> _loadUserData() async {

    final prefs = await SharedPreferences.getInstance();

    // Use the null-coalescing operator (??) to provide fallbacks
    final String user_id = prefs.getString('user_id') ?? '';
    final String name = prefs.getString('name') ?? '';
    final String phone = prefs.getString('phone') ?? '';

    if (mounted) {
      setState(() {
        userId = user_id;
        userName = name;
        userPhone = phone;
      });
    }
  }


  Future<void> _submitToNextCalling() async {

    try {
      final Map<String, dynamic> emergencyData = {
        "userId": userId,
        "lguCode": lguCode,
        "userName": userName,
        "userPhone": userPhone,
        "emergencyType": "calls",
        "severity": "low",
        "description": "calling!",
        "photoUrl": "", // Added photoUrl field
        "location": {
          "longitude": double.tryParse(currentLon?.toString() ?? "0.0"),
          "latitude": double.tryParse(currentLat?.toString() ?? "0.0"),
          "accuracy": int.tryParse('10') ?? 0,
        },
      };

      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/emergencies'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(emergencyData),
      );
      final responseData = jsonDecode(response.body);
    } catch (e) {
          debugPrint('error in sending dial button $e');
    } finally {

    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        // appBar: _buildAppBar(),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              await _getUserLocation();
              await _checkForUpdates();
            },
            color: const Color(0xFFDC143C),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    if (updateAvailable) _buildUpdateBanner(),
                    // _buildSearchBox(),
                    GreetingBanner(
                        userName: userName,
                        lat: currentLat,
                        lon: currentLon),
                    // HANDLE LOADING STATE
                    if (lguCode.isNotEmpty &&
                        foundLGUs.isNotEmpty &&
                        currentLat != null &&
                        currentLon != null) ...[
                      AlertScreen(
                        lguCode: lguCode,
                        userLat: currentLat!,
                        userLng: currentLon!,
                      ),
                      HospitalListView(
                        userLat: currentLat!,
                        userLng: currentLon!,
                        lguCode: lguCode,
                      ),
                    ],


                    _buildFamilyContact(),
                    if (foundLGUs.isNotEmpty)
                      _buildEmergencySection(),
                    if (isLoading) const LGUCardSkeleton(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        ),
        // floatingActionButton: _buildFloatingActionButton(),
      );

  }


  Widget _buildUpdateBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFFF6B35),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _downloadUpdates,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.cloud_download_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tap to Download Local Hotlines',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$pendingUpdates region${pendingUpdates > 1 ? 's' : ''} ready to download',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildFamilyContact() {
    return // Add this inside the Column in your main build method
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FamilyContactsPage()),
              );
              AnalyticsService.trackEvent(
                eventName: 'FamilyContact',
                lguCode: lguCode,
                screen: 'FamilyScreen',
              );

            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC143C).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.family_restroom, color: Color(0xFFDC143C)),
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Family Emergency Contacts",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A)
                        ),
                      ),
                      Text(
                        "Manage your personal safety circle",
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
      );
  }


 Widget _buildEmergencySection() {

   final hasConflict = !isFallback && foundLGUs.length > 1;

   // ✅ Completely separate widget — easy to debug independently
   if (isFallback) {
     return FallbackLGUSection(
       lguList: foundLGUs,
       lguCode: lguCode,
       currentLat: currentLat,
       currentLon: currentLon,
     );
   }

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasConflict) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFF59E0B).withOpacity(0.1),
                    const Color(0xFFF59E0B).withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_rounded, color: Color(0xFFF59E0B), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Multiple LGUs Detected',
                          style: TextStyle(
                            color: Color(0xFFF59E0B),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Please select your jurisdiction',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          ...foundLGUs.map((lgu) => _buildLGUCard(lgu, hasConflict)),
        ],
      ),
    );
  }

  // REPLACE YOUR _buildLGUCard METHOD WITH THIS FIXED VERSION

  Widget _buildLGUCard(LGUContact lgu, bool hasConflict) {
    final isSelected = selectedLGU?.lgu == lgu.lgu;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF10B981)
              : Colors.grey.withOpacity(0.1),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? const Color(0xFFDC143C).withOpacity(0.15)
                : Colors.black.withOpacity(0.04),
            blurRadius: isSelected ? 16 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: hasConflict ? () => _selectLGU(lgu) : null,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [

              if (hasConflict)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFDC143C)
                              : Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSelected ? Icons.check : Icons.radio_button_unchecked,
                          color: isSelected ? Colors.white : Colors.grey[400],
                          size: 16,
                        ),
                      ),
                    if (hasConflict) const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        lgu.barName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    if (!hasConflict)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.verified, color: Color(0xFF10B981), size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Location',
                              style: TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),


    ],
                ),

                const SizedBox(height: 20),

                // Quick Dial CDRRMO (from localhotlines)
                if (lgu.bdrrmo.isNotEmpty) ...[
                  _buildSectionHeader('Quick Dial', Icons.speed_rounded),
                  const SizedBox(height: 12),
                  _buildQuickDialButton(
                    icon: Icons.shield_rounded,
                    label: 'DRRMO Hotlines #',
                    number: lgu.bdrrmo,
                    color: const Color(0xFF3B82F6),
                    enabled: !hasConflict || isSelected,
                    isPrimary: true,
                  ),
                  const SizedBox(height: 12),
                ],

                // Online Report Button (if paid)
                // if (lgu.paid) ...[
                  _buildOnlineReportButton(
                    lgu: lgu,
                    enabled: !hasConflict || isSelected,
                  ),

                  const SizedBox(height: 12),
                //],

                _buildNewsPageButton(lgu: lgu, enabled: !hasConflict || isSelected),

                const SizedBox(height: 20),


                // Emergency Hotlines Section
                if (lgu.hotlines.isNotEmpty) ...[
                  _buildSectionHeader('Emergency Hotlines', Icons.phone_in_talk_rounded),
                  const SizedBox(height: 12),
                  ...lgu.hotlines.map((hotline) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildFacilityCard(
                      icon: _getHotlineIcon(hotline.name),
                      name: hotline.name,
                      address: hotline.address,
                      contact: hotline.contact,
                      contact2: hotline.contact2,
                      color: _getHotlineColor(hotline.name),
                      enabled: !hasConflict || isSelected,
                      facility: hotline,
                    ),
                  )),
                ],

                // Hospitals Section
                if (lgu.hospitals.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildSectionHeader('Public Hospitals & Safe Zone', Icons.local_hospital_rounded),
                  const SizedBox(height: 12),
                  ...lgu.hospitals.map((hospital) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildFacilityCard(
                      icon: Icons.local_hospital,
                      name: hospital.name,
                      address: hospital.address,
                      contact: hospital.contact,
                      contact2: hospital.contact2 ?? '',
                      color: const Color(0xFF10B981),
                      enabled: !hasConflict || isSelected,
                      facility: hospital,
                    ),
                  )),
                ],



              ],
            ),
          ),
        ),
      ),
    );
  }

// ADD THESE HELPER METHODS TO YOUR CLASS

  IconData _getHotlineIcon(String name) {
    final serviceName = name.toUpperCase();
    if (serviceName.contains('POLICE')) {
      return Icons.local_police;
    } else if (serviceName.contains('FIRE')) {
      return Icons.local_fire_department;
    } else if (serviceName.contains('DRRMO') || serviceName.contains('CDRRMO') || serviceName.contains('MDRRMO') || serviceName.contains('BDRRMO')) {
      return Icons.emergency;
    }
    return Icons.phone_in_talk;
  }

  Color _getHotlineColor(String name) {
    final serviceName = name.toUpperCase();
    if (serviceName.contains('POLICE')) {
      return const Color(0xFF3B82F6); // Blue
    } else if (serviceName.contains('FIRE')) {
      return const Color(0xFFDC143C); // Red
    } else if (serviceName.contains('DRRMO')) {
      return const Color(0xFFF59E0B); // Orange
    }
    return const Color(0xFF8B5CF6); // Purple
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A).withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF1A1A1A)),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }


  Widget _buildQuickDialButton({
    required IconData icon,
    required String label,
    required String number,
    required Color color,
    required bool enabled,
    bool isPrimary = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: enabled
            ? LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : null,
        color: enabled ? null : Colors.grey[300],
        borderRadius: BorderRadius.circular(16),
        boxShadow: enabled
            ? [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? () => _openUrlQD('tel:$number') : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        number,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.phone_rounded, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }


Widget _buildOnlineReportButton({
    required LGUContact lgu,
    required bool enabled,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: enabled
            ? const LinearGradient(
          colors: [Color(0xFFDC143C), Color(0xFFC41230)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : null,
        color: enabled ? null : Colors.grey[300],
        borderRadius: BorderRadius.circular(16),
        boxShadow: enabled
            ? [
          BoxShadow(
            color: const Color(0xFFDC143C).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? () => _navigateToReport(lgu) : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Row(
              children: [

              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.report_problem_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Report Incident',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Submit with GPS & Photo',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildNewsPageButton({
    required LGUContact lgu,
    required bool enabled,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: enabled
            ? const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF059659)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : null,
        color: enabled ? null : Colors.grey[300],
        borderRadius: BorderRadius.circular(16),
        boxShadow: enabled
            ? [
          BoxShadow(
            color: const Color(0xFFDC143C).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? () => _navigateToNewsPage(lgu) : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Row(
              children: [

                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.newspaper, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Advisories & Updates',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'News Updates',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildFacilityCard({
    required IconData icon,
    required String name,
    required String address,
    required String contact,
    required String contact2,
    required Color color,
    required bool enabled,
    Facility? facility, // Add facility object to access coordinates
  }) {
    final distance = facility?.getDistanceFrom(currentLat, currentLon);

    return Container(
      decoration: BoxDecoration(
        color: enabled ? color.withOpacity(0.05) : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enabled ? color.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled && facility != null
              ? () => _openMapForFacility(facility, name)
              : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: enabled ? color.withOpacity(0.1) : Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: enabled ? color : Colors.grey, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: enabled ? const Color(0xFF1A1A1A) : Colors.grey,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (address.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              address,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (distance != null && enabled) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: color.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.near_me_rounded, color: color, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              distance < 1
                                  ? '${(distance * 1000).toStringAsFixed(0)}m'
                                  : '${distance.toStringAsFixed(1)}km',
                              style: TextStyle(
                                color: color,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        label: 'Dial Now',
                        icon: Icons.phone_rounded,
                        color: color,
                        enabled: enabled,
                        onTap: () => _openUrl('Dial Now', 'tel:$contact'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (contact2.isNotEmpty)
                      Expanded(
                        child: _buildActionButton(
                          label: 'SMS',
                          icon: Icons.sms_rounded,
                          color: color,
                          enabled: enabled,
                          isOutlined: true,
                          onTap: () => _sendSms(name, contact2),
                        ),
                      ),
                    if (facility != null && enabled) ...[
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: color, width: 1.5),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _openMapForFacility(facility, name),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              child: Icon(Icons.map_rounded, color: color, size: 18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
    bool isOutlined = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: enabled && !isOutlined
            ? LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : null,
        color: enabled && isOutlined ? Colors.transparent : (enabled ? null : Colors.grey[300]),
        borderRadius: BorderRadius.circular(10),
        border: isOutlined && enabled ? Border.all(color: color, width: 1.5) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: enabled
                      ? (isOutlined ? color : Colors.white)
                      : Colors.grey,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: enabled
                        ? (isOutlined ? color : Colors.white)
                        : Colors.grey,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  // NAVIGATION & ACTIONS
  Future<void> _navigateToReport(LGUContact lgu) async {

    Navigator.push(
      context,
      SlideRightToLeftRoute(
        page: ImageCaptureApp2(
          lguCode: lguCode,
          userId: userId,
          userName: userName,
          userPhone: userPhone,
          latitude: currentLat.toString(),
          longitude: currentLon.toString(),
          accuracy: "10",
          paid: lgu.paid,

        ),
      ),
    );
  }

  // NAVIGATION & ACTIONS
  Future<void> _navigateToNewsPage(LGUContact lgu) async {

    AnalyticsService.trackEvent(
      eventName: "Newspages",
      lguCode: lguCode,
      screen: 'NewsPage',
    );

    Navigator.push(
      context,
      SlideRightToLeftRoute(
        page: NewsFeedPage(lguCode: lguCode)
      ),
    );



  }

  // UPDATE SYSTEM
  Future<void> _checkForUpdates() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/h3/manifest'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final Map<String, dynamic> manifest = jsonDecode(response.body);
      final Map<String, dynamic> serverFiles = manifest['files'] as Map<String, dynamic>;

      final prefs = await SharedPreferences.getInstance();
      final localVersions = prefs.getString('file_versions') ?? '{}';
      final Map<String, dynamic> localFiles = jsonDecode(localVersions);

      final List<String> filesToUpdate = [];

      serverFiles.forEach((filename, serverVersion) {
        final localVersion = localFiles[filename];
        if (localVersion == null || localVersion != serverVersion) {
          filesToUpdate.add(filename);
        }
      });

      setState(() {
        updateAvailable = filesToUpdate.isNotEmpty;
        pendingUpdates = filesToUpdate.length;
      });
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
  }

  void _showUpdateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.system_update_rounded, color: Color(0xFFFF6B35)),
            SizedBox(width: 12),
            Text(
              'Updates Available',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Text(
          '$pendingUpdates region file${pendingUpdates > 1 ? 's' : ''} ${pendingUpdates > 1 ? 'have' : 'has'} been updated.\n\n'
              'Download updates to get the latest emergency contact information.',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Later',
              style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _downloadUpdates();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Download Now', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadUpdates() async {
    setState(() {
      isLoading = true;
      statusMessage = 'Downloading updates...';
    });

    try {
      final manifestResponse = await http.get(
        Uri.parse('$apiBaseUrl/api/h3/manifest'),
      );
      final Map<String, dynamic> manifest = jsonDecode(manifestResponse.body);
      final Map<String, dynamic> serverFiles = manifest['files'];

      final prefs = await SharedPreferences.getInstance();
      final localVersions = prefs.getString('file_versions') ?? '{}';
      final Map<String, dynamic> localFiles = jsonDecode(localVersions);

      final List<String> filesToUpdate = [];
      serverFiles.forEach((filename, serverVersion) {
        if (localFiles[filename] != serverVersion) {
          filesToUpdate.add(filename);
        }
      });

      int downloaded = 0;

      for (final filename in filesToUpdate) {
        await _downloadFile(filename);
        downloaded++;

        setState(() {
          statusMessage = 'Downloaded $downloaded/${filesToUpdate.length} files...';
        });
      }

      await prefs.setString('file_versions', jsonEncode(serverFiles));
      await prefs.setString('last_update', DateTime.now().toIso8601String());

      setState(() {
        isLoading = false;
        updateAvailable = false;
        pendingUpdates = 0;
        statusMessage = '';

      });

      await _getUserLocation();

      _showSuccess('Successfully downloaded ${filesToUpdate.length} file${filesToUpdate.length > 1 ? 's' : ''}');
    } catch (e) {
      setState(() {
        isLoading = false;
        statusMessage = '';
      });
      _showError('Update failed: $e');
    }
  }

  Future<void> _downloadFile(String filename) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/h3/data/$filename'),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to download $filename');
      }

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$filename');
      await file.writeAsString(response.body);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _getUserLocation() async {
    setState(() {
      isLoading = true;
      statusMessage = 'Acquiring GPS location...';

    });

    try {
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) throw Exception('Location service disabled');
      }

      PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          throw Exception('Location permission denied');
        }
      }

      LocationData locationData = await location.getLocation();

      // Check if widget is still visible after the long 'await' above
      if (!mounted) return;

      if (locationData.latitude == null || locationData.longitude == null) {
        throw Exception('Could not get GPS coordinates');
      }

      // Using real data from locationData instead of hardcoded values
      double lat = locationData.latitude!;
      double lon = locationData.longitude!;

      //matalam
      // double lat = 7.087424087742862;
      // double lon = 124.90076240489252;

      GeoCoord coord = GeoCoord(lon: lon, lat: lat);
      BigInt h8 = h3.geoToCell(coord, 8);
      BigInt h4 = h3.cellToParent(h8, 4);

      setState(() {
        currentLat = lat;
        currentLon = lon;
        h8Hex = h8.toRadixString(16);
        h4Hex = h4.toRadixString(16);
        isLoading = false;
        statusMessage = '';
        foundLGUs = [];
        selectedLGU = null;
      });


      print("this hex8 ${h8Hex}");

      await _lookupLGU();


      AnalyticsService.trackEvent(
        eventName: 'getGPS',
        lguCode: lguCode,
        screen: 'HomeScreen',
      );


    } catch (e) {
      // Crucial check: don't update state or show UI if user closed the screen
      if (!mounted) return;

      setState(() {
        isLoading = false;
        statusMessage = '';
      });
      _showError('GPS Error: ${e.toString()}');
    }
  }

  // Load LGU data from h3.json file
  Future<Map<String, dynamic>> _loadLGUDataFromJSON() async {
    try {
      String jsonString;

      try {
        // Try to load from local storage first (for updates)
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/h4_$h4Hex.json');

        print(file);

        if (await file.exists()) {
          jsonString = await file.readAsString();
          print('✅ Loaded h3.json from local storage');
        } else {
          // Load from assets
          jsonString = await rootBundle.loadString('assets/data/h3.json');
          print('✅ Loaded h3.json from assets');
        }
      } catch (e) {
        // Fallback to assets if local storage fails
        jsonString = await rootBundle.loadString('assets/data/h3.json');
        print('✅ Loaded h3.json from catch error  (fallback)');
      }

      final Map<String, dynamic> jsonData = jsonDecode(jsonString);
      return jsonData;

    } catch (e) {
      print('❌ Error loading h3.json: $e');
      rethrow;
    }
  }

// Find LGUs by searching hex_list
  List<LGUContact> _findLGUsByHex(Map<String, dynamic> data, String hexToFind) {

    List<LGUContact> matchedLGUs = [];

    if (!data.containsKey('lgu')) {
      print('❌ No "lgu" key found in JSON data');
      return matchedLGUs;
    }

    List<dynamic> lguList = data['lgu'];
    print('🔍 Searching through ${lguList.length} LGUs for hex: $hexToFind');

    for (var lguJson in lguList) {
      if (lguJson['hex_list'] != null) {
        List<dynamic> hexList = lguJson['hex_list'];

        // Check if the hex is in this LGU's hex_list
        if (hexList.contains(hexToFind)) {
          try {
            LGUContact lguContact = LGUContact.fromJson(lguJson);

            matchedLGUs.add(lguContact);

            print('✅ Found match: ${lguJson['lguName']}');

          } catch (e) {
            print('❌ Error parsing LGU ${lguJson['lguName']}: $e');
          }
        }
      }
    }

    print('📊 Total matches found: ${matchedLGUs.length}');


    return matchedLGUs;
  }

  bool isFallback = false; // add this with your other state variables


  Future<void> _lookupLGU() async {
    setState(() {
      isLoading = true;
      statusMessage = 'Loading emergency contacts...';
    });

    try {
      // Load the LGU data from h3.json
      final lguData = await _loadLGUDataFromJSON();

      // Search for LGU by hex_list
      final matchedLGUs = _findLGUsByHex(lguData, h8Hex);

      // ✅ FALLBACK: No hex match — show all LGUs with localhotlines
      if (matchedLGUs.isEmpty) {
        print('⚠️ No hex match. Loading all localhotlines as fallback...');

        final allLGUs = (lguData['lgu'] as List<dynamic>)
            .where((lgu) => lgu['localhotlines'] != null)
            .map((lgu) => LGUContact.fromJson(lgu))
            .toList();

        setState(() {
          foundLGUs = allLGUs;
          isFallback = true;        // ✅ mark as fallback
          selectedLGU = null;
          lguCode = '';
          isLoading = false;
          statusMessage = '';
        });

        return; // ✅ stop here
      }




      setState(()  {
        foundLGUs = matchedLGUs;
        isLoading = false;
        isFallback = false;

        if (matchedLGUs.length == 1) {
          final autoSelectedLgu = matchedLGUs.first;
          setState(() {
            selectedLGU = autoSelectedLgu;
            lguCode = autoSelectedLgu.lgu;
            statusMessage = '';
          });


        } else {
          statusMessage = '';
        }

      });

      // _showSuccess('Emergency contacts loaded');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lguCode', matchedLGUs.first.lgu);


    } catch (e) {
      setState(() {
        isLoading = false;
        statusMessage = '';
        foundLGUs = [];
      });
      _showError('No LGU data available for this location: ${e.toString()}');
    }

    debugPrint(
      'Found LGUs (${foundLGUs.length}): ${foundLGUs.map((e) => e.lgu).join(", ")}',
    );

  }


  void _selectLGU(LGUContact lgu) {
    // // Pass the actual LGU string/code up to the MainScreen wrapper
    // widget.onLguChanged(lgu.lgu);

    setState(() {
      selectedLGU = lgu;
      lguCode = lgu.lgu;
    });

    _showSuccess('Selected: ${lgu.lgu}');
  }


  void _openUrl(String label, String url) async {
    final Uri uri = Uri.parse(url);

    // 1. Launch the URL immediately
    final bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (launched) {
      // 2. Trigger the submission in the background without awaiting it.
      // By not using 'await', the code continues immediately.
      AnalyticsService.trackEvent(
        eventName: "Call-$label",
        lguCode: lguCode,
        screen: 'HomeScreen',
      );


    } else {
      debugPrint("Could not launch $url");
    }
  }



  void _openUrlQD(String url) async {
    final Uri uri = Uri.parse(url);

    // 1. Launch the URL immediately
    final bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (launched) {
      _submitToNextCalling();
      print('nae press and call');

    } else {
      debugPrint("Could not launch $url");
    }
  }


  Future<void> _sendSms(String name, String number) async {


  String message = currentLat != null
  ? "SOS! I Need Help GPS: ${currentLat?.toStringAsFixed(6)}, ${currentLon?.toStringAsFixed(6)}"
      : "EMERGENCY SOS! I need help. Location unavailable";

  final String url = "sms:$number?body=${Uri.encodeComponent(message).replaceAll('+', '%20')}";
  if (await canLaunchUrl(Uri.parse(url))) {
    await launchUrl(Uri.parse(url));

      AnalyticsService.trackEvent(
        eventName: "SMS_$name",
        lguCode: lguCode,
        screen: 'HomeScreen',
      );

    } else {
      _showError('Could not send SMS');
    }
  }

  Future<void> _openMapForFacility(Facility facility, String facilityType) async {
    if (facility.coordinates == null || facility.coordinates!.length < 2) {
      _showError('Location coordinates not available');
      return;
    }

    final lat = facility.coordinates![0];
    final lon = facility.coordinates![1];
    final label = Uri.encodeComponent(facility.name);

    // Try Google Maps first (works on both Android and iOS)
    final googleMapsUrl = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lon&query_place_id=$label'
    );

    // iOS Apple Maps fallback
    final appleMapsUrl = Uri.parse('https://maps.apple.com/?q=$label&ll=$lat,$lon');

    // Generic geo URI for other apps
    final geoUri = Uri.parse('geo:$lat,$lon?q=$lat,$lon($label)');

    try {
      // Try Google Maps URL first
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(appleMapsUrl)) {
        await launchUrl(appleMapsUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      } else {
        _showError('No map application available');
      }
    } catch (e) {
      _showError('Could not open map: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: const Color(0xFFDC143C),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            // Key changes below:
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height - 180, // Forces it to the top
              left: 10,
              right: 10,
            ),
          ),

        );
      } catch (e) {
        print('⚠️ Snackbar error (ignored): $e');
      }
    });
  }

  void _showSuccess(String message) {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            // Key changes below:
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height - 180, // Forces it to the top
              left: 10,
              right: 10,
            ),
          ),
        );
      } catch (e) {
        print('⚠️ Snackbar error (ignored): $e');
      }
    });
  }


}




class LGUCardSkeleton extends StatelessWidget {
  const LGUCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Skeleton (Radio/Check + Title)
          const Row(
            children: [
              SkeletonItem(width: 24, height: 24, borderRadius: 12), // Radio icon
              SizedBox(width: 12),
              SkeletonItem(width: 180, height: 20), // LGU Name
            ],
          ),

          const SizedBox(height: 20),

          // 2. Section Header Skeleton (Quick Dial)
          const SkeletonItem(width: 100, height: 14),
          const SizedBox(height: 12),

          // 3. Emergency Button Skeleton (DRRMO Hotlines)
          const SkeletonItem(
            width: double.infinity,
            height: 56, // Height of your _buildEmergencyButton
            borderRadius: 12,
          ),

          const SizedBox(height: 12),

          // 4. Online Report Button Skeleton
          const SkeletonItem(
            width: double.infinity,
            height: 56,
            borderRadius: 12,
          ),

          const SizedBox(height: 12),

          // 5. News Page Button Skeleton
          const SkeletonItem(
            width: double.infinity,
            height: 50,
            borderRadius: 12,
          ),

          const SizedBox(height: 20),

          // 6. Facility Card Skeleton (e.g., Police or Hospital)
          const SkeletonItem(width: 140, height: 14), // Section Header
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[200]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                SkeletonItem(width: 40, height: 40, borderRadius: 8), // Icon
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonItem(width: 150, height: 12),
                    SizedBox(height: 6),
                    SkeletonItem(width: 100, height: 10),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}