# IronFit: Application Report

A guide for developers joining the project. Everything below comes from the code on the `feature/ai-coach` branch (forked from `hazem_flutter`), last updated on 23 November 2026 after merging `integration/ironfit-enhancements` (§13). Where the code does not answer a question, the report says **Not determined from code**.

The user interface, error messages and most code comments are in **French**. The README (`README.md`) is the French operations manual; this report gives the developer-oriented view in English.

---

## 1. Overview

**What it is.** IronFit is a gym management platform made of:

- a **Flutter application** (`app/`) for Windows, Android and Web, and
- a **REST API in Java / Spring Boot** (`backend/`) backed by **MySQL / MariaDB** (XAMPP locally).

**Purpose.** It runs the daily operations of a single gym:
- memberships and subscription requests
- a weekly class schedule with **bookings for a specific date** and attendance checking
- **online membership payments** through Stripe, in test mode only
- **guided workouts** that record every set, and directions to the gym on a map
- personal coaching (a member asks a coach, the coach writes programs and comments on logged workouts)
- body measurements, payments, a shop/equipment catalog, announcements and notifications
- a churn-risk score with reminders
- **AI Coach**, a chat assistant added on this branch

**Target users.**
- **Members** (`athlete` role) who train at the gym.
- **Coaches** (`coach` role), who are also members. They switch between "Mon entraînement" (their own training) and "Espace coach" (their clients).
- The **gym administrator** (`admin` role).

---

## 2. Technology stack

| Layer | Technology | Version (from code) |
|---|---|---|
| Backend language | Java | 17 (`pom.xml` `java.version`); verified here on JDK 21.0.11 |
| Backend framework | Spring Boot (Web, Data JPA, Validation, Security, Mail) | 3.5.16 (`spring-boot-starter-parent`) |
| ORM | Hibernate (via Spring Data JPA) | Managed by Spring Boot 3.5.16 (README says 6.6) |
| Auth tokens | jjwt (`jjwt-api`, `jjwt-impl`, `jjwt-jackson`) | 0.13.0 |
| Legacy password check | BouncyCastle `bcprov-jdk18on` (scrypt) | 1.86 |
| Boilerplate | Lombok | Managed by Spring Boot |
| Database | MySQL Connector/J → MySQL 8+ or MariaDB 10.4 (XAMPP); custom dialect `XamppMariaDbDialect` | Driver managed by Spring Boot |
| Backend build | Maven Wrapper | Maven 3.9.16 |
| Backend tests | Spring Boot Test, Spring Security Test, H2 (MySQL mode), JUnit 5, AssertJ, JDK `HttpServer` (fake OpenRouter) | Managed by Spring Boot |
| Frontend language | Dart | SDK `^3.9.0` (verified with Dart 3.13.5) |
| Frontend framework | Flutter (Material 3), `flutter_localizations` | Flutter 3.35+ required (verified with 3.47.7) |
| HTTP client | `http` | 1.6.0 (web uses `fetch` + `ReadableStream`, so streaming works there too) |
| Local storage | `shared_preferences` 2.5.6 (server address, workspace) and `flutter_secure_storage` 11.2.0 (JWT) | as listed |
| Maps and location | `flutter_map` 8.3.2, `latlong2` 0.9.1, `geolocator` 14.1.2 | as listed |
| External links | `url_launcher` | 6.3.3 |
| Lints | `flutter_lints` | 6.0.0 |
| AI | OpenRouter `/chat/completions` (OpenAI-compatible), default model `anthropic/claude-haiku-5.5` | n/a |
| Online payments | Stripe Checkout through `stripe-java` (**test mode only**) | 29.0.0 |
| Map services | OpenStreetMap tiles, Nominatim (address search), `routing.openstreetmap.de` (routes), Google Maps link | public services |
| Tooling | `tools/sqlite-to-mysql.js` (Node.js 22.13+) for a one-off SQLite → MySQL migration; `.bat` launchers for Windows | n/a |

There is no CI configuration, Dockerfile or deployment manifest in the repository.

---

## 3. Project structure

```
IronFit_Flutter/
├─ README.md                      French setup / operations manual
├─ APP_REPORT.md                  This report
├─ 1-lancer-serveur.bat           Starts the backend (backend/start.bat → mvnw spring-boot:run)
├─ 2-lancer-app-flutter.bat       Starts the app (app/setup.bat: pub get, run on Windows, else Chrome, else Edge)
├─ backend/                       Spring Boot API (Maven)
│  ├─ pom.xml
│  ├─ mvnw, mvnw.cmd, .mvn/       Maven Wrapper
│  ├─ .env.example                Template for backend/.env (DB, JWT, seed, SMTP, OpenRouter, Stripe); .env is git-ignored
│  ├─ knowledge/coach-knowledge.md AI Coach knowledge base edited by the gym (hours, rules, FAQ, house guidelines)
│  ├─ STRIPE_SETUP.txt, STRIPE_VERIFICATION.txt, DATED_MEMBERSHIPS.txt   Team notes on payments and dated bookings
│  ├─ scripts/stripe_test_listener.py   Runs the Stripe CLI listener with secrets redacted from its output
│  ├─ start.bat
│  ├─ tools/sqlite-to-mysql.js    One-off migration from the old Node.js/SQLite version
│  └─ src/
│     ├─ main/java/com/ironfit/
│     │  ├─ IronFitApplication.java   Entry point (@EnableScheduling, @EnableAsync, properties scan)
│     │  ├─ controller/           REST controllers (14, incl. AiCoachController, StripePaymentController)
│     │  ├─ service/              Service interfaces + AccessService (access rules) + Texts, MembershipRules, StripeCheckoutService
│     │  │  └─ impl/              Service implementations, MailServiceImpl, ProgramAccess
│     │  ├─ repository/           Spring Data JPA repositories + OffsetLimit (pagination)
│     │  ├─ entity/               21 JPA entities + WorkoutSet (embeddable) + Role enum + RoleConverter
│     │  ├─ dto/                  Request/response records grouped per domain (*Dtos.java)
│     │  ├─ security/             JWT, auth filter, password hasher, rate limiter, CurrentUser
│     │  ├─ config/               Security/CORS, Jackson, AppProperties, AiCoachProperties, seed data, BookingMigration, MariaDB dialect
│     │  ├─ exception/            ApiException, ErrorResponse, GlobalExceptionHandler
│     │  ├─ retention/            ChurnScorer (pure scoring) + RetentionJob (@Scheduled)
│     │  └─ ai/                   OpenRouterClient (SSE proxy), CoachPrompt (system prompt), KnowledgeBase   [AI Coach]
│     ├─ main/resources/application.properties   All settings, overridable by env vars
│     └─ test/                    MockMvc integration tests on H2 + unit tests (incl. AI Coach)
└─ app/                           Flutter application
   ├─ pubspec.yaml
   ├─ gym-location.example.json   Build-time gym location values
   ├─ assets/images/              Logo, watermark, two member illustrations
   ├─ lib/
   │  ├─ main.dart                IronFitApp: MaterialApp, light/dark theme, LaunchSplash, then AuthPage, HomeShell or Stripe return page
   │  ├─ core/config/app_config.dart     API address per platform, timeouts, AI Coach limits
   │  ├─ core/config/gym_location.dart   Gym coordinates and address
   │  ├─ core/network/api_client.dart    Api: static REST client, session, role helpers, notifiers
   │  ├─ core/network/token_store.dart   Secure (and in-memory test) JWT storage
   │  ├─ core/theme/              app_theme.dart (palettes, component themes), brand.dart (logo, backdrop, transitions)
   │  ├─ models/                  app_user.dart, module.dart (declarative CRUD modules), coach_message.dart [AI Coach]
   │  ├─ services/                One static service per domain + ai_coach_service.dart, ai_coach_chat.dart [AI Coach], stripe_service.dart, gym_route_service.dart
   │  ├─ widgets/                 common_widgets.dart, form_dialog.dart, ai_coach.dart [AI Coach], member_fitness_hero.dart
   │  └─ screens/                 auth, home_shell, member, coaches, program, coach, admin, planning, crud, notifications, risk,
   │                              launch_splash, membership, stripe_payments, guided_workout, gym_location
   ├─ test/                       Unit / widget tests (+ backend integration tests tagged `integration`)
   └─ android/ windows/ web/      Platform runners
```

