# IronFit v2 – Flutter app audit (October 2026)

Scope: the Flutter client in `app/` on top of `feature/v2-roles-coaching-security`. The Node backend (`backend/`) was only reviewed where the client depends on it. Its 30 `node:test` tests pass and it is otherwise out of scope.

## Baseline (v2 as received)

| Check | Result |
|---|---|
| `flutter pub get` | OK (Flutter 3.47.7 / Dart 3.13.5). Direct dependencies up to date, 4 transitive packages behind |
| `flutter analyze` | **No issues** with the default `flutter_lints` rules. 21 hard-coded `Colors.*`, `dynamic` casts everywhere, no stricter rules |
| `flutter test` | **16 tests pass** (API client, navigation per role, login screen, sign-up validation, integration test against the real Node server) |
| `npm test` (backend) | 30 tests pass |
| Repository hygiene | `backend/data/` (DB and signing secret) is not tracked, and the token is in secure storage. Already good |

v2 is a solid base. Most of the findings below are about consistency, accessibility and maintainability, plus a handful of real bugs.

## 1. Code review

| # | Where | Issue | Severity |
|---|---|---|---|
| 1 | `planning_screen.dart` (participants), `coach_screens.dart` (clients), `coaches_screen.dart` (directory) | `'${name}'[0]` throws `RangeError` when a name is empty, which crashes the whole screen | 🟠 Major |
| 2 | `member_screens.dart` `memberCard` | `DateTime.parse(sub_end)` throws on a malformed date. The "days left" count subtracts `DateTime.now()` (with time of day), so it can be off by one | 🟠 Major |
| 3 | `notifications_screen.dart` `read()` | `setState` after an `await` without a `mounted` check. Leaving the page while the request runs throws | 🟠 Major |
| 4 | `form_dialog.dart` date field | `showDatePicker(lastDate: now)` with an `initialDate` taken from the field. An existing future date trips the framework assertion `initialDate <= lastDate` | 🟡 Minor |
| 5 | `home_shell.dart` profile dialogs, `auth_screen.dart` `serverDialog` | `TextEditingController`s created per dialog are never disposed | 🟡 Minor |
| 6 | `Refs.load`, `AdminHome.load`, `CoachHome.load`, `CoachesTab.load` | Independent requests are awaited one after another, so screen load time is the sum of the latencies | 🟡 Minor (perf) |
| 7 | `Api.setBase` | An address typed without a scheme (`192.168.1.5:3000`) produces an invalid URI on every call | 🟡 Minor |
| 8 | `BarsPainter`/`LinePainter` | `shouldRepaint` always returns `true` | 🟢 Minor (perf) |
| 9 | `admin_screens.dart`, `coach_screens.dart` | Method named `L(...)` (`non_constant_identifier_names` in spirit) | 🟢 Style |

## 2. Technical debt (prioritised)

Priority = (Impact + Risk) × (6 − Effort)

