// Google Sign-In — OAuth 2.0 client IDs from Google Cloud Console.
// If you see "Access blocked" / "deleted_client", recreate clients and paste new IDs here
// AND in ios/Runner/Info.plist (GIDClientID, GIDServerClientID, CFBundleURLSchemes).
//
// Steps: https://console.cloud.google.com/apis/credentials (select Firebase/GCP project)
//   1) Create credentials → OAuth client ID → type "iOS" → Bundle ID: com.qalert.joma
//   2) Create credentials → OAuth client ID → type "Web" (for ID tokens to ems.qalertapp.com)
//   3) Copy each full Client ID (…apps.googleusercontent.com) below.
//   4) Backend must verify tokens using the Web client ID — update server env if it changed.

/// iOS OAuth client — must match `<key>GIDClientID</key>` in ios/Runner/Info.plist
const String kGoogleIosClientId =
    '827333383227-6itkbugt49tegj94lipf98qb1258oin2.apps.googleusercontent.com';

/// Web OAuth client — must match `<key>GIDServerClientID</key>` and backend token audience
const String kGoogleWebServerClientId =
    '827333383227-e34mmccvvbduv2fp5v7bgt6c911ij3a3.apps.googleusercontent.com';
