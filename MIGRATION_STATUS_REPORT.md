# EALPR V4 Migration — Implementation Status Report

**Project:** Offline-First Flutter Garage Management App
**App build target:** Android (CPH2811 / Flutter 3.41)
**TFLite runtime:** `tflite_flutter 0.12.1`
**Report date:** 2026-05-29
**Audience:** ML/Model team responsible for `plate_ocr.tflite`

This report describes the result of applying the *EALPR V4 Flutter Migration Plan* (sent 2026-05-28) on the Flutter side, the current runtime error, and what is still required from the model team to ship working OCR.

---

## 1. Executive Summary

| Layer | Status | Detail |
|---|---|---|
| Camera capture + framing UI | ✅ Working | Guide frame ships consistent YOLO confidence above 0.85 |
| Plate detection (`plate_detection.tflite`) | ✅ Working | YOLOv8, 640×640 letterboxed, sigmoid-applied confidence head |
| OCR preprocessing | ✅ Implemented per plan | ImageNet normalization → INT8 quantization via tensor's own scale/zeroPoint |
| OCR input shape | ✅ Correctly reshaped to `[1, 3, 96, 320]` | Verified via runtime contract assertion |
| OCR output tensor mapping | ✅ Name-based with shape-based fallback | Matches the plan's spec for disambiguating the two `[1, 2]` heads |
| OCR slot decoder | ✅ Implemented per plan | Length heads → bounded slot reads → argmax → softmax confidence |
| Canonical plate format | ✅ `digits+letters` compact (matches Android pipeline) | |
| **OCR inference itself** | ❌ **Blocked at runtime** | `tflite/c: Input tensor 91 lacks data` → `Bad state: failed precondition` |

**Root cause of the only remaining blocker:** the `.tflite` file currently in `assets/plate_ocr.tflite` is the **original, pre-fix model**. Despite two declared "fixes" by the model team, the file on disk has not changed.

---

## 2. Migration Plan Implementation — Per-Item Status

This table walks through the plan's "Implementation Sequence" (section 4) and the "Definition of done" checklist.

### Implementation Sequence

| # | Plan step | Status | Notes |
|---|---|---|---|
| 1 | Replace OCR `.tflite` with a frozen, stateless export that passes the resource-variable gate | ❌ **Not done by model team** | File at `assets/plate_ocr.tflite` is unchanged. See section 4. |
| 2 | Add Flutter startup assertion that logs and validates input shape / dtype / scale / zero-point + all output names, shapes, dtypes, scales, zero-points | ✅ Done | `OnDeviceAiHelper._validateAndMapOcr()`. Asserts at `loadModel()` and throws `StateError` on contract violation. |
| 3 | Port Android NCHW affine quantization exactly; remove all `v - 128` preprocessing | ✅ Done | `OnDeviceAiHelper._buildOcrInput()` uses `(px/255 − 0.5) / 0.5` ImageNet normalization, then `q = clamp(round(real / scale + zeroPoint), -128, 127)` with the input tensor's own scale/zeroPoint. |
| 4 | Port Android output tensor mapper; fail initialization when length heads are ambiguous | ✅ Done | Shape-based map for `[1,4,11]` and `[1,3,19]`; the two `[1,2]` length heads disambiguated by tensor name (`digit_len`, `letter_len`, `output_2`, `output_3`). Fallback to sorted index order if names don't disambiguate. |
| 5 | Port Android slot decoder and class arrays exactly | ⚠️ Implemented with one outstanding caveat | Decoder logic is correct (length heads via argmax + 3 / + 2, bounded slot reads, PAD class skip, validity flag). `_arabicLetters[9..17]` were reconstructed from context because the two letter-map deliveries from the model team came through UTF-8-mojibake'd (all entries past index 8 showed as `'Ù'`). VERIFY before billing. |
| 6 | Wire YOLO raw bounding box directly into OCR cropper with zero padding | ✅ Done | `_cropBestDetection()` returns the un-padded letterbox-inverted crop directly from the detection head. |
| 7 | Verify parity against Android on a known crop fixture | ❌ Cannot run yet | Blocked by step 1. |
| 8 | Tune crop padding / confidence threshold / frame consensus | ❌ Cannot run yet | Blocked by step 7. |

### Definition of done

| Plan requirement | Status |
|---|---|
| Flutter never sees `tensor 91 lacks data` because the OCR FlatBuffer contains no resource variables | ❌ Still seeing it. The FlatBuffer still contains the resource variables. |
| OCR initialization fails fast if tensor shapes / dtypes / names / quantization parameters differ from the contract | ✅ Done — startup contract assertion in place |
| Dart input bytes are flat NCHW int8 using affine quantization from the runtime input tensor | ✅ Done — `Int8List(3*96*320)` filled with per-tensor scale/zeroPoint quantization, then reshaped to `[1,3,96,320]` |
| Four output tensors are decoded into the canonical plate string | ✅ Done — `digits+letters` compact form |
| YOLO detector remains the only source of crop coordinates; OCR receives only the tight plate crop | ✅ Done |