---

## 4. How to run

### Prerequisites
- JDK 17+.
- Flutter 3.35+ (Dart 3.9+).
- XAMPP with MySQL/MariaDB started (port 3306, `root` with no password by default), or another MySQL 8+ server.
- Windows desktop target only: Visual Studio "Desktop development with C++" and Windows developer mode. Android target: Android SDK.

### Installation
```bash
cd app && flutter pub get
cd backend && ./mvnw -q -DskipTests package     # Windows PowerShell: .\mvnw.cmd ...
```

### Environment variables
Read from the environment or from `backend/.env` (copy `backend/.env.example`). The full table is in README §9. The main ones:

| Variable | Default | Role |
|---|---|---|
| `DB_URL`, `DB_USERNAME`, `DB_PASSWORD`, `DB_DIALECT`, `DDL_AUTO` | XAMPP-friendly values, `update` | Database |
| `PORT`, `HOST` | `8080`, `0.0.0.0` | HTTP listener |
| `IRONFIT_JWT_SECRET`, `TOKEN_DAYS` | generated into `data/jwt.secret`, `7` | JWT |
| `CORS_ORIGINS`, `RATE_LIMIT` | `*`, `10` | CORS for Flutter Web; auth attempts per minute |
| `ADMIN_PASSWORD`, `SEED_DEMO`, `SHOW_RESET_CODE` | `admin123`, `true`, `true` | Seed data and demo behaviour |
| `RETENTION_ENABLED`, `RETENTION_CRON`, `NOTIFY_EMAIL`, `MAIL_FROM`, `spring.mail.*` | `true`, `0 0 8 * * *`, `true`, … | Churn job and e-mails |
| `OPENROUTER_API_KEY` | empty (coach disabled) | **AI Coach key, server only** |
| `OPENROUTER_MODEL` | `anthropic/claude-haiku-5.5` | AI Coach model |
| `OPENROUTER_BASE_URL`, `OPENROUTER_SITE_URL`, `OPENROUTER_APP_TITLE` | OpenRouter URL, repo URL, `IronFit` | Endpoint and the `HTTP-Referer` / `X-Title` headers |
| `OPENROUTER_FALLBACK_MODELS` | empty | Comma-separated backup models (OpenRouter `models` routing), recommended with free models |
| `OPENROUTER_REASONING` | `off` | Model "thinking": `off` (fastest), `low`, `medium`, `high`, `default` |
| `AI_TIMEOUT_SECONDS`, `AI_MAX_DURATION_SECONDS`, `AI_MAX_TOKENS`, `AI_RATE_LIMIT` | `30`, `90`, `700`, `12` | AI Coach limits |
| `AI_KNOWLEDGE_FILE` | `knowledge/coach-knowledge.md` | Gym knowledge base, relative to `backend/`; empty = none |
| `STRIPE_SECRET_KEY`, `STRIPE_TEST_MODE` | empty, `true` | Must be a `sk_test_` key; live keys and `false` are rejected |
| `STRIPE_WEBHOOK_SECRET` | empty | `whsec_…` signing secret; checkout is refused without it |
| `STRIPE_RETURN_URL` | empty in code (`http://localhost:5173` in `.env.example`) | Page Stripe returns to: HTTPS, or HTTP on localhost. Must match the port the app is served on |
| `STRIPE_CURRENCY`, `STRIPE_AUTOMATIC_TAX` | `eur`, off | Any currency other than EUR is rejected |
| `STRIPE_PLAN_<id>_INTERVAL`, `_INTERVAL_COUNT`, `_TAX_CODE` | empty | Makes plan `<id>` a recurring subscription; tax code |
| `STRIPE_PUBLISHABLE_KEY`, `STRIPE_TAX_PERCENT`, `STRIPE_CREATE_INVOICE` | empty, `0`, `false` | Read into `AppProperties` but not used by any code |

### Commands

| Task | Command |
|---|---|
| Run backend | `cd backend && ./mvnw spring-boot:run` (or `1-lancer-serveur.bat`); serves `http://localhost:8080/api` |
| Run app | `cd app && flutter run -d windows` / `-d chrome` / `-d emulator-5554` (or `2-lancer-app-flutter.bat`) |
| Backend tests | `cd backend && ./mvnw test` (H2, no MySQL needed): 107 tests on this branch |
| App analysis + tests | `cd app && flutter analyze && flutter test --exclude-tags integration`: 61 tests on this branch (44 style notes from the analyzer, no warnings or errors) |
| App ↔ backend integration tests | Start a backend on a throwaway DB (README §15), then `flutter test test/backend_integration_test.dart` |
| Build | `flutter build web` / `windows` / `apk --release`; `./mvnw package` → `target/ironfit-backend-3.0.0.jar` |
| Deploy | **Not determined from code.** README §18 gives production advice (TLS reverse proxy, strong secrets, `DDL_AUTO=validate`) but there is no deployment tooling. |

Demo accounts on a fresh database with `SEED_DEMO=true`: `admin`/`admin123`, `sami`/`1234` (coach), `leila`/`1234` (coach + subscribed member), `youssef`/`1234`, `amira`/`1234`. The demo data includes four weeks of history: Youssef's strength program with 8 workouts, coach comments and 4 measurements; Amira's personal fitness program with workouts and measurements; Leila's mobility routine; check-ins, class bookings, shop items and equipment. `backend/knowledge/coach-knowledge.md` holds **fictional** gym details (address, hours, rules, FAQ) for this school project.

### Running the AI Coach
1. Create a key at https://openrouter.ai/keys.
2. Put `OPENROUTER_API_KEY=sk-or-v1-…` in `backend/.env` (or the environment) and optionally set `OPENROUTER_MODEL`.
3. Restart the backend.
4. Open the app and open **AI Coach**. It is the floating button at the bottom right, for every role. Without a key, the panel says the coach is not configured and the rest of the app is unaffected. The `.env.example` placeholder key is also treated as "not configured".

### Running online payments (Stripe test mode)
1. Put a `sk_test_…` key in `STRIPE_SECRET_KEY` (`backend/.env`).
2. Install the Stripe CLI and run `stripe listen --forward-to localhost:8080/api/payments/stripe/webhook`; put its `whsec_…` secret in `STRIPE_WEBHOOK_SECRET`, then restart the backend.
3. Set `STRIPE_RETURN_URL=http://localhost:5173` and start the app on that same port: `flutter run -d edge --web-port 5173`. Without `--web-port`, Flutter picks a random port and the return from Stripe fails.
4. Pay with Stripe's test card `4242 4242 4242 4242`. Details: `backend/STRIPE_SETUP.txt`.

**Upgrading an existing database:** the first start creates new tables and columns, copies each old booking to its next date, and sets the four standard TND plans to their approved EUR prices. Back up the database first.

---

## 5. Architecture

Layered client/server:

- **Flutter:** screens → static services → `Api`.
  - Screens call static services in `lib/services/`.
  - Services call `Api` (`core/network/api_client.dart`), which adds the JWT, applies timeouts and turns HTTP errors into `ApiException` carrying the server's French message.
- **Spring Boot:** controller → service → repository.
  - Controllers do routing, `@Valid` validation and `@PreAuthorize` role checks.
  - Services hold business rules, ownership checks (through `AccessService`), transactions and notifications.
  - Repositories are Spring Data JPA with JPQL queries.
- **Cross-cutting backend pieces:**
  - `JwtAuthFilter` authenticates every `/api/**` request.
  - A filter rejects bodies over 100 KB with a 413.
  - `GlobalExceptionHandler` produces one JSON error format.
  - `RetentionJob` runs daily.
  - `MailServiceImpl` sends e-mails asynchronously.
  - `DataInitializer` (order 0) and then `BookingMigration` (order 10) run at startup.
- **Stripe:** the app never sees card data or the secret key. The backend creates a hosted Checkout page; a signed webhook activates the membership.
- **Map:** the app calls the public OpenStreetMap services directly, not through the backend.
- **AI Coach:** the app never talks to OpenRouter. `AiCoachController` checks the per-user rate limit. `AiCoachServiceImpl` builds the prompt from the database, and `OpenRouterClient` calls OpenRouter and relays the stream.

