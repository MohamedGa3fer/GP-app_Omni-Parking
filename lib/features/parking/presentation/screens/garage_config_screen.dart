import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/l10n/app_translations.dart';
import '../../domain/entities/zone_config.dart';
import '../../domain/repositories/parking_repository.dart';
import '../providers/parking_provider.dart';
import 'dashboard_screen.dart';

/// Builds (first run) or edits (from settings) the garage layout — the list of
/// zones, each with a name and a slot count.
class GarageConfigScreen extends StatefulWidget {
  final bool isFirstRun;
  const GarageConfigScreen({super.key, required this.isFirstRun});

  @override
  State<GarageConfigScreen> createState() => _GarageConfigScreenState();
}

class _EditableZone {
  final String? zoneId; // null = new
  final TextEditingController name;
  int capacity;
  _EditableZone({this.zoneId, required String name, required this.capacity})
    : name = TextEditingController(text: name);
}

class _GarageConfigScreenState extends State<GarageConfigScreen> {
  final List<_EditableZone> _zones = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Render immediately; existing zones (edit mode) pop in once loaded. Never
    // gate the whole screen on the async query — a failure must not blank it.
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    if (widget.isFirstRun) return;
    try {
      final config = await context.read<ParkingProvider>().getGarageConfig();
      if (!mounted) return;
      setState(() {
        _zones.addAll(config.map((z) => _EditableZone(
              zoneId: z.zoneId,
              name: z.name,
              capacity: z.capacity,
            )));
      });
    } catch (e) {
      debugPrint('GarageConfigScreen: failed to load existing config: $e');
    }
  }

  @override
  void dispose() {
    for (final z in _zones) {
      z.name.dispose();
    }
    super.dispose();
  }

  void _addZone() {
    setState(() => _zones.add(_EditableZone(name: '', capacity: 10)));
  }

  void _removeZone(int i) {
    setState(() {
      _zones[i].name.dispose();
      _zones.removeAt(i);
    });
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<ParkingProvider>();
    final zones = _zones
        .map(
          (z) => ZoneConfig(
            zoneId: z.zoneId,
            name: z.name.text.trim(),
            capacity: z.capacity,
          ),
        )
        .toList();

    setState(() => _saving = true);
    final result = await provider.saveGarageConfig(zones);
    if (!mounted) return;
    setState(() => _saving = false);

    switch (result.status) {
      case GarageConfigStatus.success:
        if (widget.isFirstRun) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          );
        } else {
          Navigator.pop(context);
          messenger.showSnackBar(
            SnackBar(
              content: Text(tr(context, 'garage_saved')),
              backgroundColor: AppColors.successGreen,
            ),
          );
        }
      case GarageConfigStatus.needAtLeastOneZone:
        _error(messenger, tr(context, 'need_at_least_one_zone'));
      case GarageConfigStatus.zoneHasParkedCars:
        _error(
          messenger,
          '${tr(context, 'zone_has_parked_cars')} "${result.blockedZoneName ?? ''}"',
        );
      case GarageConfigStatus.error:
        _error(messenger, tr(context, 'garage_save_error'));
    }
  }

  void _error(ScaffoldMessengerState messenger, String msg) {
    messenger.showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalSlots = _zones.fold<int>(0, (sum, z) => sum + z.capacity);

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.surface(isDark),
        centerTitle: true,
        automaticallyImplyLeading: !widget.isFirstRun,
        leading: widget.isFirstRun
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          tr(context, widget.isFirstRun ? 'garage_setup' : 'garage_layout'),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildHeader(context, isDark),
                const SizedBox(height: 20),
                ..._zones.asMap().entries.map(
                      (e) => _buildZoneCard(e.key, isDark),
                    ),
                const SizedBox(height: 8),
                _buildAddButton(context, isDark),
              ],
            ),
          ),
          _buildBottomBar(context, isDark, totalSlots),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.mainGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.apartment, color: Colors.white, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(
                    context,
                    widget.isFirstRun ? 'setup_title' : 'garage_layout',
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr(context, 'setup_subtitle'),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneCard(int i, bool isDark) {
    final zone = _zones[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: zone.name,
              style: TextStyle(color: AppColors.textPrimary(isDark)),
              decoration: InputDecoration(
                isDense: true,
                labelText: tr(context, 'zone_name'),
                labelStyle: TextStyle(
                  color: AppColors.textSecondaryColor(isDark),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppColors.background(isDark),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildStepper(zone, isDark),
          IconButton(
            tooltip: tr(context, 'remove_zone'),
            icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
            onPressed: () => _removeZone(i),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper(_EditableZone zone, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background(isDark),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove, size: 18, color: AppColors.primary),
            onPressed: zone.capacity > 1
                ? () => setState(() => zone.capacity--)
                : null,
          ),
          GestureDetector(
            onTap: () => _editCapacity(zone),
            child: SizedBox(
              width: 32,
              child: Text(
                '${zone.capacity}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary(isDark),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
            onPressed: () => setState(() => zone.capacity++),
          ),
        ],
      ),
    );
  }

  Future<void> _editCapacity(_EditableZone zone) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController(text: '${zone.capacity}');
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          tr(ctx, 'slots'),
          style: TextStyle(color: AppColors.textPrimary(isDark)),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary(isDark),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              tr(ctx, 'cancel'),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              final v = int.tryParse(controller.text.trim());
              Navigator.pop(ctx, (v == null || v < 1) ? 1 : v);
            },
            child: Text(
              tr(ctx, 'done'),
              style: const TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
    if (value != null) setState(() => zone.capacity = value);
  }

  Widget _buildAddButton(BuildContext context, bool isDark) {
    return InkWell(
      onTap: _addZone,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              tr(context, 'add_zone'),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, bool isDark, int totalSlots) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_zones.length} ${tr(context, 'zones')}',
                  style: TextStyle(
                    color: AppColors.textSecondaryColor(isDark),
                    fontSize: 12,
                  ),
                ),
                Text(
                  '$totalSlots ${tr(context, 'total_slots')}',
                  style: TextStyle(
                    color: AppColors.textPrimary(isDark),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: (_saving || _zones.isEmpty) ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              // Override the theme's full-width minimumSize — this button sits
              // in a Row, so it must size to its content (not infinite width).
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    tr(context, widget.isFirstRun ? 'finish' : 'save'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