---

## 3. Current Runtime Error — Full Diagnosis

### What is observed at runtime

Startup logs (confirming all contract checks pass):

```
flutter: --- OCR Model Tensors ---
flutter: Input -> Name: serving_default_args_0, Shape: [1, 3, 96, 320], Type: int8
flutter: Output -> Name: serving_default_output_0_output, Shape: [1, 4, 11], Type: int8, Params: scale=0.03047528676688671 zp=-82
flutter: Output -> Name: serving_default_output_1_output, Shape: [1, 3, 19], Type: int8, Params: scale=0.03292146697640419 zp=-88
flutter: Output -> Name: serving_default_output_2_output, Shape: [1, 2], Type: int8, Params: scale=0.04726841673254967 zp=3
flutter: Output -> Name: serving_default_output_3_output, Shape: [1, 2], Type: int8, Params: scale=0.04630965366959572 zp=4
flutter: OCR input contract OK: shape=[1, 3, 96, 320] scale=0.007057582959532738 zeroPoint=4
flutter: OCR output map: digits=0 letters=1 digitLen=2 letterLen=3
```

On Check-In with a clear close-up photo:

```
flutter: YOLO best detection: conf=0.9079038500785828  crop=217,576 255x132 (source 720x1280)
E/tflite : Input tensor 91 lacks data
Check-In failed: Exception: Plate recognition failed: Bad state: failed precondition
```

### What this means

- **Detection is healthy.** YOLO returns confidence 0.91 and a sensible crop region.
- **OCR preprocessing is correct.** The Dart-side build produces a properly-shaped `[1, 3, 96, 320]` int8 tensor with values quantized using the model's own scale/zeroPoint (0.00706 / 4).
- **OCR invoke fails at the C++ runtime layer**, on a *model-internal tensor* (index 91 inside the graph). The Dart-facing interpreter only exposes 1 user-facing input tensor (`serving_default_args_0`), so tensor 91 is **not** something the app can populate from Dart — it is a stateful variable tensor that the TFLite runtime expects to be initialized internally by the FlatBuffer's variable-initializer ops, which this `.tflite` does not contain.

### Earlier intermediate state (for completeness)

Before the input reshape was added, the app was failing with a different but related error:

```
E/tflite : tflite/kernels/transpose.cc:52 op_context->perm->dims->data[0] != dims (4 != 1)
E/tflite : Node number 0 (TRANSPOSE) failed to prepare.
```

That was a Dart-side bug — passing a flat `Int8List` of length 92,160 caused `tflite_flutter` to silently resize the input tensor to 1D, which broke the first TRANSPOSE op during `allocateTensors()`. Reshaping the input to a 4D nested list before `runForMultipleInputs` fixed that. Once that was fixed, the underlying variable-tensor failure became visible again — it had been there all along, just masked by the earlier preparation-phase crash.

---

## 4. Evidence the `.tflite` File Has Not Been Updated

The user has reported "updating" the file twice since the migration plan was sent. However:

**File system check (run today):**

```
Name                     Length    LastWriteTime
plate_ocr.tflite         8,201,184 29-May-26 11:11:26 AM
```

Last-modified timestamp **29-May-26 11:11:26 AM** is the timestamp of the **first** delivery (the one that was supposed to be the fixed Transformer model). It has not changed since.

**Tensor name comparison:**

| Tensor | Names in current `.tflite` | Names from the original buggy model |
|---|---|---|
| Input | `serving_default_args_0` | `serving_default_args_0` |
| Output 0 | `serving_default_output_0_output` | `serving_default_output_0_output` |
| Output 1 | `serving_default_output_1_output` | `serving_default_output_1_output` |
| Output 2 | `serving_default_output_2_output` | `serving_default_output_2_output` |
| Output 3 | `serving_default_output_3_output` | `serving_default_output_3_output` |

The `_output` suffix decorations are tell-tale signatures of `tf.saved_model.save()` → `tf.lite.TFLiteConverter.from_saved_model()` with a `serving_default` signature — exactly the export path the migration plan (section 1) instructed the team **not** to use.

**Conclusion:** the model file currently in production is the same one that produced the `Input tensor 91 lacks data` error in the very first OCR attempt. No clean export has actually reached the app.

---

## 5. What the Model Team Must Deliver

To unblock OCR, the model team needs to do all of the following:

### 5.1 Re-export the model using the plan's canonical script

The plan's section 1 already specifies this exactly. Key points:

- Convert from a **concrete function**, **not** from `from_saved_model()`.
- Run `convert_variables_to_constants_v2(concrete)` before constructing the converter.
- Set `converter.experimental_enable_resource_variables = False`.
- Quantize to int8 (full integer), input dtype = int8, output dtype = int8.
- Calibrate the representative dataset using the **same** float-domain input that training/eval used: RGB, NCHW `[1, 3, 96, 320]`, normalized to `[-1, 1]`.

