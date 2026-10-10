# Continuous Integration

GitHub Actions, in `.github/workflows/ci.yml`. It runs on every pull request to `main` or `staging` and on every push to them.

| Job | Checks | Fix locally |
|---|---|---|
| PR title | The title follows the commit format | Rename the PR |
| Format, analyse and test | `dart run tool/check.dart`: the app's name is typed nowhere; `dart format` leaves nothing to change; model code generates; `flutter analyze` reports nothing, infos included; `flutter test` passes | `dart format lib test tool`, then fix what the analyzer and tests report |

Flutter is pinned to the version in the workflow file. Upgrading it is its own PR.

## Rules

- A red build is never merged, and never "fixed" by skipping a test or adding an ignore.
- If CI fails and your machine passes, the difference is a bug to find: usually the Flutter version or an uncommitted file.

## Planned

| Addition | When |
|---|---|
| Android and iOS build jobs | Before the first tester build |
| Coverage report | After the first features |
| Build and upload to testers | After MD-06 is decided |

## Still to set up on GitHub

Branch protection on `main` and `staging` requiring this workflow and one review.