```mermaid
flowchart LR
  subgraph App["Flutter app (Windows · Android · Web)"]
    S[Screens / widgets<br/>HomeShell, AiCoachPanel…] --> SV[Static services<br/>lib/services]
    SV --> API[Api client<br/>JWT · timeouts · errors]
    CH[AiCoachChat<br/>session state] --> SV
  end
  subgraph Backend["Spring Boot API :8080"]
    F[JwtAuthFilter + body-size filter] --> C[Controllers<br/>@Valid · @PreAuthorize]
    C --> SVC[Services<br/>AccessService rules]
    SVC --> R[JPA repositories]
    C -->|AI Coach| AIC[AiCoachController<br/>rate limit]
    AIC --> AIS[AiCoachServiceImpl<br/>CoachPrompt]
    AIS --> R
    AIC --> ORC[OpenRouterClient<br/>SSE · timeouts]
    J[RetentionJob @Scheduled] --> SVC
    SVC --> M[MailServiceImpl @Async]
    C --> STR[StripeCheckoutService]
    STR --> R
  end
  API -->|HTTP JSON + Bearer JWT| F
  API -. "SSE (text/event-stream)" .- AIC
  R -->|JDBC| DB[(MySQL / MariaDB<br/>ironfit_db)]
  ORC -->|HTTPS, server-side key| OR[OpenRouter API]
  M -->|SMTP, optional| SMTP[(Mail server)]
  STR -->|test key| STRIPE[Stripe]
  STRIPE -->|signed webhook| C
  SV -->|address search, routes, tiles| OSM[OpenStreetMap services]
```

**Typical data flow** (booking a class):
1. `PlanningPage` calls `PlanningService.toggleBooking(id, date, booked)`, which calls `Api.post('book')` with the date and the wanted state.
2. `JwtAuthFilter` sets a `CurrentUser` principal.
3. `ClassController.book` calls `ClassService.book`, which locks the class row, checks the date, the 90-day window, that the subscription covers that date and the remaining places, then writes a `DatedBooking`.
4. The response is `{ok, booked}`. Failures come back as `{"error": …}` with an HTTP status.

---

## 6. Actors and roles

| Actor | How identified | Permissions (enforced server-side) |
|---|---|---|
| Member (`athlete`) | `users.role = 'athlete'` → authority `ROLE_MEMBER` | Own profile, subscription requests, dated bookings (the subscription must cover the date), online payments, guided workouts, personal programs, workout log, own measurements, coaching requests, notifications, AI Coach about own data |
| Coach (`coach`) | `ROLE_COACH` + `ROLE_MEMBER` | Everything a member can do, plus: accept or decline coaching requests; programs and feedback for **active** clients only; clients' measurements and attendance; own classes; equipment; own announcements; scoped stats and churn list; AI Coach with aggregate numbers in "Espace coach" |
| Administrator (`admin`) | `ROLE_ADMIN` | Accounts (create, role, activate/deactivate, delete, renew), subscription approval, coaching supervision and assignment, catalog, payments, classes, all measurements and attendance, global stats, churn analysis; AI Coach with aggregate numbers |
| Anonymous | No token | `POST /api/signup`, `/login`, `/forgot`, `/reset` (rate-limited) |
| Stripe | No token; `Stripe-Signature` header | `POST /api/payments/stripe/webhook` only, after signature verification |

Hiding a button in the app is never the security boundary: `@PreAuthorize`, `AccessService` and the service-level ownership checks are (README §13 has the full matrix).

**External systems**
- MySQL/MariaDB.
- An optional SMTP server (`spring.mail.*`).
- **OpenRouter** (AI Coach), which receives the system prompt with the user's IronFit data plus the conversation.
- **Stripe** (test mode), which receives the member's name and e-mail, the plan and the amount.
- **OpenStreetMap services**, which receive the address typed, the route's start and end points and the map area viewed. **Google Maps** opens only as a link.
- On the device: secure storage (Android Keystore, Windows DPAPI, WebCrypto).

---

## 7. Classes, components and modules

### Backend

| Class / module | Purpose | Key properties / relationships |
|---|---|---|
| `IronFitApplication` | Entry point | Excludes the in-memory user store; enables scheduling, async and `@ConfigurationProperties` scanning |
| `config.SecurityConfig` | Stateless security chain, CORS, 100 KB body limit | Public auth routes, `/api/**` authenticated; adds `JwtAuthFilter`; `PasswordHasher` bean |
| `config.AppProperties` | `ironfit.*` settings record | jwtSecret, tokenDays, dataDir, corsOrigins, showResetCode, seedDemo, adminPassword, rateLimit, Stripe settings |
| `config.AiCoachProperties` | `ironfit.ai.*` settings record (**AI Coach**) | apiKey, model, baseUrl, siteUrl, appTitle, timeouts, maxTokens, rateLimit; `enabled()`; `toString()` never prints the key |
| `config.DataInitializer` | Seeds `admin` and demo data on an empty DB; otherwise fills plan durations and moves the four standard TND plans to EUR | Uses most repositories |
| `config.BookingMigration` | Copies each old `Booking` once to a `DatedBooking` on its next date | Marks the source row `migrated` |
| `service.StripeCheckoutService` | Checkout, status, reconcile, cancel, history, portal, webhook | `StripeOrderRepository`, `PaymentRepository`, `MembershipRules` |
| `service.MembershipRules` | Plan duration rules | `infer`, `validate`, `snapshot`, `extend` |
| `controller.StripePaymentController` | `/api/payments/stripe/*` | Delegates to `StripeCheckoutService` |
| `config.JacksonConfig`, `XamppMariaDbDialect` | JSON tweaks; MariaDB 10.4 compatibility | n/a |
| `security.JwtService` | Issues and reads HS256 tokens | Claims: subject = user id, `tv` = token version; `TokenData(userId, tokenVersion)` |
| `security.JwtAuthFilter` | Authenticates each request | Checks signature, expiry, then that the account exists, is active and has the same `token_version` |
| `security.PasswordHasher` | bcrypt, plus verification of legacy scrypt hashes | `upgradeEncoding` triggers a re-hash at login |
| `security.RateLimiter` | In-memory 1-minute sliding window | `check(request)` keyed by IP + route; `check(key, max, message)` keyed freely (used per user by AI Coach) |
| `security.CurrentUser` | Request principal `(id, role, name)` | `isAdmin/isCoach/isMember` |
| `security.RestAuthHandlers` | JSON 401/403 responses | n/a |
| `service.AccessService` | Shared access rules | `MEMBER_ROLES`, `require`, `coaches(coachId, clientId)`, `canSeeMember`, `member(id)`… |
| `service.*Service` + `impl.*Impl` | Business logic per domain (Auth, Member, Subscription, Coaching, Program, Workout, Class, Catalog, MemberRecord, Notification, Stats, Retention, Mail) | Signatures in §8 |
| `service.AiCoachService` / `impl.AiCoachServiceImpl` | **AI Coach**: builds the OpenRouter message list | Reads `UserRepository`, `ProgramRepository`, `ExerciseRepository`, `WorkoutRepository`, `MeasureRepository`, `CheckinRepository`, `DatedBookingRepository`, `ClassSessionRepository`, `CoachClientRepository`, `PlanRepository`, `PromoRepository`, `KnowledgeBase` |
| `ai.CoachPrompt` | **AI Coach**: pure system-prompt builder | `Mode {MEMBER, COACH, ADMIN}`; rules (French by default, concise plain text, safety, scope, no invented data) |
| `ai.OpenRouterClient` | **AI Coach**: HTTP client for OpenRouter | JDK `HttpClient`, 10 s connect timeout; `Message(role, content)`; inner `Completion` (AutoCloseable stream reader with a maximum duration) |
| `controller.*Controller` | REST endpoints (§10) | Thin: validation, role annotations, delegation |
| `controller.AiCoachController` | **AI Coach** endpoints, SSE writer | Uses `AiCoachService`, `OpenRouterClient`, `RateLimiter`, `AiCoachProperties`, Spring `ObjectMapper` |
| `retention.ChurnScorer` | Pure 0–100 churn score | Inactivity (0–50), regularity (0–25), subscription (0–25); `HIGH = 60`, `MEDIUM = 35`, 14-day grace period |
| `retention.RetentionJob` | Daily reminders | `@Scheduled(cron = ironfit.retention.cron)` → `RetentionService.runNightly()` |
| `exception.ApiException` / `ErrorResponse` / `GlobalExceptionHandler` | Error model and mapping | `{error, status, timestamp, fields?}` |
| `entity.*`, `repository.*` | Persistence | §9 |

