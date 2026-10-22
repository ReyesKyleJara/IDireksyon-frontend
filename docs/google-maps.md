> Historical setup notes. Places and directions now use Laravel for both platforms. Follow [the current one-server setup](google-maps-setup.md). The browser routing instructions below describe the previous implementation.

# Office Finder Google Maps setup

The original Office Finder layout now uses Google Maps, Places API (New), and Routes API. Enable billing and these APIs in your Google Cloud project, plus Maps SDK for Android/iOS or Maps JavaScript API for your target platform.

## Android and iOS

    flutter run --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY

Android manifest and iOS AppDelegate read the key automatically. Optional GOOGLE_MAPS_ANDROID_API_KEY and GOOGLE_MAPS_IOS_API_KEY Dart defines override the SDK key. GOOGLE_MAPS_API_KEY supplies the Places/Routes HTTP requests. Android requires API 24 or newer. iOS builds require macOS.

## Web

Copy web/maps-config.example.js to web/maps-config.js and set GOOGLE_MAPS_WEB_API_KEY to your browser key. The local file is ignored by Git. Your existing maps-config.js is preserved. Restrict the browser key to your web origins. Browser directions reuse this key through the Maps JavaScript Routes library. You do not need a backend key or GOOGLE_MAPS_API_KEY Dart define for browser directions. Place searches still use GOOGLE_MAPS_API_KEY via --dart-define.

For production, proxy Places/Routes requests through your backend to keep web-service credentials server-side. Dart defines are included in the app bundle. Use keys with restrictions appropriate to their SDK or HTTP usage.

Route estimates exclude live traffic. Live verification requires valid keys and enabled APIs.

## Local browser addresses

Use http://localhost:3000 for the current local setup. A live browser diagnostic confirmed this key is accepted on localhost:3000; http://127.0.0.1:3000 returns RefererNotAllowedMapError.

To support both addresses, add http://localhost:3000/* and http://127.0.0.1:3000/* under the key's Google Cloud website restrictions. Keep the restrictions limited to your intended origins.

The web loader uses Google's Maps callback before starting Flutter, so the SDK is ready before the map widget is created.

## Get directions in Chrome

1. Enable Routes API in the same Google Cloud project as the browser key; billing must be active.
2. In Credentials, edit the browser key. Under API restrictions, allow both Maps JavaScript API and Routes API.
3. Keep website restrictions for the local or deployed frontend origin. Use http://localhost:3000 for local testing.
4. Allow the browser to access your location. Native Android/iOS still use the REST key described above.

The Chrome app computes routes with google.maps.routes.Route.computeRoutes, reusing the browser SDK authentication instead of a second Dart-defined credential. A blocked Routes API response displays an actionable message. No backend changes are required for browser directions.

A live check returned PERMISSION_DENIED (Routes.ComputeRoutes blocked) on the current browser key. Enable the API and allow it under key restrictions before retesting.

Google setup: https://developers.google.com/maps/documentation/javascript/routes/start

Verified live in Chrome after enabling Routes API and allowing it on the browser key: a Bulacan test route returned 31 points, 1,828 meters, 439 seconds and eight instructions. The SDK path uses numeric lat/lng coordinates; the bridge accepts these and callable legacy LatLng coordinates.

