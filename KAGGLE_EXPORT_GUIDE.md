# Self-Service EALPR V4 Export Guide

**Goal:** Produce a clean `plate_ocr.tflite` ourselves from the trained PyTorch checkpoint, instead of waiting for another broken delivery from the model team.

**Why:** The teammate's prior exports went through `PyTorch → ONNX → SavedModel → TFLite`, which is exactly the chain that introduces the `RESOURCE_VARIABLE` / `READ_VARIABLE` ops that crash `tflite_flutter` with `Input tensor 91 lacks data`. We bypass that chain entirely with `ai_edge_torch` (Google's official direct PyTorch-to-TFLite converter).

---

## What you need

1. The `ealpr-v4.ipynb` notebook open in Kaggle (the one already on disk at `d:\GP\gp_app\ealpr-v4.ipynb`).
2. The trained checkpoint `best_ealpr_v4_slot_transformer.pth` available in Kaggle's working dir or attached as a dataset. If you've run the notebook end-to-end at least once, it's already at `/kaggle/working/best_ealpr_v4_slot_transformer.pth`.
3. **Internet enabled** on the Kaggle notebook (Settings → Internet → On). We need it for `pip install ai_edge_torch`.

You do **not** need to retrain. Cells 0–6 are setup; Cell 7 is the long training; Cell 8 is evaluation. If the `.pth` already exists, you can skip the long training cell and run only the cells below.

---

## Step 1 — Install ai_edge_torch

Add a new cell at the bottom of the notebook and run:

```python
!pip install -q ai-edge-torch tensorflow==2.17.0
```

`tensorflow==2.17.0` pins a known-good TF version that ai_edge_torch ships against. Kaggle's default TF may be newer and trigger version-mismatch warnings; pinning avoids that.

Restart the kernel after install (Kaggle: Run → Restart & Clear Outputs), then re-run cells 0–6 to redefine `PlateSlotTransformer`, `DIGITS`, `ARABIC_LETTERS`, etc. **Skip the training cell (Cell 7).** Run Cell 8 (eval) only if you want to confirm the checkpoint works before exporting.

---

## Step 2 — The export cell

Add a new cell after Cell 8 and paste this:

```python
# ============================================================
# CELL V4.5: Clean PyTorch → TFLite export via ai_edge_torch
# ============================================================
import os
import torch
import torch.nn as nn
import ai_edge_torch

CHECKPOINT_V4 = "/kaggle/working/best_ealpr_v4_slot_transformer.pth"
TFLITE_OUT_PATH = "/kaggle/working/plate_ocr.tflite"

# ---- 1. Load the trained checkpoint ----
ckpt = torch.load(CHECKPOINT_V4, map_location="cpu")
model = PlateSlotTransformer()
model.load_state_dict(ckpt["model_state_dict"])
model.eval()

# Confirm what we are about to export
print(f"Loaded checkpoint stage={ckpt.get('stage')} epoch={ckpt.get('epoch')}")
print(f"Reported internal val exact: {ckpt.get('internal_val_exact', 0.0):.2%}")
print(f"DIGITS: {DIGITS}")
print(f"ARABIC_LETTERS ({len(ARABIC_LETTERS)}): {ARABIC_LETTERS}")

# ---- 2. Wrap to return a tuple instead of a dict ----
# TFLite outputs are positional, not named. The wrapper fixes the output
# order to (digit_logits, letter_logits, digit_len_logits, letter_len_logits),
# which matches the Flutter app's expected output index mapping.
class TfliteExportWrapper(nn.Module):
    def __init__(self, base):
        super().__init__()
        self.base = base

    def forward(self, x):
        out = self.base(x)
        return (
            out["digit_logits"],       # index 0  -> [B, 4, 11]
            out["letter_logits"],      # index 1  -> [B, 3, 19]
            out["digit_len_logits"],   # index 2  -> [B, 2]
            out["letter_len_logits"],  # index 3  -> [B, 2]
        )

wrapper = TfliteExportWrapper(model).eval()

# ---- 3. Smoke test the wrapper before conversion ----
sample = torch.randn(1, 3, IMG_HEIGHT_V4, IMG_WIDTH_V4)  # [1, 3, 96, 320]
with torch.no_grad():
    d, l, dl, ll = wrapper(sample)
print(f"Wrapper output shapes: digit={tuple(d.shape)} letter={tuple(l.shape)} "
      f"digit_len={tuple(dl.shape)} letter_len={tuple(ll.shape)}")
assert d.shape == (1, 4, 11)
assert l.shape == (1, 3, 19)
assert dl.shape == (1, 2)
assert ll.shape == (1, 2)
print("✓ Wrapper shapes match the Flutter contract.")

# ---- 4. Convert to TFLite (float32, no quantization) ----
# Float32 is the simplest reliable path. Once verified, we can add int8
# quantization in a follow-up if model size becomes an issue.
sample_args = (sample,)
edge_model = ai_edge_torch.convert(wrapper, sample_args)
edge_model.export(TFLITE_OUT_PATH)

size_mb = os.path.getsize(TFLITE_OUT_PATH) / (1024 * 1024)
print(f"✓ Exported TFLite model: {TFLITE_OUT_PATH}  ({size_mb:.2f} MB)")
```