### Flutter

| Class / module | Purpose | Key properties / relationships |
|---|---|---|
| `IronFitApp` (`main.dart`) | Root `MaterialApp` | Rebuilds on `Api.authChanged`; `AppTheme.light/dark` with `ThemeMode.system`; French locale; `LaunchSplash`, then `AuthPage`, `HomeShell`, or `StripePaymentsPage` when the URL carries `payment_order` |
| `Api` (`api_client.dart`) | Static REST client and session | `base`, `token`, `user`, `client` (swappable in tests), `store`, notifiers `authChanged` / `workspace` / `unread`; role getters; `call`, `get`, `list`, `post`, `put`, `delete`, `postStream` (**AI Coach**), `setSession`, `logout` |
| `ApiException` | Readable error + HTTP status | n/a |
| `TokenStore` / `SecureTokenStore` / `MemoryTokenStore` | JWT persistence | Secure storage in the app, memory in tests |
| `AppConfig` | API address per platform, timeouts, assets, AI Coach limits | `defaultApiBase`, `normalizeBase` |
| `AppTheme`, `AppColors`, `BrandLogo`, `BrandBackdrop`, `BrandPageTransitionsBuilder` | Black / amber / white identity, light and dark palettes, watermark | n/a |
| `AppUser` | Typed signed-in user | `isAdmin/isCoach/isMember`, `firstName`, `hasActiveSubscription` |
| `Module`, `Field`, `RowMenu`, `Refs` (`models/module.dart`) | Declarative CRUD module definitions | Modules: athletes, coaches, classes, plans, promos, payments, equipment, products, announcements, measures, checkins |
| `CoachMessage` | **AI Coach** message | `role` (`user`/`assistant`), `content`, `append`, `toJson` |
| Services (`AuthService`, `UserService`, `CoachService`, `ProgramService`, `PlanningService`, `AdminService`, `CatalogService`, `NotificationService`, `RiskService`) | One static class per domain | §8 |
| `AiCoachService` | **AI Coach** network + SSE parsing | `enabled`, `reply`, `deltas` |
| `AiCoachChat` (`ChangeNotifier`) | **AI Coach** session conversation | `instance`, `messages`, `status` (`CoachStatus.idle/waiting/streaming/failed`), `error`, `send/retry/stop/clear/history`; replaceable `source`; cleared on `Api.authChanged` |
| `HomeShell` | Role-based navigation | Bottom `NavigationBar` under 900 px, `NavigationRail` from 900 px; coach workspace switch; `IndexedStack` keeps visited tabs alive; `AiCoachButton` for every role |
| Screens | `AuthPage`, `MemberHome`, `ExplorePage`, `MySpacePage`, `ProgressPage`, `AttendancePage`, `MyCoachesPage`, `CoachesTab`, `ProgramsPage`, `ProgramDetailPage`, `WorkoutHistoryPage`, `PlanningPage`, `ParticipantsPage`, `CoachHome`, `ClientsPage`, `ClientDetailPage`, `AdminHome`, `RequestsPage`, `CoachingAdminPage`, `ModulesGrid`, `CrudPage`, `RiskPage`, `NotificationsPage`, `ProfilePage`, `LaunchSplash`, `MembershipPage`, `StripePaymentsPage`, `GuidedWorkoutPage`, `GymLocationPage` | `StatefulWidget` + services |
| `StripeService`, `GymRouteService`, `GymLocation` | Payments API, OpenStreetMap search and routes, gym coordinates | §13 |
| Widgets | `memberTheme`, `MemberSessionCard`, `MemberIllustration`, `MemberEmptyCard` (`member_design.dart`), `MemberFitnessHero`, `TrainingProgress`, `Empty`, `AsyncBody`, `NotificationBell`, `SectionHeader`, `StatTile`, `HeroCard`, `StatusPill`, `InitialAvatar`, `IconBadge`, painters, `formDialog` | Shared UI |
| `AiCoachButton`, `AiCoachPanel`, `openAiCoach` | **AI Coach** UI | §12 |

---

## 8. Functions and methods

The important methods, grouped by module. Backend service interfaces take `CurrentUser me` whenever access depends on the caller.

### Backend services (`service/*.java`)

| Service | Signature | Purpose → output |
|---|---|---|
| AuthService | `AuthResponse signup(SignupRequest)` / `login(LoginRequest)` | Create account or authenticate (login or e-mail) → `{token, user}` |
| | `ForgotResponse forgot(ForgotRequest)` · `void reset(ResetRequest)` | Reset code (valid 15 min; returned as `dev_code` when `SHOW_RESET_CODE`) · set a new password |
| | `UserDto me(CurrentUser)` · `updateProfile(CurrentUser, ProfileRequest)` · `TokenResponse changePassword(…)` | Profile; password change bumps `token_version` and returns a new token |
| MemberService | `search(me, q, role, active, limit, offset)` · `get(me, id)` · `create/update/setStatus/delete` · `coaches()` | Admin account management; coaches see their active clients |
| SubscriptionService | `list(me)` · `create(me, planId)` · `act(me, requestId, action, method)` · `renew(memberId, planId, method)` | Subscription requests and approval (approval records a payment) |
| CoachingService | `mine(me)` · `clients(me)` · `all(status)` · `request(me, coachId)` · `assign(coachId, clientId)` · `act(me, linkId, action)` · `endAllFor(coach, reason)` | Coach ↔ client lifecycle (`pending`, `active`, `declined`, `ended`) |
| ProgramService | `list(me, scope, clientId, limit, offset)` · `get(me, id)` · `create/update/delete` · `addExercise/updateExercise/deleteExercise` | Programs (`scope = personal\|coaching\|all`) and exercises |
| WorkoutService | `list(me, userId, programId, limit, offset)` · `create(me, WorkoutRequest)` · `delete` · `feedback(me, id, comment)` | Workout log and coach comments |
| ClassService | `list(me, week)` · `create/update/delete` · `BookResponse book(me, classId, date, booked)` · `participants(me, classId, date)` · `setAttendance(me, classId, memberId, date, status)` · `markPresent(…)` | Dated class occurrences, bookings and attendance |
| StripeCheckoutService | `checkout(me, planId, requestId)` · `status/reconcile/cancel(me, id)` · `history(me)` · `portal(me)` · `webhook(payload, signature)` | Test-mode payments (§13) |
| MembershipRules | `infer(plan)` · `validate(plan)` · `snapshot(plan)` · `extend(from, plan, today)` | Duration and end date of a membership |
| CatalogService | `plans/promos/products/equipment/announcements(q, limit, offset)` + `create*/update*/delete*` | Catalog CRUD |
| MemberRecordService | `payments/measures/checkins(me, memberId, scope, q, limit, offset)` + `create*/update*/delete*` | Member data with role-based scope |
| NotificationService | `page(me, limit, offset)` · `markRead` · `markAllRead` · `notify(userId, title, body[, emailCopy])` · `notifyAllMembers(excludedId, title, body)` | In-app notifications (+ optional e-mail copy) |
| StatsService | `Map<String,Object> stats(me)` | Dashboard figures (global for admin, scoped for coach) |
| RetentionService | `atRisk(me, includeLow)` · `remind(me, memberId)` · `int runNightly()` | Churn list, manual reminder, nightly analysis |
| MailService | `send(to, subject, text)` (async) · `String sendNow(…)` | SMTP sending; no-op without `spring.mail.host` |
| **AiCoachService** | `List<Message> prepare(CurrentUser me, ChatRequest request)` | Validates the history (last message must be from the user; user messages ≤ 2 000 chars), picks the mode, collects facts, returns `[system, …recent history]` (history trimmed to 16 000 chars) |

### Backend AI helpers

