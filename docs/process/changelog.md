# Changelog

Git history says what changed in the code. `CHANGELOG.md` says what changed for the people who use and test the app.

## What goes in

| Change | Entry? |
|---|---|
| A new screen or capability | Yes |
| A visible change to an existing screen | Yes |
| A bug fix a user could have met | Yes |
| A new permission, or a higher minimum OS version | Yes, under "Release notes for testers" |
| A newly required API version or endpoint | Yes, under "Release notes for testers" |
| Refactoring, tests, CI, internal docs | No |

## Format

Add to `## [Unreleased]` in the same PR, under `Added`, `Changed`, `Fixed`, `Removed` or `Release notes for testers`:

```markdown
### Added
- **booking:** Customers can cancel a booking from its details screen and see whether a refund is due. (PM-31)

### Fixed
- **payment:** The app keeps checking the payment after returning from checkout in the background. (PM-40)
```

- Start with the area in bold.
- Write what the user can now do or see, in plain words. No class names.
- One line per change, with the ticket.

At release, the technical lead renames `[Unreleased]` to the version and date. The store's "What's new" text is written from it.
