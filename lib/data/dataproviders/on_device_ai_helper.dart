import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Public facade. Runs the entire detection + OCR pipeline on a background
/// isolate so the UI thread never freezes during recognition. The two TFLite
/// models are loaded once (from asset bytes) inside the worker isolate and kept
/// resident for the app's lifetime.
///
/// Singleton: `loadModel()` once at startup, then `recognizePlate()` per scan.
class OnDeviceAiHelper {
  static final OnDeviceAiHelper _instance = OnDeviceAiHelper._internal();
  factory OnDeviceAiHelper() => _instance;
  OnDeviceAiHelper._internal();

  Isolate? _isolate;
  SendPort? _commandPort;
  Future<void>? _loadFuture;

  /// True once the models are resident and recognition can run instantly.
  bool get isReady => _commandPort != null;

  /// Spawns the worker isolate and loads both models into it. Idempotent and
  /// concurrency-safe: callers from different places await the same in-flight
  /// load, and a failed load can be retried. Loads lazily on first use, so it's
  /// fine to call this only when the scanner opens.
  Future<void> loadModel() {
    if (_commandPort != null) return Future.value();
    return _loadFuture ??= _doLoadModel();
  }

  Future<void> _doLoadModel() async {
    try {
      // Asset bytes must be read on the main isolate (rootBundle needs the
      // binary messenger), then handed to the worker.
      final detData = await rootBundle.load('assets/plate_detection.tflite');
      final ocrData = await rootBundle.load('assets/plate_ocr.tflite');
      final detBytes = detData.buffer
          .asUint8List(detData.offsetInBytes, detData.lengthInBytes);
      final ocrBytes = ocrData.buffer
          .asUint8List(ocrData.offsetInBytes, ocrData.lengthInBytes);

      final handshake = ReceivePort();
      _isolate = await Isolate.spawn(
        _ocrIsolateEntry,
        _InitMessage(handshake.sendPort, detBytes, ocrBytes),
      );
      final ready = await handshake.first as _ReadyMessage;
      handshake.close();
      if (ready.error != null || ready.commandPort == null) {
        throw Exception('OCR model load failed: ${ready.error}');
      }
      _commandPort = ready.commandPort;
      debugPrint('OnDeviceAiHelper: worker isolate ready.');
    } catch (_) {
      _loadFuture = null; // allow a retry after a failed load
      rethrow;
    }
  }

  /// Sends the captured image path to the worker and awaits the read. The heavy
  /// work (decode, preprocess, both inferences, decode) happens off the UI
  /// thread, so this `await` never blocks rendering. Lazily loads the models on
  /// first use if they aren't resident yet.
  Future<PlateRecognition> recognizePlate(String imagePath) async {
    await loadModel();
    final port = _commandPort;
    if (port == null) throw Exception('Models not loaded');
    final reply = ReceivePort();
    port.send(_RecognizeRequest(imagePath, reply.sendPort));
    final res = await reply.first;
    reply.close();
    if (res is _ErrorReply) throw Exception(res.message);
    return res as PlateRecognition;
  }

  void close() {
    _commandPort?.send(const _CloseMessage());
    _commandPort = null;
    _loadFuture = null;
    _isolate?.kill(priority: Isolate.beforeNextEvent);
    _isolate = null;
  }
}

// ── Isolate message protocol ──────────────────────────────────────────────────

class _InitMessage {
  final SendPort replyTo;
  final Uint8List detBytes;
  final Uint8List ocrBytes;
  const _InitMessage(this.replyTo, this.detBytes, this.ocrBytes);
}

class _ReadyMessage {
  final SendPort? commandPort; // null if load failed
  final String? error;
  const _ReadyMessage(this.commandPort, this.error);
}

class _RecognizeRequest {
  final String imagePath;
  final SendPort replyTo;
  const _RecognizeRequest(this.imagePath, this.replyTo);
}

class _ErrorReply {
  final String message;
  const _ErrorReply(this.message);
}

class _CloseMessage {
  const _CloseMessage();
}

/// Worker isolate entry point. Loads the models from the passed-in buffers,
/// then serves recognition requests until told to close.
void _ocrIsolateEntry(_InitMessage init) async {
  final engine = _OcrEngine();
  try {
    engine.loadFromBuffers(init.detBytes, init.ocrBytes);
  } catch (e) {
    init.replyTo.send(_ReadyMessage(null, e.toString()));
    return;
  }

  final commands = ReceivePort();
  init.replyTo.send(_ReadyMessage(commands.sendPort, null));

  await for (final msg in commands) {
    if (msg is _RecognizeRequest) {
      try {
        final result = await engine.recognize(msg.imagePath);
        msg.replyTo.send(result);
      } catch (e) {
        msg.replyTo.send(_ErrorReply(e.toString()));
      }
    } else if (msg is _CloseMessage) {
      engine.close();
      commands.close();
      break;
    }
  }
}

