# Codebase Audit Report
**Date:** 2026-05-25  
**Project:** Offline-First Flutter Garage Management App  
**Scope:** Data layer, AI pipeline, repository, and logic/controller layer

---

## 1. Architectural Integrity

**Overall: Clean.** Data flows correctly: `SQLite/TFLite → LocalDbHelper → ParkingRepository → GarageController`. No layer violations. The controller never reaches down to the DB directly, and the DB helper has no UI logic.

**One structural concern:** `ParkingRepository` instantiates `OnDeviceAiHelper()` as a plain field — but `loadModel()` is never called anywhere in the codebase. The interpreters are always `null`, meaning every single call to `recognizePlate` will silently return the string `'Error: Models not loaded'` and that string will be stored as a real plate number in the DB. This is the most critical flaw in the current design.

---

## 2. Code Quality & Optimization

### `local_db_helper.dart`
- `import 'dart:async';` on line 1 is unused — remove it.
- `_createDB` has no return type annotation — should be `Future<void>`.
- `close()` calls `instance.database` instead of just `database`. Since it's a singleton, `instance` is `this`, so it works, but it's redundant.

### `transaction_model.dart`
- Potential runtime crash: `map['total_fee'] as double?` will throw if SQLite returns an integer `0` for a `REAL` column (SQLite is dynamically typed and returns `int` for whole-number REAL values). Fix:
  ```dart
  totalFee: (map['total_fee'] as num?)?.toDouble(),
  ```

### `parking_repository.dart`
- `recognizePlate` returns error strings instead of throwing. The repository does not validate the return value before passing it to `getActiveTransactionByPlate` or storing it via `insertTransaction`. Garbage strings like `'Error: Could not decode image'` become real plate numbers in the DB.
- `transaction.spotAssigned!` on line 54 force-unwraps a nullable field. It is always set for Active transactions by your own logic, but if the DB is ever in an inconsistent state this will crash with a null-check error rather than a graceful exception.

### `on_device_ai_helper.dart`
- `_preprocessImage` return type is untyped `List` — should be `List<List<List<List<int>>>>` for clarity and safety.
- `runForMultipleInputs` is synchronous and runs on the main thread. On a real device with a 320×320 image this will freeze the UI for several hundred milliseconds. Wrap both inference calls in `compute()` or dispatch to an isolate before UI integration.
- Input pixel values are passed as `[0–255]` integers. For a full-integer quantized INT8 model the expected range may be `[-128, 127]`. Verify the model's quantization parameters and apply the correct normalization.

---

## 3. AI Pipeline Verification

**Blocking:** `loadModel()` is never called. `ParkingRepository` creates `OnDeviceAiHelper()` but nothing triggers model loading. Fix this at app startup — either call `loadModel()` from `main.dart` before `runApp`, or add an `init()` method to the repository and call it once from the controller.

**Output shape placeholders:** `numDetections = 10` and all four output shapes in both detection and OCR stages are placeholder values. If the actual model shapes differ, `runForMultipleInputs` will throw a shape mismatch error at runtime. Before UI integration, inspect the actual shapes with:
```dart
_detectionInterpreter.getOutputTensors().forEach((t) => debugPrint('${t.name}: ${t.shape}'));
```

**Confidence threshold hardcoded to `0.5`:** Reasonable default, but worth making it a named constant so it can be tuned without hunting through the file.

**`_decodeOcrOutputs` is still a stub** returning `'أ ج 1 2 3 4'` — expected at this stage, but must be replaced before any real testing.

---

## 4. Warnings & Hidden Bugs

| # | Location | Issue | Severity |
|---|---|---|---|
| 1 | `ParkingRepository` | `loadModel()` never called — all AI calls fail silently | **Critical** |
| 2 | `ParkingRepository` / `OnDeviceAiHelper` | Error strings returned instead of thrown — stored as plate numbers in DB | **Critical** |
| 3 | `transaction_model.dart:42` | `as double?` cast crashes on SQLite integer zero for REAL column | **High** |
| 4 | `on_device_ai_helper.dart:52/70` | Synchronous inference on main thread — UI freeze | **High** |
| 5 | `parking_repository.dart:54` | `spotAssigned!` force unwrap — crashes on inconsistent DB state | **Medium** |
| 6 | `on_device_ai_helper.dart` | Input pixel range not normalized for INT8 quantized model | **Medium** |
| 7 | `garage_controller.dart` | No `dispose()` override — `OnDeviceAiHelper.close()` never called, interpreters leak memory | **Medium** |
| 8 | `local_db_helper.dart:1` | `dart:async` unused import | **Low** |
| 9 | `local_db_helper.dart:25` | `_createDB` missing `<void>` return type | **Low** |
| 10 | `on_device_ai_helper.dart:77` | `_preprocessImage` return type is untyped `List` | **Low** |

---

## 5. Readiness Assessment

**The architecture and DB layer are solid and ready for UI integration.** The SQLite schema, seeding, CRUD operations, billing logic, and state management are all correct.

**Two issues must be fixed before the UI layer is started:**

1. Call `loadModel()` at app startup (fix in `main.dart` or repository `init`).
2. Change `recognizePlate` to throw exceptions on failure instead of returning error strings, and add a guard in the repository.

The remaining items (main-thread inference, `totalFee` cast, `dispose`) should be fixed shortly after but won't block UI scaffolding since the OCR decoder is still a stub anyway.