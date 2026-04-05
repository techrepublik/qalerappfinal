import 'dart:convert';
import 'dart:io';
import 'package:cloudinary/cloudinary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:joma/services/analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:joma/chatPage.dart';

class ImageCaptureApp2 extends StatefulWidget {
  // Fallback data passed from constructor
  final String lguCode;
  final String userId;
  final String userName;
  final String userPhone;
  final String latitude;
  final String longitude;
  final String accuracy;
  final bool paid;

  const ImageCaptureApp2({
    super.key,
    required this.lguCode,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.paid,
  });

  @override
  State<ImageCaptureApp2> createState() => _ImageCaptureAppState();
}

class _ImageCaptureAppState extends State<ImageCaptureApp2> {
  File? _image;
  final picker = ImagePicker();
  String selectedEmergency = "";
  bool isLoading = false;

  // Refreshed User Profile State
  late String _currentUserId;
  late String _currentUserName;
  late String _currentUserPhone;
  late String _currentLguCode;

  late GoogleMapController mapController;
  late LatLng _initialPosition;
  final Set<Marker> _markers = {};

  final String _apiKey = dotenv.env['MOBILE_API_KEY'] ?? '';

  final cloudinary = Cloudinary.signedConfig(
    cloudName: dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '',
    apiKey: dotenv.env['CLOUDINARY_API_KEY'] ?? '',
    apiSecret: dotenv.env['CLOUDINARY_API_SECRET'] ?? '',
  );

  // Update this to your production or local network IP
  final String apiBaseUrl = "https://ems.qalertapp.com";

  // final String apiBaseUrl = "http://192.168.1.11:3000";

  @override
  void initState() {
    super.initState();
    // 1. Set initial values from widget parameters
    _currentUserId = widget.userId;
    _currentUserName = widget.userName;
    _currentUserPhone = widget.userPhone;
    _currentLguCode = widget.lguCode;

    print('mao nih LGUCode: $_currentLguCode');

    _initialPosition =
        LatLng(double.parse(widget.latitude), double.parse(widget.longitude));
    _markers.add(
      Marker(
        markerId: const MarkerId('incident_location'),
        position: _initialPosition,
      ),
    );

    // 2. Immediately try to refresh from local storage
    _loadUserProfile();
  }

