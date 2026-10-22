## One-server setup (web, CMS, Android API, maps)

From the parent IDireksyon folder, run:

```powershell
.\start-system.cmd
```

This builds Flutter web at /app/ and CMS assets, then starts Laravel on port 8000. Dependencies must already be installed (composer install, npm install, flutter pub get), and the existing local database/.env must be configured. It does not reset or seed the database. Stop any Vite dev server before running. For later starts without source changes, use .\start-system.cmd -SkipBuild. Use -Port 9000 to choose another port.

- Resident web: http://localhost:8000/app/
- CMS: http://localhost:8000/admin
- API check: http://localhost:8000/api/health
- Phone browser: http://COMPUTER_WIFI_IP:8000/app/ (same Wi-Fi; allow private-network access in Windows Firewall).

Web API requests use the same origin, including HTTPS and custom ports. Android uses this same backend; build/run it with --dart-define=API_BASE_URL=http://COMPUTER_WIFI_IP:8000/api. The standard emulator defaults to http://10.0.2.2:8000/api. A physical phone cannot use the computer's localhost.

### Google Maps configuration

Set GOOGLE_MAPS_SERVER_API_KEY in IDireksyon-backend/.env to a server key enabled for Places API (New) and Routes API. Restart the launcher after changing it. Both platforms send searches/directions to /api/maps/search and /api/maps/route; the server credential is never included in the app. Endpoints validate requests and allow 30 requests per minute per client IP.

The map display still requires platform SDK keys: web/maps-config.js uses GOOGLE_MAPS_WEB_API_KEY; Android uses --dart-define=GOOGLE_MAPS_ANDROID_API_KEY=YOUR_ANDROID_KEY. Restrict the browser key to intended website origins (including http://localhost:8000/* and intended LAN origins), and Android key to the app package/signing certificate. Keep the server key separate with suitable API/IP restrictions. Internet, billing, and enabled Google APIs are required. For browser geolocation on phones, use an HTTPS deployment; plain HTTP LAN origins may not allow location access.

One local application server handles the UI and API; Google remains an external service and MySQL remains the configured database. Native Android runs on the phone. The launcher uses Laravel's development server; production hosting should serve IDireksyon-backend/public with HTTPS and PHP, retaining /app/ and /api on the same domain.

