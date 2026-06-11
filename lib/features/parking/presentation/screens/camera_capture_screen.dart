import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gp_app/core/l10n/app_translations.dart';

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  String? _pendingPath;
  double _zoomLevel = 1.0;
  static const List<double> _zoomSteps = [1.0, 1.5, 2.0, 3.0];

  // Drives the capture overlay. A ValueNotifier (not setState) so only the
  // overlay rebuilds — rebuilding CameraAwesomeBuilder would reset the camera.
  final ValueNotifier<bool> _capturing = ValueNotifier(false);

  @override
  void dispose() {
    _capturing.dispose();
    super.dispose();
  }

  Future<SingleCaptureRequest> _buildPath(List<Sensor> sensors) async {
    final dir = await getTemporaryDirectory();
    _pendingPath =
        '${dir.path}/CAP${DateTime.now().millisecondsSinceEpoch}.jpg';
    return SingleCaptureRequest(_pendingPath!, sensors.first);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final frameW = size.width * 0.85;
    final frameH = frameW / 3.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraAwesomeBuilder.awesome(
            saveConfig: SaveConfig.photo(pathBuilder: _buildPath),

            // ── Top bar ────────────────────────────────────────────────
            topActionsBuilder: (state) => Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 8,
                vertical: MediaQuery.of(context).padding.top > 0 ? 0 : 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: _iconBox(Icons.arrow_back),
                  ),

                  // Flash menu button
                  _FlashMenuButton(state: state),
                ],
              ),
            ),

            // ── Guide frame ────────────────────────────────────────────
            middleContentBuilder: (state) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Guide frame
                  Container(
                    width: frameW,
                    height: frameH,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary, width: 2.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Hint text
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tr(context, 'align_plate_hint'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Bottom bar ─────────────────────────────────────────────
            bottomActionsBuilder: (state) => Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Zoom selector
                  _ZoomBar(
                    state: state,
                    currentZoom: _zoomLevel,
                    zoomSteps: _zoomSteps,
                    onZoomChanged: (z) => setState(() => _zoomLevel = z),
                  ),
                  const SizedBox(height: 20),
                  // Flip + Capture row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      AwesomeCameraSwitchButton(state: state),
                      _CaptureButton(
                        onTap: () {
                          if (_capturing.value) return; // ignore double-taps
                          final nav = Navigator.of(context);
                          _capturing.value = true; // show overlay immediately
                          state.when(
                            onPhotoMode: (photoState) async {
                              await photoState.takePhoto();
                              await Future.delayed(
                                const Duration(milliseconds: 400),
                              );
                              if (mounted && _pendingPath != null) {
                                nav.pop(_pendingPath);
                              }
                            },
                          );
                        },
                      ),
                      const SizedBox(width: 52), // balance
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Capture / processing overlay ──────────────────────────────
          ValueListenableBuilder<bool>(
            valueListenable: _capturing,
            builder: (context, capturing, _) {
              if (!capturing) return const SizedBox.shrink();
              return Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 3),
                      const SizedBox(height: 18),
                      Text(
                        tr(context, 'processing'),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _iconBox(IconData icon) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.5),
      shape: BoxShape.circle,
    ),
    child: Icon(icon, color: Colors.white, size: 22),
  );
}

// ── Flash popup menu ──────────────────────────────────────────────────────────

class _FlashMenuButton extends StatefulWidget {
  final CameraState state;
  const _FlashMenuButton({required this.state});

  @override
  State<_FlashMenuButton> createState() => _FlashMenuButtonState();
}

class _FlashMenuButtonState extends State<_FlashMenuButton> {
  FlashMode _current = FlashMode.none;

  IconData get _icon {
    switch (_current) {
      case FlashMode.on:
        return Icons.flash_on;
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
        return Icons.flashlight_on;
      default:
        return Icons.flash_off;
    }
  }

  void _apply(FlashMode mode) {
    setState(() => _current = mode);
    widget.state.when(onPhotoMode: (s) => s.sensorConfig.setFlashMode(mode));
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      (FlashMode.none, Icons.flash_off, tr(context, 'flash_off')),
      (FlashMode.on, Icons.flash_on, tr(context, 'flash_on')),
      (FlashMode.auto, Icons.flash_auto, tr(context, 'flash_auto')),
      (FlashMode.always, Icons.flashlight_on, tr(context, 'flash_torch')),
    ];

    return PopupMenuButton<FlashMode>(
      onSelected: _apply,
      color: const Color(0xFF1E2A3A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      offset: const Offset(0, 48),
      itemBuilder: (_) => items.map((entry) {
        final (mode, icon, label) = entry;
        final selected = _current == mode;
        return PopupMenuItem<FlashMode>(
          value: mode,
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? AppColors.primary : Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.primary : Colors.white,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (selected) ...[
                const Spacer(),
                const Icon(Icons.check, color: AppColors.primary, size: 16),
              ],
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(_icon, color: Colors.white, size: 22),
      ),
    );
  }
}

// ── Zoom bar ──────────────────────────────────────────────────────────────────

class _ZoomBar extends StatelessWidget {
  final CameraState state;
  final double currentZoom;
  final List<double> zoomSteps;
  final ValueChanged<double> onZoomChanged;

  const _ZoomBar({
    required this.state,
    required this.currentZoom,
    required this.zoomSteps,
    required this.onZoomChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: zoomSteps.map((z) {
          final selected = currentZoom == z;
          return GestureDetector(
            onTap: () {
              onZoomChanged(z);
              state.when(
                onPhotoMode: (s) => s.sensorConfig.setZoom(
                  // camerawesome zoom is 0.0–1.0; map our step to that range
                  ((z - 1.0) / (zoomSteps.last - 1.0)).clamp(0.0, 1.0),
                ),
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                z == z.truncateToDouble() ? '${z.toInt()}x' : '${z}x',
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Capture button ────────────────────────────────────────────────────────────

class _CaptureButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CaptureButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          color: Colors.white.withValues(alpha: 0.15),
        ),
        child: Center(
          child: Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