---

## Step 3 — Verify the export

Add another cell and run:

```python
# ============================================================
# CELL V4.6: Verify the exported TFLite
# ============================================================
import numpy as np
import tensorflow as tf
import torch

# ---- 1. Resource-variable gate (the plan's gate, fixed to actually work) ----
import io, contextlib
buf = io.StringIO()
with contextlib.redirect_stdout(buf):
    tf.lite.experimental.Analyzer.analyze(model_path=TFLITE_OUT_PATH)
analyzer_report = buf.getvalue()

blocked = ["READ_VARIABLE", "VAR_HANDLE", "ASSIGN_VARIABLE", "RESOURCE_VARIABLE"]
hits = [tok for tok in blocked if tok in analyzer_report]
if hits:
    raise RuntimeError(f"❌ Export still contains stateful ops: {hits}")
print("✓ Resource-variable gate passed: no stateful ops in the FlatBuffer.")

# ---- 2. Tensor metadata ----
interp = tf.lite.Interpreter(model_path=TFLITE_OUT_PATH)
interp.allocate_tensors()
ins = interp.get_input_details()
outs = interp.get_output_details()
print(f"Inputs ({len(ins)}):")
for t in ins:
    print(f"  {t['name']}  shape={list(t['shape'])}  dtype={t['dtype']}")
print(f"Outputs ({len(outs)}):")
for t in outs:
    print(f"  {t['name']}  shape={list(t['shape'])}  dtype={t['dtype']}")

assert len(ins) == 1, f"Expected 1 input, got {len(ins)}"
assert list(ins[0]["shape"]) == [1, 3, 96, 320], f"Wrong input shape: {ins[0]['shape']}"
print("✓ Input contract matches Flutter expectation [1, 3, 96, 320].")

# ---- 3. Numerical parity vs PyTorch ----
# Run the same random input through both and check the argmax classes match.
test_input = np.random.randn(1, 3, 96, 320).astype(np.float32)

# PyTorch reference
with torch.no_grad():
    d_t, l_t, dl_t, ll_t = wrapper(torch.from_numpy(test_input))

# TFLite
interp.set_tensor(ins[0]["index"], test_input)
interp.invoke()
# Outputs may be in any order — match by shape
results = {tuple(t["shape"]): interp.get_tensor(t["index"]) for t in outs}
d_tf = results[(1, 4, 11)]
l_tf = results[(1, 3, 19)]
# Two [1,2] tensors — match by output name suffix if possible
twos = [t for t in outs if list(t["shape"]) == [1, 2]]
twos_sorted = sorted(twos, key=lambda t: t["name"])
dl_tf = interp.get_tensor(twos_sorted[0]["index"])
ll_tf = interp.get_tensor(twos_sorted[1]["index"])

# Compare argmax classes (numerically tolerant)
print("\nPyTorch vs TFLite argmax comparison:")
print(f"  digits per-slot: PT={d_t.argmax(-1).tolist()}  TF={d_tf.argmax(-1).tolist()}")
print(f"  letters per-slot: PT={l_t.argmax(-1).tolist()}  TF={l_tf.argmax(-1).tolist()}")
print(f"  digit_len argmax: PT={dl_t.argmax(-1).item()}  TF={dl_tf.argmax(-1).item()}")
print(f"  letter_len argmax: PT={ll_t.argmax(-1).item()}  TF={ll_tf.argmax(-1).item()}")
print("\n✓ If argmaxes match, the conversion preserved model behavior.")
```