  /// Fetches the latest user profile from SharedPreferences
  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getString('user_id') ?? widget.userId;
      _currentUserName = prefs.getString('name') ?? widget.userName;
      _currentUserPhone = prefs.getString('phone') ?? widget.userPhone;
      _currentLguCode = widget.lguCode ?? 'qalert';
    });
    debugPrint("✅ Profile Synced: $_currentUserName ($_currentLguCode)");
  }

  // --- LOGIC ---

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
    }
  }

  Future<void> _uploadAndSubmit() async {
    setState(() => isLoading = true);
    String photoUrl = "";
    try {
      if (_image != null) {
        final File? compressed = await _compressImage(_image!);
        if (compressed != null) {
          final resp = await cloudinary.upload(
              file: compressed.path,
              resourceType: CloudinaryResourceType.image);
          if (resp.isSuccessful) photoUrl = resp.secureUrl ?? "";
        }
      }
      await _submitToNextJs(photoUrl);
    } catch (e) {
      setState(() => isLoading = false);
      Fluttertoast.showToast(msg: "Error");
    }
  }

  Future<String> getEmergencyStatus(String incidentId) async {
    final uri = Uri.parse('$apiBaseUrl/api/v2/emergencies/$incidentId');
    final response = await http.get(
      uri,
      headers: {
        'x-api-key': _apiKey,
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      // Extract status safely
      final status = body['data']?['status'];
      if (status == null) {
        throw Exception('Status not found');
      }

      print('this is $status');

      return status;
    } else {
      print('getEmergencyStatus Error: ${response.statusCode}');
      throw Exception('Failed: ${response.reasonPhrase}');
    }
  }

  Future<String?> getValidIncidentId() async {
    final prefs = await SharedPreferences.getInstance();

    final incidentId = prefs.getString("active_incident_id");
    final incidentTime = prefs.getInt("incident_time");

    if (incidentId == null || incidentTime == null) return null;

    final now = DateTime.now().millisecondsSinceEpoch;

    const thirtyMinutes = 7 * 60 * 1000;

    try {
      // 🔥 Get latest status from API
      final status = await getEmergencyStatus(incidentId);

      print('mao nih $status');
      // ❌ If not pending → invalidate
      if (status != 'pending') {
        await prefs.remove("active_incident_id");
        await prefs.remove("incident_time");
        return null;
      }

      // ⏱️ If expired → invalidate
      if (now - incidentTime > thirtyMinutes) {
        await prefs.remove("active_incident_id");
        await prefs.remove("incident_time");
        return null;
      }

      return incidentId;
    } catch (e) {
      print("Error checking incident: $e");
      return null;
    }
  }

  //submit incident report

  Future<void> _submitToNextJs(String photoUrl) async {
    print('photoURL $photoUrl');
    try {
      final Map<String, dynamic> emergencyData = {
        "userId": _currentUserId,
        "lguCode": _currentLguCode,
        "userName": _currentUserName,
        "userPhone": _currentUserPhone,
        "emergencyType": selectedEmergency.toLowerCase(),
        "severity": "high",
        "description": "Incident in $_currentLguCode",
        "photoUrl": photoUrl, // Added photoUrl field
        "location": {
          "longitude": double.parse(widget.longitude),
          "latitude": double.parse(widget.latitude),
          "accuracy": int.tryParse(widget.accuracy) ?? 10
        },
      };

      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/v2/emergencies'),
        headers: {"Content-Type": "application/json", "x-api-key": _apiKey},
        body: jsonEncode(emergencyData),
      );

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final String newIncidentId = responseData['data']['_id'];

        final prefs = await SharedPreferences.getInstance();

        await prefs.setString("active_incident_id", newIncidentId);
        await prefs.setInt(
            "incident_time", DateTime.now().millisecondsSinceEpoch);

        AnalyticsService.trackEvent(
          eventName: 'Submit Incident',
          lguCode: _currentLguCode,
          screen: 'Report Incident Screen',
        );

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => EmergencyChatPage(
                  incidentId: newIncidentId, userName: _currentUserName),
            ),
          );
        }
      } else if (response.statusCode == 429) {
        Fluttertoast.showToast(
            msg: "Too many reports sent recently. Please wait a few minutes.");
      } else {
        Fluttertoast.showToast(
            msg: "Complete your profile in the Profile page.");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Network error. Connection failed.");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<File?> _compressImage(File image) async {
    final String targetPath =
        image.path.replaceAll(RegExp(r'\.(jpg|jpeg|png)$'), '_compressed.jpg');
    final XFile? result = await FlutterImageCompress.compressAndGetFile(
      image.absolute.path,
      targetPath,
      quality: 70,
    );
    return result != null ? File(result.path) : null;
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition:
                CameraPosition(target: _initialPosition, zoom: 17),
            markers: _markers,
            onMapCreated: (controller) => mapController = controller,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          _buildGradientOverlay(),
          _buildUIContent(),
          if (isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildUIContent() {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPhotoPreview(),
                const Text("INCIDENT TYPE",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.2)),
                const SizedBox(height: 10),
                _buildEmergencyGrid(),
                const SizedBox(height: 20),
                _buildSubmitButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
            label: const Text('Back'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withOpacity(0.15),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 12),
          const Text("REPORTING FROM",
              style: TextStyle(
                  color: Colors.white70, fontSize: 10, letterSpacing: 1.5)),
          Text("${widget.latitude}, ${widget.longitude}",
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(5)),
            child: Text("LGU: $_currentLguCode".toUpperCase(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FutureBuilder<String?>(
                future: getValidIncidentId(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data == null) {
                    return const SizedBox(); // hide chat button
                  }

                  return FloatingActionButton.extended(
                    icon: const Icon(Icons.chat),
                    label: const Text("Active Chat Report!"),
                    backgroundColor: Colors.yellow,
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EmergencyChatPage(
                            incidentId: snapshot.data!,
                            userName: _currentUserName,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildEmergencyGrid() {
    final items = [
      {'t': 'Fire', 'i': Icons.local_fire_department},
      {'t': 'Medical', 'i': Icons.medical_services},
      {'t': 'Police', 'i': Icons.local_police},
      {'t': 'Ambulance', 'i': Icons.car_crash},
      {'t': 'Flood', 'i': Icons.water},
      {'t': 'Landslide', 'i': Icons.landslide},
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: items.map((item) {
          bool sel = selectedEmergency == item['t'];
          return GestureDetector(
            // onTap: () => setState(() => selectedEmergency = item['t'] as String),
            onTap: () {
              if (!widget.paid) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    title: Row(
                      children: [
                        Icon(Icons.lock_outline, color: Colors.red.shade800),
                        const SizedBox(width: 8),
                        const Text("Feature Not Activated"),
                      ],
                    ),
                    content: Text(
                      "Incident Reporting is not yet available in ${_currentLguCode.toUpperCase()}. "
                      "Please contact your LGUs to request this feature.",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "Got it",
                          style: TextStyle(
                              color: Colors.red.shade800,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
                return; // stop here, don't select the type
              }
              setState(() => selectedEmergency = item['t'] as String);
            },

            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 75,
              height: 75,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color:
                    sel ? Colors.red.shade800 : Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item['i'] as IconData,
                      color: sel ? Colors.white : Colors.red.shade800,
                      size: 28),
                  const SizedBox(height: 4),
                  Text(item['t'] as String,
                      style: TextStyle(
                          color: sel ? Colors.white : Colors.black87,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Column(
      children: [
        if (_image == null)
          OutlinedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.camera_alt, color: Colors.white),
            label: const Text("ADD PHOTO (Optional)",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              side: const BorderSide(color: Colors.white, width: 2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        const SizedBox(height: 5),
        ElevatedButton(
          onPressed: (selectedEmergency.isEmpty || isLoading)
              ? null
              : _uploadAndSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade900,
            disabledBackgroundColor: Colors.grey.shade800,
            minimumSize: const Size(double.infinity, 60),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 5,
          ),
          child: const Text("SEND EMERGENCY HELP",
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1.1)),
        ),
      ],
    );
  }

  Widget _buildPhotoPreview() {
    if (_image == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(_image!,
                  width: 50, height: 50, fit: BoxFit.cover)),
          const SizedBox(width: 15),
          const Expanded(
              child: Text("Evidence Attached",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.black87))),
          IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red),
              onPressed: () => setState(() => _image = null)),
        ],
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.8),
                Colors.transparent,
                Colors.black.withOpacity(0.95)
              ]),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            Text("Submitting Report...",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