| Item | Type | I | R | E | Priority |
|---|---|---|---|---|---|
| The same `loading / error / load()` state machine is hand-written in 18 screens, with small differences (some reset `loading` on refresh, some don't) | Code | 4 | 3 | 2 | **28** |
| Theme scattered: 21 raw `Colors.*`, ad-hoc paddings (10/12/14/16/18/28) and font sizes (11/12/22), bold applied case by case | Code | 3 | 2 | 2 | 20 |
| Duplicated helpers: two booking buttons (`bookAction` and `PlanningPage.book`), `dayLabel` re-declaring the day list, two-digit date padding re-implemented in 4 places, four avatar-initial implementations | Code | 3 | 2 | 2 | 20 |
| Layer-first folders. `member_screens.dart` (474 lines) and `program_screens.dart` (408) each hold 5+ screens. `home_shell.dart` mixes navigation, the coach switch, the admin grid and the profile | Architecture | 3 | 2 | 3 | 15 |
| Default lint set only, and `dynamic` everywhere (`as int` casts on JSON) | Code | 2 | 3 | 2 | 20 |
| No unit tests for date and subscription logic, the module catalogue invariants or form validation | Test | 3 | 3 | 2 | 24 |
| README describes the old `screens/` layout once the code moves | Docs | 1 | 1 | 1 | 10 |

## 3. Architecture

**Current:** `services/`, `models/`, `widgets/`, `screens/`. The dependency rule (no screen imported by a service or model) is respected. However, `models/module.dart` builds widgets (`bookAction`, `disabledBadge`, `accountMenu`), and screen files are grouped by role rather than by feature, so the coaching feature is spread across 4 files.

### ADR-001: Feature-first folders, a shared async-state mixin, no new state library

**Status:** Accepted · **Date:** 2026-10-19

**Context.** About 25 screens, all with screen-local state. The cross-screen state (session, coach workspace, unread count) is already well handled by three `ValueNotifier`s on `Api`. The team is small and the project is a teaching/demo app.

| | A. Feature folders + `AsyncLoadMixin` (no new dependency) | B. Feature folders + Riverpod | C. BLoC |
|---|---|---|---|
| Complexity | Low | Medium | High |
| New dependencies | 0 | 1 | 2 |
| Rewrite risk | Low (same widgets, same `setState`) | Every screen rewritten | Every screen rewritten, plus events and states |
| Testability | Good (`Api.client` is injectable and `MockClient` tests exist) | Very good | Very good |

**Decision.** Option A. `core/` holds what is shared (API client and token store, theme, utils, generic widgets). `features/<name>/` holds the screens and logic of one feature. Every screen that loads data uses `AsyncLoadMixin` (`fetch()` / `reload()` / `loading` / `error` / `data`) and renders with `AsyncStateView`. The three existing `ValueNotifier`s stay as they are.

**Consequences.** Every data screen behaves identically on load, refresh, error and retry. Moving to Riverpod later is a per-feature change, because `fetch()` maps directly onto a `FutureProvider`.

```
lib/
├─ main.dart, app.dart
├─ core/
│  ├─ api/        api.dart (Api, ApiException, Workspace), token_store.dart, refs.dart
│  ├─ theme/      app_theme.dart, app_colors.dart (ThemeExtension), spacing.dart
│  ├─ utils/      dates.dart, values.dart
│  └─ widgets/    async_view.dart, empty_state.dart, kpi.dart, charts.dart, feedback.dart, form_dialog.dart
└─ features/
   ├─ auth/           auth_page.dart, server_dialog.dart
   ├─ shell/          home_shell.dart, workspace_switch.dart, modules_grid.dart, notification_bell.dart
   ├─ crud/           module.dart, module_catalogue.dart, crud_page.dart, form_sheet.dart
   ├─ planning/       planning_page.dart, participants_page.dart, booking.dart
   ├─ member/         member_home_page.dart, explore_page.dart, my_space_page.dart, progress.dart, attendance_page.dart, subscription.dart
   ├─ coaching/       coaches_tab.dart, my_coaches_page.dart
   ├─ programs/       program_list.dart, program_detail_page.dart, workouts.dart
   ├─ coach/          coach_home_page.dart, clients_page.dart, client_detail_page.dart
   ├─ admin/          admin_home_page.dart, requests_page.dart, coaching_admin_page.dart
   ├─ notifications/  notifications_page.dart
   └─ profile/        profile_page.dart
```

## 4. Accessibility (WCAG 2.1 AA)

| # | Issue | Criterion | Severity | Fix |
|---|---|---|---|---|
| 1 | Member card: `white70` 12 px text on a `primary → tertiary` gradient. The tertiary end of the generated scheme is light (~2.3:1) | 1.4.3 | 🔴 | Fixed dark brand gradient with ≥ 5:1 contrast for white text |
| 2 | Success, warning and danger rendered with `Colors.green/orange/red` (green on white is 2.8:1, orange 2.2:1). Inactive promo avatar is white on grey (2.4:1) | 1.4.3 / 1.4.11 | 🔴 | Semantic `AppColors` (success/warning/danger) at ≥ 4.5:1 in light and dark |
| 3 | Icon-only buttons without a tooltip: planning refresh, client-detail ⋮ menu, program ⋮ menu, CRUD row ⋮ menus | 4.1.2 | 🟠 | Tooltip on every icon-only button |
| 4 | Revenue and weight charts are `CustomPaint` with no semantics | 1.1.1 | 🟠 | `Semantics(label:)` with a text summary |
| 5 | KPI cards read as icon + number + label fragments. Day chips read as "Lun •  3" | 1.3.1 | 🟡 | One merged label per card or chip ("Membres : 12", "Lundi, aujourd'hui, 3 cours") |
| 6 | Fixed heights clip at 1.5–2× text: KPI grid `mainAxisExtent: 132`, day-chip strip `56`, status-filter strip `56`, three `kpiCard`s in a `Row`, modules grid `childAspectRatio` | 1.4.4 | 🟠 | Heights derived from `MediaQuery.textScalerOf` |
| 7 | Form and dialog errors are plain red text that screen readers do not announce | 3.3.1 | 🟡 | `Semantics(liveRegion: true)` |
| 8 | Section titles are not marked as headings | 1.3.1 | 🟡 | `Semantics(header: true)` |
| 9 | Unread notifications are distinguished by colour and weight only | 1.4.1 | 🟡 | "Non lue" in the semantics label |
| 10 | Tap targets: Material defaults (≥ 48 dp) | 2.5.5 | ✅ | — |

## 5. Visual design

The base is Material 3 from a seed, but each screen adds its own styling: three card paddings, four font sizes, bold applied with `copyWith`, a mix of outlined (`border: OutlineInputBorder()`) and underlined inputs, and a member card whose colours change with the generated scheme.

**Direction:** one IronFit theme. The brand orange `#EA580C` is the seed. The member card uses a fixed dark-orange gradient (`#9A3412 → #C2410C`) and a slate gradient when inactive. An `AppColors` ThemeExtension holds the status colours. Cards have no elevation, a 16 px radius and a subtle outline. All inputs are filled and outlined. Buttons share a 48 dp minimum height and a stadium shape. The text theme sets the weights once, and spacing follows a 4-pt scale (`Gaps`).

## 6. Testing strategy

**Existing (kept):** API client, role navigation, login and sign-up widgets, integration against the real Node server (tagged `integration`, skipped if Node is missing).

**Gaps and plan:**

| Area | Type | Cases |
|---|---|---|
| `core/utils` | Unit | ISO dates, `dayLabel`/`daysAhead` wrap-around, month labels, tolerant parsing, initials, local timestamps |
| `SubscriptionStatus` | Unit | none / active / ends today / expired / malformed |
| Module catalogue | Unit | unique ids, valid roles, select fields have options or a ref, titles tolerate empty rows |
| Form validation | Unit | `validateField`, `buildBody` (trim, decimal comma, hidden fields, empty password) |
| Core widgets | Widget | KPI merged semantics, no overflow at 2×, chart labels, live region, async load → error → retry |
| Screens | Widget | Empty-name regressions (participants, clients, coaches), notifications leave-while-loading, planning booking, CRUD search and validation |

Target: `core/` ≥ 80 % line coverage. Every bug fixed above gets a regression test.
