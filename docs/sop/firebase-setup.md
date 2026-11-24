# SOP: Set Up Firebase Push Notifications

> **Status:** The app and the API are ready. **Nothing is configured**: there is no Firebase project yet (open decision OD-21 in the API's `docs/overview/open-decisions.md`). Until the steps below are done, the app runs with push off and the Activity list still shows every notification.

## How it works

- At start-up after sign-in the app calls `Firebase.initializeApp()`. Without the platform files below this fails quietly and push stays off (`lib/core/push/push_messaging.dart`).
- With them, the app asks the user to allow notifications, then sends its FCM registration token to `PUT /api/v1/me/push-token` with `platform` `android` or `ios`, and again whenever Firebase replaces the token.
- At sign-out it calls `DELETE /api/v1/me/push-token` before the session ends, then deletes the token on the device.
- Tapping a notification opens the screen its data names (booking, facility, support ticket, payout) and marks it read.
- The API sends with the FCM HTTP v1 API (`app/Integrations/Push/FcmPushSender.php`). It is off until `PARKEASY_PUSH_DRIVER=fcm`.

## What is needed, and from whom

| Item | Who | Where it goes |
|---|---|---|
| A Firebase project, owned by a company Google account | Management / technical lead | Firebase console |
| Android app registered with ID `com.swanlabstechnologies.parkeasy` | Technical lead | Firebase console |
| `google-services.json` for that app | Technical lead | `android/app/google-services.json` (git-ignored; never commit it) |
| iOS app registered with bundle ID `com.swanlabstechnologies.parkeasy` | Technical lead | Firebase console |
| `GoogleService-Info.plist` for that app | Technical lead | `ios/Runner/GoogleService-Info.plist`, added to the Runner target in Xcode (git-ignored) |
| A paid Apple Developer Program membership | Management | developer.apple.com |
| An APNs authentication key (.p8) with its Key ID and Team ID | Technical lead | Uploaded in Firebase: Project settings > Cloud Messaging > Apple app configuration |
| A service-account key for the API, with permission to send messages | Technical lead | On the API server only, path in `FIREBASE_CREDENTIALS` |

## Steps

1. Create the project and register both apps with the IDs above.
2. Android: download `google-services.json` into `android/app/`. The Google Services Gradle plugin (declared in `android/settings.gradle.kts`) is applied automatically when this file exists.
3. iOS, on a Mac with Xcode:
   1. Add `GoogleService-Info.plist` to `ios/Runner/` and tick the Runner target.
   2. Runner target > Signing & Capabilities: add **Push Notifications**. (Background Modes > Remote notifications is already set in `Info.plist`.)
   3. Upload the APNs key to Firebase.
   4. `cd ios && pod install`. The minimum iOS version is 15.0, which Firebase needs.
4. API: put the service-account JSON on the server outside the web root, then set `PARKEASY_PUSH_DRIVER=fcm` and `FIREBASE_CREDENTIALS=/path/to/key.json`, and run `php artisan config:cache`.
5. Check: sign in on a real device, allow notifications, confirm a row appears in `push_tokens`, then trigger a notification (for example confirm a booking) and see it arrive. iOS simulators before Xcode 14 cannot receive push; use a real iPhone.

## Notes

- `firebase_messaging` 17 marks `getToken`, `onTokenRefresh` and `deleteToken` as deprecated in favour of installation IDs (`register` / `onRegistered`). The app keeps the token calls on purpose: the API sends to registration tokens. Moving both sides to installation IDs is a separate change.
- When the app is open, iOS shows the notification banner. Android does not show one while the app is in the foreground; the Activity badge updates instead. Showing it would need `flutter_local_notifications`, not added.
