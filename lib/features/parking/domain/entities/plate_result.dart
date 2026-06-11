class PlateResult {
  final String plateText;
  final double confidence;
  final bool isLowConfidence;

  const PlateResult({
    required this.plateText,
    this.confidence = 1.0,
    this.isLowConfidence = false,
  });
}
