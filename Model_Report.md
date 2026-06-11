# Model Report — On-Device License Plate Recognition

**Project:** Offline-First Flutter Garage Management App
**App build target:** Android (CPH2811 / Snapdragon)
**TFLite runtime:** `tflite_flutter 0.12.1`
**Report date:** 2026-06-06
**Status:** Both models working end-to-end on device. OCR pipeline validated.

> Supersedes the 2026-05-26 integration report, which described the OCR model as blocked/stubbed. The OCR model is now working (see §4).

---

## 1. Executive Summary

The application runs a fully on-device, two-stage AI pipeline (no network):

1. **Detection** — YOLOv8 locates the license plate in the camera image.
2. **OCR** — a PlateSlotTransformer reads the plate (Egyptian format: 3–4 digits + 2–3 Arabic letters).

Both models are TensorFlow Lite (`.tflite`) and bundled as assets. The OCR model went through a difficult path: two earlier int8 exports (the original and a teammate's replacement) **crashed at runtime** due to a broken export toolchain. We resolved this by re-exporting the trained model with Google's official **litert-torch** converter, producing a clean float32 model that is now working in production. This report documents the failure, the fix, the current state, and the remaining model-side action plan.

| Model | Asset path | Size | Precision | Status |
|---|---|---|---|---|
| Plate detection (YOLOv8) | `assets/plate_detection.tflite` | ~40 MB | float32 | ✅ Working |
| Plate OCR (PlateSlotTransformer) | `assets/plate_ocr.tflite` | ~30.2 MB | float32 | ✅ Working |

---

## 2. Current Model Situation

### 2.1 OCR model I/O contract
- **Input:** `[1, 3, 96, 320]` float32, NCHW. Normalization: `(px/255 − 0.5) / 0.5 → [−1, 1]`.
- **Outputs (4 named heads):**
  - `digit_logits` — `[1, 4, 11]` (10 digits + PAD)
  - `letter_logits` — `[1, 3, 19]` (18 Arabic letters + PAD)
  - `digit_len_logits` — `[1, 2]` (argmax → 3 or 4 digits)
  - `letter_len_logits` — `[1, 2]` (argmax → 2 or 3 letters)

### 2.2 Detection model I/O contract
- **Input:** `[1, 640, 640, 3]` float32, NHWC, normalized `px/255 → [0, 1]`, YOLO-style letterbox (gray 114 padding).
- **Output:** `[1, 5, 8400]` → `[cx, cy, w, h, confidence]`, 8400 candidate anchors. Box values normalized to `[0, 1]` of the 640×640 input; confidence already sigmoid-activated.

### 2.3 On-device validation (device CPH2811, Snapdragon)
- YOLO detection confidence on real plates: **~0.89–0.91**.
- OCR reads such as `7894سوم`, `7268وطم` at **~0.98 confidence**.
- Full flow confirmed: detection → crop → OCR → check-in/out → fee calculation → spot toggling.

### 2.4 Training metrics (locked test set, 1616 samples)
- **Exact-match accuracy:** 90.66%
- **Character Error Rate (CER):** 0.0204
- Total errors: 151
- **Known systematic error:** digit order occasionally reversed (e.g. GT `6323نبأ` → pred `3326نبأ`), attributed to a right-to-left labeling ambiguity in the training data. Non-blocking.

### 2.5 Known model limitations (confirmed on device)
- **Digit count locked to 3–4.** The digit-length head only predicts 3 or 4 digits. A single-digit plate (`١`) cannot be read — the model emits `111`. (See action plan item 3.)
- **Letter count 2–3 supported.** Two-letter plates read correctly; the letter-length head handles 2 or 3.
- **Small/distant plates degrade.** Low-resolution crops cause the length heads to fail first, producing confidently-wrong reads.

---

## 3. The Problem — Why the Teammate's Model Did Not Work

### 3.1 Symptom
When the teammate's replacement OCR model (int8) was loaded on device, the app:
1. Loaded both interpreters and printed all tensor shapes correctly.
2. Ran YOLO detection successfully (confidence ~0.91, valid crop).
3. **Crashed at the OCR stage** with:

```
E/tflite: Input tensor 91 lacks data
```

This is the **exact same crash** the original OCR model produced.

### 3.2 Root cause
Both the original and the teammate's models were exported through the chain:

```
PyTorch → ONNX → SavedModel → TFLite
```

This chain bakes some weights as **stateful runtime variables** (`RESOURCE_VARIABLE` / `VAR_HANDLE` / `READ_VARIABLE` ops) instead of inlined constants. At inference, those variable tensors are never populated, so TFLite aborts with `Input tensor 91 lacks data`.

The intended Dart-side workaround — `resetVariableTensors()` in `tflite_flutter 0.12.1` — is **broken**, so the problem could not be fixed from the app.

### 3.3 Confirmation
Two independently produced int8 models (the original and the teammate's) — both built through the same export chain — reproduced the **identical** `tensor 91` crash. This isolated the fault to the **export toolchain**, not the application code or the model weights themselves.

---

## 4. The Fix — Re-Export on Kaggle with litert-torch

The trained PlateSlotTransformer was re-exported using **litert-torch** (Google's official PyTorch → TFLite converter; the package was renamed from `ai-edge-torch`). This converter inlines weights as **constants**, eliminating resource-variable ops entirely.

### 4.1 Steps performed on Kaggle

**1. Wrong package first.** `import ai_edge_torch` resolved to a deprecated stub with no `convert` attribute (`AttributeError: module 'ai_edge_torch' has no attribute 'convert'`). Resolved by installing the real package:
```bash
pip install litert-torch -q
```

**2. Device-propagation failure.** The first conversion attempt failed:
```
RuntimeError: Unhandled FakeTensor Device Propagation for aten.sub.Tensor,
found two different devices cpu, cuda:0
```
Cause: the model was on the GPU (`cuda:0`) while litert-torch traces on CPU, conflicting during BatchNorm tracing.

**3. Fix — move the model to CPU before conversion:**
```python
import litert_torch
import torch

model.eval()
model_cpu = model.cpu()                      # move off GPU before tracing
sample_input = torch.zeros(1, 3, 96, 320)    # CPU tensor

edge_model = litert_torch.convert(model_cpu, (sample_input,))
edge_model.export('/kaggle/working/plate_ocr.tflite')
```

**4. Export succeeded.** All conversion stages (Torch Export → FX Passes → Lower to MLIR → LiteRT Converter Passes → Write Model) completed with no errors. Final size: **30.22 MB**.

**5. Verification cell — all checks passed:**
- ✅ **No resource-variable ops** (`READ_VARIABLE` / `VAR_HANDLE` / `RESOURCE_VARIABLE` absent).
- ✅ Input: `serving_default_args_0` — shape `[1, 3, 96, 320]`, dtype float32.
- ✅ Four outputs, all float32, with **explicit names**:
  - `digit_logits` `[1, 4, 11]`
  - `letter_logits` `[1, 3, 19]`
  - `digit_len_logits` `[1, 2]`
  - `letter_len_logits` `[1, 2]`
- ✅ Inference ran successfully on random input (sane argmax outputs).

> **Operational note:** A Kaggle session factory-reset wiped `/kaggle/working`, requiring the export cell to be re-run. The trained checkpoint and notebook were unaffected. **Recommendation:** save the exported `.tflite` as a Kaggle **Dataset** immediately after export so it survives session resets.

### 4.2 Why this fixed it
- Weights are inlined as **constants** → zero resource-variable ops → no `tensor 91` crash.
- Output tensors carry **explicit names**, which the app uses (alongside shape) to map the four OCR heads deterministically.

---

## 5. App-Side Integration Changes (that accompanied the new model)

- **Preprocessing switched from int8 to float32**, with **automatic dtype detection at load** (`_ocrIsFloat32`). The float32 path builds float input buffers and reads float outputs directly; an int8 fallback path is retained for compatibility.
- **Output mapping** validates and binds the four heads by **shape + tensor name** (`_validateAndMapOcr`), failing fast on any contract mismatch.
- **Decoder** produces the canonical compact form `digits + letters` (letters reversed to physical right-to-left plate order), plus a softmax confidence and a validity flag.
- **Inference moved to a background isolate** so recognition never freezes the UI; preprocessing uses flat `Float32List` buffers for low allocation/GC on weak devices.
- **Detection confidence threshold raised to `0.40`** (was `0.005`) to reject non-plate images that previously produced fabricated reads.
- **Validated on device:** reads such as `7894سوم` / `7268وطم` at ~0.98 confidence; full check-in/out and fee calculation confirmed.

---

## 6. Model-Side Action Plan

The following work lives in the **training / export pipeline** (Python / Kaggle), not the Flutter app — though items flagged below also require paired app-side changes.

### Priority 1 — Correctness (do before trusting OCR for billing)

**1. Verify the Arabic letter class map**
- **What:** Confirm the exact `class index → Arabic letter` mapping for all 18 letters against the actual training code / label encoder.
- **Why:** The app's letter list was reconstructed from a corrupted (mojibake'd) hand-off guide — **positions 9–17 are assumed, not confirmed.** A wrong order means plates read with the wrong letters and fees attach to the wrong vehicle.
- **How:** Export the label-encoder / class list from the training notebook and diff it against the app's `_arabicLetters` array.
- **Verify:** Run 20–30 known plates end-to-end; every letter must match the physical plate.

### Priority 2 — Size & Performance (biggest resource win)

**2. Re-export both models as int8 (quantized)**
- **What:** Produce int8-quantized versions of both models using **litert-torch** with post-training quantization (a representative calibration dataset of real plates).
- **Why:** Both are float32 today (~40 MB + ~30 MB). int8 cuts **RAM ~70 MB → ~18 MB** and **APK size ~70 MB → ~18 MB** — the single largest improvement for old / weak devices.
- **Critical constraints:**
  - Must go through **litert-torch**, *not* the old `PyTorch → ONNX → SavedModel → TFLite` chain (that chain caused the `tensor 91` crash).
  - After export, confirm **no resource-variable ops** and correct input/output shapes (reuse the existing verification cell).
- **Accuracy check:** int8 can lose precision — measure CER / exact-match on the locked test set **before vs. after** quantization. Accept only if the drop is negligible.
- **App-side dependency:**
  - **OCR int8 → already supported** (the app auto-detects dtype and has a working int8 path). Drop-in.
  - **Detection int8 → needs app code changes.** The detection path currently assumes float32 I/O; an int8 detector requires restoring a dtype-aware path. Coordinate before switching.

### Priority 3 — Functional Coverage (real plates we currently fail)

**3. Support 1–2 digit plates (retrain + widen the digit-length head)**
- **What:** Retrain with 1- and 2-digit plate samples and widen the **digit-length head** to predict **1–4 digits** (currently hard-locked to 3 or 4).
- **Why:** A single-digit plate (e.g. `١`) is currently impossible to read — the model is forced to emit ≥3 digits and produces garbage (e.g. `111`). This is an architecture + data limitation, not a capture issue.
- **App-side dependency:** The decoder's digit-length logic and validity bounds must be relaxed to match the new head. Coordinate the head's output encoding so the app decoder stays in sync.
- **Verify:** Test 1-, 2-, 3-, and 4-digit plates.

### Priority 4 — Accuracy Refinement (soft, non-blocking)

**4. Fix the systematic digit-order reversal**
- **What:** Address the known error where digit order is occasionally reversed (GT `6323نبأ` → pred `3326نبأ`).
- **Why:** Traced to a right-to-left labeling ambiguity in the training data.
- **How:** Audit / clean the digit-slot label ordering and retrain.

**5. Improve distant / small-plate detection**
- **What:** Add more small / distant-plate examples to the detection training set (and optionally evaluate a higher detection input resolution).
- **Why:** Small plates produce low-resolution crops; the OCR length heads degrade first, causing confidently-wrong reads on far plates.
- **Verify:** Re-measure detection confidence on a distant-plate test batch.

### Priority 5 — Process & Hygiene (maintainability)

**6. Document and freeze the model I/O contract**
- **What:** Record, alongside each model file: input shape / dtype / normalization, the four output tensor **names** and shapes, the digit / letter class maps, and PAD indices.
- **Why:** The app maps OCR outputs by **shape + tensor name**. Any re-export that renames or reshapes outputs silently breaks the mapping. A frozen contract prevents that.

**7. Version the model files with provenance**
- **What:** Tag each export with a version and store the export script, training-run reference, and verification-cell output next to it.
- **Why:** Today the lineage is ad-hoc. Versioning makes exports auditable and reversible.

**8. Calibrate the detection confidence threshold**
- **What:** Characterize YOLO confidence across a labeled set of real plates vs. non-plates (doors, screens, walls) and pick the optimal cutoff.
- **Why:** The app threshold is currently `0.40`, set empirically after a false-positive bug (non-plate images were producing fabricated plate reads). A data-driven value confirms the right number.
- **App-side:** One-constant change (`_confidenceThreshold`) — provide the calibrated value.

---

## 7. Items Requiring Paired App-Side Changes

These model-side changes **cannot ship alone** — the Flutter code must change in lockstep:

| Action plan item | Required app-side change |
|---|---|
| 2 — int8 **detection** model | Restore a dtype-aware detection path (currently float32-only) |
| 3 — 1–2 digit support | Relax decoder digit-length logic + validity bounds |
| 8 — threshold calibration | Update `_confidenceThreshold` constant |

---

## 8. Recommended Execution Order

```
1  →  2 (OCR first: drop-in; detection int8 with app update)  →  8  →  3  →  6 / 7  →  4  →  5
```

- **High-value, low-effort:** items 1, 2, 6, 7, 8.
- **Larger effort (retraining):** items 3, 4, 5.

---

## 9. Key Lessons

1. **Export toolchain matters more than the weights.** Two correctly-trained models were unusable purely because of the export chain. Standardize on **litert-torch**.
2. **Always move the model to CPU before `litert_torch.convert(...)`** to avoid the FakeTensor device-propagation error.
3. **Run the verification cell every export** (no resource-variable ops, correct shapes, sample inference) before shipping the file.
4. **Persist exported artifacts immediately** (Kaggle Dataset) — session resets wipe `/kaggle/working`.
5. **The model contract is load-bearing.** The app binds OCR outputs by shape + name; never rename or reshape outputs without updating the app.
