import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/l10n/app_translations.dart';
import '../../domain/entities/plate_result.dart';
import '../../domain/entities/zone.dart';
import '../../domain/repositories/parking_repository.dart';
import '../providers/parking_provider.dart';
import 'ticket_screen.dart';

class ZoneSelectionScreen extends StatefulWidget {
  final PlateResult plateResult;

  const ZoneSelectionScreen({super.key, required this.plateResult});

  @override
  State<ZoneSelectionScreen> createState() => _ZoneSelectionScreenState();
}

class _ZoneSelectionScreenState extends State<ZoneSelectionScreen> {
  String? _selectedZoneId;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ParkingProvider>(context, listen: false).loadZones();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<ParkingProvider>(context);
    final zones = provider.state.zones;
    final selectedZone = _findZone(zones, _selectedZoneId);

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.surface(isDark),
        title: Text(tr(context, 'choose_zone')),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.mainGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.directions_car,
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayPlate(widget.plateResult.plateText),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr(context, 'choose_zone'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            Text(
              tr(context, 'available_zones'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: zones.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : ListView.separated(
                      itemCount: zones.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, index) =>
                          _buildZoneCard(zones[index], isDark),
                    ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedZoneId != null && !_isProcessing
                    ? () => _confirmZone()
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        selectedZone == null
                            ? tr(context, 'confirm_zone').trim()
                            : '${tr(context, 'confirm_zone')}${selectedZone.name}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Zone? _findZone(List<Zone> zones, String? id) {
    if (id == null) return null;
    for (final zone in zones) {
      if (zone.id == id) return zone;
    }
    return null;
  }

  Widget _buildZoneCard(Zone zone, bool isDark) {
    final isSelected = _selectedZoneId == zone.id;

    return InkWell(
      onTap: zone.availableSpots > 0
          ? () => setState(() => _selectedZoneId = zone.id)
          : null,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryPink.withValues(alpha: 0.15)
              : AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryPink : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryPink.withValues(alpha: 0.2)
                    : AppColors.primaryPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.local_parking,
                color: isSelected
                    ? AppColors.primaryPink
                    : AppColors.primaryPurple,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    zone.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                  if (zone.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      zone.description!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryColor(isDark),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${zone.availableSpots}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: zone.availableSpots > 5
                        ? AppColors.successGreen
                        : zone.availableSpots > 0
                        ? Colors.orange
                        : Colors.red,
                  ),
                ),
                Text(
                  tr(context, 'available_spots'),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondaryColor(isDark),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmZone() async {
    if (_selectedZoneId == null) return;
    setState(() => _isProcessing = true);

    final provider = Provider.of<ParkingProvider>(context, listen: false);
    final zoneName =
        _findZone(provider.state.zones, _selectedZoneId)?.name ??
        _selectedZoneId!;
    final result = await provider.checkIn(
      widget.plateResult.plateText,
      _selectedZoneId!,
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    switch (result) {
      case CheckInResult.success:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TicketScreen(
              plateText: widget.plateResult.plateText,
              zoneName: zoneName,
              entryTime: DateTime.now(),
            ),
          ),
        );
      case CheckInResult.duplicate:
        _showError(tr(context, 'check_in_failed_duplicate'));
      case CheckInResult.garageFull:
        _showError(tr(context, 'garage_full'));
      case CheckInResult.error:
        _showError(tr(context, 'check_in_error'));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }
}
