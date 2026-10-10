# Pull Requests

## Before opening

```bash
dart run tool/check.dart
```

- [ ] It passes.
- [ ] You ran the change on Android and iOS.
- [ ] The diff contains only this change.
- [ ] You reviewed your own diff.

## The PR

- **Title** in the commit format; it becomes the squash commit. CI checks it.
- Fill in the template: what and why, screenshots, impact, how it was tested.
- Keep it small: one screen or one behaviour. Over about 400 changed lines, split it.
- Open as a draft until it is ready.

## Review

- One approval and green CI are required.
- Changes to `core/api`, `core/auth`, payment, CI or native Android and iOS configuration need the technical lead's approval.

The reviewer checks, in this order:

1. **Does it work?** Run it. Try no network, a slow network, and going back mid-request.
2. **Rules.** [engineering-rules.md](../conventions/engineering-rules.md): layers respected, money and error codes handled properly, nothing sensitive logged.
3. **States.** Loading, empty, error; small screen; large text; dark mode.
4. **Tests.** Do they fail if the behaviour breaks?
5. **Readability.**

Comment prefixes: `must:` blocks the merge, `should:` expects a reply, `nit:` is optional, `question:` asks.

The author replies to every comment and does not resolve the reviewer's threads. Disagreements that two rounds do not settle go to the technical lead.

## Merging

Squash and merge, by the author, after approval and green CI. Delete the branch.
