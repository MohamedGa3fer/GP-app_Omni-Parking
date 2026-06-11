# CLAUDE.md — Project Context & Continuation Guide

**Project:** Offline-First Flutter Garage Management App with On-Device License Plate OCR
**Last Updated:** 2026-06-08
**Status:** Working end-to-end. Float32 OCR model on a **background isolate** (no UI freeze). **User-defined garage** (custom zones/slots) replaces the old hard-coded layout. UI polished: custom bottom bar with a center-docked Scan button, split plate-entry fields, theme-aware sheets.

---

## 1. Project Overview

A Flutter app for managing a parking garage with local SQLite persistence and fully on-device AI. No internet required.

- **User-defined garage:** On first run the user builds their own garage — any number of named **zones**, each with its own slot count — and can edit it anytime. (Replaces the old fixed 60-spot / 2-floor layout.)
- **Check-in / Check-out:** Camera captures the plate → YOLO detects → OCR reads → user verifies → picks a zone → transaction created/closed.
- **On-device AI:** YOLOv8 plate detection + PlateSlotTransformer OCR (both TFLite), running on a **background isolate**. Zero network calls.
- **Fee calculation:** Parking duration → fee. Configurable hourly rate (default 10 EGP), 1-hour minimum.
- **Egyptian plates:** 3–4 digits + 2–3 Arabic letters, custom training data.
- **Bilingual UI:** English + Arabic with full RTL support, dark/light themes, persisted via `SharedPreferences`.

---

## 2. Architecture (Feature-First Clean Architecture)

Single presentation folder under `lib/features/parking/presentation/`.

```
lib/
├── main.dart                          Entry; loads locale/theme, pre-loads models (isolate), providers.
│                                      Wraps init in try/catch → _InitErrorApp on failure (no white-screen).
├── core/
│   ├── l10n/app_translations.dart     LocaleService, ThemeService, AppColors, AppTranslations (EN+AR),
│   │                                  tr() + top-level helpers displayPlate(), isSameDay()
│   └── theme/app_theme.dart           dark/lightTheme (Plus Jakarta Sans). NoSplash ink, floating snackbars,
│                                      theme-aware dialog/bottomSheet backgrounds
├── data/
│   ├── models/
│   │   ├── parking_spot_model.dart    ParkingSpot (spotId, zoneId, spotNumber, isOccupied)
│   │   └── transaction_model.dart     Transaction (UUID PK, ISO8601 timestamps, status, fee)
│   └── dataproviders/
│       ├── local_db_helper.dart       SQLite singleton (v2): zones + parking_spots + transactions; garage config
│       └── on_device_ai_helper.dart   Facade → background isolate running _OcrEngine (YOLO + OCR)
├── features/parking/
│   ├── domain/
│   │   ├── entities/                  ParkingSession, Zone, ZoneConfig, GarageSettings, PlateResult
│   │   ├── repositories/parking_repository.dart   Abstract interface + CheckInResult & GarageConfigResult enums
│   │   └── usecases/                  check_in, check_out, get_active_sessions, get_zones (thin, mostly unused)
│   ├── data/repositories/
│   │   └── parking_repository_impl.dart  ADAPTER over LocalDbHelper + OnDeviceAiHelper
│   └── presentation/
│       ├── providers/parking_provider.dart   ChangeNotifier holding ParkingState
│       └── screens/                   splash, dashboard, garage_config, scanner, camera_capture,
│                                      plate_verification_sheet, zone_selection, ticket,
│                                      checkout, history, manual_entry, settings
└── shared/widgets/                    Reusable widgets actually used by the screens:
                                       app_card.dart (AppCard), icon_badge.dart (IconBadge),
                                       status_pill.dart (StatusPill), plate_input_fields.dart (PlateInputFields)
```

### The integration seam: `ParkingRepositoryImpl`

The UI codes against the abstract `ParkingRepository`; the impl backs it with our real SQLite + AI.