// ── Worker-side engine (runs inside the isolate) ──────────────────────────────

/// Holds the two interpreters and the full pipeline. All heavy work lives here;
/// this class only ever runs on the worker isolate.
class _OcrEngine {
  static const int _detectionInputSize = 640; // 640x640 NHWC float32
  static const int _detectionOutputAnchors = 8400;
  static const int _detectionOutputChannels = 5; // cx, cy, w, h, conf
  static const int _ocrInputWidth = 320;
  static const int _ocrInputHeight = 96;
  static const int _ocrInputChannels = 3; // NCHW
  // Minimum YOLO box confidence to accept a detection as a real plate.
  // Real plates score ~0.89–0.91; random scenes (doors, screens, walls) score
  // well under 0.1, so 0.40 rejects junk while keeping a wide margin for
  // harder/distant plates. If genuine plates start getting rejected, lower
  // this; if non-plates still slip through, raise it (watch the
  // "YOLO best detection: conf=" log line to see what real vs junk score).
  static const double _confidenceThreshold = 0.40;
  static const double _minOcrConfidence = 0.60;

  Interpreter? _detectionInterpreter;
  Interpreter? _ocrInterpreter;

  // Letterbox transform parameters from last detection input build
  double _lbScale = 1.0;
  int _lbPadX = 0;
  int _lbPadY = 0;

  // OCR output index mapping, populated at load time.
  int _digitLogitsIdx = 0;
  int _letterLogitsIdx = 1;
  int _digitLenIdx = 2;
  int _letterLenIdx = 3;

  double _ocrInputScale = 0.0;
  int _ocrInputZeroPoint = 0;
  bool _ocrIsFloat32 = false;

  void loadFromBuffers(Uint8List detBytes, Uint8List ocrBytes) {
    _detectionInterpreter = Interpreter.fromBuffer(detBytes);
    _detectionInterpreter!.allocateTensors();
    debugPrint('--- Detection Model Tensors ---');
    _detectionInterpreter!.getInputTensors().forEach((t) => debugPrint(
        'Input -> Name: ${t.name}, Shape: ${t.shape}, Type: ${t.type}'));
    _detectionInterpreter!.getOutputTensors().forEach((t) => debugPrint(
        'Output -> Name: ${t.name}, Shape: ${t.shape}, Type: ${t.type}'));

    _ocrInterpreter = Interpreter.fromBuffer(ocrBytes);
    _ocrInterpreter!.allocateTensors();
    debugPrint('--- OCR Model Tensors ---');
    _ocrInterpreter!.getInputTensors().forEach((t) => debugPrint(
        'Input -> Name: ${t.name}, Shape: ${t.shape}, Type: ${t.type}'));
    _ocrInterpreter!.getOutputTensors().forEach((t) => debugPrint(
        'Output -> Name: ${t.name}, Shape: ${t.shape}, Type: ${t.type}, Params: scale=${t.params.scale} zp=${t.params.zeroPoint}'));

    _validateAndMapOcr();
  }

