# Dependencies

**No new package without the technical lead's approval.** A package is code we ship and must maintain.

## Before proposing one

- [ ] Flutter or Dart does not already do it, and it is not thirty lines we could write.
- [ ] Maintained: a release in the last twelve months, issues answered.
- [ ] Supports Android and iOS and the current stable Flutter.
- [ ] Licence allows commercial use (MIT, BSD, Apache-2.0).
- [ ] What permissions and native code it adds.
- [ ] What it does to app size.

Put the answers in the PR that adds it.

## Approved

The list in [ADR-0002](../adr/0002-technology-stack.md). Each is added to `pubspec.yaml` when the first feature needs it.

## Rules

- Versions use caret ranges; `pubspec.lock` is committed.
- Upgrades are their own PR (`chore(deps): …`), never mixed with a feature.
- A third-party SDK (payments, maps, reporting) is wrapped behind our own class in `core`, so features do not import the package.
- Do not copy code from a package or a website into the repository without checking its licence.
- Flutter itself is upgraded deliberately: the version is pinned in CI and stated in [onboarding.md](../sop/onboarding.md).
