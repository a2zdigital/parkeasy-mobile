# Security

## Tokens and sessions

- The access token is stored only with `flutter_secure_storage`. Never in shared preferences, a file, a log or a crash report.
- Only `core/auth` reads or writes it.
- On `UNAUTHENTICATED`, or on sign-out, delete the token and every cached piece of user data.
- There is no refresh token; the user signs in again when the token ends.

## What must never be logged or reported

Tokens · OTP codes · phone numbers and emails · payment details · full request or response bodies. Log the request ID, the path, the status and the error code.

## Keys and secrets

**Anything shipped inside the app can be extracted from it.** Obfuscation slows a reader down; it does not hide a string. So the rule has two halves: real secrets never enter the app, and the keys that must be in the app are restricted so that a copy is useless.

| Kind | Examples | Where it lives | In git | In the app |
|---|---|---|---|---|
| **Secret** | Razorpay key secret and webhook secret · SMS provider credentials · Firebase service-account file or server key · any Google key that is not locked to the app (Places, Geocoding, Directions web services) · database and API credentials | The server's environment only | Never | **Never** |
| **Signing material** | Android keystore and its passwords · iOS certificates, `.p8`, `.p12`, provisioning profiles · store upload credentials | CI secret store and the technical lead's password manager | Never | Never |
| **Restricted client key** | Google Maps SDK key · `google-services.json` and `GoogleService-Info.plist` · Razorpay key ID (sent by our API with each order) | CI secret store; each developer's untracked local files | Never | Yes, unavoidably, and therefore restricted (below) |
| **Public configuration** | API base URL · environment name · feature switches | `env/*.json` (only the example is tracked) | Example only | Yes |

### Rules

1. **A feature that needs a secret key is built on our API, not in the app.** Place search, geocoding, sending notifications, creating payment orders and refunds are API calls to our server, which holds the key. The app never calls a third party with a secret.
2. **Every client key is restricted at the provider before it is used:** Android keys to the package name and the signing certificate's SHA-1, iOS keys to the bundle ID, and each key to the one API it needs. An unrestricted key is treated as leaked. Debug and release use different keys.
3. **No key is typed in source code, a manifest, a plist, a Gradle file or a document.** Native files read a build variable (`${MAPS_API_KEY}` in the manifest, `$(MAPS_API_KEY)` in the plist) that comes from an untracked file locally and from the CI secret store in the pipeline.
4. **The files that hold them are git-ignored** (`.gitignore`, "Keys, credentials and signing material"), and `dart run tool/secret_scan.dart` fails the check and CI if a key-shaped string or one of those files is tracked.
5. **Firebase:** client configuration files are restricted client keys (rule 2) and stay out of git. Security comes from Firebase security rules and App Check, never from hiding the file. The service account stays on the server.
6. **A key that was ever committed or pasted into a chat, ticket or screenshot is revoked and replaced**, not just deleted. History keeps it.
7. **Keys are never logged, shown on a screen, sent to analytics or included in an error report.**
8. **Nobody shares a key by message or email.** New keys go into the secret store; developers get access to the store.

### What exists today

No key is in the project. The Razorpay SDK is installed, and it needs none from us: the public key ID arrives from our API with each order and is passed straight to the checkout window (`lib/core/payment`); the key secret and the webhook secret exist only on the API server. There is no Maps or Firebase SDK yet.

| When this is added | The key goes |
|---|---|
| Google Maps SDK (MD-02) | Restricted per platform; `android/secrets.properties` → manifest placeholder; `ios/Flutter/Secrets.xcconfig` → `Info.plist` variable. Both files untracked; CI writes them from its secrets |
| Place search or geocoding | A server-side key on our API; the app calls our API |
| Firebase (push, crash reports) | `google-services.json` and `GoogleService-Info.plist` written by CI from its secrets; App Check enabled |
| Razorpay checkout (**in place**) | Key ID arrives from our API per order; nothing stored in the app. Switching from test to live keys is a server change only; the app is not rebuilt |
| Release signing | Keystore and passwords from CI secrets; `key.properties` untracked |

## Trust

- The app is a convenience, not a guard. Hiding a button is not a permission check; the API refuses, and the app handles the refusal.
- Never send a price, a role or a user ID for the server to trust.
- A payment is successful only when the API says so.

## Network

- HTTPS only outside local development: the configuration refuses a non-HTTPS URL for staging or production, Android allows plain HTTP in debug builds only, and iOS only to the local network.
- Android backups are disabled so the sign-in token is never copied off the device.
- Certificate pinning is **Planned**, to be decided before production.

## Device

- Request a permission (location) at the moment it is needed, after explaining why. The app must work when it is refused: search by a typed place.
- Screens showing payment are not captured in logs or analytics.
- Release builds are obfuscated (`--obfuscate --split-debug-info`), and debug logging is off.

## Dependencies

A package runs with the app's full rights. See [dependencies.md](dependencies.md).

## Reporting

A suspected vulnerability goes straight to the technical lead, not into a public issue.