  /// Validates the OCR input contract and maps the four output tensors by
  /// shape + name. Fail fast on contract violation so a future model with a
  /// different shape can't silently corrupt reads.
  void _validateAndMapOcr() {
    final input = _ocrInterpreter!.getInputTensor(0);
    final shape = input.shape;
    if (shape.length != 4 ||
        shape[0] != 1 ||
        shape[1] != _ocrInputChannels ||
        shape[2] != _ocrInputHeight ||
        shape[3] != _ocrInputWidth) {
      throw StateError(
          'OCR input shape mismatch. expected=[1, $_ocrInputChannels, $_ocrInputHeight, $_ocrInputWidth] actual=$shape');
    }
    _ocrIsFloat32 = input.type.toString().toLowerCase().contains('float32');
    _ocrInputScale = input.params.scale;
    _ocrInputZeroPoint = input.params.zeroPoint;
    debugPrint(
        'OCR input contract OK: shape=$shape dtype=${input.type} float32=$_ocrIsFloat32 scale=$_ocrInputScale zeroPoint=$_ocrInputZeroPoint');

    // EALPR V6 output shapes are all distinct, so map each head directly by
    // shape: digits [1,4,11], letters [1,3,18] ('ي' removed, was 19), digit
    // length [1,4] (was [1,2]) and letter length [1,3] (was [1,2]).
    int? digitLogits;
    int? letterLogits;
    int? digitLen;
    int? letterLen;
    final outputs = _ocrInterpreter!.getOutputTensors();
    for (int i = 0; i < outputs.length; i++) {
      final s = outputs[i].shape;
      if (_shapeEquals(s, const [1, 4, 11])) {
        digitLogits = i;
      } else if (_shapeEquals(s, const [1, 3, 18])) {
        letterLogits = i;
      } else if (_shapeEquals(s, const [1, 4])) {
        digitLen = i;
      } else if (_shapeEquals(s, const [1, 3])) {
        letterLen = i;
      }
    }

    if (digitLogits == null ||
        letterLogits == null ||
        digitLen == null ||
        letterLen == null) {
      throw StateError(
          'OCR output mapping failed. Need [1,4,11], [1,3,18], [1,4], [1,3].');
    }

    _digitLogitsIdx = digitLogits;
    _letterLogitsIdx = letterLogits;
    _digitLenIdx = digitLen;
    _letterLenIdx = letterLen;
    debugPrint(
        'OCR output map: digits=$digitLogits letters=$letterLogits digitLen=$digitLen letterLen=$letterLen');
  }

  static bool _shapeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<PlateRecognition> recognize(String imagePath) async {
    if (_detectionInterpreter == null || _ocrInterpreter == null) {
      throw Exception('Models not loaded');
    }

    final imageBytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) throw Exception('Image decoding failed');
    final original = img.bakeOrientation(decoded);
    debugPrint(
        'Decoded image: ${decoded.width}x${decoded.height} → oriented ${original.width}x${original.height}');

    // ---- Stage 1: Detection (YOLOv8) ----
    // Flat Float32List written straight to the input tensor (no nested lists,
    // no per-pixel object allocation) → much less GC on weak devices.
    final detInput = _buildDetectionInput(original);
    final detIn = _detectionInterpreter!.getInputTensor(0);
    detIn.data = detInput.buffer
        .asUint8List(detInput.offsetInBytes, detInput.lengthInBytes);
    _detectionInterpreter!.invoke();
    final detOutBytes = _detectionInterpreter!.getOutputTensor(0).data;
    final detOut = Float32List.view(detOutBytes.buffer, detOutBytes.offsetInBytes,
        _detectionOutputChannels * _detectionOutputAnchors);

    final croppedPlate = _cropBestDetection(original, detOut);
    if (croppedPlate == null) throw Exception('No plate detected');

    // ---- Stage 2: OCR (PlateSlotTransformer) ----
    // Supports both float32 and int8 models: dtype is auto-detected at load time.
    final _OcrResult result;
    if (_ocrIsFloat32) {
      final ocrInput = _buildOcrInputFloat32(croppedPlate);
      final ocrIn = _ocrInterpreter!.getInputTensor(0);
      ocrIn.data = ocrInput.buffer
          .asUint8List(ocrInput.offsetInBytes, ocrInput.lengthInBytes);
      _ocrInterpreter!.invoke();

      final dB = _ocrInterpreter!.getOutputTensor(_digitLogitsIdx).data;
      final lB = _ocrInterpreter!.getOutputTensor(_letterLogitsIdx).data;
      final dlB = _ocrInterpreter!.getOutputTensor(_digitLenIdx).data;
      final llB = _ocrInterpreter!.getOutputTensor(_letterLenIdx).data;

      result = _decodePlate(
        digitLogits: _chunk(
            Float32List.view(dB.buffer, dB.offsetInBytes, 4 * 11), 11),
        letterLogits: _chunk(
            Float32List.view(lB.buffer, lB.offsetInBytes, 3 * 18), 18),
        digitLenLogits:
            Float32List.view(dlB.buffer, dlB.offsetInBytes, 4).toList(),
        letterLenLogits:
            Float32List.view(llB.buffer, llB.offsetInBytes, 3).toList(),
      );
    } else {
      // int8 model: quantized input, quantized outputs dequantized before decode.
      final ocrInput = _buildOcrInputInt8(croppedPlate).reshape<int>(
          [1, _ocrInputChannels, _ocrInputHeight, _ocrInputWidth]);
      final raw0 =
          List.generate(1, (_) => List.generate(4, (_) => List.filled(11, 0)));
      final raw1 =
          List.generate(1, (_) => List.generate(3, (_) => List.filled(18, 0)));
      final raw2 = List.generate(1, (_) => List.filled(4, 0));
      final raw3 = List.generate(1, (_) => List.filled(3, 0));
      _ocrInterpreter!.runForMultipleInputs([ocrInput], {
        _digitLogitsIdx: raw0,
        _letterLogitsIdx: raw1,
        _digitLenIdx: raw2,
        _letterLenIdx: raw3,
      });
      // Dequantize int8 → float so the same decoder handles both model types.
      final dq = _ocrInterpreter!.getOutputTensor;
      List<double> deq(List<int> q, int idx) {
        final p = dq(idx).params;
        return q.map((v) => (v - p.zeroPoint) * p.scale).toList();
      }

      result = _decodePlate(
        digitLogits: raw0[0].map((s) => deq(s, _digitLogitsIdx)).toList(),
        letterLogits: raw1[0].map((s) => deq(s, _letterLogitsIdx)).toList(),
        digitLenLogits: deq(raw2[0], _digitLenIdx),
        letterLenLogits: deq(raw3[0], _letterLenIdx),
      );
    }