- **`initialize()`** — spawns the OCR worker isolate and loads both models once at startup (from `main.dart`).
- **Session ID mapping** — UI uses `int` session IDs; transactions use UUID strings keyed by plate. `_idToPlate` maps `plateNumber.hashCode.abs()` → plate so `checkOut(int)` resolves the right transaction. Repopulated on every `getActiveSessions()`.
- **Transaction ↔ ParkingSession** — `_toSession(t, {zoneName})` converts our `Transaction` to the `ParkingSession` entity. **`zoneId` is set to the zone's human NAME** (resolved via `_db.spotZoneNames()`), not the spot id; `durationHours` is derived from the timestamps.
- **Zones** — `getZones()` reads the real `zones` table (id, name, capacity, occupancy). No more `F1`/`F2` hardcode.
- **Hourly rate** — `SharedPreferences` key `hourly_rate` (default 10.0). `getGarageSettings().totalCapacity` = sum of all zone capacities (live from DB).

---

## 3. End-to-End Flows

### Check-In (camera path)
1. **Dashboard** → tap the **center Scan-Plate button** (the docked FAB) → bottom sheet → **Auto Scan**.
2. **ScannerScreen** → **Open Camera** → pushes **CameraCaptureScreen**.
3. **CameraCaptureScreen** (camerawesome) → frame plate → capture → shows a "Processing…" overlay → returns the JPG path.
4. ScannerScreen runs `OnDeviceAiHelper().recognizePlate(path)` (off the UI thread, on the isolate) → a `PlateRecognition {text, confidence, isLowConfidence}`. The temp JPG is **deleted** afterward (no cache leak).
5. **PlateVerificationSheet** — **two separate fields**: Numbers (LTR, digits, max 4) + Letters (RTL, Arabic, space-separated, max 3), via the shared `PlateInputFields`. Shows a banner: green "Plate Detected", **amber "Not sure"** when low-confidence (with a **Try Again** button that re-opens the camera), or orange "Duplicate". A **Try Again** button is always present (amber when low-confidence, blue otherwise).
6. **ZoneSelectionScreen** → user picks a zone → `provider.checkIn(plate, zoneId)` → `ParkingRepositoryImpl.checkIn()` returns a **`CheckInResult`** (`success` / `duplicate` / `garageFull` / `error`). Assigns the **first free spot within the chosen zone** (`getFirstAvailableSpotInZone`). Zone selection now genuinely matters.
7. **TicketScreen** → entry ticket (plate via `displayPlate`, zone name, entry time, QR).

> Manual entry (Dashboard → Scan sheet → Enter Manually → `ManualEntryScreen`) uses the **same `PlateInputFields`** split fields, then goes straight to zone selection (duplicate guard runs at check-in).

### Check-Out
1. **Check-Out tab** → active sessions, searchable by plate (spaces stripped on both sides).
2. Tap a session → expands → **Confirm Checkout** (live fee).
3. `provider.checkOut(sessionId)` → fee = `max(1.0, durationHours) * hourlyRate`; marks `Completed`, frees the spot, and refreshes both active **and completed** sessions.

### History
- **History tab** — **Today** / **All** tabs. Loads completed sessions in `initState` (`loadCompletedSessions`). "Today" = entered today **or** checked out today. Summary card shows **completed-only** metrics: count, revenue (sum of fees), avg duration.

---

## 4. On-Device AI Pipeline (`on_device_ai_helper.dart`)

**Runs entirely on a background isolate** so the UI never freezes during recognition.

### Architecture (facade + worker)
- **`OnDeviceAiHelper`** (public singleton facade) — `loadModel()` reads the two `.tflite` asset byte buffers via `rootBundle`, spawns the worker isolate, and hands it the bytes; `recognizePlate(path)` sends the image path and awaits the result; `close()` shuts the worker down. Message protocol = small `_InitMessage` / `_ReadyMessage` / `_RecognizeRequest` / `_ErrorReply` classes.
- **`_OcrEngine`** (runs inside the isolate) — owns the two `Interpreter`s (created via `Interpreter.fromBuffer` + `allocateTensors`), and holds the entire pipeline (decode → preprocess → both inferences → decode). Public API (`recognizePlate`, `loadModel`, `close`, the `PlateRecognition` result type) is unchanged, so the rest of the app didn't change.

