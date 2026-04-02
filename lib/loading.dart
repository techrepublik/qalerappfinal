import 'package:flutter/material.dart';
import 'package:joma/agreement.dart';
import 'package:joma/GoogleSignUpPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mainScreen.dart';
import 'package:in_app_update/in_app_update.dart';

class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key});

  @override
  _LoadingPageState createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {



  @override
  void initState() {
    super.initState();
    checkForUpdate();
  }

  Future<bool?> getUserAgreed() async {
    final prefs = await SharedPreferences.getInstance();
    bool? userAgreed = prefs.getBool('userAgreed');
    return userAgreed;
  }


  Future<void> checkUserProfile() async {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Pull the data we saved in GoogleSignUpPage
      String email = prefs.getString('email') ?? "";
      String phone = prefs.getString('phone') ?? "";

      bool userAgreed = prefs.getBool('userAgreed') ?? false;
      bool isLoggedIn = prefs.getBool('is_logged_in') ?? false; // Better to check this


      // Make sure the widget is still in the tree before navigating
      if (!mounted) return;

      if (!userAgreed) {
        // 1. Send to Agreement Screen if not agreed
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => UserAgreementScreen()),
        );
      } else if (!isLoggedIn || email.isEmpty || phone.isEmpty ) {
        // 2. Syntax fixed to 'else if'.
        // Go to Login if not logged in OR email is missing.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const GoogleSignUpPage()), // Your new Google page
        );
      } else {
        // 3. User is logged in and has agreed -> Go Home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()), // Changed from QAlertWithUpdates
        );
      }
    }

  Future<void> immediateUpdate() async {
    try {
      await InAppUpdate.performImmediateUpdate();
    } catch (e) {
      print("Immediate update failed: $e");
    }
  }

  Future<void> checkForUpdate() async {
    try {
      final updateInfo = await InAppUpdate.checkForUpdate();

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        await immediateUpdate(); // 🔴 force update
      } else {
        await checkUserProfile(); // continue your flow
      }
    } catch (e) {
      print("Update check failed: $e");
      await checkUserProfile(); // fallback
    }
  }



  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Q-ALERT'),
      ),
    );
  }
}