Office Finder embeds `flutter_map`; office selection and driving directions stay inside the app. The existing three Bulacan office records are in `lib/features/office_finder/models/office_catalog.dart`. They are a curated starter catalog, not a live nationwide office directory. Verify their coordinates and hours before release.

Map tiles use the existing Esri light/dark canvas layers with visible attribution. Location is requested only when the user taps My location or Get directions. Android and iOS location permission declarations already exist. Web location requires HTTPS or localhost.

Directions use OSRM road geometry, distance, duration and maneuver steps. They are a route preview, without live traffic, voice guidance, background tracking or automatic rerouting. Location and destination coordinates are sent to the routing provider when directions are requested.

Place search is explicitly submitted, restricted to the Philippines, cached for the screen lifetime and rate limited. Typing filters the local office catalog without network requests. See the [Nominatim policy](https://operations.osmfoundation.org/policies/nominatim/) and [OSRM API](https://project-osrm.org/docs/v5.24.0/api/).

Public services need a network connection and have no app-specific availability guarantee. For production traffic, configure managed or self-hosted services using `--dart-define=ROUTING_URL=https://your-osrm-host` and `--dart-define=GEOCODING_URL=https://your-nominatim-host/search`. Endpoints must implement the same response formats. Confirm tile-provider terms and capacity for your release.

Run `flutter test test/office_map_test.dart` for route decoding, search caching, missing routes, permission errors, selection/filtering, light/dark themes and compact/landscape layouts. Real GPS permissions still need a device check.