### Stage 1 — Detection (YOLOv8)
- Input `[1,640,640,3]` float32, `px/255 → [0,1]`, YOLO letterbox (gray 114 pad). Built as a **flat `Float32List`** from the canvas's raw RGB bytes (`getBytes`), written straight to the input tensor (`inputTensor.data = …`) — no nested lists / no per-pixel `getPixel` (low allocation/GC on weak devices).
- Output `[1,5,8400]` read as a flat `Float32List`. Best box above **`_confidenceThreshold = 0.40`** is cropped. (Was `0.005`, which falsely "detected" plates in doors/screens/walls — raised so junk scenes are rejected.)

### Stage 2 — OCR (PlateSlotTransformer)
- Input `[1,3,96,320]`, ImageNet norm `(px/255-0.5)/0.5 → [-1,1]`. **Dtype auto-detected** (`_ocrIsFloat32`):
  - **float32** (current model): flat `Float32List` (NCHW, transposed from raw HWC bytes), tensor-data API, outputs read as flat float lists.
  - **int8** (fallback): quantized input + dequantized outputs via the tensor's scale/zeroPoint, through `runForMultipleInputs`.
- Four heads mapped by **shape + tensor name** in `_validateAndMapOcr()`: `[1,4,11]` digits, `[1,3,19]` letters, two `[1,2]` length heads (digit→3/4, letter→2/3).
- **Decoder canonical form = `digits + letters`, with letters REVERSED to physical right-to-left plate order** (e.g. model slots ع‑ج‑م → stored `…مجع`). Done once at the source so the DB and every screen are consistent.
- **`recognizePlate()` returns a `PlateRecognition {text, confidence, isLowConfidence}` — it does NOT throw on low confidence.** `isLowConfidence` = below `_minOcrConfidence = 0.60` **or** fails the format-validity check. It only throws on a genuine dead-end ("No plate detected", "empty OCR output", decode failure, models not loaded). Low-confidence reads flow into the verification sheet for the user to correct.

### Plate display formatting (UI)
- Canonical/DB form is the compact `digits+letters` (letters already in RTL order, e.g. `3269مجع`).
- **`displayPlate(canonical)`** (top-level in `app_translations.dart`) renders it as digits + **space-separated** letters (Arabic letters must be spaced or they join into a cursive word): `3269مجع` → `3269 م ج ع`. Used by every read-only plate display. (The old `_formatPlate` is gone.)