| Method | Purpose |
|---|---|
| `CoachPrompt.system(Mode, firstName, today, facts)` → `String` | Builds the system prompt |
| `CoachPrompt.clip(text, max)` → `String` | Normalizes whitespace and truncates user-entered text |
| `OpenRouterClient.stream(List<Message>)` → `Completion` | POSTs `{model, messages, stream: true, max_tokens, temperature: 0.6}` with `Authorization`, `HTTP-Referer` and `X-Title`. Throws `ApiException` before streaming (503 no key, 502 bad key/credit/model/upstream, 429, 504 timeout, 502 network) |
| `Completion.forEachDelta(Consumer<String>)` | Parses OpenRouter SSE: skips comments, stops at `[DONE]`, turns mid-stream `error` objects into `ApiException`; the stream is force-closed after `AI_MAX_DURATION_SECONDS` |
| `OpenRouterClient.forStatus(int)` → `ApiException` | Maps upstream status to a user-facing error. Never returns 401, because a 401 would log the app out |
| `AiCoachController.chat(me, ChatRequest, HttpServletResponse)` | Rate limit → prepare → open the stream. Pre-stream errors are written as JSON; otherwise writes `data: {"delta"}` … `{"done":true}` or `{"error"}` |
| `RateLimiter.check(String key, int maxPerMinute, String message)` | Keyed limiter used per user |

### Other backend utilities
- `ChurnScorer.score(Input)` → `Result(score, level, reasons, daysInactive)` and `ChurnScorer.level(score)`.
- `JwtService.issue(User)` → token; `JwtService.read(token)` → `Optional<TokenData>`.
- `PasswordHasher.matches(raw, stored)` handles both bcrypt and legacy scrypt.
- `Texts.clean`, `Texts.like`, `Texts.isEmail` are string helpers.

### Flutter (`lib/`)

| Function | Purpose |
|---|---|
| `Api.init()` | Loads the saved address (migrates old `:3000` addresses), workspace and token (migrates a plain-text token), then refreshes `me` |
| `Api.call(method, path, [body])` | JSON request; maps timeout/network/HTTP errors to `ApiException`; a 401 logs out |
| `Api.postStream(path, body, {timeout, idle})` → `Future<Stream<String>>` | **AI Coach**: streamed POST with the same error handling, plus an idle timeout between chunks |
| `Api.withQuery(path, map)` | Builds a query string, dropping empty values |
| `Api.setSession(r)`, `Api.logout()`, `Api.setBase(b)`, `Api.setWorkspace(w)` | Session and preferences |
| `AuthService.login/signup/forgotPassword/resetPassword/updateProfile/changePassword/logout` | Account flows |
| `ProgramService.programs({scope, clientId})`, `program(id)`, `create`, `addExercise`, `workouts`, `logWorkout`, `comment` … | Programs and workouts |
| `PlanningService.classes({week})`, `toggleBooking(id, {date, booked})` → `bool`, `participants(id, {date})`, `markPresent(…, {date, status})` | Schedule and attendance |
| `StripeService.checkout/status/history/cancel/reconcile/portal` | Online payments |
| `GymRouteService.search(query)`, `route(from, to, mode)` | Address search; driving or walking route |
| `UserService.measures/addMeasure/checkins/myRequests/requestPlan/cancelRequest/coaches` | Member data |
| `CoachService.myCoaches/requestCoach/endLink/clients/answer/stats` | Coaching |
| `AdminService.stats/pendingRequests/approveRequest/rejectRequest/renew/setAccountActive/members/coachingLinks/assignCoach/endCoaching` | Administration |
| `CatalogService.*`, `NotificationService.load/markRead/markAllRead/refreshUnread`, `RiskService.atRisk/remind/runNow` | Catalog, notifications, churn |
| `AiCoachService.enabled()` → `Future<bool>`; `reply(history, {workspace})` → `Stream<String>`; `deltas(Stream<String>)` → `Stream<String>` | **AI Coach** status, request and SSE parsing (missing `done` = interrupted) |
| `AiCoachChat.send(text)`, `retry()`, `stop()`, `clear()`, `history()` | **AI Coach** state transitions; `history()` keeps the last 20 non-empty messages |
| `openAiCoach(context, {sidePanel})` | Opens the side panel (≥ 700 px, or when `sidePanel` is set, which nothing uses any more) or the bottom sheet |
| Helpers in `common_widgets.dart` | `snack`, `confirm`, `attempt`, `money(v, {currency = 'EUR'})`, `dateOnly`, `localStamp`, `dayLabel`, `pickMethod`; `formDialog` in `form_dialog.dart`; `serverDialog` in `auth_screen.dart` |

---

## 9. Data model

JPA entities (schema generated by Hibernate with `ddl-auto=update`; no versioned migrations).

| Entity → table | Fields | Relationships |
|---|---|---|
| `User` → `users` | id, name, login (unique), email (unique), phone, role (`admin`/`coach`/`athlete`), passwordHash, subEnd, specialty, active, tokenVersion, stripeCustomerId, created | `plan` → Plan (SET NULL) |
| `Plan` → `plans` | id, name, price, duration, descr, currency (missing = TND), durationUnit (`DAY`/`MONTH`), durationCount, accessType (`PERIOD`/`DAY_PASS`) | n/a |
| `Promo` → `promos` | id, title, descr, discount, until (`valid_until`) | n/a |
| `Product` → `products` | id, name, category, price, stock | n/a |
| `Equipment` → `equipment` | id, name, category, qty, status | n/a |
| `Announcement` → `announcements` | id, title, body, postedOn | `author` → User |
| `SubscriptionRequest` → `requests` | id, status, created | `member` → User, `plan` → Plan (CASCADE) |
| `Payment` → `payments` | id, amount, method, paidOn, note, currency, amountMinor, stripeReference (unique), receiptUrl | `member` → User (CASCADE) |
| `Measure` → `measures` | id, measuredOn, weight, bodyFat, note | `member` → User (CASCADE) |
| `Checkin` → `checkins` | id, checkinOn, note | `member` → User (CASCADE) |
| `ClassSession` → `classes` | id, day (`week_day`, 0 = Monday), time (`start_time`), title, spots | `coach` → User (SET NULL) |
| `DatedBooking` → `dated_bookings` | id, sessionDate, present, attendanceStatus (`pending`/`present`/`absent`), attendanceCheckinId, legacyBookingId; unique (user, class, date) | `user` → User, `classSession` → ClassSession (CASCADE) |
| `StripeOrder` → `stripe_orders` | id (text), memberId, planId, planName, duration, structuredDuration, subtotal, mode, sessionId, checkoutUrl, customerId, subscriptionId, status, currency, created | ids only, no foreign keys |
| `Booking` → `bookings` (**legacy**, kept as archive) | id, migrated; unique (user, class) | `user` → User, `classSession` → ClassSession (CASCADE) |
| `CoachClient` → `coach_clients` | id, status (`pending`/`active`/`declined`/`ended`), created, updated; unique pair | `coach`, `client` → User (CASCADE) |
| `Program` → `programs` | id, title, goal, notes, active, created | `client` → User (CASCADE), `coach` → User (SET NULL; null = personal program) |
| `Exercise` → `exercises` | id, day (`day_label`), name, sets, reps, load (`load_text`), rest, notes, position | `program` → Program (CASCADE) |
| `Workout` → `workouts` | id, doneOn, duration, rpe, notes, coachComment, submissionKey (unique), created; `sets` → `workout_sets` (`WorkoutSet`: exerciseId, exerciseName, setNumber, reps, weight) | `user` → User (CASCADE), `program` → Program (SET NULL) |
| `Notification` → `notifications` | id, title, body, seen, created | `user` → User |
| `PasswordReset` → `resets` | id, codeHash, expires, tries | `user` → User |
| `RetentionAlert` → `retention_alerts` | id, sentOn, score, source | `member` → User |

`Role` is an enum stored as text through `RoleConverter`.

**AI Coach adds no table.** The conversation lives only in app memory (`AiCoachChat`) for the current session, and the backend stores nothing.

---

## 10. API endpoints

Prefix `/api`, JSON in `snake_case`. Every route needs `Authorization: Bearer <token>` except the four public auth routes and the signed Stripe webhook.
- Creations return `201 {"id": …}`; actions return `200 {"ok": true}`.
- Lists accept `?limit=` (1–500), `?offset=` and often `?q=`.
- Errors look like `{"error": "...", "status": 400, "timestamp": "...", "fields": {...}}`.