    debugPrint(
        'OCR decoded: "${result.text}"  conf=${result.confidence.toStringAsFixed(3)}  valid=${result.isValid}  D=${result.digitLength} L=${result.letterLength}');

    if (result.text.isEmpty) {
      throw Exception('No readable plate (empty OCR output)');
    }

    final lowConfidence =
        !result.isValid || result.confidence < _minOcrConfidence;
    return PlateRecognition(
      text: result.text,
      confidence: result.confidence,
      isLowConfidence: lowConfidence,
    );
  }

  /// Detection input: flat Float32List for [1, 640, 640, 3] (NHWC), normalized
  /// to [0.0, 1.0]. YOLO-style letterbox (gray 114 pad). Reads the resized
  /// canvas's raw RGB bytes in one go instead of per-pixel getPixel().
  Float32List _buildDetectionInput(img.Image source) {
    final scale = math.min(
      _detectionInputSize / source.width,
      _detectionInputSize / source.height,
    );
    final newW = (source.width * scale).round();
    final newH = (source.height * scale).round();
    final padX = (_detectionInputSize - newW) ~/ 2;
    final padY = (_detectionInputSize - newH) ~/ 2;

    _lbScale = scale;
    _lbPadX = padX;
    _lbPadY = padY;

    final resized = img.copyResize(source, width: newW, height: newH);
    final canvas =
        img.Image(width: _detectionInputSize, height: _detectionInputSize);
    img.fill(canvas, color: img.ColorRgb8(114, 114, 114));
    img.compositeImage(canvas, resized, dstX: padX, dstY: padY);

    // Raw RGB bytes are interleaved row-major (HWC) — exactly NHWC order.
    final bytes = canvas.getBytes(order: img.ChannelOrder.rgb);
    final input = Float32List(_detectionInputSize * _detectionInputSize * 3);
    for (int i = 0; i < input.length; i++) {
      input[i] = bytes[i] / 255.0;
    }
    return input;
  }

  /// OCR input for float32 models: flat Float32List for [1, 3, 96, 320] (NCHW).
  /// Normalization: (px/255 - 0.5) / 0.5 → [-1.0, 1.0]. Transposes the raw
  /// HWC bytes into CHW planar order.
  Float32List _buildOcrInputFloat32(img.Image source) {
    final resized =
        img.copyResize(source, width: _ocrInputWidth, height: _ocrInputHeight);
    final bytes = resized.getBytes(order: img.ChannelOrder.rgb); // HWC
    final input = Float32List(_ocrInputChannels * _ocrInputHeight * _ocrInputWidth);
    final plane = _ocrInputHeight * _ocrInputWidth; // pixels per channel
    int p = 0; // walks the interleaved RGB bytes
    for (int y = 0; y < _ocrInputHeight; y++) {
      for (int x = 0; x < _ocrInputWidth; x++) {
        final hw = y * _ocrInputWidth + x;
        input[hw] = (bytes[p] / 255.0 - 0.5) / 0.5; // R → channel 0
        input[plane + hw] = (bytes[p + 1] / 255.0 - 0.5) / 0.5; // G → channel 1
        input[2 * plane + hw] = (bytes[p + 2] / 255.0 - 0.5) / 0.5; // B → channel 2
        p += 3;
      }
    }
    return input;
  }

  /// Splits a flat logits buffer into `rows` of `cols` for the decoder.
  List<List<double>> _chunk(Float32List flat, int cols) {
    final rows = flat.length ~/ cols;
    return List.generate(
        rows, (r) => List<double>.generate(cols, (c) => flat[r * cols + c]));
  }

  /// OCR input for int8 models: flat Int8List, NCHW, length 3*96*320.
  /// Quantized via tensor's own scale/zeroPoint after ImageNet normalization.
  Int8List _buildOcrInputInt8(img.Image source) {
    final resized =
        img.copyResize(source, width: _ocrInputWidth, height: _ocrInputHeight);
    final out = Int8List(_ocrInputChannels * _ocrInputHeight * _ocrInputWidth);
    int idx = 0;
    for (int c = 0; c < _ocrInputChannels; c++) {
      for (int y = 0; y < _ocrInputHeight; y++) {
        for (int x = 0; x < _ocrInputWidth; x++) {
          final p = resized.getPixel(x, y);
          final v = c == 0 ? p.r.toInt() : (c == 1 ? p.g.toInt() : p.b.toInt());
          final norm = (v / 255.0 - 0.5) / 0.5;
          final q = (norm / _ocrInputScale + _ocrInputZeroPoint).round();
          out[idx++] = q < -128 ? -128 : (q > 127 ? 127 : q);
        }
      }
    }
    return out;
  }

  /// Parses YOLOv8 output [1, 5, 8400] (flat, channel-major) and crops the best
  /// detection. Row `ch`, anchor `i` lives at `out[ch * anchors + i]`.
  img.Image? _cropBestDetection(img.Image source, Float32List out) {
    final n = _detectionOutputAnchors;
    final confBase = 4 * n; // channel 4 = confidence

    int bestIdx = -1;
    double bestConf = _confidenceThreshold;
    double maxConf = 0.0; // highest score seen, even below threshold (debug)
    for (int i = 0; i < n; i++) {
      final c = out[confBase + i];
      if (c > maxConf) maxConf = c;
      if (c > bestConf) {
        bestConf = c;
        bestIdx = i;
      }
    }
    if (bestIdx < 0) {
      debugPrint(
          'YOLO: no detection above threshold $_confidenceThreshold (max seen=${maxConf.toStringAsFixed(3)})');
      return null;
    }

    final cx = out[bestIdx] * _detectionInputSize; // channel 0
    final cy = out[n + bestIdx] * _detectionInputSize; // channel 1
    final w = out[2 * n + bestIdx] * _detectionInputSize; // channel 2
    final h = out[3 * n + bestIdx] * _detectionInputSize; // channel 3

    final x1Lb = cx - w / 2;
    final y1Lb = cy - h / 2;
    final x2Lb = cx + w / 2;
    final y2Lb = cy + h / 2;

    final cropX =
        ((x1Lb - _lbPadX) / _lbScale).clamp(0, source.width - 1).toInt();
    final cropY =
        ((y1Lb - _lbPadY) / _lbScale).clamp(0, source.height - 1).toInt();
    final cropX2 = ((x2Lb - _lbPadX) / _lbScale)
        .clamp(0, source.width.toDouble())
        .toInt();
    final cropY2 = ((y2Lb - _lbPadY) / _lbScale)
        .clamp(0, source.height.toDouble())
        .toInt();
    final cropW = cropX2 - cropX;
    final cropH = cropY2 - cropY;

    debugPrint(
        'YOLO best detection: conf=$bestConf  crop=$cropX,$cropY ${cropW}x$cropH (source ${source.width}x${source.height})');

    if (cropW <= 0 || cropH <= 0) return null;

    return img.copyCrop(source,
        x: cropX, y: cropY, width: cropW, height: cropH);
  }

  // Character maps for EALPR V6. The 17-letter order is the authoritative
  // sequence from the V6 migration report (model author): the letter 'ي' was
  // scrubbed to match the official Egyptian standard, so the alphabet is now
  // 17 letters + PAD (PAD index 17, letter head shape [1,3,18]).
  static const List<String> _digits = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'
  ];
  static const List<String> _arabicLetters = [
    'أ', 'ب', 'ج', 'د', 'ر', 'س', 'ص', 'ط', 'ع',
    'ف', 'ق', 'ك', 'ل', 'م', 'ن', 'ه', 'و',
  ];
  static const int _digitPadClass = 10;
  static const int _letterPadClass = 17;

  /// Decodes the four PlateSlotTransformer outputs into a structured result.
  _OcrResult _decodePlate({
    required List<List<double>> digitLogits,
    required List<List<double>> letterLogits,
    required List<double> digitLenLogits,
    required List<double> letterLenLogits,
  }) {
    // V6 length heads are zero-indexed from length 1 (unified argmax + 1).
    final digitLength = _argmaxDouble(digitLenLogits) + 1; // 0→1 … 3→4
    final letterLength = _argmaxDouble(letterLenLogits) + 1; // 0→1 … 2→3

    final digitChars = StringBuffer();
    final letterChars = StringBuffer();
    double confSum = 0.0;
    int confCount = 0;
    bool hasPad = false;

    final boundedD = math.min(digitLength, digitLogits.length);
    for (int slot = 0; slot < boundedD; slot++) {
      final logits = digitLogits[slot];
      final cls = _argmaxDouble(logits);
      if (cls == _digitPadClass || cls < 0 || cls >= _digits.length) {
        hasPad = true;
        continue;
      }
      digitChars.write(_digits[cls]);
      confSum += _slotSoftmaxConfidenceDouble(logits);
      confCount++;
    }

    final boundedL = math.min(letterLength, letterLogits.length);
    for (int slot = 0; slot < boundedL; slot++) {
      final logits = letterLogits[slot];
      final cls = _argmaxDouble(logits);
      if (cls == _letterPadClass || cls < 0 || cls >= _arabicLetters.length) {
        hasPad = true;
        continue;
      }
      letterChars.write(_arabicLetters[cls]);
      confSum += _slotSoftmaxConfidenceDouble(logits);
      confCount++;
    }

    // Canonical compact format: digits + letters. The model emits letters in
    // left-to-right slot order; Egyptian plates read letters right-to-left, so
    // we reverse them here to match how the plate is physically written
    // (e.g. slots ع‑ج‑م → "مجع"). Done once at the source so every screen and
    // the DB stay consistent.
    final reversedLetters = letterChars.toString().split('').reversed.join();
    final text = '${digitChars.toString()}$reversedLetters';
    final confidence = confCount == 0 ? 0.0 : confSum / confCount;
    // V6 supports 1–4 digits and 1–3 letters (was locked to 3–4 / 2–3 in V4).
    final isValid = !hasPad &&
        digitLength >= 1 &&
        digitLength <= 4 &&
        letterLength >= 1 &&
        letterLength <= 3 &&
        digitChars.length == digitLength &&
        letterChars.length == letterLength;

    return _OcrResult(
      text: text,
      confidence: confidence,
      digitLength: digitLength,
      letterLength: letterLength,
      isValid: isValid,
    );
  }

  int _argmaxDouble(List<double> logits) {
    int bestIdx = 0;
    double bestVal = logits[0];
    for (int i = 1; i < logits.length; i++) {
      if (logits[i] > bestVal) {
        bestVal = logits[i];
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  /// Numerically stable max-softmax probability for a single slot (float32).
  double _slotSoftmaxConfidenceDouble(List<double> logits) {
    if (logits.isEmpty) return 0.0;
    double maxV = logits[0];
    for (final v in logits) {
      if (v > maxV) maxV = v;
    }
    double sum = 0.0;
    double maxExp = 0.0;
    for (final v in logits) {
      final e = math.exp(v - maxV);
      sum += e;
      if (e > maxExp) maxExp = e;
    }
    return sum == 0.0 ? 0.0 : maxExp / sum;
  }

  void close() {
    _detectionInterpreter?.close();
    _detectionInterpreter = null;
    _ocrInterpreter?.close();
    _ocrInterpreter = null;
  }
}

/// Public result of [OnDeviceAiHelper.recognizePlate].
/// [isLowConfidence] is true when the read is below the confidence threshold
/// or fails the plate-format validity check — the UI should ask the user to
/// verify/correct it rather than trusting it outright.
class PlateRecognition {
  const PlateRecognition({
    required this.text,
    required this.confidence,
    required this.isLowConfidence,
  });

  final String text;
  final double confidence;
  final bool isLowConfidence;
}

class _OcrResult {
  const _OcrResult({
    required this.text,
    required this.confidence,
    required this.digitLength,
    required this.letterLength,
    required this.isValid,
  });

  final String text;
  final double confidence;
  final int digitLength;
  final int letterLength;
  final bool isValid;
}
