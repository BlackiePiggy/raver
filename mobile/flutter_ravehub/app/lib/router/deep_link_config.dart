// This file documents the platform-specific deep link configuration
// required for RaveHub's deep linking to work end-to-end.
//
// No runtime code is needed here -- the DeepLinkHandler class in
// deep_link_handler.dart handles the actual URI-to-path conversion.
// This file serves as the single source of truth for what each platform
// needs configured.
//
// ---------------------------------------------------------------------------
// Android: android/app/src/main/AndroidManifest.xml
// ---------------------------------------------------------------------------
//
// Add the following <intent-filter> inside the <activity> element:
//
//   <intent-filter android:autoVerify="true">
//     <action android:name="android.intent.action.VIEW"/>
//     <category android:name="android.intent.category.DEFAULT"/>
//     <category android:name="android.intent.category.BROWSABLE"/>
//
//     <!-- HTTPS universal links -->
//     <data android:scheme="https" android:host="ravehub.top"/>
//
//     <!-- Custom scheme -->
//     <data android:scheme="raver"/>
//   </intent-filter>
//
// For Android App Links verification, host the Digital Asset Links file at:
//   https://ravehub.top/.well-known/assetlinks.json
//
// Example assetlinks.json:
//   [{
//     "relation": ["delegate_permission/common.handle_all_urls"],
//     "target": {
//       "namespace": "android_app",
//       "package_name": "top.ravehub.app",
//       "sha256_cert_fingerprints": ["<SHA-256 of signing cert>"]
//     }
//   }]
//
// ---------------------------------------------------------------------------
// iOS: ios/Runner/Runner.entitlements
// ---------------------------------------------------------------------------
//
// Add the Associated Domains entitlement:
//
//   <key>com.apple.developer.associated-domains</key>
//   <array>
//     <string>applinks:ravehub.top</string>
//   </array>
//
// Also register the custom URL scheme in Info.plist:
//
//   <key>CFBundleURLTypes</key>
//   <array>
//     <dict>
//       <key>CFBundleURLSchemes</key>
//       <array>
//         <string>raver</string>
//       </array>
//       <key>CFBundleURLName</key>
//       <string>top.ravehub.app</string>
//     </dict>
//   </array>
//
// For iOS Universal Links verification, host the association file at:
//   https://ravehub.top/.well-known/apple-app-site-association
//
// Example apple-app-site-association:
//   {
//     "applinks": {
//       "apps": [],
//       "details": [{
//         "appIDs": ["<TEAM_ID>.top.ravehub.app"],
//         "paths": ["/events/*", "/djs/*", "/sets/*", "/news/*",
//                   "/labels/*", "/festivals/*", "/rankings/*",
//                   "/genres/*", "/search", "/users/*",
//                   "/circle/*", "/inbox/*", "/profile/*"]
//       }]
//     }
//   }
//
// ---------------------------------------------------------------------------
// HarmonyOS: entry/src/main/module.json5
// ---------------------------------------------------------------------------
//
// Add the following to the "abilities" array entry for the main ability:
//
//   "skills": [{
//     "uris": [
//       { "scheme": "https", "host": "ravehub.top" },
//       { "scheme": "raver" }
//     ]
//   }]
//
// ---------------------------------------------------------------------------
// Web: Server-side configuration
// ---------------------------------------------------------------------------
//
// Ensure the following files are served from https://ravehub.top:
//   /.well-known/assetlinks.json          (for Android App Links)
//   /.well-known/apple-app-site-association (for iOS Universal Links)
//
// Both files must be served with Content-Type: application/json and
// must be accessible without redirects.