### 5.2 Verify the result before sending it

Run the plan's post-export gate (section 1) **and** open the resulting `.tflite` in [Netron](https://netron.app):

- Search for `READ_VARIABLE`, `VAR_HANDLE`, `ASSIGN_VARIABLE`, `RESOURCE_VARIABLE`.
- **Zero hits is required.** Any hit means the export still has the variable-tensor bug. Do not send the file.
- Confirm input tensor count = 1, shape = `[1, 3, 96, 320]`, dtype = int8.
- Confirm output tensors: `[1, 4, 11] int8`, `[1, 3, 19] int8`, two `[1, 2] int8`.

The post-export gate in the plan also has a subtle bug worth fixing: `tf.lite.experimental.Analyzer.analyze(...)` returns `None` and prints to stdout; wrap it in `contextlib.redirect_stdout(io.StringIO())` to actually capture the text the asserts are checking against.

### 5.3 Ship the Arabic letter map as actual UTF-8

Both prior deliveries of the letter map arrived UTF-8 → Latin-1 mojibake'd (positions 9–17 of `arabicLetterClasses` were transmitted as `'Ù'`, missing the second byte). The Flutter side has reconstructed those positions from Egyptian-plate convention as:

```
['أ', 'ب', 'ج', 'د', 'ر', 'س', 'ص', 'ط', 'ع', 'ف', 'ق', 'ك', 'ل', 'م', 'ن', 'ه', 'و', 'ي']
```

Please confirm or correct this list by sending the 18 characters as plain UTF-8 text (e.g., in a `.txt` file) — not embedded in a markdown code block that gets corrupted by editor encoding.

### 5.4 Optional but recommended — ship a parity fixture

Send one cropped plate image (the 320×96 RGB crop after the YOLO box has been extracted) along with:

- The exact Android-decoded text for that crop
- The per-head argmax classes
- The digit length and letter length
- The Android confidence value

This lets us verify that the Flutter pipeline produces bit-identical output for a known input, isolating any remaining preprocessing mismatch.

---

## 6. Verifying the New File Has Been Installed

A reliable way to confirm the new `.tflite` actually replaced the old one on the device:

1. Right-click `d:\GP\gp_app\assets\plate_ocr.tflite` → Properties → "Date modified" should be **today** (or whenever you copied the new file), not 29-May-26 11:11 AM.
2. Run `flutter clean` followed by `flutter run`. The asset bundle is built into the APK at compile time; without `flutter clean`, the build can re-use a cached APK that contains the old asset.
3. Watch the startup logs for the OCR tensor names:
   - If they still show `serving_default_args_0` and `serving_default_output_X_output`, the file is still the SavedModel-signature export and contains the bug.
   - If they show different names (e.g., `args_0`, `digit_logits`, `letter_logits`, `digit_len_logits`, `letter_len_logits`), the new file is loaded.

---

## 7. What's Ready on the Flutter Side

Once a clean `.tflite` lands, **no Flutter code changes should be required**. The current implementation:

- Validates the input contract and fails fast on mismatch
- Maps outputs by both shape and name (handles either the old `serving_default_output_X` names or the cleaner `digit_logits` / `letter_logits` names from the plan's canonical export)
- Applies the plan's exact preprocessing (resize → ImageNet normalize → per-tensor quantize → clamp)
- Decodes with length-bounded slot reads, PAD-class handling, and softmax confidence
- Returns the canonical compact `digits+letters` string
- Rejects low-confidence reads (< 0.60) and invalid format reads with a descriptive exception

The remaining work after a clean model is integrated is straightforward:

1. **Letter-map verification** — confirm the reconstructed 18-letter list against the model team's UTF-8 deliverable
2. **Parity test** — run the team's fixture crop through the pipeline, diff against Android output
3. **Threshold tuning** — adjust `_minOcrConfidence` once we know what real-world reads score
4. **Background inference** — move both interpreter calls off the main thread (currently causes ~1s UI freeze per Check-In)

None of these are blockers for the first successful OCR read.

---

## 8. Hand-off Checklist for the Model Team

Please reply with:

- [ ] A new `plate_ocr.tflite` produced by the plan's canonical export script
- [ ] Netron screenshot showing zero hits for `READ_VARIABLE` / `VAR_HANDLE` / `RESOURCE_VARIABLE`
- [ ] Netron screenshot showing input tensor count = 1, shape `[1, 3, 96, 320]`, dtype int8
- [ ] The 18 Arabic letters as plain UTF-8 text (not in markdown)
- [ ] One cropped plate image + Android's decoded result for parity testing (optional but recommended)

Replace the existing file at `d:\GP\gp_app\assets\plate_ocr.tflite`, run `flutter clean && flutter pub get && flutter run`, and the first Check-In should produce a real plate string.