| Area | Method + path | Purpose / access |
|---|---|---|
| Auth | `POST /signup`, `/login`, `/forgot`, `/reset` | Public, rate-limited (`RATE_LIMIT` per minute per IP and route) |
| Account | `GET /me` · `PUT /profile` · `POST /password` | Signed in |
| Members | `GET /members`, `GET /members/{id}`, `POST /members`, `PUT /members/{id}`, `POST /members/{id}/status`, `DELETE /members/{id}`, `POST /members/{id}/renew` · `GET /coaches` | Admin (coach: own clients); directory for anyone signed in |
| Subscriptions | `GET /requests` · `POST /requests` · `POST /requests/{id}/{approve\|reject\|cancel}` | Member / admin |
| Coaching | `GET /coaching/mine`, `/coaching/clients`, `/coaching?status=` · `POST /coaching/request`, `/coaching/assign`, `/coaching/{id}/{accept\|decline\|end}` | Per role |
| Programs | `GET/POST /programs`, `GET/PUT/DELETE /programs/{id}`, `POST /programs/{id}/exercises`, `PUT/DELETE /exercises/{id}` | Client, author coach, admin (read) |
| Workouts | `GET/POST /workouts`, `DELETE /workouts/{id}`, `POST /workouts/{id}/feedback` | Self; coach for their programs. `POST /workouts` also accepts `request_id` and `sets` |
| Classes | `GET /classes?week=`, `POST /classes`, `PUT/DELETE /classes/{id}`, `POST /book` `{class_id, session_date, booked}`, `GET /classes/{id}/participants?date=`, `POST /classes/{id}/present` `{member_id, session_date, attendance_status}` | Members book; admin or the class's coach manages |
| Online payments | `POST /payments/stripe/checkout` `{plan_id, request_id}`, `GET /payments/stripe/orders/{id}`, `POST …/orders/{id}/cancel`, `POST …/orders/{id}/reconcile`, `GET /payments/stripe/history`, `POST /payments/stripe/portal` | Member, own orders only |
| Stripe webhook | `POST /payments/stripe/webhook` | Public, signature required |
| Catalog | `GET/POST /plans\|promos\|products\|equipment\|announcements`, `PUT/DELETE …/{id}` | Read: signed in; write: admin (equipment: admin + coach; announcements: own for coach) |
| Member data | `GET/POST /payments\|measures\|checkins`, `PUT/DELETE …/{id}` | Role-scoped |
| Notifications | `GET /notifications` · `POST /notifications/{id}/read` · `POST /notifications/read-all` | Signed in |
| Stats | `GET /stats` | Admin (global), coach (scoped) |
| Churn risk | `GET /risk[?all=true]` · `POST /risk/{memberId}/remind` · `POST /risk/run` | Admin / coach; `run`: admin |
| **AI Coach** | `GET /ai-coach/status` | Signed in → `{"enabled": bool, "model": "…"}` (never the key) |
| **AI Coach** | `POST /ai-coach/chat` | Signed in. Request and response below |

**`POST /ai-coach/chat` request**

```json
{"messages": [{"role": "user", "content": "…"}], "workspace": "personal"}
```

- `messages`: 1–20 items, `role` is `user` or `assistant`, user messages ≤ 2 000 chars, the last message must be from the user.
- `workspace`: `personal` (default) or `coach`.

**Response:** `200 text/event-stream` with these events:
- `data: {"delta":"…"}` for each chunk
- then `data: {"done":true}` at the end, or `data: {"error":"…"}` if the stream fails midway.

**Errors before streaming** come back as JSON with these statuses:
- 400 validation
- 401 not signed in
- 429 per-user limit or OpenRouter rate limit
- 502 bad key, no credit, invalid model or upstream failure
- 503 no key configured
- 504 timeout

---

## 11. State management, authentication and error handling

**State (Flutter)**
- `StatefulWidget`s, plus static `ValueNotifier`s on `Api`:
  - `authChanged` rebuilds `MaterialApp`;
  - `workspace` switches the coach's workspace;
  - `unread` drives the notification badge.
- Lists stay as raw JSON maps; only the signed-in user is typed (`AppUser`).
- AI Coach follows the same pattern with a singleton `ChangeNotifier` (`AiCoachChat.instance`) read through `ListenableBuilder`-style listeners.

**Authentication**
1. `POST /login` returns a JWT (HS256; subject = user id, claim `tv` = token version; lifetime `TOKEN_DAYS`).
2. On every request, `JwtAuthFilter` re-checks the user in the database: the account exists, is active and has the same `token_version`. A password change, reset or deactivation increments the version, which cuts every existing session.
3. Passwords use bcrypt; legacy scrypt hashes are verified and upgraded at login.
4. Authorities: `ROLE_ADMIN`, `ROLE_COACH`, `ROLE_MEMBER`. Access is enforced with `@PreAuthorize` plus service-level ownership checks.
5. The app keeps the token in `flutter_secure_storage`; any 401 triggers `Api.logout()`.

**Error handling**
- Backend:
  - business errors throw `ApiException(status, French message)`;
  - `GlobalExceptionHandler` maps validation, JSON, type, access, integrity, 404/405 and unexpected errors to `ErrorResponse`;
  - 500s are logged server-side without details to the client.
- App: `Api.call` and `Api.postStream` turn network and timeout failures and server messages into `ApiException`. Screens show them through `AsyncBody`, snackbars or banners.
- Stripe errors become a 502 with a generic French message; only the Stripe code and request id are logged.
- AI Coach does its own mapping for upstream failures (§8), and its SSE errors become `ApiException` in the app, which `AiCoachChat` shows with a retry button.

---

## 12. The AI Coach feature

### Files added or changed

| File | Change | Why |
|---|---|---|
| `backend/.../config/AiCoachProperties.java` | new | Typed `ironfit.ai.*` settings; key never printed |
| `backend/.../ai/OpenRouterClient.java` | new | Server-side OpenRouter call, SSE parsing, timeouts, error mapping |
| `backend/.../ai/CoachPrompt.java` | new | Domain-specific system prompt (pure, testable); stable sections first |
| `backend/.../ai/KnowledgeBase.java` | new | Loads `knowledge/coach-knowledge.md`, reloads on change, 12 000-char cap, turns `À COMPLÉTER` lines into explicit "unknown" facts |
| `backend/knowledge/coach-knowledge.md` | new | Knowledge base: app how-to, house training guidelines and **fictional** gym details |
| `backend/.../dto/AiCoachDtos.java` | new | Validated request records and limits |
| `backend/.../service/AiCoachService.java`, `impl/AiCoachServiceImpl.java` | new | Builds the user's data context and the message list |
| `backend/.../controller/AiCoachController.java` | new | `/api/ai-coach/status` and `/chat` (SSE) |
| `backend/.../security/RateLimiter.java` | changed | Added a keyed `check(key, max, message)` for per-user limits; existing behaviour unchanged |
| `backend/src/main/resources/application.properties` | changed | `ironfit.ai.*` ← `OPENROUTER_*` / `AI_*` env vars |
| `backend/src/test/...` (`AiCoachApiTest`, `AiCoachDisabledApiTest`, `ai/CoachPromptTest`, `application-test.properties`) | new / changed | 21 tests (incl. `ai/KnowledgeBaseTest`) against a fake local OpenRouter; tests never read a real key |
| `backend/.env.example` | changed | OpenRouter variables; committed SMTP credentials replaced by placeholders |
| `app/lib/core/config/app_config.dart` | changed | AI Coach timeouts and limits |
| `app/lib/core/network/api_client.dart` | changed | `Api.postStream` for streamed responses |
| `app/lib/models/coach_message.dart` | new | Message model |
| `app/lib/services/ai_coach_service.dart` | new | Status, request, SSE parser |
| `app/lib/services/ai_coach_chat.dart` | new | Session conversation state |
| `app/lib/widgets/ai_coach.dart` | new | Floating button, side panel / bottom sheet, bubbles, typing indicator, banners |
| `app/lib/screens/home_shell.dart` | changed | AI Coach entry points (reworked for members by the merge) |
| `app/test/ai_coach_test.dart` | new | 14 tests (parser, client, state, widget flow, bold rendering) with mocked HTTP |
| `README.md` | changed | Setup (§9.1), env vars, routes, test counts |

