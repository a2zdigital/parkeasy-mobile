# SOP: Onboarding

From a new machine to the app running against a local API.

## Install

| Tool | Version | Notes |
|---|---|---|
| Flutter | 3.35.3 (stable) | The version CI uses. `flutter --version` must match |
| Android Studio | Current | Android SDK, an emulator image, the Flutter and Dart plugins |
| Xcode | Current | macOS only; needed for iOS. Windows developers build Android only |
| CocoaPods | Current | macOS only |
| Git | Current | |

```bash
flutter doctor
```

Fix everything it reports for the platforms you build.

## Get the code

```bash
git clone https://github.com/a2zdigital/parkeasy-mobile.git
```

```bash
flutter pub get
```

```bash
dart run tool/check.dart
```

The last command must end with "All checks passed" before you change anything. It also generates the model code (`*.g.dart`, `*.freezed.dart`), which is not in git: until it has run once, the editor shows errors in every model file.

## The API

The app needs the ParkEasy API running. Follow the onboarding document in the API repository, then load the demo data there (`php artisan migrate:fresh --seed`) and start its server, queue worker and scheduler.

Test accounts (local only, code `123456`): `+919000000001` customer, `+919000000002` owner.

| Running the app on | API address |
|---|---|
| Android emulator | `http://10.0.2.2:8000` |
| iOS simulator | `http://localhost:8000` |
| A real phone | Your machine's LAN address; start the API with `php artisan serve --host=0.0.0.0` |

Environment files (`env/local.json`) arrive with the first feature; see [configuration.md](../conventions/configuration.md).

## Run

```bash
flutter run
```

## Read

1. [Project overview](../overview/project-overview.md)
2. [Engineering rules](../conventions/engineering-rules.md)
3. [Architecture](../conventions/architecture.md)
4. [State management](../conventions/state-management.md) and [Calling the API](../conventions/api-client.md)
5. [Feature development](feature-development.md)

## Editor

Format on save with `dart format`. Do not commit editor settings that change formatting.

## Windows notes

- Enable long paths in Git: `git config --system core.longpaths true`.
- Line endings: keep Git's default conversion; the repository stores LF.
- iOS cannot be built on Windows. A change to iOS configuration is tested by someone on macOS before merge.
