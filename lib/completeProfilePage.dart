import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:joma/mainScreen.dart';
import 'package:joma/services/analytics.dart';
import 'package:joma/services/fcm_backend.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:location/location.dart' as loc; // Updated for location package

class CompleteProfilePage extends StatefulWidget {
  final String userId;
  const CompleteProfilePage({super.key, required this.userId});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  static const Color mintGreen = Color(0xFF00BFA5);
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  // API Data Lists
  List<dynamic> _provinces = [];
  List<dynamic> _cities = [];
  List<dynamic> _barangays = [];

  // Selected Values
  String? _selectedSex;
  String? _selectedProvinceName;
  String? _selectedCityName;
  String? _selectedCityCode;
  String? _selectedBarangay;

  bool _isSubmitting = false;
  bool _isLoadingLocations = true;

  @override
  void initState() {
    super.initState();
    _fetchProvinces();
  }

  // --- LOCATION PACKAGE LOGIC ---

  Future<loc.LocationData?> _getUserLocation() async {
    loc.Location location = loc.Location();

    bool serviceEnabled;
    loc.PermissionStatus permissionGranted;

    // Check if service is enabled
    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return null;
    }

    // Check for permissions
    permissionGranted = await location.hasPermission();
    if (permissionGranted == loc.PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != loc.PermissionStatus.granted) return null;
    }

    try {
      // Get current location with timeout to prevent hanging
      return await location.getLocation().timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint("Error getting location: $e");
      return null;
    }
  }

  // --- API FETCHING LOGIC ---

  Future<void> _fetchProvinces() async {
    try {
      final response =
          await http.get(Uri.parse('https://psgc.gitlab.io/api/provinces/'));
      if (response.statusCode == 200) {
        setState(() {
          _provinces = json.decode(response.body);
          _provinces.sort((a, b) => a['name'].compareTo(b['name']));
          _isLoadingLocations = false;
        });
      }
    } catch (e) {
      debugPrint("Error");
    }
  }

  Future<void> _fetchCities(String provinceCode) async {
    setState(() {
      _cities = [];
      _barangays = [];
      _selectedCityName = null;
      _selectedBarangay = null;
    });
    try {
      final response = await http.get(Uri.parse(
          'https://psgc.gitlab.io/api/provinces/$provinceCode/cities-municipalities/'));
      if (response.statusCode == 200) {
        setState(() {
          _cities = json.decode(response.body);
          _cities.sort((a, b) => a['name'].compareTo(b['name']));
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> _fetchBarangays(String cityCode) async {
    setState(() {
      _barangays = [];
      _selectedBarangay = null;
    });
    try {
      final response = await http.get(Uri.parse(
          'https://psgc.gitlab.io/api/cities-municipalities/$cityCode/barangays/'));
      if (response.statusCode == 200) {
        setState(() {
          _barangays = json.decode(response.body);
          _barangays.sort((a, b) => a['name'].compareTo(b['name']));
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  // --- SUBMISSION ---

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() ||
        _selectedBarangay == null ||
        _selectedProvinceName == null ||
        _selectedCityName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please complete the form")));
      return;
    }

    setState(() => _isSubmitting = true);

    // Fetch coordinates via location package
    loc.LocationData? locationData = await _getUserLocation();

    try {
      final Map<String, dynamic> body = {
        'phone': _phoneController.text,
        'sex': _selectedSex,
        'age': int.tryParse(_ageController.text) ?? 0,
        'province': _selectedProvinceName,
        'municipality': _selectedCityName,
        'lguCode': _selectedCityName,
        // 'lguCode': _selectedCityName?.toLowerCase().replaceAll(' ', ''),
        'barangay': _selectedBarangay,
      };

      // Map to GeoJSON format for your MongoDB model
      if (locationData != null &&
          locationData.longitude != null &&
          locationData.latitude != null) {
        body['location'] = {
          'type': 'Point',
          'coordinates': [
            locationData.longitude!,
            locationData.latitude!
          ], // [lng, lat]
        };
      }
      debugPrint("userId: ${widget.userId}");
      final response = await http.put(
        Uri.parse('https://ems.qalertapp.com/api/users/${widget.userId}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final updatedUser = responseData['data'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('phone', updatedUser['phone'] ?? '');
        await prefs.setString('lguCode', updatedUser['lguCode'] ?? '');
        await prefs.setString(
            'municipality', updatedUser['municipality'] ?? '');
        await prefs.setString('barangay', updatedUser['barangay'] ?? '');

        await registerFcmTokenWithBackend();

        AnalyticsService.trackEvent(
          eventName: 'Complete Profile',
          lguCode: 'Not Set',
          screen: 'Complete Profile Screen',
        );

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainScreen()),
          );
        }
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Duplicate data!")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Submission failed")));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text("Complete Your Profile",
              style: TextStyle(color: Colors.black))),
      body: _isLoadingLocations
          ? const Center(child: CircularProgressIndicator(color: mintGreen))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel("Phone Number"),
                    TextFormField(
                        controller: _phoneController,
                        validator: (v) => (v == null || v.isEmpty)
                            ? "Phone is required"
                            : null,
                        keyboardType: TextInputType.phone,
                        decoration: _inputDecoration("09xxxxxxxxx")),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              _buildLabel("Sex"),
                              DropdownButtonFormField<String>(
                                validator: (v) =>
                                    (v == null) ? "Required" : null,
                                decoration: _inputDecoration("Select"),
                                items: ["Male", "Female"]
                                    .map((s) => DropdownMenuItem(
                                        value: s, child: Text(s)))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _selectedSex = v),
                              ),
                            ])),
                        const SizedBox(width: 15),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              _buildLabel("Age"),
                              TextFormField(
                                  controller: _ageController,
                                  validator: (v) => (v == null || v.isEmpty)
                                      ? "Required"
                                      : null,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDecoration("Years")),
                            ])),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildLabel("Province"),
                    DropdownButtonFormField<dynamic>(
                      validator: (v) => (v == null) ? "Required" : null,
                      decoration: _inputDecoration("Select Province"),
                      items: _provinces
                          .map((p) => DropdownMenuItem(
                              value: p, child: Text(p['name'])))
                          .toList(),
                      onChanged: (v) {
                        setState(() => _selectedProvinceName = v['name']);
                        _fetchCities(v['code']);
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildLabel("City / Municipality"),
                    DropdownButtonFormField<dynamic>(
                      validator: (v) => (v == null) ? "Required" : null,
                      initialValue: _selectedCityCode,
                      decoration: _inputDecoration("Select City"),
                      items: _cities
                          .map((c) => DropdownMenuItem(
                              value: c['code'], child: Text(c['name'])))
                          .toList(),
                      onChanged: (v) {
                        final city = _cities
                            .firstWhere((element) => element['code'] == v);
                        setState(() {
                          _selectedCityCode = v;
                          _selectedCityName = city['name'];
                        });
                        _fetchBarangays(v);
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildLabel("Barangay"),
                    DropdownButtonFormField<String>(
                      validator: (v) => (v == null) ? "Required" : null,
                      initialValue: _selectedBarangay,
                      decoration: _inputDecoration("Select Barangay"),
                      items: _barangays
                          .map((b) => DropdownMenuItem(
                              value: b['name'] as String,
                              child: Text(b['name'])))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedBarangay = v),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: mintGreen,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        child: _isSubmitting
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text("COMPLETE REGISTRATION",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // --- REUSABLE UI ---
  Widget _buildLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.black54)));
  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[200]!)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: mintGreen, width: 2)),
      );
}