If the resource-variable gate fails or the argmaxes diverge wildly, stop and tell me — we'll debug. If both pass, you have a clean model.

---

## Step 4 — Download the .tflite

In the Kaggle notebook's left sidebar there's an "Output" or "Files" pane that shows `/kaggle/working/`. Click the new `plate_ocr.tflite` file and download it.

---

## Step 5 — Drop it into the Flutter project

Replace the file on disk:
```
d:\GP\gp_app\assets\plate_ocr.tflite
```

Then in PowerShell:
```powershell
flutter clean
flutter pub get
flutter run
```

At startup, the OCR contract log will look different from the broken model. Specifically:
- **Tensor name should NOT be `serving_default_args_0`** (that name is the SavedModel-signature artifact). With `ai_edge_torch` the input name will be `args_0` or similar.
- **No `_output` suffix on outputs.**
- **The input/output dtypes will be `float32`**, not `int8`.

---

## Step 6 — One Flutter-side change needed

Because the exported model is float32 (not int8), the OCR preprocessing on the Flutter side needs a small adjustment:

- `_buildOcrInput` should produce a 4D nested **double** list with values `(px/255 - 0.5) / 0.5` directly (skip the int8 quantization step).
- OCR output buffers should be nested `double` lists, not `int`.
- The startup contract assertion should accept `float32` for input/output.
- `_argmaxInt` becomes `_argmax` over doubles (we already have that pattern).

When you send me the downloaded `.tflite`, paste the new startup tensor log and I'll patch `OnDeviceAiHelper` to match exactly what the new model expects. The Flutter changes will be ~30 lines, no architectural changes.

---

## What to do if Step 2 fails

Common issues and fixes:

| Symptom | Fix |
|---|---|
| `ModuleNotFoundError: ai_edge_torch` | The pip install didn't finish or the kernel wasn't restarted. Restart kernel and re-run install. |
| `RuntimeError: PyTorch X.Y not supported by ai_edge_torch` | Pin PyTorch: `!pip install -q torch==2.4.1 ai-edge-torch tensorflow==2.17.0` and restart. |
| Conversion succeeds but tensor 91 still missing in Flutter | Shouldn't happen with `ai_edge_torch`. If it does, report the exact tensor names from Step 3's log and we'll re-export through onnx2tf as a fallback. |
| Out of memory during conversion | Set `device="cpu"` everywhere when loading the checkpoint; conversion is CPU-only anyway. |

---

## Why this will work where the teammate's approach failed

The teammate's chain (`PyTorch → ONNX → SavedModel → TFLite`) goes through TF SavedModel, which by default exports model weights as **stateful resource variables**. The TFLite converter preserves these as `READ_VARIABLE_OP` tensors. Those tensors need initialization at runtime, which `tflite_flutter` does not perform.

`ai_edge_torch` skips TF entirely. It uses PyTorch's TorchScript / Dynamo path to lower the model graph directly into TFLite's FlatBuffer with weights inlined as constants. There is no SavedModel waypoint and there are no resource variables in the result — by construction.

This is the same library the Google Mobile AI team uses for their own PyTorch model deployments. It is the modern recommended path. The variable-tensor problem we have been chasing for two days is a *known* artifact of the old chain, and `ai_edge_torch` was built specifically to eliminate it.
