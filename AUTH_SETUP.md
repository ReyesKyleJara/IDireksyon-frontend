# Local resident authentication

From `IDireksyon-backend`, run:

```powershell
composer install
php artisan migrate
php artisan serve --host=0.0.0.0 --port=8000
```

From `IDireksyon-frontend`, run `flutter run`. Android emulators use
`http://10.0.2.2:8000/api`; desktop and web use `http://127.0.0.1:8000/api`.
For a physical phone on the same network, use your computer's LAN address:

```powershell
flutter run --dart-define=API_BASE_URL=http://YOUR_LAN_IP:8000/api
```

Android debug builds allow local HTTP. Use an HTTPS API URL for release builds.

Email and Philippine mobile signup call `POST /api/auth/register`.
Login calls `POST /api/auth/login` with `identifier` and `password`.
The API returns a resident profile and a Sanctum token valid for 30 days.
The app keeps the session in memory; restarting requires signing in again.
Authenticated requests can use `Authorization: Bearer <token>` with
`GET /api/auth/me` and `POST /api/auth/logout`.

Successful signup opens Set Up Profile: government IDs first, then documents.
Next keeps selected IDs; Skip skips the current step. Completing or skipping
the documents step saves the selections through `POST /api/auth/profile-setup`
then shows the loading animation for 2 seconds and the “You’re all set” screen
for 3 seconds before opening home. Login always opens home directly, even if setup was interrupted.
Selections and the completion timestamp are stored on the account and returned
with login and `GET /api/auth/me`. CMS accounts cannot
use resident login. Phone numbers are normalized to +639 format; signup does
not yet verify ownership through SMS or email. Password recovery and the actual
Terms/Privacy content remain placeholders in the existing UI.

Authentication uses [Laravel Sanctum's mobile API tokens](https://laravel.com/docs/12.x/sanctum#mobile-application-authentication).
