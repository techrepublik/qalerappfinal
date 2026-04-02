// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// /// Service for handling authentication with NextJS backend
// class AuthService {
//   // TODO: Replace with your actual NextJS backend URL
//   static const String BASE_URL = 'https://qalertapp.com/api';
//
//   final GoogleSignIn _googleSignIn = GoogleSignIn(
//     scopes: ['email', 'profile'],
//   );
//
//   // ==================== GOOGLE SIGN UP ====================
//
//   Future<Map<String, dynamic>?> signUpWithGoogle() async {
//     try {
//       // 1. Sign in with Google
//       final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
//
//       if (googleUser == null) {
//         return null; // User cancelled
//       }
//
//       // 2. Get authentication details
//       final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
//
//       // 3. Send to NextJS backend
//       final response = await http.post(
//         Uri.parse('$BASE_URL/auth/google/signup'),
//         headers: {
//           'Content-Type': 'application/json',
//         },
//         body: jsonEncode({
//           'idToken': googleAuth.idToken,
//           'accessToken': googleAuth.accessToken,
//           'email': googleUser.email,
//           'displayName': googleUser.displayName,
//           'photoUrl': googleUser.photoUrl,
//         }),
//       );
//
//       if (response.statusCode == 200 || response.statusCode == 201) {
//         final data = jsonDecode(response.body);
//
//         // Save user data locally
//         await _saveUserData(data);
//
//         return data;
//       } else {
//         final error = jsonDecode(response.body);
//         throw Exception(error['message'] ?? 'Sign up failed');
//       }
//     } catch (e) {
//       print('Google Sign Up Error: $e');
//       rethrow;
//     }
//   }
//
//   // ==================== GOOGLE SIGN IN ====================
//
//   Future<Map<String, dynamic>?> signInWithGoogle() async {
//     try {
//       // 1. Sign in with Google
//       final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
//
//       if (googleUser == null) {
//         return null; // User cancelled
//       }
//
//       // 2. Get authentication details
//       final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
//
//       // 3. Send to NextJS backend
//       final response = await http.post(
//         Uri.parse('$BASE_URL/auth/google/signin'),
//         headers: {
//           'Content-Type': 'application/json',
//         },
//         body: jsonEncode({
//           'idToken': googleAuth.idToken,
//           'accessToken': googleAuth.accessToken,
//         }),
//       );
//
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//
//         // Save user data locally
//         await _saveUserData(data);
//
//         return data;
//       } else {
//         final error = jsonDecode(response.body);
//         throw Exception(error['message'] ?? 'Sign in failed');
//       }
//     } catch (e) {
//       print('Google Sign In Error: $e');
//       rethrow;
//     }
//   }
//
//   // ==================== FACEBOOK SIGN UP ====================
//
//   Future<Map<String, dynamic>?> signUpWithFacebook() async {
//     try {
//       // 1. Login with Facebook
//       final LoginResult result = await FacebookAuth.instance.login(
//         permissions: ['email', 'public_profile'],
//       );
//
//       if (result.status != LoginStatus.success) {
//         throw Exception('Facebook login failed: ${result.status}');
//       }
//
//       // 2. Get access token
//       final AccessToken accessToken = result.accessToken!;
//
//       // 3. Get user data from Facebook
//       final userData = await FacebookAuth.instance.getUserData();
//
//       // 4. Send to NextJS backend
//       final response = await http.post(
//         Uri.parse('$BASE_URL/auth/facebook/signup'),
//         headers: {
//           'Content-Type': 'application/json',
//         },
//         body: jsonEncode({
//           'accessToken': accessToken.token,
//           'userId': accessToken.userId,
//           'email': userData['email'],
//           'name': userData['name'],
//           'picture': userData['picture']?['data']?['url'],
//         }),
//       );
//
//       if (response.statusCode == 200 || response.statusCode == 201) {
//         final data = jsonDecode(response.body);
//
//         // Save user data locally
//         await _saveUserData(data);
//
//         return data;
//       } else {
//         final error = jsonDecode(response.body);
//         throw Exception(error['message'] ?? 'Sign up failed');
//       }
//     } catch (e) {
//       print('Facebook Sign Up Error: $e');
//       rethrow;
//     }
//   }
//
//   // ==================== FACEBOOK SIGN IN ====================
//
//   Future<Map<String, dynamic>?> signInWithFacebook() async {
//     try {
//       // 1. Login with Facebook
//       final LoginResult result = await FacebookAuth.instance.login(
//         permissions: ['email', 'public_profile'],
//       );
//
//       if (result.status != LoginStatus.success) {
//         throw Exception('Facebook login failed: ${result.status}');
//       }
//
//       // 2. Get access token
//       final AccessToken accessToken = result.accessToken!;
//
//       // 3. Send to NextJS backend
//       final response = await http.post(
//         Uri.parse('$BASE_URL/auth/facebook/signin'),
//         headers: {
//           'Content-Type': 'application/json',
//         },
//         body: jsonEncode({
//           'accessToken': accessToken.token,
//           'userId': accessToken.userId,
//         }),
//       );
//
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//
//         // Save user data locally
//         await _saveUserData(data);
//
//         return data;
//       } else {
//         final error = jsonDecode(response.body);
//         throw Exception(error['message'] ?? 'Sign in failed');
//       }
//     } catch (e) {
//       print('Facebook Sign In Error: $e');
//       rethrow;
//     }
//   }
//
//   // ==================== HELPER METHODS ====================
//
//   /// Save user data to local storage
//   Future<void> _saveUserData(Map<String, dynamic> data) async {
//     final prefs = await SharedPreferences.getInstance();
//
//     // Save authentication token
//     if (data['token'] != null) {
//       await prefs.setString('auth_token', data['token']);
//     }
//
//     // Save user info
//     if (data['user'] != null) {
//       await prefs.setString('user_id', data['user']['id'] ?? '');
//       await prefs.setString('user_email', data['user']['email'] ?? '');
//       await prefs.setString('user_name', data['user']['name'] ?? '');
//       await prefs.setString('user_photo', data['user']['photoUrl'] ?? '');
//     }
//
//     // Save additional fields as needed
//     if (data['mobUserId'] != null) {
//       await prefs.setString('mobUserId', data['mobUserId']);
//     }
//   }
//
//   /// Get saved authentication token
//   Future<String?> getAuthToken() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getString('auth_token');
//   }
//
//   /// Get saved user data
//   Future<Map<String, String?>> getUserData() async {
//     final prefs = await SharedPreferences.getInstance();
//     return {
//       'userId': prefs.getString('user_id'),
//       'email': prefs.getString('user_email'),
//       'name': prefs.getString('user_name'),
//       'photoUrl': prefs.getString('user_photo'),
//       'mobUserId': prefs.getString('mobUserId'),
//     };
//   }
//
//   /// Check if user is authenticated
//   Future<bool> isAuthenticated() async {
//     final token = await getAuthToken();
//     return token != null && token.isNotEmpty;
//   }
//
//   /// Sign out
//   Future<void> signOut() async {
//     try {
//       // Sign out from Google
//       await _googleSignIn.signOut();
//
//       // Sign out from Facebook
//       await FacebookAuth.instance.logOut();
//
//       // Clear local storage
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.clear();
//
//       // Optional: Call backend logout endpoint
//       final token = await getAuthToken();
//       if (token != null) {
//         await http.post(
//           Uri.parse('$BASE_URL/auth/logout'),
//           headers: {
//             'Content-Type': 'application/json',
//             'Authorization': 'Bearer $token',
//           },
//         );
//       }
//     } catch (e) {
//       print('Sign out error: $e');
//     }
//   }
//
//   /// Make authenticated API request
//   Future<http.Response> authenticatedRequest({
//     required String endpoint,
//     required String method,
//     Map<String, dynamic>? body,
//   }) async {
//     final token = await getAuthToken();
//
//     if (token == null) {
//       throw Exception('Not authenticated');
//     }
//
//     final uri = Uri.parse('$BASE_URL$endpoint');
//     final headers = {
//       'Content-Type': 'application/json',
//       'Authorization': 'Bearer $token',
//     };
//
//     switch (method.toUpperCase()) {
//       case 'GET':
//         return await http.get(uri, headers: headers);
//       case 'POST':
//         return await http.post(uri, headers: headers, body: jsonEncode(body));
//       case 'PUT':
//         return await http.put(uri, headers: headers, body: jsonEncode(body));
//       case 'DELETE':
//         return await http.delete(uri, headers: headers);
//       default:
//         throw Exception('Unsupported HTTP method: $method');
//     }
//   }
// }