# Definition of Done

A ticket is done when all of this is true.

## Behaviour

- [ ] It does what the ticket asks, on Android and iOS.
- [ ] Loading, empty and error states exist and were seen.
- [ ] It behaves with no network, a slow network, and when the user goes back mid-request.
- [ ] It works on the smallest supported screen, at 200% text size and in dark mode.

## Code

- [ ] `dart run tool/check.dart` passes.
- [ ] It follows the [engineering rules](../conventions/engineering-rules.md).
- [ ] No hard-coded colours, sizes or strings.
- [ ] Nothing sensitive is logged.

## Tests

- [ ] Tests cover the new behaviour and its failure cases.

## Docs

- [ ] `CHANGELOG.md` updated if a tester would notice.
- [ ] Conventions, configuration inventory or open decisions updated if they changed.

## Delivery

- [ ] PR reviewed, CI green, merged into `staging`.
- [ ] The ticket links the PR.
