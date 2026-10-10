# Configuration

Decision record: [ADR-0004](../adr/0004-environments.md).

> **Status:** Confirmed. `env/` and `AppConfig` are created with the first feature.

## Environments

| Environment | File | API |
|---|---|---|
| Local | `env/local.json` | The developer's own API: `http://10.0.2.2:8000` from the Android emulator, `http://localhost:8000` from the iOS simulator, the machine's LAN address from a real phone |
| Staging | `env/staging.json` | **Planned**; no staging server exists |
| Production | `env/production.json` | **Planned** |

```bash
flutter run --dart-define-from-file=env/local.json
```

## Rules

- Only `lib/core/config` reads environment values, into one typed `AppConfig`. Everything else depends on `AppConfig`.
- A missing or malformed value stops the app at start-up with a clear message.
- These files contain no secrets.
- `env/local.example.json` is committed and kept complete. Real environment files are git-ignored.
- A new value is added to the example file and to the inventory below in the same PR.
- Behaviour never branches on the environment's name. Add a specific value (`enablePaymentSimulation`) instead.

## Inventory

| Key | Meaning |
|---|---|
| `API_BASE_URL` | Base URL without `/api/v1` |
| `ENVIRONMENT` | `local`, `staging` or `production`; for display and reporting only |
| `ENABLE_PAYMENT_SIMULATION` | Shows the simulated-payment controls; true only where the API uses its fake payment provider |

## Values that belong to the server

Booking timings, commission, search radius and prices come from the API. Do not copy them into the app.
