import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'loading.dart';
import 'mainScreen.dart';
import 'services/analytics.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';



final GlobalKey<ScaffoldMessengerState> snackbarKey = GlobalKey<ScaffoldMessengerState>();
const Color mintGreen = Color(0xFF00BFA5);


// The Channel ID MUST match the one in your Next.js backend
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'qalert_emergency_channel',
  'Emergency Alerts',
  description: 'Notifications for emergency alerts.',
  importance: Importance.max,
  playSound: true,
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();


// ✅ Background handler — must be top-level
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('🔔 Background notification: ${message.notification?.title}');
}

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FlutterNativeSplash.remove();

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    scaffoldMessengerKey: snackbarKey,
    home: const QAlertLanding(),
  ));
}

/// iOS: [FirebaseMessaging.getToken] needs APNs token; poll briefly after permission.
Future<void> _waitForApnsToken(FirebaseMessaging messaging) async {
  for (var i = 0; i < 20; i++) {
    final apns = await messaging.getAPNSToken();
    if (apns != null) return;
    await Future.delayed(const Duration(milliseconds: 250));
  }
  debugPrint('APNS token not received in time (simulator has no APNs); FCM may fail until device.');
}


class QAlertLanding extends StatefulWidget {
  const QAlertLanding({super.key});

  @override
  State<QAlertLanding> createState() => _QAlertLandingState();
}

class _QAlertLandingState extends State<QAlertLanding> {
  bool _isLoading = false;
  bool _isServerOnline = false;
  bool _isInternetConnected = true;
  Timer? _statusTimer;
  String _munName = '';

  @override
  void initState() {
    super.initState();
    _initializeAppFlow();
    _setupFirebaseNotifications(); // ✅
  }

  final String _apiKey = dotenv.env['MOBILE_API_KEY'] ?? '';


  Future<void> _sendTokenToBackend(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final String? userId = prefs.getString('user_id');
    final String? lguCode = prefs.getString('lguCode');


    if (userId == null || lguCode == null) return;

    try {
      await http.post(
        Uri.parse('https://ems.qalertapp.com/api/v2/fcm/register'),
        headers: {'Content-Type': 'application/json', "x-api-key": _apiKey},
        body: jsonEncode({
          'userId': userId,
          'lguCode': lguCode,
          'token': token,
        }),
      );

      print("sending v2 api fcm-token to be save $userId and $lguCode");

    } catch (e) {
      debugPrint('❌ Failed to send FCM token: $e');
    }
  }

  // ✅ FCM Setup
  Future<void> _setupFirebaseNotifications() async {
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true, badge: true, sound: true,
    );

    // Foreground listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: '@mipmap/ic_launcher', // Ensure this exists
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
            ),
          ),
        );
      }
    });

    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) return;

    // iOS: FCM token requires APNs registration first; avoid apns-token-not-set
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _waitForApnsToken(messaging);
    }

    String? token;
    try {
      token = await messaging.getToken();
    } catch (e) {
      debugPrint('FCM getToken (retry after delay): $e');
      await Future.delayed(const Duration(seconds: 2));
      try {
        token = await messaging.getToken();
      } catch (e2) {
        debugPrint('FCM getToken failed: $e2');
      }
    }

    if (token != null) {
      debugPrint('📱 FCM Token: $token');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);

      await _sendTokenToBackend(token); // ✅ add this

    }

    messaging.onTokenRefresh.listen((newToken) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', newToken);

      await _sendTokenToBackend(newToken); // ✅ add this

    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationNavigation);

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleNotificationNavigation(initialMessage);
      });
    }
  }

  void _handleNotificationNavigation(RemoteMessage message) {
    debugPrint('📦 Notification data: ${message.data}');
    // TODO: Add routing logic based on message.data
  }


  Future<void> _clearAndLogout() async {
    final prefs = await SharedPreferences.getInstance();

    final keysToRemove = ['email', 'userId', 'phone','name','role','municipality','barangay','province'];
    for (String key in keysToRemove) {
      await prefs.remove(key);
    }


    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoadingPage()),
      );
    }
  }



  Future<void> _initializeAppFlow() async {
    final prefs = await SharedPreferences.getInstance();
    final bool hasSeenDisclaimer = prefs.getBool('disclaimer_shown') ?? false;

    if (!hasSeenDisclaimer && mounted) {
      await _showDisclaimerDialog(prefs);
    }

    final String? email = prefs.getString('email');
    final String? lguCode = prefs.getString('lguCode');
    final String? userId = prefs.getString('user_id'); // make sure this is saved on login

    if (mounted) {
      final bool hasEmail = email != null && email.isNotEmpty;
      final bool hasLguCode = lguCode != null && lguCode.isNotEmpty;
      final bool hasUserId = userId != null && userId.isNotEmpty;

      AnalyticsService.trackEvent(
        eventName: 'OpenApp',
        lguCode: lguCode ?? 'NOT_SET',
        screen: 'Open Screen',
      );

      if (hasEmail && hasLguCode && hasUserId) {
        // // ✅ Check if user is still active on the backend
        // final bool isActive = await _checkUserStatus(userId);
        //
        // if (!isActive) {
        //   debugPrint('🚫 User is inactive or not found. Clearing session...');
        //   await _clearAndLogout();
        //   return;
        // }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoadingPage()),
        );
      }
    }
  }



  Future<void> _showDisclaimerDialog(SharedPreferences prefs) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.gavel_rounded, color: mintGreen),
            SizedBox(width: 10),
            Text('Disclaimer'),
          ],
        ),
        content: const Text(
          'Q-ALERT is an independent app and is not affiliated with any government entity. It serves as an emergency hotline reference and incident reporting tool.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await prefs.setBool('disclaimer_shown', true);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('I UNDERSTAND',
                style: TextStyle(fontWeight: FontWeight.bold, color: mintGreen)),
          ),
        ],
      ),
    );
  }

  void _startSystemHeartbeat() {
    _checkStatus();
    _statusTimer = Timer.periodic(const Duration(seconds: 20), (_) => _checkStatus());
  }

  Future<void> _checkStatus() async {
    final internet = await InternetConnection().hasInternetAccess;
    bool server = false;
    try {
      final res = await http.get(Uri.parse('https://ems.qalertapp.com'))
          .timeout(const Duration(seconds: 5));
      server = res.statusCode < 500;
    } catch (_) { server = false; }

    if (mounted) {
      setState(() {
        _isInternetConnected = internet;
        _isServerOnline = server;
      });
    }
  }

  Future<void> _handleGetStarted() async {
    setState(() => _isLoading = true);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoadingPage()));
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isOperational = _isInternetConnected && _isServerOnline;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // _buildStatusChip(isOperational),

            Expanded(
              flex: 2,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: Image.asset(
                      'assets/images/qalert.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.emergency_rounded, size: 40, color: mintGreen),
                    ),
                  ),
                ),
              ),
            ),

            Expanded(
              flex: 5,
              child: Column(
                children: [
                  Text(_munName.toUpperCase(),
                      style: const TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 8),
                  const Text('Q-ALERT',
                      style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A))),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 50, vertical: 5),
                    child: Text(
                    'One App, One Alert',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
              child: SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleGetStarted,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mintGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('GET STARTED', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

