import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:joma/GoogleSignUpPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:location/location.dart';

// --- UPDATED CONSTANTS ---
class AppConstants {
  static const Color primaryColor = Color(0xFF10B981);
  static const Color secondaryColor = Color(0xFF059669);
  static const Color disabledColor = Color(0xFFB0BEC5);
  static const Color disabledSecondaryColor = Color(0xFFCFD8DC);
  static const Color backgroundColor = Color(0xFFFFFFFF);
  static const Color textColor = Color(0xFF424242);
  static const Color cardColor = Color(0xFFF5F5F5);
  static const String privacyPolicyUrl = "https://restapi.qalertapp.com/policy";
}

class LocationAgreementScreen extends StatefulWidget {
  const LocationAgreementScreen({super.key});

  @override
  _LocationAgreementScreenState createState() => _LocationAgreementScreenState();
}

class _LocationAgreementScreenState extends State<LocationAgreementScreen> {
  bool _isChecked = false;
  bool _isLocationPermissionGranted = false;
  bool _isLoading = false;

  Future<void> _setUserAgreed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('userAgreed', true);
    } catch (e) {
      _showSnackBar('Error saving agreement');
    }
  }

  Future<bool> _checkLocationPermissions() async {
    setState(() => _isLoading = true);
    Location location = Location();
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    try {
      serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          _showPermissionDeniedDialog('Location service is disabled');
          return false;
        }
      }

      permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          _showPermissionDeniedDialog('Location permission was denied');
          return false;
        }
      }

      setState(() {
        _isLocationPermissionGranted = true;
        _isChecked = true; // Auto-check the checkbox on grant
      });
      return true;
    } catch (e) {
      _showSnackBar('Error checking permissions');
      return false;
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.primaryColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showPermissionDeniedDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Permission Required',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppConstants.textColor),
        ),
        content: Text(
          '$message. Q-ALERT needs location access to share your location with authorities when you report an incident.',
          style: TextStyle(color: AppConstants.textColor.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Uncheck the checkbox if permission was denied
              setState(() => _isChecked = false);
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _checkLocationPermissions();
            },
            child: const Text(
              'Try Again',
              style: TextStyle(color: AppConstants.primaryColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: AppConstants.primaryColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "App Permissions",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppConstants.textColor),
              ),
              const SizedBox(height: 10),
              Text(
                "We need your permission to provide the best emergency response experience",
                style: TextStyle(fontSize: 14, color: AppConstants.textColor.withOpacity(0.7)),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppConstants.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Location Permission",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppConstants.textColor),
                        ),
                        SizedBox(height: 10),
                        Text(
                          "Q-ALERT requires location access to:\n\n"
                              "• Share your location with authorities when you report an incident\n"
                              "• Ensure service availability in your area\n"
                              "• Ensure the incident is reported from your current location\n\n"
                              "Important notes:\n"
                              "• Data is collected only when you actively report\n"
                              "• No background collection or hidden storage",
                          style: TextStyle(fontSize: 14, color: AppConstants.textColor, height: 1.5),
                          textAlign: TextAlign.justify,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // CHECKBOX — triggers location permission request
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _isLoading
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppConstants.primaryColor,
                    ),
                  )
                      : Checkbox(
                    value: _isChecked,
                    onChanged: _isLocationPermissionGranted
                        ? null // Lock checkbox after permission is granted
                        : (bool? value) async {
                      if (value == true) {
                        HapticFeedback.selectionClick();
                        // Temporarily check it, then trigger permission
                        setState(() => _isChecked = true);
                        final granted = await _checkLocationPermissions();
                        if (!granted) {
                          // Revert if permission was not granted
                          setState(() => _isChecked = false);
                        }
                      }
                    },
                    activeColor: AppConstants.primaryColor,
                    checkColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  Flexible(
                    child: Text(
                      _isLocationPermissionGranted
                          ? "Location permission granted ✓"
                          : "I understand and I want to proceed",
                      style: TextStyle(
                        fontSize: 14,
                        color: _isLocationPermissionGranted
                            ? AppConstants.primaryColor
                            : AppConstants.textColor,
                        fontWeight: _isLocationPermissionGranted
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // CONTINUE BUTTON
              Center(
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isChecked && _isLocationPermissionGranted
                          ? [AppConstants.primaryColor, AppConstants.secondaryColor]
                          : [AppConstants.disabledColor, AppConstants.disabledSecondaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: _isChecked && _isLocationPermissionGranted
                        ? () async {
                      HapticFeedback.heavyImpact();
                      setState(() => _isLoading = true);
                      await _setUserAgreed();
                      if (mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const GoogleSignUpPage()),
                        );
                      }
                    }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      "Continue",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}