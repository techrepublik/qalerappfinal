import 'package:flutter/material.dart';
import 'package:joma/location_agree.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class UserAgreementScreen extends StatefulWidget {
  const UserAgreementScreen({super.key});

  @override
  _UserAgreementScreenState createState() => _UserAgreementScreenState();
}

class _UserAgreementScreenState extends State<UserAgreementScreen> {
  bool _isChecked = false;
  final String privacyPolicyUrl = "https://qalertapp.com/policy";

  // Define Emerald Green Theme Colors
  final Color emeraldGreen = const Color(0xFF10B981);
  final Color darkEmerald = const Color(0xFF059669);

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch $url'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _setUserAgreed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('userAgreed', true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: emeraldGreen, // Updated to Emerald Green
        elevation: 0,
      ),
      body: Container(
        color: const Color(0xFFFFFFFF),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "User Agreement and Privacy Policy",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF424242),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  "Please read and agree to our terms to proceed with Q-ALERT.",
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF424242).withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const SingleChildScrollView(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Disclaimer", style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF424242),
                          )),
                          SizedBox(height: 10),
                          Text(
                            "Welcome to Q-ALERT! This app helps you stay informed about local emergencies and report incidents. It is an independent app and is not affiliated with, endorsed by, or representative of any government entity.\n\n",
                            style: TextStyle(fontSize: 14, color: Color(0xFF424242), height: 1.5),
                            textAlign: TextAlign.justify,
                          ),
                          Text(
                            "User Agreement",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF424242),
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            "Welcome to Q-ALERT. By using Q-ALERT, you agree to the terms outlined in this User Agreement and the Privacy Policy linked below...\n\n"
                                "• Acceptance of Terms: By installing and using Q-ALERT, you agree to comply with this agreement.\n\n"
                                "• Use of the App: Q-ALERT is intended to assist users in requesting emergency help.\n\n"
                                "• Data Sharing: You consent to the collection and sharing of your data for emergency response.",
                            style: TextStyle(fontSize: 14, color: Color(0xFF424242), height: 1.5),
                            textAlign: TextAlign.justify,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                GestureDetector(
                  onTap: () => _launchUrl(privacyPolicyUrl),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.link, color: emeraldGreen, size: 20), // Updated
                      const SizedBox(width: 5),
                      Text(
                        "Read our Privacy Policy",
                        style: TextStyle(
                          fontSize: 16,
                          color: emeraldGreen, // Updated
                          decoration: TextDecoration.underline,
                          decorationColor: emeraldGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: _isChecked,
                      onChanged: (bool? value) {
                        setState(() {
                          _isChecked = value ?? false;
                        });
                      },
                      activeColor: emeraldGreen, // Updated
                      checkColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Flexible(
                      child: Text(
                        "I agree to the User Agreement and Privacy Policy",
                        style: TextStyle(fontSize: 14, color: Color(0xFF424242)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isChecked
                            ? [emeraldGreen, darkEmerald] // Updated
                            : [const Color(0xFFB0BEC5), const Color(0xFFCFD8DC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        if (_isChecked)
                          BoxShadow(
                            color: emeraldGreen.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isChecked
                          ? () async {
                        await _setUserAgreed();
                        if (mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => LocationAgreementScreen()),
                          );
                        }
                      }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Continue",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}