AI Coach needed no new dependencies (the merged features did, see §2). The backend uses the JDK `HttpClient` and the existing Jackson; the app uses the existing `http` package.

### Request flow
1. **Opening the panel.** Every role uses the floating button at the bottom right of the main tabs. `openAiCoach` shows a 420 px side panel at ≥ 700 px and a 92 %-height bottom sheet below. The panel calls `GET /ai-coach/status`.
2. **Sending a message.** On send (button, suggestion chip, or Enter; Shift+Enter adds a new line), `AiCoachChat` appends the user message and goes to `waiting`, which shows the animated typing indicator.
3. **Request from the app.** `AiCoachService.reply` POSTs the last 20 messages plus `workspace` (`coach` when a coach is in "Espace coach") through `Api.postStream`, with the JWT and `Accept: text/event-stream, application/json`.
4. **Context building.** The backend authenticates, applies the per-user rate limit and validates the body. `AiCoachServiceImpl.prepare` then builds the facts for the current mode:
   - **Member mode:** subscription status and plan; active coach (first name + specialty); up to 3 active programs with up to 15 exercises each; the 8 latest workouts (duration, RPE, notes, coach comment); 28-day workout and check-in counts; days since the last workout; the 6 latest measurements; the next 10 dated bookings; plus **pre-computed summaries** (date range, average RPE, sessions at RPE 8+, average duration, weight and body-fat change), because small models miscount lists.
   - **Coach mode:** active clients, pending requests, active programs, sessions logged in the last 7 days, sessions awaiting comments, classes taught.
   - **Admin mode:** member, coach and subscription counts; subscriptions expiring within 7 days; coaching counts; workouts in the last 7 days; check-ins today; number of classes.

   Only the user's **first name** is sent, never the last name, e-mail, phone or login.

   For every mode, the prompt also gets the **knowledge base**:
   - **live gym data** from the database: plans with their own currency (EUR or TND), the weekly class schedule with capacity, current offers (100 % shown as "FREE"), and coaches with their specialties;
   - the text of **`backend/knowledge/coach-knowledge.md`**.

   A rule tells the model to answer gym questions only from these two sections and to say it doesn't know otherwise. Section order is rules → knowledge → gym data → user data, so the stable prefix can be cached by providers that support it.
5. **Calling OpenRouter.** `OpenRouterClient.stream` calls `{OPENROUTER_BASE_URL}/chat/completions` with `stream: true`, the server-side key, `reasoning: {enabled: false}` (unless `OPENROUTER_REASONING` says otherwise) and, when fallbacks are set, `models: [primary, …fallbacks]`. The controller relays each delta as SSE. A stream that ends with no text becomes an `error` event.
6. **Rendering.** The app parses the events. On the first delta the state becomes `streaming` and the reply bubble grows live. The user can **stop** a reply, **retry** after an error, **clear** the conversation, or close the panel with ✕, Esc or a barrier tap.
7. **Lifetime.** The history survives closing and reopening the panel and is cleared on logout or account change.

### Configuration
`OPENROUTER_API_KEY` (required to enable), `OPENROUTER_MODEL`, `OPENROUTER_FALLBACK_MODELS`, `OPENROUTER_REASONING`, `AI_KNOWLEDGE_FILE`, `OPENROUTER_BASE_URL`, `OPENROUTER_SITE_URL`, `OPENROUTER_APP_TITLE`, `AI_TIMEOUT_SECONDS`, `AI_MAX_DURATION_SECONDS`, `AI_MAX_TOKENS`, `AI_RATE_LIMIT`. Defaults are listed in §4.

Free setup tested in November 2026: `OPENROUTER_MODEL=nvidia/nemotron-3.5-lightning:free`, `OPENROUTER_FALLBACK_MODELS=nvidia/nemotron-3.5-super-vl:free,google/gemma-4-31b-it:free`. Free accounts get 50 requests per day.

### Protections
- The key exists only on the server and never appears in logs, `toString()` output or responses.
- Bean validation enforces ≤ 20 messages and a 2 000-character limit on user messages; the history is trimmed to 16 000 characters, on top of the existing 100 KB body limit.
- Per-user rate limit (`AI_RATE_LIMIT` per minute).
- Header timeout (`AI_TIMEOUT_SECONDS`) and maximum stream duration (`AI_MAX_DURATION_SECONDS`); the app adds a 45 s header timeout and a 60 s idle timeout.
- Upstream 401 is mapped to 502, so a bad server key never logs the user out.
- The system prompt contains safety rules (no medical advice, refer to professionals) and keeps the assistant in scope.

### Verification done on this branch
The manual, OpenRouter and MySQL checks below were made **before** the November merge. After it, the automated checks and a short AI Coach check were rerun (marked below); the new screens, Stripe and MySQL were not.
- **Automated (after the merge):**
  - backend: 107/107 tests;
  - app: 61/61 tests, web build OK, analyzer: 44 style notes, no warnings or errors.
- **Manual:**
  - The real backend ran on in-memory H2 with demo data and talked to a local mock OpenRouter; the Flutter web build was used in the browser as `youssef`.
  - Desktop side panel and phone bottom sheet, in light and dark mode: OK.
  - The streamed reply quoted the user's real program, last workout and subscription from the database.
  - Esc closes the panel; the upstream 429 shows a clear message with Retry.
  - This check found and fixed a bug: pre-stream errors returned 500 to clients that only accept `text/event-stream`. A regression test now covers it.
- **Real OpenRouter** (free-tier key, backend on H2):
  - With reasoning **on**, `nemotron-3.5-lightning:free` spent 3.7 s and its whole token budget thinking and returned no text. With reasoning **off**, the first word arrived in about 0.4 s.
  - The `gemma-4` free models were rate-limited upstream; the fallback chain answered with Nemotron in the same request.
  - Member questions were answered in French with the user's real data in 1–4 s.
  - Knowledge base: prices, schedule and offers were answered correctly from live data (1.7 s). Before the "unknown" marking, the model **invented** Sunday opening hours; after it, it said it didn't know and pointed to the front desk (0.8 s).
- **After the merge (23 November, real free model, backend on H2):** gym address, EUR price, Stripe test payment path and dated bookings were answered correctly. The model first got weekdays wrong, so the prompt now gives the weekday with today's date and each booking.
- **MySQL (XAMPP MariaDB 10.4):** on first start the backend created `ironfit_db` and loaded the demo data (5 accounts, 13 workouts, 7 measurements, 3 bookings, 3 programs with 11 exercises). AI Coach answered from it with the real free model. The progress summary's arithmetic was wrong until the server started sending pre-computed totals (weight −1.9 kg, body fat −1.3 points, average RPE 7.4, 3 hard sessions); after that the numbers were right.

### Limitations
- The conversation is not persisted: it is lost on reload, logout or app restart.
- Formatting: only `**bold**` and `#` headings are rendered (small models write them anyway); other markdown shows as text.
- Small free models can still omit or misread facts (one offer out of two was omitted in testing). A paid model such as `anthropic/claude-haiku-5.5` follows the rules more reliably.
- The knowledge base is sent whole with every request; past roughly 12 000 characters it would need retrieval (RAG) instead.
- The coach and admin modes see only aggregate numbers. By design, no other member's personal data is sent to OpenRouter, so a coach must describe a client in the chat.
- The member's own data (including free-text workout notes) **is** sent to OpenRouter. This should appear in the privacy notice before production.
- Each streaming reply holds one servlet thread for its duration (synchronous writer, no async dispatch). That is fine for a single gym, not for heavy load.
- Rate limits are in memory (single instance), like the existing auth limiter.
- The prompt is in English with French as the default reply language; the app UI is French only.
- The default model's availability and price depend on OpenRouter. Change it with `OPENROUTER_MODEL`.

---

## 13. Enhancements merged in November 2026

Source: `integration/ironfit-enhancements` (commits by lyna-ismil and AminOsbsd, 22 and 23 November 2026), merged twice without conflicts.

