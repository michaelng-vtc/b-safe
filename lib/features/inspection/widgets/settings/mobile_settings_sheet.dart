import 'package:flutter/material.dart';
import 'package:bsafe_app/models/uwb_model.dart';
import 'package:bsafe_app/services/uwb_service.dart';
import 'package:bsafe_app/core/theme/app_theme.dart';

class InspectionMobileSettingsSheet extends StatelessWidget {
  final UwbService uwbService;
  final Widget Function(
    String label,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) buildToggle;
  final Future<void> Function() onLoadFloorPlan;
  final Widget Function(String title, IconData icon) buildSectionHeader;
  final Widget Function(UwbAnchor anchor, int index, UwbService uwbService)
      buildAnchorTile;
  final VoidCallback onAddAnchor;
  final String distanceMappingDescription;
  final Widget Function(UwbService uwbService, String label, int i, int j)
      buildDistanceSwapButton;
  final VoidCallback onShowRoomDimensions;

  const InspectionMobileSettingsSheet({
    super.key,
    required this.uwbService,
    required this.buildToggle,
    required this.onLoadFloorPlan,
    required this.buildSectionHeader,
    required this.buildAnchorTile,
    required this.onAddAnchor,
    required this.distanceMappingDescription,
    required this.buildDistanceSwapButton,
    required this.onShowRoomDimensions,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: uwbService,
      builder: (context, _) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.tune, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  const Text('Settings',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        buildToggle('Trajectory', Icons.timeline,
                            uwbService.config.showTrajectory, (v) {
                          uwbService.updateConfig(
                              uwbService.config.copyWith(showTrajectory: v));
                        }),
                        buildToggle(
                            'Fence', Icons.fence, uwbService.config.showFence,
                            (v) {
                          uwbService.updateConfig(
                              uwbService.config.copyWith(showFence: v));
                        }),
                        buildToggle('Floor Plan', Icons.map,
                            uwbService.config.showFloorPlan, (v) {
                          uwbService.updateConfig(
                              uwbService.config.copyWith(showFloorPlan: v));
                        }),
                      ],
                    ),
                    if (uwbService.config.floorPlanImagePath != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.layers,
                                    size: 16, color: Colors.blue.shade700),
                                const SizedBox(width: 6),
                                Text(
                                  'Floor Plan Opacity',
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${(uwbService.config.floorPlanOpacity * 100).round()}%',
                                    style: TextStyle(
                                      color: Colors.blue.shade800,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Icon(Icons.opacity,
                                    size: 14, color: Colors.blue.shade300),
                                Expanded(
                                  child: Slider(
                                    value: uwbService.config.floorPlanOpacity,
                                    min: 0.1,
                                    max: 1.0,
                                    divisions: 18,
                                    activeColor: Colors.blue.shade600,
                                    inactiveColor: Colors.blue.shade100,
                                    onChanged:
                                        uwbService.updateFloorPlanOpacity,
                                  ),
                                ),
                                Icon(Icons.opacity,
                                    size: 20, color: Colors.blue.shade600),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: uwbService.clearTrajectory,
                            icon: const Icon(Icons.delete_sweep, size: 18),
                            label: const Text('Clear Trajectory'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onLoadFloorPlan,
                            icon: const Icon(Icons.image, size: 18),
                            label: const Text('Load Floor Plan'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onShowRoomDimensions,
                        icon: const Icon(Icons.square_foot, size: 18),
                        label: const Text('Enter Room Dimensions'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    buildSectionHeader('Anchor Management', Icons.cell_tower),
                    const SizedBox(height: 8),
                    ...uwbService.anchors.asMap().entries.map((entry) =>
                        buildAnchorTile(entry.value, entry.key, uwbService)),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onAddAnchor,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Anchor'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    buildSectionHeader(
                        'Distance Index Mapping', Icons.swap_horiz),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select multiple swap pairs. E.g.: D0↔D1 then D2↔D3.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.orange.shade800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Current Mapping: $distanceMappingDescription',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        buildDistanceSwapButton(uwbService, 'D0↔D1', 0, 1),
                        buildDistanceSwapButton(uwbService, 'D0↔D2', 0, 2),
                        buildDistanceSwapButton(uwbService, 'D0↔D3', 0, 3),
                        buildDistanceSwapButton(uwbService, 'D1↔D2', 1, 2),
                        buildDistanceSwapButton(uwbService, 'D1↔D3', 1, 3),
                        buildDistanceSwapButton(uwbService, 'D2↔D3', 2, 3),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () {
                          uwbService.updateConfig(
                            uwbService.config.copyWith(
                              distanceIndexMap: const [0, 1, 2, 3],
                            ),
                          );
                        },
                        icon: const Icon(Icons.restore, size: 16),
                        label: const Text('Reset to Default [0,1,2,3]'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