### Known model limitations (confirmed on device)
- **Digit count locked to 3–4** (length head can't emit 1–2). A 1-digit plate `١` reads as `111` — model/training limitation, not a capture issue.
- **2-letter plates are supported** (letter head does 2 or 3).
- Small/distant plates degrade (low-res crop → length heads fail first).

---

## 5. OCR Model History (Why the model is what it is)

- **Original** int8 model (exported `PyTorch → ONNX → SavedModel → TFLite`) contained stateful `RESOURCE_VARIABLE` tensors → `Input tensor 91 lacks data` crash. `tflite_flutter 0.12.1`'s `resetVariableTensors()` is broken → not workaroundable from Dart.
- A **teammate's int8 replacement** (same export chain) reproduced the exact `tensor 91` crash → confirmed the export chain, not our code.
- **Fix:** re-exported the trained PlateSlotTransformer with **`litert-torch`** (Google's official PyTorch→TFLite converter; renamed from `ai-edge-torch`). Weights inline as constants — zero resource-variable ops.
  - Gotcha: move the model to **CPU** before `litert_torch.convert(...)` or tracing fails with `FakeTensor Device Propagation ... cpu vs cuda:0`.
  - Final model: **float32, ~30.2 MB**, input `[1,3,96,320]`, four named outputs. Verified in Python: no resource-variable ops, correct shapes, successful inference.
- **Validated on device (CPH2811):** YOLO ~0.89–0.91, OCR reads like `7894سوم` at ~0.98.

> Training metrics (locked test, 1616 samples): **90.66% exact match, CER 0.0204.** Known systematic error: digit order occasionally reversed (RTL labeling ambiguity). See `Model_Report.md` for the full model situation + action plan.

---

## 6. Camera Screen (`camera_capture_screen.dart`)

`camerawesome ^2.0.0`, built with `CameraAwesomeBuilder.awesome(...)`:
- **Guide frame** — centered 3:1 box (`AppColors.primary`) + bilingual hint pill (`align_plate_hint`).
- **Top bar** — RTL-aware back button + **flash popup menu** (`_FlashMenuButton`: Off/On/Auto/Torch with a checkmark, via `state.when(onPhotoMode: (s) => s.sensorConfig.setFlashMode(...))`).
- **Zoom bar** (`_ZoomBar`) — chips 1x/1.5x/2x/3x (forced `TextDirection.ltr`), mapped to camerawesome's 0–1 range.
- **Capture** — flips a `ValueNotifier` to show a **"Processing…" overlay** instantly, `takePhoto()` to a `path_provider` temp path, ~400 ms flush, then `Navigator.pop(path)`.

---

## 7. Settings Screen (`settings_screen.dart`)

Sections (no back arrow — it's a bottom-nav tab):
- **General** — Language (EN/AR sheet, key `language`), Dark Mode (switch, key `dark_mode`).
- **Garage** — **Manage Zones** → opens `GarageConfigScreen` (edit the garage layout); **Hourly Rate** (numeric dialog, key `hourly_rate`); **Clean History** (sheet: Never / 7 / 30 / 90 days, key `clean_history_days`; runs `deleteOldCompletedTransactions` immediately).
- **App** — Notifications (placeholder), About (version dialog).

All sheets/dialogs are **theme-aware** (background from `dialogTheme`/`bottomSheetTheme`, text via `AppColors.textPrimary(isDark)`) — they render correctly in light mode now.

---

## 8. Navigation & Dashboard

`DashboardScreen` (`_DashboardScreenState`) hosts a **custom bottom bar** (not Material `NavigationBar`):
- 4 tabs — **Dashboard / Check-Out / History / Settings** — swapped via `_selectedIndex` (no nested Navigator). **Labels show only on the selected tab** (icon-only otherwise; label height reserved so icons don't shift). Rounded top corners.
- A **center-docked circular "Scan Plate" button** (the Scaffold's `floatingActionButton` at `centerDocked`) — gradient circle with a label, protrudes above the bar, opens the Car-Entry sheet. (FAB slot is used so the whole circle is tappable.)

`_DashboardBody` (tab 0):
- Gradient header, display-only search bar, stat cards: **Cars** (active count), **Available** (totalCapacity − active), **Revenue** (**today's collected** = sum of completed fees with `exitTime` today).
- **Recent Activity** — active + completed merged, newest first (by `exitTime ?? entryTime`), capped at **10**, each card shows an **Active/Completed** status pill. **Show All** switches to the History tab (via an `onShowAll` callback).
- **First-run prompt** — when `provider.state.zones.isEmpty`, a centered overlay card ("Set up your garage" + button) opens `GarageConfigScreen`. (There is **no** forced full-screen first-run gate — the splash always goes to the dashboard.)

Sub-flows (scanner, camera, verification, zone, ticket, manual entry, garage config) are pushed as routes.

---

## 9. Garage Configuration (user-defined zones)

The core of the "build your own garage" feature.

- **`GarageConfigScreen`** (`garage_config_screen.dart`) — one screen (param `isFirstRun`, currently always reached as edit mode). Editable list of zones (name field + slot **stepper**, tap the number to type a value; remove button), an **Add Zone** button, a footer with total zones/slots and **Save**. Renders immediately; existing zones load in the background (never gates the whole screen on the query).
  - Reached from: the dashboard first-run prompt, and **Settings → Garage → Manage Zones**.
- **`ZoneConfig`** entity = `{String? zoneId, String name, int capacity}` (zoneId null = new zone).
- **`GarageConfigResult {status, blockedZoneName}`** with `GarageConfigStatus { success, needAtLeastOneZone, zoneHasParkedCars, error }`.
- **Block & warn:** you cannot shrink a zone below its occupied count or delete a zone that still has parked cars — `applyGarageConfig` validates first and returns `zoneHasParkedCars` naming the offending zone. Only **free** spots are ever deleted.

---

## 10. Database Schema (`local_db_helper.dart`)

SQLite singleton, `garage.db`, **version 2**.

**`zones`** — `zone_id` TEXT PK (generated `z{ms}_{seq}`), `name` TEXT, `sort_order` INT.
**`parking_spots`** — `spot_id` TEXT PK (`"{zone_id}-{n}"`, **stable**), `zone_id` TEXT (FK→zones), `spot_number` INT, `is_occupied` INT.
**`transactions`** — `id` TEXT PK (UUID), `plate_number`, `check_in_time`, `check_out_time`, `spot_assigned` TEXT (FK→parking_spots), `total_fee` REAL, `is_synced` INT, `status` (`'Active'`/`'Completed'`).

- **`onCreate` seeds nothing** (no forced default garage — the user builds it).
- **`onUpgrade` (v1→v2) drops & recreates all tables empty** — wipes pre-release data on upgrade. Spot ids stay stable across edits (zone renames don't touch spot ids), so active `transactions.spot_assigned` FKs never break.

Key methods:
- Garage config: `isGarageConfigured()`, `getZoneStats()`, `getGarageConfig()`, `applyGarageConfig(List<ZoneConfigRow>)` (diff in one transaction), `totalCapacity()`, `spotZoneNames()` (spotId→zone name).
- Spots: `getAllParkingSpots()` (ordered by zone sort then spot number), `getFirstAvailableSpotInZone(zoneId)`, `updateSpotStatus()`.
- Transactions: `insert/completeTransaction`, `getActive/CompletedTransactions`, `getActiveTransactionByPlate`, `deleteOldCompletedTransactions(days)`, `resetAll()`.

> **Schema changes require uninstall (or `flutter clean` + reinstall)** — the v1→v2 `onUpgrade` wipes data; there's no real migration.

---

## 11. Error Handling Conventions

- **Programmer/contract errors fail fast** (throw): OCR tensor/shape mismatches (`_validateAndMapOcr`), models-not-loaded, no-plate-detected.
- **Expected business outcomes are typed values, not exceptions**: `CheckInResult` (duplicate / garageFull / …), `GarageConfigResult`. The UI shows the precise reason.
- **Startup is graceful**: `main()` wraps init in try/catch → `_InitErrorApp` ("Failed to start") instead of a white screen.
- **Provider load errors are logged + surfaced**: `debugPrint` in every catch; the dashboard shows a red error banner when `state.error != null`.
- Low-confidence OCR is **soft** (flows to the verification sheet), by design.

---

## 12. Dependencies (`pubspec.yaml`)

`flutter_localizations` (SDK), `google_fonts: ^6.2.1`, `intl: ^0.20.2`, `shared_preferences: ^2.2.2`, `qr_flutter: ^4.1.0`, `camerawesome: ^2.0.0` (replaced `camera`), `path_provider: ^2.1.0`. Retained: `sqflite`, `path`, `uuid`, `tflite_flutter: ^0.12.1`, `image: ^4.3.0`, `provider`, `image_picker`, `cupertino_icons`.

Assets: `assets/plate_detection.tflite` (~40 MB), `assets/plate_ocr.tflite` (float32, ~30 MB).

---

## 13. Translations & Theme conventions (`app_translations.dart`, `app_theme.dart`)

- All strings in `AppTranslations._translations` (`'en'` + `'ar'`), via `tr(context, 'key')`. **Add new keys to BOTH maps.** Watch for **duplicate keys** (analyzer warns) — several keys like `zones`, `hourly_rate` already exist.
- Top-level helpers in `app_translations.dart`: `displayPlate(canonical)`, `isSameDay(a, b)`.
- `AppColors`: primary `#2563EB`, secondary `#06B6D4`, success `#10B981`; `primaryPink`/`primaryPurple` alias primary/secondary; helpers `background/surface/textPrimary/textSecondaryColor(isDark)`.
- **Read dark mode via `Theme.of(context).brightness == Brightness.dark`** (standardized; `ThemeService` is only used where the toggle is set).
- Theme: **NoSplash** (no tap ink — it leaked past rounded containers), **floating snackbars** (so they don't push the docked FAB), theme-aware `dialogTheme`/`bottomSheetTheme` backgrounds. Note `elevatedButtonTheme` forces `minimumSize: Size(double.infinity, 56)` — buttons placed in a `Row` must override `minimumSize` (e.g. `Size(0, 48)`) or they demand infinite width and the layout fails.

---

## 14. Reusable Widgets (`shared/widgets/`)

The dead duplicate set was deleted; these are the **used** ones (extracted to kill copy-paste):
- **`AppCard`** — rounded surface container with optional `selected`/`onTap` (dashboard/checkout/history session cards).
- **`IconBadge`** — the colored rounded leading icon box.
- **`StatusPill`** — small rounded label ("Auto"/"Active"/"Completed").
- **`PlateInputFields`** — the two-field Numbers+Letters plate input (with the Arabic-letter spacing formatter + `digitsOf`/`spacedLettersOf`/`combine` helpers). Shared by the verification sheet and manual entry.

---

## 15. Build & Run Notes

- `flutter clean && flutter pub get && flutter run`. **Android-only**, tested on CPH2811.
- **Uninstall the app before running after the DB v2 bump** (clean first-run experience; otherwise `onUpgrade` wipes and you still land on the setup prompt).
- `flutter clean` is essential after replacing any `.tflite`.
- Harmless warnings: Kotlin Gradle Plugin deprecation (camerawesome/image_picker); CUDA noise is Kaggle-only.
- Windows PowerShell: chain with `;` not `&&`.

---

## 16. Testing Checklist

- [ ] Startup logs: `OnDeviceAiHelper: worker isolate ready.`; OCR input `dtype=float32 float32=true`; output map `digits=0 letters=1 digitLen=2 letterLen=3`.
- [ ] **Fresh install** → dashboard shows the **Set-up-garage** prompt → add zones → prompt disappears, Available reflects total slots.
- [ ] Car Entry → camera (flash menu + zoom) → "Processing…" → verification sheet shows split Numbers/Letters; low-confidence shows amber + Try Again.
- [ ] Zone selection assigns a spot **in that zone**; a full zone is non-selectable; duplicate plate rejected.
- [ ] Check-Out: search, confirm; fee respects 1-hour min + current rate; History updates.
- [ ] Dashboard Revenue = today's collected; Recent Activity merges active+completed (max 10) with status pills; **Show All** → History tab.
- [ ] History Today/All: revenue + count + avg duration are completed-only and correct.
- [ ] Settings → Manage Zones: rename/add/resize → Save; shrinking/deleting an occupied zone is **blocked & warned**.
- [ ] Snackbars float (don't push the Scan button); all sheets/dialogs render correctly in **light mode**; RTL flips on Arabic.

---

## 17. Future Work (Not Blocking)

- **Model (see `Model_Report.md`):** verify the 18 Arabic letter map order; re-export **int8** (cuts RAM + APK ~52 MB each; OCR int8 path already supported, detection int8 would need a dtype-aware detection path); support **1–2 digit plates** (retrain + widen digit-length head); calibrate `_confidenceThreshold`.
- **Soft:** tune `_minOcrConfidence` (0.60); dashboard search bar & Notifications are display-only placeholders.
- **Optional:** run `clean_history_days` on startup too; cap camera capture resolution (camerawesome 2.5 has no API for it — would need the `camera` package).
- **No git repo yet** — standalone project.
