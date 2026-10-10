# Security

## Tokens and sessions

- The access token is stored only with `flutter_secure_storage`. Never in shared preferences, a file, a log or a crash report.
- Only `core/auth` reads or writes it.
- On `UNAUTHENTICATED`, or on sign-out, delete the token and every cached piece of user data.
- There is no refresh token; the user signs in again when the token ends.

## What must never be logged or reported

Tokens · OTP codes · phone numbers and emails · payment details · full request or response bodies. Log the request ID, the path, the status and the error code.

## Nothing secret in the app

Anything compiled into the app can be extracted. The environment files hold URLs and public keys only. The Razorpay key ID is public by design and arrives from the API with each order; the key secret never leaves the server.

## Trust

- The app is a convenience, not a guard. Hiding a button is not a permission check; the API refuses, and the app handles the refusal.
- Never send a price, a role or a user ID for the server to trust.
- A payment is successful only when the API says so.

## Network

- HTTPS only outside local development. Cleartext is allowed only for the local environment's debug builds.
- Certificate pinning is **Planned**, to be decided before production.

## Device

- Request a permission (location) at the moment it is needed, after explaining why. The app must work when it is refused: search by a typed place.
- Screens showing payment are not captured in logs or analytics.
- Release builds are obfuscated (`--obfuscate --split-debug-info`), and debug logging is off.

## Dependencies

A package runs with the app's full rights. See [dependencies.md](dependencies.md).

## Reporting

A suspected vulnerability goes straight to the technical lead, not into a public issue.
