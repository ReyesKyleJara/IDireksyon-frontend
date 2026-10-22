# IDireksyon

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

**IDireksyon** is a mobile application designed to help residents of Santa Maria, Bulacan navigate the process of acquiring government-issued IDs.

The application organizes government ID requirements and provides personalized guidance based on the user's goals, existing IDs, and available documents. Through its smart sequencing feature, IDireksyon recommends an appropriate order for completing requirements and obtaining IDs.

## 🎯 Project Goal

IDireksyon aims to make government ID processing easier to understand by turning scattered requirements and procedures into a clear, step-by-step journey.

The application focuses on answering:

> **"What should I do first, what comes next, and where do I go?"**

## ✨ Key Features

- 🛣️ **Personalized ID Roadmap**  
  Provides users with an ordered sequence of recommended steps based on their needs and available documents.

- 🪪 **Government ID Directory**  
  Allows users to browse and learn about different government-issued IDs and their requirements.

- 📄 **Document Inventory**  
  Helps users keep track of the IDs and documents they already have.

- 📍 **Office Finder**  
  Helps users locate relevant government offices and access directions.

- 💰 **Cost Estimation**  
  Provides estimated costs associated with obtaining selected government IDs.

- 📋 **Requirement Guidance**  
  Presents the documents and requirements needed for specific IDs.

## 🧠 Smart Sequencing

IDireksyon uses a **rule-based sequencing approach** rather than artificial intelligence or machine learning.

The recommended sequence considers factors such as:

- User's selected goal
- Existing IDs and documents
- ID requirements
- Prerequisite relationships between requirements
- Document readiness
- Predefined application rules

The resulting sequence is presented to the user as a **personalized ID roadmap**.

## 🛠️ Technology Stack

### Frontend
- Flutter
- Dart

### Backend
- Laravel
- PHP
- REST API

### Database
- MySQL

## 📱 Project Structure

The frontend follows a feature-based Flutter architecture:

```text
lib/
├── core/
├── data/
├── features/
├── admin/
├── services/
└── main.dart
```

## 👥 Development

IDireksyon is an undergraduate capstone project developed by a student team.

The project is currently under active development. Features, interfaces, and system components may change as development and evaluation progress.

📌 Project Status

In Development

Current development focus:

- Resident mobile application
- User interface implementation
- Personalized roadmap
- Government ID information
- Backend API integration
- Smart sequencing logic