### 13.1 Dated bookings and attendance
- **Before:** one booking per member and weekly class. **Now:** one booking per member, class **and date** (`dated_bookings`).
- `GET /classes?week=YYYY-MM-DD` returns that week's occurrences with the places taken, whether the member booked, and the attendance status.
- **Booking rules:** from today to 90 days ahead; the date must match the class's weekday; the subscription must cover that date; not a class you teach; no place left gives 409. The class row is locked, so two members cannot take the last place.
- **Safe retries:** sending `booked: true/false` states the wanted result. If the answer is lost, `PlanningPage` blocks that class until the schedule is refreshed.
- **Cancelling** is refused once the class has started or attendance has been recorded.
- **Attendance:** the admin or the class's coach sets `present`, `absent` or `pending` once the class has started. `present` creates a check-in, going back removes it, and the member is notified.
- **Editing a class:** its day cannot change while it has bookings, and its capacity cannot go below existing future bookings.
- Dates use the `Africa/Tunis` time zone.

### 13.2 Memberships in euros
- Standard plans: Séance €10, Mensuel €60, Trimestriel €160, Annuel €550. These are approved prices, not conversions. New plans are in EUR; shop items stay in TND; old payments keep their currency.
- Plans have a structured duration (`DAY`/`MONTH` × count) and an access type (`PERIOD` or `DAY_PASS`).
- A renewal starts the day after the current end date; the end date is included. Revenue statistics are grouped by currency.
- **`MembershipPage`** ("Mon abonnement"): current plan, days left, requests at the front desk, online payments and all payments.

### 13.3 Online payments (Stripe, test mode)
```mermaid
sequenceDiagram
  participant M as Member (app)
  participant B as Backend
  participant S as Stripe (test)
  M->>B: POST /payments/stripe/checkout {plan_id, request_id}
  B->>S: Create customer + Checkout session
  S-->>B: Checkout URL
  B-->>M: order_id + URL
  M->>S: Pays on Stripe's hosted page
  S->>B: Signed webhook
  B->>B: Check signature, amount, currency, duplicates
  B->>B: Extend membership + record payment
  S-->>M: Back to the app (?payment_order=…)
  M->>B: GET order status (polling); reconcile if still pending
```
- The member chooses "À l'accueil" (front desk) or "Carte · Stripe test" in Explorer → Tarifs.
- **Protections:** only `sk_test_` keys and non-live events; hosted card page; signed webhook; amount and currency checks; `request_id` and a unique `stripeReference` prevent double charging and double activation; members see only their own orders; the app opens only known Stripe hosts.
- **One-time plans** are activated by the checkout webhook, or by *reconcile* if the webhook was missed. **Recurring plans** (configured per plan id) are activated and renewed only by `invoice.paid`.
- Cancelling a subscription or changing the card is done in Stripe's customer portal.

### 13.4 Guided workouts and progress
- A program has a "Démarrer / reprendre la séance guidée" button that opens `GuidedWorkoutPage`: one row per planned set, with real reps and weight, a rest timer (30/60/90/120 s) and a progress bar.
- The draft is saved on the device, so the workout can be resumed. Only validated sets are sent. `request_id` prevents a workout being recorded twice.
- The server checks that each exercise belongs to the program, and refuses duplicate sets.
- `TrainingProgress` shows sessions, detailed sets, volume (weight × reps) and the best weight per exercise over the workouts shown (30 at most).

### 13.5 Gym location and directions
- `GymLocationPage` (Profil → "Nous trouver") shows the gym on an OpenStreetMap map, searches a starting address or uses the device position **only when the user asks**, and draws a driving or walking route. A Google Maps link is available.
- Position is kept in memory only. Android now requests location permissions.
- The location can be set at build time with `--dart-define-from-file` (`GYM_LATITUDE`, `GYM_LONGITUDE`, `GYM_ADDRESS`, `GYM_NAME`, `GYM_DETAILS`).

### 13.6 Interface
- `LaunchSplash`: a 2.1 s animated introduction while the session loads, skipped when returning from Stripe, with a failure state if loading fails.
- **Member redesign** (second merge, commit `20f33f6`): members get their own orange, ivory and charcoal theme (`memberTheme`); coaches, admins and the sign-in screen keep theirs. New home banner, session cards and planning header with a date picker.
- **Mes réservations** has À venir / Passées / Annulées filters for the week shown. Cancelled bookings are deleted by the API, so that tab cannot list them.
- Tabs keep their state when switching. The floating AI Coach button, removed for members in the first merge, is back for every role.

### 13.7 Tests added
| Area | Tests |
|---|---|
| Stripe (`StripeRegressionTest` 17, `StripeWebhookTest` 13) | 30 |
| Dated bookings (`DatedBookingTest`) | 5 |
| Currency and memberships (`CurrencyMigrationTest` 1, `CurrencyTest` 1, `MembershipRulesTest` 3) | 5 |
| AI Coach with dated bookings | 1 |
| Flutter: splash, location routes, payments return, first package, planning, attendance, currency, AI Coach entry points, member redesign | 31 more than before (61 in total) |

Stripe tests use fixtures: no real Stripe payment was made as part of this merge check.

---

## 14. Known issues, technical debt and suggested improvements

**Security**
- **A Gmail SMTP address and app password were committed in `backend/.env.example`.** This branch replaces them with placeholders, but they remain in git history and must be **revoked/rotated**. README §18 already notes that older commits contain an old SQLite database and a since-regenerated key; purge the history (`git filter-repo`) if the repository is shared.
- Demo defaults are unsafe for production: `ADMIN_PASSWORD=admin123`, `SEED_DEMO=true`, `SHOW_RESET_CODE=true` (the reset code is returned to the client), `CORS_ORIGINS=*`, and Android `usesCleartextTraffic`.

**Infrastructure and operations**
- The schema is managed by `ddl-auto=update`, with no versioned migrations (README: Flyway was skipped because of MariaDB 10.4).
- Rate limiting is in memory, so it does not work across instances.
- No CI, containerisation or deployment scripts: **Not determined from code** how production is deployed.

**Code quality and tests**
- The README is partly stale: it states "31 tests" for the backend, while the base branch already had 45 (107 now).
- Flutter lists are untyped JSON maps; only `AppUser` is a typed model.
- `test/backend_integration_test.dart` needs a running backend; the `integration` tag description in `dart_test.yaml` still mentions the old Node server.

**Found while reviewing the November merge**
- **Fixed:** `coach-knowledge.md` now gives the map's address (Cebalat Ben Ammar) and describes Stripe test payment and dated bookings; the prompt points to "Mon abonnement" instead of the removed "Mes paiements". The address is written in two places (`gym_location.dart` and the knowledge file), so change both together.
- **AI Coach does not see guided-workout details:** its prompt does not include the recorded sets.
- **Currency on admin screens:** the subscription request and renewal dialogs call `money()` without a currency, so a plan still in TND would be shown in euros.
- **Plan prices rewritten at startup:** any TND plan named Séance, Mensuel, Trimestriel or Annuel is set to the fixed EUR price, even if the gym had changed its price.
- **Logo unreadable on the member home in light mode:** the transparent logo's white lettering sits on a light background, so only the mountain shows.
- The floating AI Coach button can cover content near the bottom right, such as the "Planning" link on the phone home.
- The demo video shows the member screens as they were before the redesign.
- Unused code: `StripeDtos` and three Stripe settings (§4). `StripeCheckoutService` is dense and duplicates the membership-activation code in `reconcile` and `webhook`.
- `ClassServiceImpl.update` loads every booking to check capacity, which will slow down as bookings grow.
- `app/lib` calls public OpenStreetMap servers directly; their usage policies make them unsuitable for heavy production use.
- `app/android/build/reports/problems/problems-report.html` is a build output that was committed.

**Product limits** (README §19 and code)
- Class templates are weekly; bookings are dated, but there is no calendar for holidays or exceptions.
- No push notifications. Online payments work in Stripe **test mode only**.
- French-only UI.

**Suggested next steps**
1. Rotate the leaked SMTP credential.
2. Add Flyway once on MySQL 8+.
3. Add CI running `./mvnw test` and `flutter analyze && flutter test`.
4. Add the front-desk phone number to `coach-knowledge.md` (marked `À COMPLÉTER`).
5. For AI Coach: persist conversations (opt-in), render basic markdown, add per-client context for coaches behind explicit consent, add a user-facing privacy notice, and move streaming to async (`SseEmitter`) if load grows.
