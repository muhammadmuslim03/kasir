# Kasir Warung

Point-of-sale app for a small Indonesian warung, based on `Product Requirements Document.pdf`.

## Structure

- `frontend/` - Flutter app using MVC-style folders: `model`, `controller`, `view`.
- `backend/` - Go REST API with SQLite persistence.

## Run Backend

```bash
cd backend
go run ./cmd/server
```

The API listens on `http://localhost:8080` by default and creates `backend/kasir.db`.

If you run from `backend/cmd/server`, this equivalent command also works:

```bash
go run main.go
```

If port `8080` is already used, stop the old process or choose another port:

```bash
go run ./cmd/server -addr :8081
```

Environment variables are also supported:

```bash
KASIR_ADDR=:8081 KASIR_DB_DSN=kasir.db go run ./cmd/server
```

Demo auth endpoint:

- `owner` role can manage products, view reports, and view sales history.
- `cashier` role can use checkout, add and edit products, and view sales history.
- Owner mode requires a PIN. The default development PIN is `123456`.

For production-like testing, override demo tokens:

```bash
KASIR_OWNER_TOKEN=replace-owner-token KASIR_CASHIER_TOKEN=replace-cashier-token KASIR_OWNER_PIN=replace-pin go run ./cmd/server
```

## Run Flutter

```bash
cd frontend
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
```

For phone/tablet access on the same Wi-Fi, run the backend and Flutter web
server from the laptop, then open the laptop IP from the phone browser:

```bash
cd backend
go run ./cmd/server -addr :8080
```

```bash
cd frontend
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 3000
```

Then open `http://<laptop-ip>:3000` on the phone or tablet. When the app is
opened through a browser without `API_BASE_URL`, it automatically uses
`http://<laptop-ip>:8080` for the API.

Android emulator uses host networking through `10.0.2.2`:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

For a physical Android phone connected with USB debugging, forward the backend
port first so the app can reach the laptop backend through `localhost`:

```bash
adb reverse tcp:8080 tcp:8080
flutter run -d <device-id>
```

## Security Notes Implemented

- Backend validates product prices, image URLs/uploaded image data, quantities, and cash received.
- Checkout uses one SQL transaction for transaction insert and transaction item insert.
- Product delete hides the menu with a soft delete so existing transaction history remains readable.
- Flutter stores the active demo token and role in `flutter_secure_storage`, not shared preferences.
- Backend enforces role-based access for owner-only product delete and report endpoints.
- Production mode requires non-default tokens, owner PIN, and explicit CORS origins.
- Cloud backup is intentionally left as a future extension from the PRD.

## Production Deployment

Run checks before deploying:

```bash
cd backend
go test ./...
go build -buildvcs=false -o /tmp/kasir-server ./cmd/server

cd ../frontend
flutter test
flutter analyze
flutter build web --release --dart-define=API_BASE_URL=https://api.example.com
```

The Flutter web release files are generated in `frontend/build/web`.

Backend production environment variables:

```bash
KASIR_ENV=production
KASIR_ADDR=:8080
KASIR_DB_DSN=file:/var/lib/kasir/kasir.db?_pragma=foreign_keys(1)&_pragma=busy_timeout(5000)
KASIR_OWNER_TOKEN=<random-owner-token-at-least-16-chars>
KASIR_CASHIER_TOKEN=<random-cashier-token-at-least-16-chars>
KASIR_OWNER_PIN=<non-default-pin-at-least-6-chars>
KASIR_ALLOWED_ORIGINS=https://kasir.example.com
```

Notes:

- Do not use `owner-demo-token`, `cashier-demo-token`, `123456`, or `KASIR_ALLOWED_ORIGINS=*` when `KASIR_ENV=production`.
- Use a persistent path for SQLite, for example `/var/lib/kasir/kasir.db`, and back it up regularly.
- Serve the backend and frontend through HTTPS. If they use different domains, `KASIR_ALLOWED_ORIGINS` must contain the frontend origin.
