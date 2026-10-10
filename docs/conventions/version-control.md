# Version Control

The same model as the API repository.

## Branches

| Branch | Purpose |
|---|---|
| `main` | What is released, or ready to be |
| `staging` | What testers have |
| `feat/…`, `fix/…`, `chore/…`, `docs/…`, `refactor/…`, `test/…` | Work, branched from `staging` |

Name: `<type>/<ticket>-<short-description>`, for example `feat/PM-12-booking-summary`.

1. Branch from the latest `staging`.
2. Commit small, complete steps.
3. Open a PR into `staging`. See [pull-requests.md](../process/pull-requests.md).
4. Merge by squash. Delete the branch.
5. A release is a PR from `staging` into `main`.

During initial setup the technical lead commits directly to `main` and keeps `staging` level with it.

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org):

```
<type>(<scope>): <subject>
```

| Part | Rule |
|---|---|
| `type` | `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `perf`, `ci`, `build`, `style`, `revert` |
| `scope` | The feature or area in lowercase: `auth`, `search`, `booking`, `payment`, `owner`, `core`, `theme`, `ci`. Optional for repo-wide changes |
| `subject` | Imperative, lowercase start, no full stop, at most 72 characters |

```
feat(booking): add booking summary screen
fix(payment): keep polling when the app returns from checkout
```

The body, when needed, says why. No AI attribution or co-author trailers.

| Wrong | Why |
|---|---|
| `Fixed stuff` | No type, says nothing |
| `feat: Added Booking Screen.` | Past tense, capital, full stop, no scope |
| `feat(booking): add summary and fix login and bump packages` | Three changes |

## Never

- Commit an environment file, a keystore, a signing certificate, `google-services.json` with production values, or any token.
- Commit generated files (`*.g.dart`, `*.freezed.dart`) or build output.
- Rewrite the history of `main` or `staging`.

## Tags

Releases are tagged on `main` as `vMAJOR.MINOR.PATCH`. See [release.md](../process/release.md).
