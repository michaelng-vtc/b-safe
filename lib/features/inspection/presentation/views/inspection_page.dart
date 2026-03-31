import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:bsafe_app/shared/models/uwb_model.dart';
import 'package:bsafe_app/shared/models/inspection_model.dart';
import 'package:bsafe_app/shared/models/project_model.dart';
import 'package:bsafe_app/shared/services/uwb_service.dart';
import 'package:bsafe_app/shared/services/desktop_serial_service.dart';
import 'package:bsafe_app/shared/services/mobile_serial_service.dart';
import 'package:bsafe_app/shared/services/yolo_service.dart';
import 'package:bsafe_app/features/ai_analysis/presentation/providers/ai_provider.dart';
import 'package:bsafe_app/features/ai_analysis/presentation/screens/ai_analysis_screen.dart';
import 'package:bsafe_app/features/inspection/presentation/providers/inspection_provider.dart';
import 'package:bsafe_app/core/theme/app_theme.dart';

import 'package:bsafe_app/features/inspection/presentation/widgets/settings/inspection_settings_bottom_sheet.dart';
import 'package:bsafe_app/features/inspection/presentation/widgets/pins/inspection_pin_list_bottom_sheet.dart';
import 'package:bsafe_app/shared/services/api_service.dart';
import 'package:bsafe_app/shared/services/word_export_service.dart';
import 'package:bsafe_app/shared/services/pdf_export_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

/// Main inspection workflow screen.
///
/// Supports UWB pin placement and export actions.
class InspectionScreen extends StatefulWidget {
  final Project? project;
  const InspectionScreen({super.key, this.project});

  @override
  State<InspectionScreen> createState() => _InspectionScreenState();
}

class _InspectionScreenState extends State<InspectionScreen> {
  late UwbService _uwbService;
  bool _showSettings = false;
  bool _showPinList = true;
  bool _showFullSettings = false;
  int _currentFloor = 1;
  bool _isAnchorPlacementMode = false;
  int? _anchorPlacementIndex;

  // Serial settings.
  int _baudRate = 115200;

  @override
  void initState() {
    super.initState();
    _uwbService = UwbService();
    _uwbService.loadAnchorsFromStorage();
    if (widget.project != null) {
      _currentFloor = widget.project!.currentFloor;
    }
  }

  @override
  void dispose() {
    _uwbService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _uwbService,
      child: Consumer2<UwbService, InspectionProvider>(
        builder: (context, uwbService, inspection, _) {
          final screenWidth = MediaQuery.of(context).size.width;
          final isMobile = screenWidth < 600;

          return Scaffold(
            backgroundColor: Colors.grey.shade50,
            body: SafeArea(
              child: Column(
                children: [
                  // (mobile/ ).
                  isMobile
                      ? _buildMobileTopBar(uwbService, inspection)
                      : _buildTopBar(uwbService, inspection),
                  // Content.
                  Expanded(
                    child: isMobile
                        ? _buildMapArea(uwbService, inspection)
                        : Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildMapArea(uwbService, inspection),
                              ),
                              if (_showPinList)
                                SizedBox(
                                  width: 320,
                                  child: _buildPinListPanel(inspection),
                                ),
                              if (_showFullSettings) ...[
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 300,
                                  child: _buildFullSettingsPanel(
                                      uwbService, inspection),
                                ),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            ),
            floatingActionButton: _buildFAB(uwbService, inspection),
            // Mobile.
            bottomNavigationBar:
                isMobile ? _buildMobileBottomBar(uwbService, inspection) : null,
          );
        },
      ),
    );
  }

  // ===== mobile ( ) =====.
  Widget _buildMobileTopBar(
      UwbService uwbService, InspectionProvider inspection) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border:
            Border(bottom: BorderSide(color: AppTheme.borderColor, width: 1)),
      ),
      child: Row(
        children: [
          // App title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryLight,
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_rounded, color: Colors.white, size: 14),
                SizedBox(width: 3),
                Text(
                  'B-SAFE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // UWB connect.
          Expanded(
            child: Center(
              child: _buildConnectionChip(uwbService),
            ),
          ),

          if (widget.project != null) ...[
            const SizedBox(width: 6),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => _showFloorSelector(inspection, uwbService),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_currentFloor}F',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          // Translated legacy note.
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (value) => _handleMenuAction(value, inspection),
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: 'export_word', child: Text('Export Word')),
              const PopupMenuItem(
                  value: 'export_pdf', child: Text('Export PDF')),
              const PopupMenuDivider(),
              const PopupMenuItem(
                  value: 'clear_pins', child: Text('Clear All Pins')),
            ],
          ),
        ],
      ),
    );
  }

  // ===== mobile =====.
  Widget _buildMobileBottomBar(
      UwbService uwbService, InspectionProvider inspection) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.borderColor, width: 1)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Translated legacy note.
              _buildBottomBarItem(
                icon: Icons.tune,
                label: 'Settings',
                onTap: () => _showMobileSettingsSheet(uwbService),
              ),
              // Coordinateshow.
              _buildBottomBarItem(
                icon: Icons.my_location,
                label: uwbService.currentTag != null
                    ? '${uwbService.currentTag!.x.toStringAsFixed(1)},${uwbService.currentTag!.y.toStringAsFixed(1)}'
                    : 'Not Located',
                onTap: () {},
                color:
                    uwbService.currentTag != null ? Colors.indigo : Colors.grey,
              ),
              // Inspection.
              _buildBottomBarItem(
                icon: Icons.push_pin,
                label: 'Pins (${inspection.currentPins.length})',
                onTap: () => _showMobilePinListSheet(inspection),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBarItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c = color ?? AppTheme.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: c),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                  fontSize: 10, color: c, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ===== mobile Pin Bottom Sheet =====.
  void _showMobilePinListSheet(InspectionProvider inspection) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => InspectionPinListBottomSheet(
          scrollController: scrollController,
          buildPinSummary: _buildPinSummary,
          buildEmptyPinState: _buildEmptyPinState,
          buildPinCard: _buildPinCard,
        ),
      ),
    );
  }

  // ===== mobile Bottom Sheet =====.
  void _showMobileSettingsSheet(UwbService uwbService) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (context, scrollController) => Consumer<InspectionProvider>(
          builder: (context, inspection, _) => InspectionSettingsBottomSheet(
            uwbService: uwbService,
            buildToggle: _buildToggle,
            buildSectionHeader: _buildSectionHeader,
            buildAnchorTile: _buildAnchorTile,
            onAddAnchor: () => _showAddAnchorDialog(uwbService),
            onPlaceAnchorOnMap: () => _startAnchorPlacement(),
            distanceMappingDescription:
                _describeDistanceMapping(uwbService.config.distanceIndexMap),
            buildDistanceSwapButton: _buildDistanceSwapButton,
            onShowRoomDimensions: () => _showRoomDimensionDialog(uwbService),
            showDeleteFloorPlanButton: inspection.currentFloorPlans.isNotEmpty,
            onDeleteFloorPlan: () async {
              final selectedOrder = inspection.selectedFloorPlanOrder;
              final fallbackOrder = inspection.currentFloorPlans.isNotEmpty
                  ? inspection.currentFloorPlans.first.order
                  : null;
              final targetOrder = selectedOrder ?? fallbackOrder;
              if (targetOrder == null) return;

              final removed = inspection.deleteFloorPlanSegment(targetOrder);
              if (!removed) return;

              final updatedPlans = inspection.currentFloorPlans;
              if (updatedPlans.isNotEmpty) {
                final selected = inspection.selectedFloorPlanOrder;
                final plan = updatedPlans.firstWhere(
                  (segment) => segment.order == selected,
                  orElse: () => updatedPlans.first,
                );
                await uwbService.loadFloorPlanImage(plan.path);
                uwbService.updateConfig(
                    uwbService.config.copyWith(showFloorPlan: true));
              } else {
                uwbService.clearFloorPlan();
              }
            },
          ),
        ),
      ),
    );
  }

  // Translated legacy comment.
  Widget _buildTopBar(UwbService uwbService, InspectionProvider inspection) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // App title.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withValues(alpha: 0.8)
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield, color: Colors.white, size: 20),
                SizedBox(width: 6),
                Text(
                  'B-SAFE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // UWB connect.
          Expanded(
            child: Center(
              child: _buildConnectionChip(uwbService),
            ),
          ),

          if (widget.project != null) ...[
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _showFloorSelector(inspection, uwbService),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.layers,
                          size: 14, color: Colors.orange.shade800),
                      const SizedBox(width: 4),
                      Text(
                        '${_currentFloor}F',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.keyboard_arrow_down,
                          size: 16, color: Colors.orange.shade800),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Translated legacy note.
          if (uwbService.isConnected && uwbService.currentTag != null)
            _buildCoordinateChip(uwbService),

          // Translated legacy note.
          if (inspection.currentSession != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_open,
                      size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 6),
                  Text(
                    inspection.currentSession!.name,
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${inspection.currentPins.length} pins)',
                    style: TextStyle(
                      color: Colors.blue.shade400,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(width: 8),

          // Button.
          IconButton(
            onPressed: () => setState(() => _showSettings = !_showSettings),
            icon: Icon(
              _showSettings ? Icons.settings : Icons.settings_outlined,
              color:
                  _showSettings ? AppTheme.primaryColor : Colors.grey.shade600,
            ),
            tooltip: 'Show Settings',
          ),
          IconButton(
            onPressed: () =>
                setState(() => _showFullSettings = !_showFullSettings),
            icon: Icon(
              Icons.tune,
              color: _showFullSettings ? Colors.orange : Colors.grey.shade600,
            ),
            tooltip: 'Full Settings',
          ),
          IconButton(
            onPressed: () => setState(() => _showPinList = !_showPinList),
            icon: Icon(
              _showPinList ? Icons.view_sidebar : Icons.view_sidebar_outlined,
              color:
                  _showPinList ? AppTheme.primaryColor : Colors.grey.shade600,
            ),
            tooltip: 'Inspection Points',
          ),
          const SizedBox(width: 4),
          // Translated legacy note.
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _handleMenuAction(value, inspection),
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: 'export_word', child: Text('Export Word')),
              const PopupMenuItem(
                  value: 'export_pdf', child: Text('Export PDF')),
              const PopupMenuDivider(),
              const PopupMenuItem(
                  value: 'clear_pins', child: Text('Clear All Pins')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionChip(UwbService uwbService) {
    final isConnected = uwbService.isConnected;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isConnected
            ? () => uwbService.disconnect()
            : () => _showConnectDialog(uwbService),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isConnected ? Colors.green.shade50 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isConnected ? Colors.green.shade300 : Colors.grey.shade300,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isConnected ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  isConnected
                      ? (uwbService.isRealDevice
                          ? 'UWB Connected'
                          : 'Simulation Mode')
                      : 'UWB Disconnected',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isConnected
                        ? Colors.green.shade700
                        : Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoordinateChip(UwbService uwbService) {
    final tag = uwbService.currentTag!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.my_location, size: 14, color: Colors.indigo.shade600),
          const SizedBox(width: 6),
          Text(
            'X: ${tag.x.toStringAsFixed(2)}  Y: ${tag.y.toStringAsFixed(2)}',
            style: TextStyle(
              color: Colors.indigo.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  // Translated legacy comment.
  Widget _buildMapArea(UwbService uwbService, InspectionProvider inspection) {
    return Column(
      children: [
        // Translated legacy note.
        if (_showSettings) _buildQuickSettings(uwbService),

        // Translated legacy note.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Stack(
              children: [
                // UWB + Pin.
                _buildInspectionCanvas(uwbService, inspection),

                // Pin mode.
                if (inspection.isPinMode)
                  Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade700,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withValues(alpha: 0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.push_pin,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              MediaQuery.of(context).size.width < 600
                                  ? 'Tap canvas to place Pin'
                                  : 'Tap canvas to place Pin',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                if (_isAnchorPlacementMode)
                  Positioned(
                    top: inspection.isPinMode ? 52 : 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade700,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.teal.withValues(alpha: 0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.place,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _anchorPlacementIndex == null
                                  ? 'Tap canvas to add Anchor'
                                  : 'Tap canvas to set Anchor position',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Loadfloor button ( floor plan ).
                if (uwbService.floorPlanImage == null &&
                    !uwbService.config.showFloorPlan)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: ElevatedButton.icon(
                      onPressed: () => _loadFloorPlan(uwbService, inspection),
                      icon: const Icon(Icons.map, size: 18),
                      label: const Text('Load Floor Plan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryColor,
                        elevation: 4,
                      ),
                    ),
                  ),

                // Distance Debug (show anchordistance).
                if (uwbService.isConnected && uwbService.currentTag != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Distance Debug',
                              style: TextStyle(
                                  color: Colors.yellow,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          ...uwbService.currentTag!.anchorDistances.entries
                              .map((e) {
                            final isMin = uwbService
                                        .currentTag!.anchorDistances.values
                                        .where((v) => v > 0)
                                        .fold<double>(double.infinity, min) ==
                                    e.value &&
                                e.value > 0;
                            return Text(
                              '${e.key}: ${e.value.toStringAsFixed(2)}m',
                              style: TextStyle(
                                color:
                                    isMin ? Colors.greenAccent : Colors.white,
                                fontSize: 10,
                                fontWeight:
                                    isMin ? FontWeight.bold : FontWeight.normal,
                              ),
                            );
                          }),
                          const SizedBox(height: 2),
                          Text(
                            'pos: (${uwbService.currentTag!.x.toStringAsFixed(2)}, ${uwbService.currentTag!.y.toStringAsFixed(2)})',
                            style: const TextStyle(
                                color: Colors.cyanAccent, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===== Pin inspection =====.
  Widget _buildInspectionCanvas(
      UwbService uwbService, InspectionProvider inspection) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (details) {
            if (_isAnchorPlacementMode) {
              final uwbCoord = _canvasToUwb(
                details.localPosition,
                Size(constraints.maxWidth, constraints.maxHeight),
                uwbService,
              );
              if (uwbCoord != null) {
                _placeAnchorAt(uwbCoord, uwbService);
              }
              return;
            }

            if (inspection.isPinMode) {
              // UWB coordinate.
              final uwbCoord = _canvasToUwb(
                details.localPosition,
                Size(constraints.maxWidth, constraints.maxHeight),
                uwbService,
              );
              if (uwbCoord != null) {
                final pin = inspection.addPin(uwbCoord.dx, uwbCoord.dy);
                _openAiAnalysisScreen(pin);
              }
            } else {
              // Pin.
              _checkPinTap(
                details.localPosition,
                Size(constraints.maxWidth, constraints.maxHeight),
                uwbService,
                inspection,
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: inspection.isPinMode
                    ? Colors.orange.shade400
                    : Colors.grey.shade300,
                width: inspection.isPinMode ? 2 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                isComplex: true,
                willChange: true,
                painter: InspectionCanvasPainter(
                  anchors: uwbService.anchors,
                  currentTag: uwbService.currentTag,
                  config: uwbService.config,
                  floorPlanImage: uwbService.floorPlanImage,
                  pins: inspection.currentPins,
                  selectedPinId: inspection.selectedPin?.id,
                  padding: 40.0,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Painter coordinate ( ).
  ({double minX, double maxX, double minY, double maxY}) _computeViewportBounds(
      UwbService uwbService) {
    final anchors = uwbService.anchors;
    double minX = anchors.map((a) => a.x).reduce(min) - 1;
    double maxX = anchors.map((a) => a.x).reduce(max) + 1;
    double minY = anchors.map((a) => a.y).reduce(min) - 1;
    double maxY = anchors.map((a) => a.y).reduce(max) + 1;

    final config = uwbService.config;
    final floorPlanImage = uwbService.floorPlanImage;
    if (config.showFloorPlan && floorPlanImage != null) {
      final img = floorPlanImage;
      final realWidth = img.width.toDouble() / config.xScale;
      final realHeight = img.height.toDouble() / config.yScale;
      final imgLeft = config.xOffset;
      final imgBottom = config.yOffset;
      final imgRight = imgLeft + realWidth;
      final imgTop = imgBottom + realHeight;
      minX = min(minX, imgLeft - 0.5);
      maxX = max(maxX, imgRight + 0.5);
      minY = min(minY, imgBottom - 0.5);
      maxY = max(maxY, imgTop + 0.5);
    }

    return (minX: minX, maxX: maxX, minY: minY, maxY: maxY);
  }

  /// Coordinate UWB coordinate.
  Offset? _canvasToUwb(
      Offset canvasPos, Size canvasSize, UwbService uwbService) {
    if (uwbService.anchors.isEmpty) return null;

    const double padding = 40.0;
    final bounds = _computeViewportBounds(uwbService);

    final double rangeX = bounds.maxX - bounds.minX;
    final double rangeY = bounds.maxY - bounds.minY;

    final double scaleX = (canvasSize.width - padding * 2) / rangeX;
    final double scaleY = (canvasSize.height - padding * 2) / rangeY;
    final double scale = min(scaleX, scaleY);

    final double offsetX = (canvasSize.width - rangeX * scale) / 2;
    final double offsetY = (canvasSize.height - rangeY * scale) / 2;

    // (canvas → uwb).
    final double uwbX = (canvasPos.dx - offsetX) / scale + bounds.minX;
    final double uwbY =
        (canvasSize.height - canvasPos.dy - offsetY) / scale + bounds.minY;

    return Offset(uwbX, uwbY);
  }

  /// Pin.
  void _checkPinTap(Offset tapPos, Size canvasSize, UwbService uwbService,
      InspectionProvider inspection) {
    if (uwbService.anchors.isEmpty) return;

    const double padding = 40.0;
    final bounds = _computeViewportBounds(uwbService);

    final double rangeX = bounds.maxX - bounds.minX;
    final double rangeY = bounds.maxY - bounds.minY;

    final double scaleX = (canvasSize.width - padding * 2) / rangeX;
    final double scaleY = (canvasSize.height - padding * 2) / rangeY;
    final double scale = min(scaleX, scaleY);

    final double offsetXCanvas = (canvasSize.width - rangeX * scale) / 2;
    final double offsetYCanvas = (canvasSize.height - rangeY * scale) / 2;

    for (final pin in inspection.currentPins) {
      final pinCanvasX = offsetXCanvas + (pin.x - bounds.minX) * scale;
      final pinCanvasY =
          canvasSize.height - offsetYCanvas - (pin.y - bounds.minY) * scale;
      final dist = (tapPos - Offset(pinCanvasX, pinCanvasY)).distance;
      if (dist < 20) {
        inspection.selectPin(pin);
        _openAiAnalysisScreen(pin);
        return;
      }
    }
    inspection.deselectPin();
  }

  // Translated legacy comment.
  Widget _buildQuickSettings(UwbService uwbService) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: isMobile
          ? Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildToggle('Fence', Icons.fence, uwbService.config.showFence,
                    (v) {
                  uwbService
                      .updateConfig(uwbService.config.copyWith(showFence: v));
                }),
                _buildToggle(
                    'Floor Plan', Icons.map, uwbService.config.showFloorPlan,
                    (v) {
                  uwbService.updateConfig(
                      uwbService.config.copyWith(showFloorPlan: v));
                }),
              ],
            )
          : Row(
              children: [
                _buildToggle('Fence', Icons.fence, uwbService.config.showFence,
                    (v) {
                  uwbService
                      .updateConfig(uwbService.config.copyWith(showFence: v));
                }),
                _buildToggle(
                    'Floor Plan', Icons.map, uwbService.config.showFloorPlan,
                    (v) {
                  uwbService.updateConfig(
                      uwbService.config.copyWith(showFloorPlan: v));
                }),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.image, color: AppTheme.primaryColor),
                  onPressed: () => _loadFloorPlan(
                      uwbService, context.read<InspectionProvider>()),
                  tooltip: 'Load Floor Plan',
                ),
              ],
            ),
    );
  }

  Widget _buildToggle(
      String label, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: value,
        onSelected: onChanged,
        avatar: Icon(
          icon,
          size: 16,
          color: value ? AppTheme.primaryColor : Colors.grey.shade600,
        ),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: value ? FontWeight.w600 : FontWeight.normal,
            color: value ? AppTheme.primaryColor : Colors.grey.shade800,
          ),
        ),
        selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
        backgroundColor: Colors.grey.shade100,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
    );
  }

  // ===== Pin =====.
  Widget _buildPinListPanel(InspectionProvider inspection) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          // Title.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                const Icon(Icons.push_pin,
                    size: 20, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Inspection Points',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                Text(
                  '${inspection.currentPins.length}',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),

          // Translated legacy note.
          if (inspection.currentPins.isNotEmpty) _buildPinSummary(inspection),

          // Pin.
          Expanded(
            child: inspection.currentPins.isEmpty
                ? _buildEmptyPinState()
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: inspection.currentPins.length,
                    itemBuilder: (context, index) {
                      final pin = inspection.currentPins[index];
                      return _buildPinCard(pin, index, inspection);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinSummary(InspectionProvider inspection) {
    final session = inspection.currentSession;
    if (session == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          _buildStatBadge(
              'Low Risk', session.lowRiskDefects.toString(), Colors.blue),
          const SizedBox(width: 8),
          _buildStatBadge('Medium Risk', session.mediumRiskDefects.toString(),
              Colors.orange),
          const SizedBox(width: 8),
          _buildStatBadge(
              'High Risk', session.highRiskDefects.toString(), Colors.red),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
            ),
            Text(
              label,
              style:
                  TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPinState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.push_pin_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'No Inspection Points',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Press "+" below\nto add an inspection point',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPinCard(
      InspectionPin pin, int index, InspectionProvider inspection) {
    final isSelected = inspection.selectedPin?.id == pin.id;
    final defectCount = pin.defects.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          inspection.selectPin(pin);
          _openAiAnalysisScreen(pin);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Pin.
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: pin.isAnalyzed
                          ? AppTheme.primaryColor.withValues(alpha: 0.15)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: pin.isAnalyzed
                              ? AppTheme.primaryColor
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Coordinate.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '(${pin.x.toStringAsFixed(2)}, ${pin.y.toStringAsFixed(2)})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: pin.isAnalyzed
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                pin.isAnalyzed ? 'Analyzed' : pin.statusLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: pin.isAnalyzed
                                      ? Colors.green
                                      : Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (defectCount > 0) ...[
                              const SizedBox(width: 6),
                              Text(
                                'Defects: $defectCount',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Button( ).
                  if (pin.imageBase64 == null)
                    IconButton(
                      icon: const Icon(Icons.camera_alt, size: 20),
                      color: Colors.grey,
                      onPressed: () => _openAiAnalysisScreen(pin),
                      tooltip: 'Take Photo',
                    ),
                  // Translated legacy note.
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    color: Colors.grey.shade400,
                    onPressed: () => _confirmDeletePin(pin, inspection),
                    tooltip: 'Delete',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ],
              ),
              // Analysisresult.
              if (pin.isAnalyzed && pin.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  pin.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
              // Translated legacy note.
              if (pin.note != null && pin.note!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.note, size: 12, color: Colors.amber.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        pin.note!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11, color: Colors.amber.shade700),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ===== button =====.
  Widget _buildFAB(UwbService uwbService, InspectionProvider inspection) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_isAnchorPlacementMode)
          FloatingActionButton.small(
            heroTag: 'anchor_mode',
            onPressed: () => _startAnchorPlacement(),
            backgroundColor: Colors.teal,
            tooltip: 'Place Anchor on map',
            child: const Icon(Icons.place, color: Colors.white),
          ),
        if (_isAnchorPlacementMode)
          FloatingActionButton.small(
            heroTag: 'cancel_anchor',
            onPressed: _cancelAnchorPlacement,
            backgroundColor: Colors.grey,
            tooltip: 'Cancel anchor placement mode',
            child: const Icon(Icons.close, color: Colors.white),
          ),
        const SizedBox(height: 8),
        // Pin modebutton ( ).
        if (!inspection.isPinMode)
          FloatingActionButton.small(
            heroTag: 'pin_mode',
            onPressed: () => inspection.togglePinMode(),
            backgroundColor: Colors.orange,
            tooltip: 'Click map to place Pin',
            child: const Icon(Icons.touch_app, color: Colors.white),
          ),
        if (inspection.isPinMode)
          FloatingActionButton.small(
            heroTag: 'cancel_pin',
            onPressed: () => inspection.disablePinMode(),
            backgroundColor: Colors.grey,
            tooltip: 'Cancel placement mode',
            child: const Icon(Icons.close, color: Colors.white),
          ),
        const SizedBox(height: 8),
        // UWB Pin.
        FloatingActionButton(
          heroTag: 'add_pin',
          onPressed: uwbService.isConnected && uwbService.currentTag != null
              ? () {
                  final tag = uwbService.currentTag!;
                  final pin = inspection.addPin(tag.x, tag.y);
                  _openAiAnalysisScreen(pin);
                }
              : null,
          backgroundColor:
              uwbService.isConnected && uwbService.currentTag != null
                  ? AppTheme.primaryColor
                  : Colors.grey,
          tooltip: 'Add Pin at current location',
          child: const Icon(Icons.add_location_alt, color: Colors.white),
        ),
      ],
    );
  }

  // ===== + AI analysis =====.
  Future<void> _openAiAnalysisScreen(InspectionPin pin) async {
    final result = await Navigator.push<AiAnalysisScreenResult>(
      context,
      MaterialPageRoute(
        builder: (_) => AiAnalysisScreen(
          imageBase64: pin.imageBase64,
          additionalContext:
              'Pin location: (${pin.x.toStringAsFixed(2)}, ${pin.y.toStringAsFixed(2)})',
          imagePath: pin.imagePath,
        ),
      ),
    );

    if (!mounted || result == null) return;

    var updatedPin = pin.copyWith(
      imageBase64: result.imageBase64 ?? pin.imageBase64,
      imagePath: result.imagePath ?? pin.imagePath,
    );

    final selected = result.selectedResult;
    if (selected != null) {
      final raw = selected.raw;
      final defect = Defect(
        id: const Uuid().v4(),
        imagePath: result.imagePath ?? pin.imagePath,
        imageBase64: result.imageBase64 ?? pin.imageBase64,
        aiResult: raw,
        category: raw['category'] as String?,
        severity: raw['severity'] as String?,
        riskScore: selected.riskScore,
        riskLevel: selected.riskLevel,
        description: selected.analysis,
        recommendations: selected.recommendations,
        status: 'analyzed',
      );

      updatedPin = updatedPin.copyWith(
        aiResult: raw,
        category: raw['category'] as String?,
        severity: raw['severity'] as String?,
        riskScore: selected.riskScore,
        riskLevel: selected.riskLevel,
        description: selected.analysis,
        recommendations: selected.recommendations,
        status: 'analyzed',
        defects: [...pin.defects, defect],
      );
    }

    context.read<InspectionProvider>().updatePin(updatedPin);
  }

  // Translated legacy comment.
  void _confirmDeletePin(InspectionPin pin, InspectionProvider inspection) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Inspection Point'),
        content: Text(
            'Delete inspection point at (${pin.x.toStringAsFixed(2)}, ${pin.y.toStringAsFixed(2)})?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              inspection.removePin(pin.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ===== loadfloor =====.
  Future<void> _loadFloorPlan(
      UwbService uwbService, InspectionProvider inspection) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'svg', 'pdf'],
      dialogTitle: 'Select Floor Plan',
    );
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      await uwbService.loadFloorPlanImage(path);
      uwbService.updateConfig(uwbService.config.copyWith(showFloorPlan: true));
      inspection.updateFloorPlan(path);
    }
  }

  Future<void> _applySessionFloorPlan(
      UwbService uwbService, InspectionSession session) async {
    final path = session.floorPlanPath;
    if (path == null || path.isEmpty) {
      uwbService.clearFloorPlan();
      return;
    }

    await uwbService.loadFloorPlanImage(path);
    uwbService.updateConfig(uwbService.config.copyWith(showFloorPlan: true));
  }

  // ===== connect =====.
  void _showConnectDialog(UwbService uwbService) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.usb, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                const Text('Connect UWB Device',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close)),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            _buildConnectOption(
              icon: Icons.wifi_tethering,
              title: 'Auto Connect BU04',
              subtitle: 'Connect AI-Thinker UWB via USB or USB-C OTG',
              color: AppTheme.primaryColor,
              onTap: () {
                Navigator.pop(ctx);
                _showSerialConnectDialog(uwbService);
              },
            ),
            const SizedBox(height: 12),
            _buildConnectOption(
              icon: Icons.play_circle_outline,
              title: 'Demo / Simulation Mode',
              subtitle: 'Demonstrate UWB positioning with simulated data',
              color: Colors.green,
              onTap: () {
                Navigator.pop(ctx);
                uwbService.connect(simulate: true);
              },
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'PC: Ensure BU04 is USB-connected with CH340/CP210x driver.\nPhone: Connect BU04 via USB-C; OTG required.',
                      style:
                          TextStyle(color: Colors.blue.shade900, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(ctx).viewInsets.bottom + 20),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                color: Colors.grey.shade400, size: 16),
          ],
        ),
      ),
    );
  }

  void _showSerialConnectDialog(UwbService uwbService) {
    if (kIsWeb) return;

    // Android platform： USB OTG.
    if (!kIsWeb && Platform.isAndroid) {
      _showMobileUsbConnectDialog(uwbService);
      return;
    }

    // Platform： COM serial.
    List<String> ports = [];
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final serialService = DesktopSerialService();
      ports = serialService.getAvailablePorts();
    }

    if (ports.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.usb_off, color: Colors.red),
              SizedBox(width: 8),
              Text('No Serial Port Found'),
            ],
          ),
          content: const Text(
            'No serial devices detected.\n\n'
            'Please verify:\n'
            '• BU04 is connected via USB\n'
            '• On Linux, your user is in the dialout group\n'
            '  (sudo usermod -aG dialout <user>)\n'
            '• Re-login after group changes',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    String selectedPort = ports.first;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Select Serial Port'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedPort,
                items: ports
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => selectedPort = v);
                },
                decoration: const InputDecoration(
                  labelText: 'Serial Port',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _baudRate,
                items: [9600, 19200, 38400, 57600, 115200]
                    .map((b) => DropdownMenuItem(value: b, child: Text('$b')))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => _baudRate = v);
                },
                decoration: const InputDecoration(
                  labelText: 'Baud Rate',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                uwbService.connect(
                  simulate: false,
                  port: selectedPort,
                  baudRate: _baudRate,
                );
              },
              child: const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Android USB OTG connect =====.
  void _showMobileUsbConnectDialog(UwbService uwbService) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          _MobileUsbConnectDialog(uwbService: uwbService, baudRate: _baudRate),
    );
  }

  // ===== settings =====.
  Widget _buildFullSettingsPanel(
      UwbService uwbService, InspectionProvider inspection) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                const Icon(Icons.tune, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Settings',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Colors.white),
                  onPressed: () => setState(() => _showFullSettings = false),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Anchor list.
                  _buildSectionHeader('Anchor Management', Icons.cell_tower),
                  const SizedBox(height: 8),
                  ...uwbService.anchors.asMap().entries.map((entry) {
                    final index = entry.key;
                    final anchor = entry.value;
                    return _buildAnchorTile(anchor, index, uwbService);
                  }),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showAddAnchorDialog(uwbService),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Anchor'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _startAnchorPlacement,
                      icon: const Icon(Icons.place, size: 18),
                      label: const Text('Set Anchor on Floor Plan'),
                    ),
                  ),
                  const SizedBox(height: 8),

                  const SizedBox(height: 20),

                  // Translated legacy note.
                  _buildSectionHeader('Floor Plan Settings', Icons.map),
                  const SizedBox(height: 8),

                  // Loadbutton.
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _loadFloorPlan(
                              uwbService, context.read<InspectionProvider>()),
                          icon: uwbService.isLoadingFloorPlan
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.folder_open, size: 16),
                          label: Text(uwbService.isLoadingFloorPlan
                              ? 'Loading...'
                              : 'Open Floor Plan'),
                        ),
                      ),
                      if (uwbService.config.floorPlanImagePath != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            uwbService.clearFloorPlan();
                            setState(() {});
                          },
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red, size: 20),
                          tooltip: 'Clear Map',
                        ),
                      ],
                    ],
                  ),

                  if (inspection.currentFloorPlans.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: inspection.currentFloorPlans.map((segment) {
                        final isSelected =
                            inspection.selectedFloorPlanOrder == segment.order;
                        return ChoiceChip(
                          label: Text('Plan ${segment.order}'),
                          selected: isSelected,
                          onSelected: (_) async {
                            inspection.selectFloorPlanOrder(segment.order);
                            await uwbService.loadFloorPlanImage(segment.path);
                            uwbService.updateConfig(
                              uwbService.config.copyWith(showFloorPlan: true),
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ],

                  // Show/.
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: uwbService.config.showFloorPlan,
                    onChanged: (v) {
                      uwbService.updateConfig(
                          uwbService.config.copyWith(showFloorPlan: v));
                      setState(() {});
                    },
                    title: const Text('Show Floor Plan',
                        style: TextStyle(fontSize: 13)),
                  ),

                  // Translated legacy note.
                  if (inspection.currentFloorPlans.isNotEmpty) ...[
                    Row(
                      children: [
                        const SizedBox(
                            width: 60,
                            child: Text('Opacity',
                                style: TextStyle(fontSize: 13))),
                        Expanded(
                          child: Slider(
                            value: uwbService.config.floorPlanOpacity,
                            min: 0.0,
                            max: 1.0,
                            divisions: 20,
                            label:
                                '${(uwbService.config.floorPlanOpacity * 100).toInt()}%',
                            onChanged: (v) {
                              uwbService.updateFloorPlanOpacity(v);
                              setState(() {});
                            },
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${(uwbService.config.floorPlanOpacity * 100).toInt()}%',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),

                    const Divider(),

                    // Translated legacy note.
                    const Text('Offset Settings',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    _buildNumberField('X Offset (m)', uwbService.config.xOffset,
                        (v) {
                      uwbService
                          .updateConfig(uwbService.config.copyWith(xOffset: v));
                    }),
                    _buildNumberField('Y Offset (m)', uwbService.config.yOffset,
                        (v) {
                      uwbService
                          .updateConfig(uwbService.config.copyWith(yOffset: v));
                    }),
                    const SizedBox(height: 8),

                    // Translated legacy note.
                    const Text('Scale Settings',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    _buildNumberField(
                        'X Scale (px/m)', uwbService.config.xScale, (v) {
                      uwbService
                          .updateConfig(uwbService.config.copyWith(xScale: v));
                    }),
                    _buildNumberField(
                        'Y Scale (px/m)', uwbService.config.yScale, (v) {
                      uwbService
                          .updateConfig(uwbService.config.copyWith(yScale: v));
                    }),
                    const SizedBox(height: 8),

                    // Translated legacy note.
                    const Text('Flip Settings',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: uwbService.config.flipX,
                            onChanged: (v) {
                              uwbService.updateConfig(uwbService.config
                                  .copyWith(flipX: v ?? false));
                              setState(() {});
                            },
                            title: const Text('Flip X',
                                style: TextStyle(fontSize: 12)),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        ),
                        Expanded(
                          child: CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: uwbService.config.flipY,
                            onChanged: (v) {
                              uwbService.updateConfig(uwbService.config
                                  .copyWith(flipY: v ?? false));
                              setState(() {});
                            },
                            title: const Text('Flip Y',
                                style: TextStyle(fontSize: 12)),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        ),
                      ],
                    ),

                    // Hint.
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Tip: X/Y Scale = pixels per meter on the image\nOffset = image bottom-left in UWB coordinates',
                        style: TextStyle(
                            fontSize: 11, color: Colors.blue.shade800),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Show.
                  _buildSectionHeader('Display Settings', Icons.visibility),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: uwbService.config.showFence,
                    onChanged: (v) => uwbService
                        .updateConfig(uwbService.config.copyWith(showFence: v)),
                    title: const Text('Show Fence',
                        style: TextStyle(fontSize: 13)),
                  ),

                  const SizedBox(height: 20),

                  // Distance.
                  _buildSectionHeader(
                      'Distance Index Mapping', Icons.swap_horiz),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Multiple swap pairs can be selected.\n'
                          'E.g.: Select D0↔D1 then D2↔D3.',
                          style: TextStyle(
                              fontSize: 11, color: Colors.blue.shade700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Current Mapping: ${uwbService.config.distanceIndexMap}',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: Colors.blue.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _describeDistanceMapping(
                              uwbService.config.distanceIndexMap),
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildDistanceSwapButton(uwbService, 'D0↔D1', 0, 1),
                      _buildDistanceSwapButton(uwbService, 'D0↔D2', 0, 2),
                      _buildDistanceSwapButton(uwbService, 'D0↔D3', 0, 3),
                      _buildDistanceSwapButton(uwbService, 'D1↔D2', 1, 2),
                      _buildDistanceSwapButton(uwbService, 'D1↔D3', 1, 3),
                      _buildDistanceSwapButton(uwbService, 'D2↔D3', 2, 3),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        uwbService.updateConfig(
                          uwbService.config
                              .copyWith(distanceIndexMap: [0, 1, 2, 3]),
                        );
                        setState(() {});
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
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }

  String _describeDistanceMapping(List<int> map) {
    if (map.length != 4) return 'Invalid Mapping';
    if (map[0] == 0 && map[1] == 1 && map[2] == 2 && map[3] == 3) {
      return 'Default Order (No Swaps)';
    }
    // Detect active swaps
    final swaps = <String>[];
    final visited = <int>{};
    for (int i = 0; i < 4; i++) {
      if (visited.contains(i)) continue;
      if (map[i] != i) {
        final j = map[i];
        if (j < 4 && map[j] == i) {
          swaps.add('D$i↔D$j');
          visited.addAll([i, j]);
        } else {
          swaps.add('D$i→Anchor$j');
          visited.add(i);
        }
      }
    }
    return 'Swapped: ${swaps.join(', ')}';
  }

  /// Check if a specific pair (a, b) is currently swapped in the mapping
  bool _isSwapActive(List<int> map, int a, int b) {
    return map.length == 4 && map[a] == b && map[b] == a;
  }

  /// Toggle a swap pair on the current mapping
  void _toggleSwap(UwbService uwbService, int a, int b) {
    final current = List<int>.from(uwbService.config.distanceIndexMap);
    if (_isSwapActive(current, a, b)) {
      // Undo this swap
      current[a] = a;
      current[b] = b;
    } else {
      // First restore any existing swaps involving a or b
      for (int i = 0; i < 4; i++) {
        if (current[i] == a && i != a) {
          current[i] = i; // undo old swap partner of a
        }
        if (current[i] == b && i != b) {
          current[i] = i; // undo old swap partner of b
        }
      }
      current[a] = a;
      current[b] = b;
      // Apply the new swap
      current[a] = b;
      current[b] = a;
    }
    uwbService.updateConfig(
      uwbService.config.copyWith(distanceIndexMap: current),
    );
    setState(() {});
  }

  Widget _buildDistanceSwapButton(
      UwbService uwbService, String label, int a, int b) {
    final current = uwbService.config.distanceIndexMap;
    final isActive = _isSwapActive(current, a, b);

    return SizedBox(
      height: 36,
      child: isActive
          ? ElevatedButton(
              onPressed: () => _toggleSwap(uwbService, a, b),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              child: Text('✓ $label'),
            )
          : OutlinedButton(
              onPressed: () => _toggleSwap(uwbService, a, b),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(fontSize: 13),
              ),
              child: Text(label),
            ),
    );
  }

  Widget _buildAnchorTile(UwbAnchor anchor, int index, UwbService uwbService) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.cell_tower,
              size: 20, color: anchor.isActive ? Colors.green : Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(anchor.id,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                Text(
                  '(${anchor.x}, ${anchor.y}, ${anchor.z})',
                  style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.place, size: 18),
            color: Colors.teal,
            onPressed: () => _startAnchorPlacement(anchorIndex: index),
            tooltip: 'Set on Floor Plan',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            color: AppTheme.primaryColor,
            onPressed: () => _showEditAnchorDialog(anchor, index, uwbService),
            tooltip: 'Edit Coordinates',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            color: Colors.red.shade400,
            onPressed: () {
              uwbService.removeAnchor(index);
              setState(() {});
            },
            tooltip: 'Delete',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  void _showEditAnchorDialog(
      UwbAnchor anchor, int index, UwbService uwbService) {
    final xController = TextEditingController(text: anchor.x.toString());
    final yController = TextEditingController(text: anchor.y.toString());
    final zController = TextEditingController(text: anchor.z.toString());
    final nameController = TextEditingController(text: anchor.id);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.edit_location_alt, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text('Edit ${anchor.id}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Anchor Name',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: xController,
                    decoration: const InputDecoration(
                      labelText: 'X (m)',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: yController,
                    decoration: const InputDecoration(
                      labelText: 'Y (m)',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: zController,
                    decoration: const InputDecoration(
                      labelText: 'Z (m)',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newName = nameController.text.trim();
              final newAnchor = UwbAnchor(
                id: newName.isNotEmpty ? newName : anchor.id,
                x: double.tryParse(xController.text) ?? anchor.x,
                y: double.tryParse(yController.text) ?? anchor.y,
                z: double.tryParse(zController.text) ?? anchor.z,
                isActive: anchor.isActive,
              );
              uwbService.updateAnchor(index, newAnchor);
              if (newName.isNotEmpty && newName != anchor.id) {
                uwbService.renameAnchor(index, newName);
              }
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddAnchorDialog(UwbService uwbService) {
    final xController = TextEditingController(text: '0.0');
    final yController = TextEditingController(text: '0.0');
    final zController = TextEditingController(text: '3.0');
    final nameController =
        TextEditingController(text: 'Anchor ${uwbService.anchors.length}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_location, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('Add Anchor'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Anchor Name',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: xController,
                    decoration: const InputDecoration(
                      labelText: 'X (m)',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: yController,
                    decoration: const InputDecoration(
                      labelText: 'Y (m)',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: zController,
                    decoration: const InputDecoration(
                      labelText: 'Z (m)',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startAnchorPlacement();
            },
            child: const Text('Pick on Map'),
          ),
          ElevatedButton(
            onPressed: () {
              uwbService.addAnchor(UwbAnchor(
                id: nameController.text.trim().isNotEmpty
                    ? nameController.text.trim()
                    : 'Anchor ${uwbService.anchors.length}',
                x: double.tryParse(xController.text) ?? 0.0,
                y: double.tryParse(yController.text) ?? 0.0,
                z: double.tryParse(zController.text) ?? 3.0,
                isActive: true,
              ));
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showRoomDimensionDialog(UwbService uwbService) {
    final widthController = TextEditingController(text: '4.85');
    final heightController = TextEditingController(text: '5.44');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.square_foot, color: Colors.teal),
            SizedBox(width: 8),
            Flexible(child: Text('Enter Room Dimensions')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: widthController,
              decoration: const InputDecoration(
                labelText: 'Room Width',
                suffixText: 'm',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: heightController,
              decoration: const InputDecoration(
                labelText: 'Room Length',
                suffixText: 'm',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            Text(
              'Tip: Anchors are typically installed at the four ceiling corners of the room',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final w = double.tryParse(widthController.text);
              final h = double.tryParse(heightController.text);
              if (w != null && h != null && w > 0 && h > 0) {
                // Store room dimensions in UWB config for visualization
                debugPrint('Room dimensions set: ${w}m x ${h}m');
                Navigator.pop(ctx);
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _startAnchorPlacement({int? anchorIndex}) {
    setState(() {
      _isAnchorPlacementMode = true;
      _anchorPlacementIndex = anchorIndex;
    });
  }

  void _cancelAnchorPlacement() {
    setState(() {
      _isAnchorPlacementMode = false;
      _anchorPlacementIndex = null;
    });
  }

  void _placeAnchorAt(Offset uwbCoord, UwbService uwbService) {
    final targetIndex = _anchorPlacementIndex;
    if (targetIndex != null &&
        targetIndex >= 0 &&
        targetIndex < uwbService.anchors.length) {
      final existing = uwbService.anchors[targetIndex];
      uwbService.updateAnchor(
        targetIndex,
        UwbAnchor(
          id: existing.id,
          x: uwbCoord.dx,
          y: uwbCoord.dy,
          z: existing.z,
          isActive: existing.isActive,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${existing.id} position updated on floor plan')),
      );
    } else {
      final newId = 'Anchor ${uwbService.anchors.length}';
      uwbService.addAnchor(UwbAnchor(
        id: newId,
        x: uwbCoord.dx,
        y: uwbCoord.dy,
        z: 3.0,
        isActive: true,
      ));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$newId added on floor plan')),
      );
    }

    setState(() {
      _isAnchorPlacementMode = false;
      _anchorPlacementIndex = null;
    });
  }

  Widget _buildNumberField(
      String label, double value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextFormField(
                initialValue: value.toString(),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                style: const TextStyle(fontSize: 13),
                onFieldSubmitted: (text) {
                  final v = double.tryParse(text);
                  if (v != null) {
                    onChanged(v);
                  }
                },
                onChanged: (text) {
                  // Update( ).
                  if (text.isEmpty || text == '-' || text.endsWith('.')) {
                    return; // Translated note.
                  }
                  final v = double.tryParse(text);
                  if (v != null) {
                    onChanged(v);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Translated legacy comment.
  void _handleMenuAction(String action, InspectionProvider inspection) {
    switch (action) {
      case 'new_session':
        _showNewSessionDialog(inspection);
        break;
      case 'load_session':
        _showLoadSessionDialog(inspection);
        break;
      case 'export_word':
        _exportWord(inspection);
        break;
      case 'export_pdf':
        _exportPdf(inspection);
        break;
      case 'clear_pins':
        if (inspection.currentPins.isNotEmpty) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Clear All Inspection Points'),
              content: const Text(
                  'Clear all inspection points? This cannot be undone.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    for (final pin in List.from(inspection.currentPins)) {
                      inspection.removePin(pin.id);
                    }
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Clear',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }
        break;
    }
  }

  void _showFloorSelector(
      InspectionProvider inspection, UwbService uwbService) {
    if (widget.project == null) return;
    final project = widget.project!;

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        int selectedFloor = _currentFloor;
        int? selectedPlanOrder = inspection.selectedFloorPlanOrder;
        final projectFloorSessions = inspection.sessions
            .where((s) => s.projectId == project.id)
            .toList();
        final maxSessionFloor = projectFloorSessions.isEmpty
            ? 1
            : projectFloorSessions
                .map((s) => s.floor)
                .reduce((a, b) => a > b ? a : b);
        int maxFloorNumber = max(1, max(project.floorCount, maxSessionFloor));

        List<FloorPlanSegment> sortedPlansForFloor(int floor) {
          final session = inspection.sessions.where((s) {
            return s.projectId == project.id && s.floor == floor;
          });
          if (session.isEmpty) return <FloorPlanSegment>[];
          final plans = List<FloorPlanSegment>.from(session.first.floorPlans);
          plans.sort((a, b) => a.order.compareTo(b.order));
          return plans;
        }

        void normalizeSelectedPlan(List<FloorPlanSegment> plans) {
          if (plans.isEmpty) {
            selectedPlanOrder = null;
            return;
          }
          final exists = plans.any((p) => p.order == selectedPlanOrder);
          if (!exists) {
            selectedPlanOrder = plans.first.order;
          }
        }

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Switch Floor',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      IconButton.filled(
                        onPressed: () async {
                          final newFloor = maxFloorNumber + 1;
                          await _switchFloor(
                            inspection,
                            project,
                            newFloor,
                            uwbService,
                          );
                          setSheetState(() {
                            maxFloorNumber = newFloor;
                            selectedFloor = newFloor;
                            selectedPlanOrder = null;
                          });
                        },
                        tooltip: 'Add Floor',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.teal.shade600,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.add, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: maxFloorNumber,
                      itemBuilder: (context, index) {
                        final floorNum = index + 1;
                        final plans = sortedPlansForFloor(floorNum);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFloorGridCard(
                                floorNum: floorNum,
                                onTap: () {
                                  setSheetState(() {
                                    selectedFloor = floorNum;
                                    normalizeSelectedPlan(plans);
                                    if (plans.isNotEmpty) {
                                      selectedPlanOrder = selectedPlanOrder ==
                                                  null ||
                                              !plans.any((p) =>
                                                  p.order == selectedPlanOrder)
                                          ? plans.first.order
                                          : selectedPlanOrder;
                                    } else {
                                      selectedPlanOrder = null;
                                    }
                                  });
                                },
                                onDelete: () async {
                                  if (maxFloorNumber <= 1) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'At least one floor is required')),
                                      );
                                    }
                                    return;
                                  }

                                  final shouldDelete = await showDialog<bool>(
                                    context: context,
                                    builder: (dialogCtx) => AlertDialog(
                                      title: const Text('Delete Floor'),
                                      content: Text(
                                          'Delete floor $floorNum and all its plan data?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dialogCtx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(dialogCtx, true),
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (shouldDelete != true) return;

                                  await inspection.removeProjectFloor(
                                    project.id,
                                    floorNum,
                                  );

                                  final remainingProjectSessions = inspection
                                      .sessions
                                      .where((s) => s.projectId == project.id)
                                      .toList();
                                  final remainingMaxFloor =
                                      remainingProjectSessions.isEmpty
                                          ? 1
                                          : remainingProjectSessions
                                              .map((s) => s.floor)
                                              .reduce((a, b) => a > b ? a : b);

                                  setSheetState(() {
                                    maxFloorNumber = max(
                                      1,
                                      max(project.floorCount - 1,
                                          remainingMaxFloor),
                                    );
                                    if (selectedFloor >= floorNum) {
                                      selectedFloor = max(1, selectedFloor - 1);
                                      final fallbackPlans =
                                          sortedPlansForFloor(selectedFloor);
                                      normalizeSelectedPlan(fallbackPlans);
                                    }
                                  });

                                  await _switchFloor(
                                    inspection,
                                    project,
                                    selectedFloor,
                                    uwbService,
                                    targetPlanOrder: selectedPlanOrder,
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 44,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      ...plans.map(
                                        (plan) => Padding(
                                          padding:
                                              const EdgeInsets.only(right: 8),
                                          child: _buildFloorSegmentCard(
                                            label: '${floorNum}F${plan.order}',
                                            isSelected: selectedFloor ==
                                                    floorNum &&
                                                selectedPlanOrder == plan.order,
                                            onTap: () {
                                              setSheetState(() {
                                                selectedFloor = floorNum;
                                                selectedPlanOrder = plan.order;
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                      _buildFloorSegmentCard(
                                        label: '+',
                                        isSelected: false,
                                        onTap: () async {
                                          await _switchFloor(
                                            inspection,
                                            project,
                                            floorNum,
                                            uwbService,
                                          );
                                          await _loadFloorPlan(
                                              uwbService, inspection);
                                          final updatedPlans =
                                              sortedPlansForFloor(floorNum);
                                          setSheetState(() {
                                            selectedFloor = floorNum;
                                            if (updatedPlans.isNotEmpty) {
                                              updatedPlans.sort((a, b) =>
                                                  a.order.compareTo(b.order));
                                              selectedPlanOrder =
                                                  updatedPlans.last.order;
                                            }
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await _switchFloor(
                              inspection,
                              project,
                              selectedFloor,
                              uwbService,
                              targetPlanOrder: selectedPlanOrder,
                            );
                          },
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFloorGridCard({
    required int floorNum,
    required VoidCallback onTap,
    required VoidCallback onDelete,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Floor $floorNum',
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  tooltip: 'Delete floor',
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: Colors.red.shade500,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloorSegmentCard({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 72,
      height: 44,
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
        color: isSelected ? AppTheme.primaryColor : Colors.white,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _switchFloor(InspectionProvider inspection, Project project,
      int floor, UwbService uwbService,
      {int? targetPlanOrder}) async {
    setState(() => _currentFloor = floor);
    // Find or create session for this floor
    final existing = inspection.sessions.where(
      (s) => s.projectId == project.id && s.floor == floor,
    );
    late final InspectionSession session;
    if (existing.isNotEmpty) {
      session = existing.first;
      inspection.switchSession(session.id);
    } else {
      session = await inspection.createSession(
        '${project.buildingName} - ${floor}F',
        projectId: project.id,
        floor: floor,
      );
    }

    if (targetPlanOrder != null &&
        session.floorPlans.any((p) => p.order == targetPlanOrder)) {
      inspection.selectFloorPlanOrder(targetPlanOrder);
      final selectedSegment =
          session.floorPlans.firstWhere((p) => p.order == targetPlanOrder);
      await uwbService.loadFloorPlanImage(selectedSegment.path);
      uwbService.updateConfig(uwbService.config.copyWith(showFloorPlan: true));
    } else {
      await _applySessionFloorPlan(uwbService, session);
    }
  }

  void _showNewSessionDialog(InspectionProvider inspection) {
    final controller = TextEditingController(
      text: 'Inspection ${DateTime.now().toString().substring(0, 16)}',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Inspection Session'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Session Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              inspection.createSession(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showLoadSessionDialog(InspectionProvider inspection) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Load Inspection Session'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: inspection.sessions.isEmpty
              ? const Center(child: Text('No saved inspection sessions'))
              : ListView.builder(
                  itemCount: inspection.sessions.length,
                  itemBuilder: (context, index) {
                    final session = inspection.sessions[index];
                    return ListTile(
                      title: Text(session.name),
                      subtitle: Text(
                          '${session.totalPins} pins  ${session.createdAt.toString().substring(0, 16)}'),
                      trailing: session.id == inspection.currentSession?.id
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                      onTap: () {
                        inspection.switchSession(session.id);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  // ===== Word =====.
  Future<void> _exportWord(InspectionProvider inspection) async {
    final projectSessions = _getExportSessions(inspection);
    if (projectSessions == null) return;

    final buildingName = widget.project?.buildingName ?? 'Unnamed Building';
    final fileName =
        '${buildingName}_InspectionReport_${DateTime.now().toString().substring(0, 10)}.docx';

    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';

      await WordExportService.exportReport(
        outputPath: filePath,
        buildingName: buildingName,
        sessions: projectSessions,
      );

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'B-SAFE Inspection Report (Word)',
      );

      if (mounted) inspection.markExported();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ===== PDF =====.
  Future<void> _exportPdf(InspectionProvider inspection) async {
    final projectSessions = _getExportSessions(inspection);
    if (projectSessions == null) return;

    final buildingName = widget.project?.buildingName ?? 'Unnamed Building';
    final fileName =
        '${buildingName}_InspectionReport_${DateTime.now().toString().substring(0, 10)}.pdf';

    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';

      await PdfExportService.exportReport(
        outputPath: filePath,
        buildingName: buildingName,
        sessions: projectSessions,
      );

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'B-SAFE Inspection Report (PDF)',
      );

      if (mounted) inspection.markExported();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Collects sessions for export; returns null if nothing to export.
  List<InspectionSession>? _getExportSessions(InspectionProvider inspection) {
    final projectId = widget.project?.id;
    final projectSessions = projectId != null
        ? inspection.sessions.where((s) => s.projectId == projectId).toList()
        : [if (inspection.currentSession != null) inspection.currentSession!];

    final allPinsCount =
        projectSessions.fold<int>(0, (sum, s) => sum + s.pins.length);
    if (allPinsCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No inspection points to export'),
            backgroundColor: Colors.orange),
      );
      return null;
    }
    return projectSessions;
  }
}

// ===== inspection / Widget =====.
class _PinDetailDialog extends StatefulWidget {
  final InspectionPin pin;
  final ImagePicker imagePicker;
  final ValueChanged<InspectionPin> onUpdate;
  final VoidCallback onRetakePhoto;
  final VoidCallback onDelete;

  const _PinDetailDialog({
    required this.pin,
    required this.imagePicker,
    required this.onUpdate,
    required this.onRetakePhoto,
    required this.onDelete,
  });

  @override
  State<_PinDetailDialog> createState() => _PinDetailDialogState();
}

class _PinDetailDialogState extends State<_PinDetailDialog> {
  late TextEditingController _noteController;
  late String _riskLevel;
  late int _riskScore;
  late String? _description;
  late List<String> _recommendations;
  late Map<String, dynamic>? _aiResult;
  late String _status;
  late InspectionPin _currentPin;
  bool _isEditing = false;
  bool _hasChanges = false;
  bool _isAnalyzing = false;
  int? _expandedDefectIndex;
  final _defectChatController = TextEditingController();
  final _defectChatScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentPin = widget.pin;
    _noteController = TextEditingController(text: widget.pin.note ?? '');
    _riskLevel = widget.pin.riskLevel;
    _riskScore = widget.pin.riskScore;
    _description = widget.pin.description;
    _recommendations = List<String>.from(widget.pin.recommendations);
    _aiResult = widget.pin.aiResult != null
        ? Map<String, dynamic>.from(widget.pin.aiResult!)
        : null;
    _status = widget.pin.status;
  }

  @override
  void dispose() {
    _noteController.dispose();
    _defectChatController.dispose();
    _defectChatScrollController.dispose();
    super.dispose();
  }

  /// Defect.
  Defect? get _selectedDefect {
    if (_expandedDefectIndex != null &&
        _expandedDefectIndex! < _currentPin.defects.length) {
      return _currentPin.defects[_expandedDefectIndex!];
    }
    return null;
  }

  /// Show risk ： show defect.
  String get _displayRiskLevel => _selectedDefect?.riskLevel ?? 'none';

  Color get _riskColor {
    switch (_displayRiskLevel) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  String get _riskLevelLabel {
    switch (_displayRiskLevel) {
      case 'high':
        return 'High Risk';
      case 'medium':
        return 'Medium Risk';
      case 'low':
        return 'Low Risk';
      default:
        return 'Not Assessed';
    }
  }

  @override
  Widget build(BuildContext context) {
    final pin = _currentPin;
    final hasPhoto = pin.imageBase64 != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ===== title =====.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _riskColor.withValues(alpha: 0.9),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(
                    pin.isAnalyzed ? Icons.analytics : Icons.location_on,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Inspection Point Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          'Location: (${pin.x.toStringAsFixed(2)}, ${pin.y.toStringAsFixed(2)})  |  ${pin.createdAt.toString().substring(0, 16)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Translated legacy comment.
                  IconButton(
                    icon: Icon(
                      _isEditing ? Icons.check_circle : Icons.edit,
                      color: Colors.white,
                    ),
                    tooltip: _isEditing ? 'Done Editing' : 'Edit',
                    onPressed: () {
                      if (_isEditing && _hasChanges) {
                        _saveChanges();
                      }
                      setState(() => _isEditing = !_isEditing);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      if (_hasChanges) {
                        _saveChanges();
                      }
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),

            // ===== content =====.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Photo.
                    _buildPhotoSection(hasPhoto, pin),

                    const SizedBox(height: 16),

                    // AI analysisbutton ( photo analysis).
                    if (hasPhoto &&
                        !_isAnalyzing &&
                        _status != 'analyzed' &&
                        _expandedDefectIndex == null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ElevatedButton.icon(
                          onPressed: _runAiAnalysis,
                          icon: const Icon(Icons.auto_awesome, size: 18),
                          label: const Text('Analyze with AI'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 44),
                          ),
                        ),
                      ),

                    // AI analysis.
                    if (_isAnalyzing)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 8),
                              Text('AI Analyzing...',
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),

                    // Risk ( defect show).
                    if (_expandedDefectIndex != null) _buildRiskSection(),

                    if (_expandedDefectIndex != null)
                      const SizedBox(height: 16),

                    // Defect + Chat.
                    if (_expandedDefectIndex != null)
                      _buildExpandedDefectChat(),

                    // Defect.
                    _buildDefectsSection(),
                  ],
                ),
              ),
            ),

            // ===== button =====.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.end,
                children: [
                  // Translated legacy note.
                  TextButton.icon(
                    onPressed: () => _confirmDelete(),
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: Colors.red),
                    label: const Text('Delete',
                        style: TextStyle(color: Colors.red, fontSize: 13)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  // AI analysis ( photo analysis show).
                  if (hasPhoto && _status != 'analyzed' && !_isAnalyzing)
                    ElevatedButton(
                      onPressed: _runAiAnalysis,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: const Text('AI', style: TextStyle(fontSize: 13)),
                    ),
                  // Translated legacy note.
                  OutlinedButton.icon(
                    onPressed: _isAnalyzing ? null : widget.onRetakePhoto,
                    icon: const Icon(Icons.camera_alt, size: 16),
                    label: const Text('Retake Photo',
                        style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                  // Translated legacy note.
                  ElevatedButton(
                    onPressed: _isAnalyzing
                        ? null
                        : () {
                            if (_hasChanges) {
                              _saveChanges();
                            }
                            Navigator.pop(context);
                          },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('OK', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Photo.
  Widget _buildPhotoSection(bool hasPhoto, InspectionPin pin) {
    // Defect，showdefectphoto； show pin photo.
    final defect = _selectedDefect;
    final displayBase64 = defect?.imageBase64 ?? pin.imageBase64;
    final hasDisplayPhoto = displayBase64 != null;

    if (hasDisplayPhoto) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              base64Decode(displayBase64),
              width: double.infinity,
              height: 220,
              fit: BoxFit.contain,
            ),
          ),
          // Hint show.
          if (defect != null)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Defect #${_expandedDefectIndex! + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          // Button( defect pin).
          Positioned(
            bottom: 8,
            right: 8,
            child: Material(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: defect != null
                    ? () => _retakeDefectPhoto(_expandedDefectIndex!)
                    : widget.onRetakePhoto,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.camera_alt, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text('Retake',
                          style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return GestureDetector(
        onTap: widget.onRetakePhoto,
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo, size: 36, color: Colors.grey.shade400),
              const SizedBox(height: 6),
              Text('Tap to Take Photo',
                  style: TextStyle(color: Colors.grey.shade500)),
            ],
          ),
        ),
      );
    }
  }

  // Defect.
  Future<void> _retakeDefectPhoto(int defectIndex) async {
    try {
      final XFile? image =
          await widget.imagePicker.pickImage(source: ImageSource.camera);
      if (image == null || !mounted) return;

      final bytes = await image.readAsBytes();
      final base64 = base64Encode(bytes);

      final defect = _currentPin.defects[defectIndex];
      final updatedDefect = defect.copyWith(
        imageBase64: base64,
        status: 'pending', // Analysis.
      );
      _updateDefectInPin(updatedDefect, defectIndex);
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo failed: $e')),
        );
      }
    }
  }

  // Defect + Chat.
  Widget _buildExpandedDefectChat() {
    final defect = _selectedDefect;
    if (defect == null) return const SizedBox.shrink();
    final index = _expandedDefectIndex!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Translated legacy note.
        if (defect.chatMessages.isNotEmpty) ...[
          const Row(
            children: [
              Icon(Icons.chat_bubble_outline, size: 16, color: Colors.grey),
              SizedBox(width: 6),
              Text('Chat History',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ListView.builder(
              controller: _defectChatScrollController,
              shrinkWrap: true,
              padding: const EdgeInsets.all(8),
              itemCount: defect.chatMessages.length,
              itemBuilder: (context, i) {
                final msg = defect.chatMessages[i];
                final isUser = msg.role == 'user';
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.55),
                    decoration: BoxDecoration(
                      color:
                          isUser ? AppTheme.primaryColor : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: isUser
                          ? null
                          : Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      msg.content,
                      style: TextStyle(
                        fontSize: 12,
                        color: isUser ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Chat.
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _defectChatController,
                decoration: InputDecoration(
                  hintText: 'Enter additional info for AI re-analysis...',
                  hintStyle: const TextStyle(fontSize: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
                minLines: 1,
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: _isAnalyzing
                  ? null
                  : () => _sendDefectChatMessage(defect, index),
              icon: const Icon(Icons.send, size: 20),
              color: AppTheme.primaryColor,
              tooltip: 'Send',
            ),
          ],
        ),

        if (_isAnalyzing) ...[
          const SizedBox(height: 8),
          const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ],

        const SizedBox(height: 16),
      ],
    );
  }

  // Risk.
  Widget _buildRiskSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _riskColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _riskColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.shield, color: _riskColor, size: 20),
          const SizedBox(width: 8),
          const Text('Risk Level',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const Spacer(),
          if (_isEditing) ...[
            _buildRiskChip('low', 'Low', Colors.green),
            const SizedBox(width: 6),
            _buildRiskChip('medium', 'Medium', Colors.orange),
            const SizedBox(width: 6),
            _buildRiskChip('high', 'High', Colors.red),
          ] else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _riskColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _riskLevelLabel,
                style: TextStyle(
                  color: _riskColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRiskChip(String level, String label, Color color) {
    final selected = _displayRiskLevel == level;
    return ChoiceChip(
      label: Text(label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : color,
            fontWeight: FontWeight.w600,
          )),
      selected: selected,
      selectedColor: color,
      backgroundColor: color.withValues(alpha: 0.1),
      onSelected: (val) {
        if (val) {
          final defect = _selectedDefect;
          if (defect != null && _expandedDefectIndex != null) {
            // Defect risk.
            final updated = defect.copyWith(riskLevel: level);
            _updateDefectInPin(updated, _expandedDefectIndex!);
          } else {
            // Pin risk.
            _riskLevel = level;
          }
          setState(() => _hasChanges = true);
        }
      },
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildDefectsSection() {
    final defects = _currentPin.defects;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.report_problem, size: 18, color: Colors.orange),
            const SizedBox(width: 6),
            Text('Defect Records (${defects.length})',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            TextButton.icon(
              onPressed: widget.onRetakePhoto,
              icon: const Icon(Icons.add_a_photo, size: 16),
              label: const Text('Add Defect'),
            ),
          ],
        ),
        if (defects.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Center(
              child: Text('No defect records. Tap "Add Defect" to start.',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
            ),
          ),
        ...defects.asMap().entries.map((entry) {
          final idx = entry.key;
          final defect = entry.value;
          return _buildDefectCard(defect, idx);
        }),
      ],
    );
  }

  Widget _buildDefectCard(Defect defect, int index) {
    Color riskColor;
    switch (defect.riskLevel) {
      case 'high':
        riskColor = Colors.red;
        break;
      case 'medium':
        riskColor = Colors.orange;
        break;
      default:
        riskColor = Colors.green;
    }

    final isSelected = _expandedDefectIndex == index;

    return Card(
      margin: const EdgeInsets.only(top: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isSelected
            ? const BorderSide(color: AppTheme.primaryColor, width: 2)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          setState(() {
            _expandedDefectIndex = isSelected ? null : index;
            _defectChatController.clear();
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              if (defect.imageBase64 != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.memory(
                    base64Decode(defect.imageBase64!),
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.image, color: Colors.grey, size: 20),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Defect #${index + 1}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: riskColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            defect.riskLevelLabel,
                            style: TextStyle(
                                color: riskColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    if (defect.description != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          defect.description!,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (defect.chatMessages.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '💬 ${defect.chatMessages.length} messages',
                          style: TextStyle(
                              fontSize: 11, color: Colors.blue.shade400),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                isSelected ? Icons.check_circle : Icons.chevron_right,
                color: isSelected ? AppTheme.primaryColor : Colors.grey,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendDefectChatMessage(Defect defect, int defectIndex) async {
    final text = _defectChatController.text.trim();
    if (text.isEmpty || defect.imageBase64 == null) return;

    // Add user message to defect
    final userMsg = ChatMessage(
      id: const Uuid().v4(),
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    );

    final updatedMessages = [...defect.chatMessages, userMsg];
    final updatedDefect = defect.copyWith(chatMessages: updatedMessages);
    _updateDefectInPin(updatedDefect, defectIndex);

    setState(() {
      _defectChatController.clear();
      _isAnalyzing = true;
    });
    _scrollDefectChat();

    try {
      // History.
      final chatHistory = updatedMessages
          .map((m) => {
                'role': m.role == 'ai' ? 'assistant' : m.role,
                'content': m.content,
              })
          .toList();

      // ChatWithAI.
      final responseText = await ApiService.instance.chatWithAI(
        userMessage: text,
        imageBase64: defect.imageBase64,
        chatHistory:
            chatHistory.sublist(0, chatHistory.length - 1), // （ userMessage）.
      );

      if (!mounted) return;

      final aiMsg = ChatMessage(
        id: const Uuid().v4(),
        role: 'ai',
        content: responseText,
        timestamp: DateTime.now(),
      );

      final finalMessages = [...updatedMessages, aiMsg];
      final finalDefect = defect.copyWith(
        chatMessages: finalMessages,
      );
      _updateDefectInPin(finalDefect, defectIndex);

      setState(() => _isAnalyzing = false);
      _scrollDefectChat();
    } catch (e) {
      if (!mounted) return;

      final errMsg = ChatMessage(
        id: const Uuid().v4(),
        role: 'ai',
        content: 'Analysis failed: $e',
        timestamp: DateTime.now(),
      );
      final errMessages = [...updatedMessages, errMsg];
      final errDefect = defect.copyWith(chatMessages: errMessages);
      _updateDefectInPin(errDefect, defectIndex);

      setState(() => _isAnalyzing = false);
    }
  }

  void _updateDefectInPin(Defect updatedDefect, int defectIndex) {
    final newDefects = List<Defect>.from(_currentPin.defects);
    newDefects[defectIndex] = updatedDefect;
    final updatedPin = _currentPin.copyWith(defects: newDefects);
    setState(() {
      _currentPin = updatedPin;
      _hasChanges = true;
    });
    widget.onUpdate(updatedPin);
  }

  void _scrollDefectChat() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_defectChatScrollController.hasClients) {
        _defectChatScrollController.animateTo(
          _defectChatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _saveChanges() {
    final updatedPin = _currentPin.copyWith(
      note: _noteController.text.isEmpty ? null : _noteController.text,
      riskLevel: _riskLevel,
      riskScore: _riskScore,
      description: _description,
      recommendations: _recommendations,
      aiResult: _aiResult,
      status: _status,
    );
    setState(() => _currentPin = updatedPin);
    widget.onUpdate(updatedPin);
    _hasChanges = false;
  }

  /// Photo AI analysis.
  Future<void> _runAiAnalysis() async {
    if (_currentPin.imageBase64 == null) return;

    setState(() => _isAnalyzing = true);

    try {
      final provider = context.read<InspectionProvider>();
      final updatedPin = await provider.analyzePin(
        _currentPin,
        imageBase64: _currentPin.imageBase64!,
        imagePath: _currentPin.imagePath,
      );

      if (!mounted) return;

      setState(() {
        _aiResult = updatedPin.aiResult ??
            {
              'risk_level': updatedPin.riskLevel,
              'risk_score': updatedPin.riskScore,
              'analysis': updatedPin.description,
              'recommendations': updatedPin.recommendations,
            };
        _riskLevel = updatedPin.riskLevel;
        _riskScore = updatedPin.riskScore;
        _description = updatedPin.description;
        _recommendations = updatedPin.recommendations;
        _status = 'analyzed';
        _isAnalyzing = false;
        _hasChanges = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      debugPrint('AI analysis error: $e');
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Inspection Point'),
        content: Text(
          'Delete inspection point at (${_currentPin.x.toStringAsFixed(2)}, ${_currentPin.y.toStringAsFixed(2)})?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDelete();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ===== + AI analysis Widget =====.
class _PhotoAnalysisDialog extends StatefulWidget {
  final InspectionPin pin;
  final ImagePicker imagePicker;
  final ValueChanged<InspectionPin> onComplete;
  final VoidCallback onDelete;
  final List<InspectionPin> allPins;
  final List<InspectionSession> allSessions;
  final int currentFloor;

  const _PhotoAnalysisDialog({
    required this.pin,
    required this.imagePicker,
    required this.onComplete,
    required this.onDelete,
    required this.allPins,
    required this.allSessions,
    required this.currentFloor,
  });

  @override
  State<_PhotoAnalysisDialog> createState() => _PhotoAnalysisDialogState();
}

class _PhotoAnalysisDialogState extends State<_PhotoAnalysisDialog> {
  late final AiProvider _aiProvider;
  String? _imageBase64;
  String? _imagePath;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;
  bool _photoTaken = false;

  // Inspector observation fields
  final _buildingElementController = TextEditingController();
  final _defectTypeController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _suspectedCauseController = TextEditingController();
  final _recommendationController = TextEditingController();
  final _defectSizeController = TextEditingController();

  // Additional Information form fields (matching inspection form)
  // 0. Extent of Defect
  String? _extentOfDefect; // 'locally' or 'generally'
  // 1. Room information
  final _currentUseController = TextEditingController();
  final _designedUseController = TextEditingController();
  bool? _onlyTypicalFloor;
  final _useOfAboveController = TextEditingController();
  // 2-4, 6: Yes/No toggles
  bool? _adjacentWetArea;
  bool? _adjacentExternalWall;
  bool? _concealedPipeworks;
  bool? _heavyLoadingAbove;
  // 5. Repetitive pattern
  final _repetitivePatternController = TextEditingController();
  // 8. Remarks
  final _remarksController = TextEditingController();

  // Chat.
  final List<ChatMessage> _chatMessages = [];
  final ScrollController _chatScrollController = ScrollController();

  // YOLO.
  List<YoloDetection> _yoloDetections = [];
  bool _isYoloDetecting = false;
  bool _yoloModelLoaded = false;
  bool _showBoundingBoxes = true;
  double? _photoWidth;
  double? _photoHeight;

  @override
  void initState() {
    super.initState();
    _aiProvider = AiProvider();
    // Load photo.
    if (widget.pin.imageBase64 != null) {
      _imageBase64 = widget.pin.imageBase64;
      _imagePath = widget.pin.imagePath;
      _photoTaken = true;
      _updatePhotoDimensions(base64Decode(widget.pin.imageBase64!));
    }
    _initYolo();
  }

  Future<void> _updatePhotoDimensions(Uint8List imageBytes) async {
    try {
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() {
        _photoWidth = frame.image.width.toDouble();
        _photoHeight = frame.image.height.toDouble();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _photoWidth = null;
        _photoHeight = null;
      });
    }
  }

  Future<void> _initYolo() async {
    if (YoloService.isSupported) {
      final loaded = await YoloService.instance.loadModel();
      if (mounted) {
        setState(() => _yoloModelLoaded = loaded);
      }
    }
  }

  @override
  void dispose() {
    _chatScrollController.dispose();
    _buildingElementController.dispose();
    _defectTypeController.dispose();
    _diagnosisController.dispose();
    _suspectedCauseController.dispose();
    _recommendationController.dispose();
    _defectSizeController.dispose();
    _currentUseController.dispose();
    _designedUseController.dispose();
    _useOfAboveController.dispose();
    _repetitivePatternController.dispose();
    _remarksController.dispose();
    _aiProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title.
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.camera_alt, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Photo & AI Analysis',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                        ),
                        Text(
                          'Location: (${widget.pin.x.toStringAsFixed(2)}, ${widget.pin.y.toStringAsFixed(2)})',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Photo ( YOLO Bounding Box ).
                    if (_imageBase64 != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            Image.memory(
                              base64Decode(_imageBase64!),
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.contain,
                            ),
                            // YOLO.
                            if (_showBoundingBoxes &&
                                _yoloDetections.isNotEmpty)
                              Positioned.fill(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    return CustomPaint(
                                      painter: _YoloBoundingBoxPainter(
                                        detections: _yoloDetections,
                                        imageWidth: _photoWidth,
                                        imageHeight: _photoHeight,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            // Result.
                            if (_yoloDetections.isNotEmpty)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.visibility,
                                          color: Colors.greenAccent, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${_yoloDetections.length} Objects',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    else
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isAnalyzing ? null : _showImageSourceOptions,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 150,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.grey.shade300,
                                  style: BorderStyle.solid),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo,
                                    size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text('Select or Take Photo',
                                    style:
                                        TextStyle(color: Colors.grey.shade500)),
                              ],
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 12),

                    // YOLO button ( platform show).
                    if (YoloService.isSupported && _photoTaken) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: (_isYoloDetecting || _isAnalyzing)
                                  ? null
                                  : _runYoloDetection,
                              icon: const Icon(Icons.smart_toy, size: 18),
                              label: Text(_yoloDetections.isNotEmpty
                                  ? 'YOLO Re-detect'
                                  : 'YOLO Object Detection'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          if (_yoloDetections.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _showBoundingBoxes = !_showBoundingBoxes;
                                });
                              },
                              icon: Icon(
                                _showBoundingBoxes
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.deepPurple,
                              ),
                              tooltip: _showBoundingBoxes
                                  ? 'Hide Detection Boxes'
                                  : 'Show Detection Boxes',
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (!_yoloModelLoaded && !_isYoloDetecting)
                        Text(
                          'Loading YOLO Model...',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 11),
                        ),
                    ],

                    // YOLO.
                    if (_isYoloDetecting) ...[
                      const SizedBox(height: 12),
                      const Center(
                        child: Column(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.deepPurple,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text('YOLO Detecting Objects...',
                                style: TextStyle(
                                    color: Colors.deepPurple, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],

                    // YOLO result.
                    if (_yoloDetections.isNotEmpty && !_isYoloDetecting) ...[
                      const SizedBox(height: 8),
                      _buildYoloResultSummary(),
                    ],

                    const SizedBox(height: 12),

                    // --- Structured Input Fields for AI ---
                    if (_photoTaken) ...[
                      _buildStructuredInputFields(),
                      const SizedBox(height: 12),
                    ],

                    // AI Chat.
                    if (_chatMessages.isNotEmpty) ...[
                      Container(
                        constraints: const BoxConstraints(maxHeight: 150),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ListView.builder(
                          controller: _chatScrollController,
                          padding: const EdgeInsets.all(8),
                          itemCount: _chatMessages.length,
                          itemBuilder: (context, index) {
                            final msg = _chatMessages[index];
                            final isUser = msg.role == 'user';
                            return Align(
                              alignment: isUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width *
                                            0.65),
                                decoration: BoxDecoration(
                                  color: isUser
                                      ? AppTheme.primaryColor
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  msg.content,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        isUser ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // AI analysis.
                    if (_isAnalyzing) ...[
                      const SizedBox(height: 16),
                      const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('AI Analyzing...',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],

                    // AI analysisresult.
                    if (_analysisResult != null) ...[
                      const SizedBox(height: 16),
                      _buildAnalysisResultCard(),
                    ],
                  ],
                ),
              ),
            ),

            // Button.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _isAnalyzing ? null : _confirmDeletePin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('Delete'),
                  ),
                  const SizedBox(width: 8),
                  if (_photoTaken && !_isAnalyzing)
                    Flexible(
                      child: ElevatedButton(
                        onPressed: _analyzeImage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child:
                            const Text('AI', overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isAnalyzing ? null : _saveAndClose,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Structured Input Fields for AI Analysis ---
  Widget _buildStructuredInputFields() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: Colors.orange.shade700),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Additional Information',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              Tooltip(
                message:
                    'AI considers surrounding defects within 5m radius\nand the floor above within 5m radius',
                child: Icon(Icons.info_outline,
                    size: 16, color: Colors.blue.shade300),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Inspector observation fields
          _buildInspectorInputField('Building Element',
              _buildingElementController, 'e.g. Column, Beam, Slab, Wall'),
          const SizedBox(height: 6),
          _buildInspectorInputField('Defect Type', _defectTypeController,
              'e.g. Crack, Spalling, Corrosion'),
          const SizedBox(height: 6),
          _buildInspectorInputField('Diagnosis', _diagnosisController,
              'e.g. Structural damage observed'),
          const SizedBox(height: 6),
          _buildInspectorInputField('Suspected Cause',
              _suspectedCauseController, 'e.g. Water ingress, Overloading'),
          const SizedBox(height: 6),
          _buildInspectorInputField('Recommendation', _recommendationController,
              'e.g. Immediate repair required'),
          const SizedBox(height: 6),
          _buildInspectorInputField('Defect Size', _defectSizeController,
              'e.g. 30cm x 10cm, Width 2mm'),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // 0. Extent of Defect
          _buildToggleRow('0. Extent of Defect:', [
            _buildChoiceChip('Locally noted', _extentOfDefect == 'locally',
                () => setState(() => _extentOfDefect = 'locally')),
            _buildChoiceChip('Generally noted', _extentOfDefect == 'generally',
                () => setState(() => _extentOfDefect = 'generally')),
          ]),
          const SizedBox(height: 6),

          // 1. Room information
          const Text('1. Room Information:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          _buildTextInputRow('1.1 Current use:', _currentUseController),
          const SizedBox(height: 4),
          _buildTextInputRow('1.2 Designed use:', _designedUseController),
          const SizedBox(height: 4),
          _buildYesNoRow('1.3 Only typical floor:', _onlyTypicalFloor,
              (v) => setState(() => _onlyTypicalFloor = v)),
          const SizedBox(height: 4),
          _buildTextInputRow('1.4 Use of above:', _useOfAboveController),
          const SizedBox(height: 6),

          // 2. Adjacent wet area
          _buildYesNoRow('2. Adjacent space is wet area:', _adjacentWetArea,
              (v) => setState(() => _adjacentWetArea = v)),
          const SizedBox(height: 4),

          // 3. Adjacent to External wall
          _buildYesNoRow('3. Adjacent to External wall:', _adjacentExternalWall,
              (v) => setState(() => _adjacentExternalWall = v)),
          const SizedBox(height: 4),

          // 4. Any concealed pipeworks
          _buildYesNoRow('4. Any concealed pipeworks:', _concealedPipeworks,
              (v) => setState(() => _concealedPipeworks = v)),
          const SizedBox(height: 4),

          // 5. Any repetitive pattern
          _buildTextInputRow(
              '5. Any repetitive pattern:', _repetitivePatternController),
          const SizedBox(height: 4),

          // 6. Heavy loading on floor above
          _buildYesNoRow('6. Heavy loading on floor above:', _heavyLoadingAbove,
              (v) => setState(() => _heavyLoadingAbove = v)),
          const SizedBox(height: 6),

          // 8. Remarks
          _buildTextInputRow('Remarks:', _remarksController, maxLines: 2),
        ],
      ),
    );
  }

  Widget _buildToggleRow(String label, List<Widget> chips) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
            flex: 4,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500))),
        Expanded(flex: 6, child: Wrap(spacing: 6, children: chips)),
      ],
    );
  }

  Widget _buildChoiceChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: selected ? AppTheme.primaryColor : Colors.grey.shade400),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, color: selected ? Colors.white : Colors.black87)),
      ),
    );
  }

  Widget _buildYesNoRow(
      String label, bool? value, ValueChanged<bool> onChanged) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
            flex: 5,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500))),
        Expanded(
          flex: 5,
          child: Row(
            children: [
              _buildChoiceChip('Yes', value == true, () => onChanged(true)),
              const SizedBox(width: 6),
              _buildChoiceChip('No', value == false, () => onChanged(false)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextInputRow(String label, TextEditingController controller,
      {int maxLines = 1}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 4,
          child: Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ),
        Expanded(
          flex: 6,
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
            ),
            style: const TextStyle(fontSize: 12),
            maxLines: maxLines,
          ),
        ),
      ],
    );
  }

  Widget _buildInspectorInputField(
      String label, TextEditingController controller, String hint) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
            ),
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  String? _readAiStringValue(
      Map<String, dynamic> result, List<String> candidateKeys) {
    for (final key in candidateKeys) {
      final value = result[key];
      if (value == null) continue;
      if (value is String) {
        final text = value.trim();
        if (text.isNotEmpty) return text;
        continue;
      }
      if (value is num || value is bool) {
        return value.toString();
      }
    }
    return null;
  }

  void _applyAiResultToInspectorFields(Map<String, dynamic> result) {
    final buildingElement = _readAiStringValue(result, const [
      'building_element',
      'buildingElement',
      'Building Element',
    ]);
    final defectType = _readAiStringValue(result, const [
      'defect_type',
      'defectType',
      'Defect Type',
    ]);
    final diagnosis = _readAiStringValue(result, const [
      'diagnosis',
      'Diagnosis',
    ]);
    final suspectedCause = _readAiStringValue(result, const [
      'suspected_cause',
      'suspectedCause',
      'Suspected Cause',
    ]);
    String? recommendation = _readAiStringValue(result, const [
      'recommendation',
      'Recommendation',
    ]);
    final defectSize = _readAiStringValue(result, const [
      'defect_size',
      'defectSize',
      'Defect Size',
    ]);

    if (recommendation == null) {
      final recommendations = result['recommendations'];
      if (recommendations is List && recommendations.isNotEmpty) {
        final firstRecommendation = recommendations.first;
        if (firstRecommendation is String &&
            firstRecommendation.trim().isNotEmpty) {
          recommendation = firstRecommendation.trim();
        }
      }
    }

    if (buildingElement != null) {
      _buildingElementController.text = buildingElement;
    }
    if (defectType != null) {
      _defectTypeController.text = defectType;
    }
    if (diagnosis != null) {
      _diagnosisController.text = diagnosis;
    }
    if (suspectedCause != null) {
      _suspectedCauseController.text = suspectedCause;
    }
    if (recommendation != null) {
      _recommendationController.text = recommendation;
    }
    if (defectSize != null) {
      _defectSizeController.text = defectSize;
    }
  }

  /// Gather surrounding defect context within 5m radius (same floor + floor above)
  String _buildSurroundingContext() {
    final buf = StringBuffer();
    final pin = widget.pin;
    const radius = 5.0;

    // Same-floor nearby defects
    final nearbyDefects = <String>[];
    for (final p in widget.allPins) {
      if (p.id == pin.id) continue;
      final dx = p.x - pin.x;
      final dy = p.y - pin.y;
      final dist = (dx * dx + dy * dy);
      if (dist <= radius * radius) {
        for (final d in p.defects) {
          final info = StringBuffer(
              'Defect at (${p.x.toStringAsFixed(1)}, ${p.y.toStringAsFixed(1)}), dist=${dist > 0 ? (dist).toStringAsFixed(1) : "0"}m');
          if (d.buildingElement != null) {
            info.write(', element: ${d.buildingElement}');
          }
          if (d.defectType != null) info.write(', type: ${d.defectType}');
          if (d.description != null) info.write(', desc: ${d.description}');
          if (d.riskLevel != 'low') info.write(', risk: ${d.riskLevel}');
          nearbyDefects.add(info.toString());
        }
      }
    }

    // Floor above defects within 5m horizontal radius
    final floorAbove = widget.currentFloor + 1;
    final aboveDefects = <String>[];
    for (final session in widget.allSessions) {
      if (session.floor == floorAbove) {
        for (final p in session.pins) {
          final dx = p.x - pin.x;
          final dy = p.y - pin.y;
          final dist = (dx * dx + dy * dy);
          if (dist <= radius * radius) {
            for (final d in p.defects) {
              final info = StringBuffer(
                  'Floor-above defect at (${p.x.toStringAsFixed(1)}, ${p.y.toStringAsFixed(1)})');
              if (d.buildingElement != null) {
                info.write(', element: ${d.buildingElement}');
              }
              if (d.defectType != null) info.write(', type: ${d.defectType}');
              if (d.description != null) info.write(', desc: ${d.description}');
              if (d.riskLevel != 'low') info.write(', risk: ${d.riskLevel}');
              aboveDefects.add(info.toString());
            }
          }
        }
      }
    }

    if (nearbyDefects.isNotEmpty) {
      buf.writeln(
          'Surrounding defects within ${radius.toInt()}m radius on the same floor:');
      for (final d in nearbyDefects) {
        buf.writeln('- $d');
      }
    }
    if (aboveDefects.isNotEmpty) {
      buf.writeln(
          'Defects on the floor above within ${radius.toInt()}m radius:');
      for (final d in aboveDefects) {
        buf.writeln('- $d');
      }
    }

    return buf.toString();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      XFile? image;
      if (source == ImageSource.camera) {
        // File_picker.
        if (!kIsWeb &&
            (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
          final result = await FilePicker.platform.pickFiles(
            type: FileType.image,
            dialogTitle: 'Select Photo',
          );
          if (result != null && result.files.single.path != null) {
            image = XFile(result.files.single.path!);
          }
        } else {
          image = await widget.imagePicker.pickImage(
            source: ImageSource.camera,
            maxWidth: 1024,
            maxHeight: 1024,
            imageQuality: 85,
          );
        }
      } else {
        // Gallery / File
        if (!kIsWeb &&
            (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
          final result = await FilePicker.platform.pickFiles(
            type: FileType.image,
            dialogTitle: 'Select Photo',
          );
          if (result != null && result.files.single.path != null) {
            image = XFile(result.files.single.path!);
          }
        } else {
          image = await widget.imagePicker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 1024,
            maxHeight: 1024,
            imageQuality: 85,
          );
        }
      }

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _imageBase64 = base64Encode(bytes);
          _imagePath = image!.path;
          _photoTaken = true;
          _analysisResult = null;
          _yoloDetections = []; // Clear result.
          _photoWidth = null;
          _photoHeight = null;
        });
        _updatePhotoDimensions(bytes);
      }
    } catch (e) {
      debugPrint('Image selection failed: $e');
    }
  }

  Future<void> _showImageSourceOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('From Files'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _analyzeImage() async {
    if (_imageBase64 == null) return;

    setState(() {
      _isAnalyzing = true;
    });

    try {
      // Build additional context from structured fields + surrounding defects
      final contextBuf = StringBuffer();

      // Structured fields
      if (_buildingElementController.text.trim().isNotEmpty) {
        contextBuf.writeln(
            'Building Element: ${_buildingElementController.text.trim()}');
      }
      if (_defectTypeController.text.trim().isNotEmpty) {
        contextBuf.writeln('Defect Type: ${_defectTypeController.text.trim()}');
      }
      if (_diagnosisController.text.trim().isNotEmpty) {
        contextBuf.writeln('Diagnosis: ${_diagnosisController.text.trim()}');
      }
      if (_suspectedCauseController.text.trim().isNotEmpty) {
        contextBuf.writeln(
            'Suspected Cause: ${_suspectedCauseController.text.trim()}');
      }
      if (_recommendationController.text.trim().isNotEmpty) {
        contextBuf.writeln(
            'Recommendation: ${_recommendationController.text.trim()}');
      }
      if (_defectSizeController.text.trim().isNotEmpty) {
        contextBuf.writeln('Defect Size: ${_defectSizeController.text.trim()}');
      }
      if (_extentOfDefect != null) {
        contextBuf.writeln(
            'Extent of Defect: ${_extentOfDefect == 'locally' ? 'Locally noted' : 'Generally noted'}');
      }
      if (_currentUseController.text.trim().isNotEmpty) {
        contextBuf
            .writeln('Room Current Use: ${_currentUseController.text.trim()}');
      }
      if (_designedUseController.text.trim().isNotEmpty) {
        contextBuf.writeln(
            'Room Designed Use: ${_designedUseController.text.trim()}');
      }
      if (_onlyTypicalFloor != null) {
        contextBuf.writeln(
            'Only Typical Floor: ${_onlyTypicalFloor! ? 'Yes' : 'No'}');
      }
      if (_useOfAboveController.text.trim().isNotEmpty) {
        contextBuf
            .writeln('Use of Above: ${_useOfAboveController.text.trim()}');
      }
      if (_adjacentWetArea != null) {
        contextBuf.writeln(
            'Adjacent Space is Wet Area: ${_adjacentWetArea! ? 'Yes' : 'No'}');
      }
      if (_adjacentExternalWall != null) {
        contextBuf.writeln(
            'Adjacent to External Wall: ${_adjacentExternalWall! ? 'Yes' : 'No'}');
      }
      if (_concealedPipeworks != null) {
        contextBuf.writeln(
            'Concealed Pipeworks: ${_concealedPipeworks! ? 'Yes' : 'No'}');
      }
      if (_repetitivePatternController.text.trim().isNotEmpty) {
        contextBuf.writeln(
            'Repetitive Pattern: ${_repetitivePatternController.text.trim()}');
      }
      if (_heavyLoadingAbove != null) {
        contextBuf.writeln(
            'Heavy Loading on Floor Above: ${_heavyLoadingAbove! ? 'Yes' : 'No'}');
      }
      if (_remarksController.text.trim().isNotEmpty) {
        contextBuf.writeln('Remarks: ${_remarksController.text.trim()}');
      }

      // Surrounding defect context
      final surroundingCtx = _buildSurroundingContext();
      if (surroundingCtx.isNotEmpty) {
        contextBuf.writeln();
        contextBuf.writeln(
            'Consider surrounding defects to draw a conclusive cause:');
        contextBuf.write(surroundingCtx);
      }

      final additionalContext = contextBuf.toString().trim();

      await _aiProvider.runVlmAnalysis(
        imageBase64: _imageBase64!,
        additionalContext:
            additionalContext.isNotEmpty ? additionalContext : null,
      );

      final result = _aiProvider.lastVlmResult?.raw;
      if (result == null) {
        throw Exception(_aiProvider.errorMessage ?? 'VLM analysis failed');
      }

      if (!mounted) return;

      _applyAiResultToInspectorFields(result);

      setState(() {
        _analysisResult = result;
        _isAnalyzing = false;

        // AI analysisresult.
        final analysisText =
            result['analysis'] as String? ?? 'Analysis complete';
        final recs =
            (result['recommendations'] as List<dynamic>?)?.join('\n• ') ?? '';
        final riskScore = result['risk_score'] ?? 0;
        final riskLevel = result['risk_level'] ?? 'low';
        final fullMsg =
            '[AI Analysis Result]\nRisk Level: $riskLevel ($riskScore)\n\n$analysisText'
            '${recs.isNotEmpty ? '\n\nRecommendations:\n• $recs' : ''}';
        _chatMessages.add(ChatMessage(
          id: const Uuid().v4(),
          role: 'ai',
          content: fullMsg,
          timestamp: DateTime.now(),
        ));
      });
      _scrollChatToBottom();
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
      });
      debugPrint('AI analysis error: $e');
    }
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// YOLO.
  Future<void> _runYoloDetection() async {
    if (_imageBase64 == null) return;

    setState(() {
      _isYoloDetecting = true;
    });

    try {
      final imageBytes = base64Decode(_imageBase64!);
      await _aiProvider.runYoloDetection(Uint8List.fromList(imageBytes));

      final yoloRaw = _aiProvider.lastYoloResult?.raw;
      if (yoloRaw == null) {
        throw Exception(_aiProvider.errorMessage ?? 'YOLO detection failed');
      }

      final detections =
          ((yoloRaw['detections'] as List<dynamic>?) ?? const <dynamic>[])
              .map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return YoloDetection(
          className: (map['class'] as String?) ?? 'unknown',
          confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
          x: (map['x'] as num?)?.toDouble() ?? 0.0,
          y: (map['y'] as num?)?.toDouble() ?? 0.0,
          width: (map['width'] as num?)?.toDouble() ?? 0.0,
          height: (map['height'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        _yoloDetections = detections;
        _isYoloDetecting = false;
        // AI analysisresult， YOLO result.
        if (_analysisResult == null) {
          _analysisResult = yoloRaw;
        } else {
          // YOLO analysisresult.
          _analysisResult = {
            ..._analysisResult!,
            'yolo_detections': yoloRaw['detections'],
            'yolo_detection_count': yoloRaw['detection_count'],
            'yolo_analysis': yoloRaw['analysis'],
          };
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isYoloDetecting = false;
      });
      debugPrint('YOLO detection error: $e');
    }
  }

  Widget _buildYoloResultSummary() {
    // Translated legacy note.
    final classCount = <String, int>{};
    for (final det in _yoloDetections) {
      classCount[det.className] = (classCount[det.className] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.smart_toy, size: 16, color: Colors.deepPurple),
              const SizedBox(width: 6),
              const Text(
                'YOLO Detection Results',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.deepPurple,
                ),
              ),
              const Spacer(),
              Text(
                '${_yoloDetections.length} Objects',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: classCount.entries.map((e) {
              return Chip(
                label: Text(
                  '${e.key} ×${e.value}',
                  style: const TextStyle(fontSize: 11),
                ),
                backgroundColor: Colors.deepPurple.withValues(alpha: 0.1),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _saveAndClose() {
    var updatedPin = widget.pin;

    // Defect ( ).
    if (_imageBase64 != null) {
      final defect = Defect(
        id: const Uuid().v4(),
        imagePath: _imagePath,
        imageBase64: _imageBase64,
        aiResult: _analysisResult,
        category: _analysisResult?['category'] as String?,
        severity: _analysisResult?['severity'] as String?,
        riskScore: _analysisResult?['risk_score'] as int? ?? 0,
        riskLevel: _analysisResult?['risk_level'] as String? ?? 'low',
        description: _analysisResult?['analysis'] as String?,
        recommendations: (_analysisResult?['recommendations'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        status: _analysisResult != null ? 'analyzed' : 'pending',
        chatMessages: List<ChatMessage>.from(_chatMessages),
        createdAt: DateTime.now(),
        buildingElement: _buildingElementController.text.trim().isNotEmpty
            ? _buildingElementController.text.trim()
            : null,
        defectType: _defectTypeController.text.trim().isNotEmpty
            ? _defectTypeController.text.trim()
            : null,
        diagnosis: _diagnosisController.text.trim().isNotEmpty
            ? _diagnosisController.text.trim()
            : null,
        suspectedCause: _suspectedCauseController.text.trim().isNotEmpty
            ? _suspectedCauseController.text.trim()
            : null,
        recommendation: _recommendationController.text.trim().isNotEmpty
            ? _recommendationController.text.trim()
            : null,
        defectSize: _defectSizeController.text.trim().isNotEmpty
            ? _defectSizeController.text.trim()
            : null,
        extentOfDefect: _extentOfDefect,
        currentUse: _currentUseController.text.trim().isNotEmpty
            ? _currentUseController.text.trim()
            : null,
        designedUse: _designedUseController.text.trim().isNotEmpty
            ? _designedUseController.text.trim()
            : null,
        onlyTypicalFloor: _onlyTypicalFloor,
        useOfAbove: _useOfAboveController.text.trim().isNotEmpty
            ? _useOfAboveController.text.trim()
            : null,
        adjacentWetArea: _adjacentWetArea,
        adjacentExternalWall: _adjacentExternalWall,
        concealedPipeworks: _concealedPipeworks,
        repetitivePattern: _repetitivePatternController.text.trim().isNotEmpty
            ? _repetitivePatternController.text.trim()
            : null,
        heavyLoadingAbove: _heavyLoadingAbove,
        remarks: _remarksController.text.trim().isNotEmpty
            ? _remarksController.text.trim()
            : null,
      );

      final newDefects = [...updatedPin.defects, defect];
      updatedPin = updatedPin.copyWith(
        defects: newDefects,
        imageBase64: _imageBase64,
        imagePath: _imagePath,
      );

      // Update legacy.
      if (_analysisResult != null) {
        updatedPin = updatedPin.copyWith(
          aiResult: _analysisResult,
          riskLevel: _analysisResult!['risk_level'] as String? ?? 'low',
          riskScore: _analysisResult!['risk_score'] as int? ?? 0,
          description: _analysisResult!['analysis'] as String?,
          recommendations:
              (_analysisResult!['recommendations'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  [],
          status: 'analyzed',
        );
      }
    }

    widget.onComplete(updatedPin);
    Navigator.pop(context);
  }

  void _confirmDeletePin() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Inspection Point'),
        content: const Text(
            'Are you sure you want to delete this inspection point?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              widget.onDelete();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisResultCard() {
    final riskLevel = _analysisResult!['risk_level'] as String? ?? 'low';
    final riskScore = _analysisResult!['risk_score'] as int? ?? 0;
    final analysis = _analysisResult!['analysis'] as String? ?? '';
    final recommendations =
        _analysisResult!['recommendations'] as List<dynamic>? ?? [];

    Color riskColor;
    switch (riskLevel) {
      case 'high':
        riskColor = Colors.red;
        break;
      case 'medium':
        riskColor = Colors.orange;
        break;
      default:
        riskColor = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: riskColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: riskColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: riskColor),
              const SizedBox(width: 8),
              const Text(
                'AI Analysis Results',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Risk: $riskScore',
                  style: TextStyle(
                    color: riskColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(analysis, style: const TextStyle(fontSize: 13)),
          if (recommendations.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Recommendations:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ...recommendations.map((r) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 13)),
                      Expanded(
                          child: Text(r.toString(),
                              style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

// ===== YOLO Bounding Box =====.
class _YoloBoundingBoxPainter extends CustomPainter {
  final List<YoloDetection> detections;
  final double? imageWidth;
  final double? imageHeight;

  _YoloBoundingBoxPainter({
    required this.detections,
    this.imageWidth,
    this.imageHeight,
  });

  // Translated legacy note.
  static final List<Color> _colors = [
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.orange,
    Colors.purple,
    Colors.cyan,
    Colors.pink,
    Colors.teal,
    Colors.amber,
    Colors.indigo,
  ];

  Color _getColorForClass(String className) {
    final hash = className.hashCode.abs();
    return _colors[hash % _colors.length];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final sourceWidth = imageWidth;
    final sourceHeight = imageHeight;

    double drawLeft = 0;
    double drawTop = 0;
    double drawWidth = size.width;
    double drawHeight = size.height;

    if (sourceWidth != null && sourceHeight != null && sourceHeight > 0) {
      final imageAspect = sourceWidth / sourceHeight;
      final canvasAspect = size.width / size.height;
      if (imageAspect > canvasAspect) {
        drawWidth = size.width;
        drawHeight = size.width / imageAspect;
        drawTop = (size.height - drawHeight) / 2;
      } else {
        drawHeight = size.height;
        drawWidth = size.height * imageAspect;
        drawLeft = (size.width - drawWidth) / 2;
      }
    }

    for (final det in detections) {
      final color = _getColorForClass(det.className);

      final normalized =
          det.x <= 1.5 && det.y <= 1.5 && det.width <= 1.5 && det.height <= 1.5;

      final nx = normalized
          ? det.x
          : ((sourceWidth != null && sourceWidth > 0)
              ? det.x / sourceWidth
              : 0);
      final ny = normalized
          ? det.y
          : ((sourceHeight != null && sourceHeight > 0)
              ? det.y / sourceHeight
              : 0);
      final nw = normalized
          ? det.width
          : ((sourceWidth != null && sourceWidth > 0)
              ? det.width / sourceWidth
              : 0);
      final nh = normalized
          ? det.height
          : ((sourceHeight != null && sourceHeight > 0)
              ? det.height / sourceHeight
              : 0);

      final left = drawLeft + (nx - nw / 2) * drawWidth;
      final top = drawTop + (ny - nh / 2) * drawHeight;
      final boxWidth = nw * drawWidth;
      final boxHeight = nh * drawHeight;

      final rect = Rect.fromLTWH(left, top, boxWidth, boxHeight);

      // Bounding box.
      final boxPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRect(rect, boxPaint);

      // Current tag data.
      final label =
          '${det.className} ${(det.confidence * 100).toStringAsFixed(0)}%';
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final bgRect = Rect.fromLTWH(
        left,
        (top - textPainter.height - 4).clamp(0.0, size.height),
        textPainter.width + 8,
        textPainter.height + 4,
      );

      final bgPaint = Paint()
        ..color = color.withValues(alpha: 0.85)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(2)),
        bgPaint,
      );

      textPainter.paint(canvas, Offset(left + 4, top - textPainter.height - 2));
    }
  }

  @override
  bool shouldRepaint(covariant _YoloBoundingBoxPainter oldDelegate) {
    return oldDelegate.detections != detections ||
        oldDelegate.imageWidth != imageWidth ||
        oldDelegate.imageHeight != imageHeight;
  }
}

// ===== Android USB OTG connect =====.
class _MobileUsbConnectDialog extends StatefulWidget {
  final UwbService uwbService;
  final int baudRate;

  const _MobileUsbConnectDialog(
      {required this.uwbService, required this.baudRate});

  @override
  State<_MobileUsbConnectDialog> createState() =>
      _MobileUsbConnectDialogState();
}

class _MobileUsbConnectDialogState extends State<_MobileUsbConnectDialog> {
  final MobileSerialService _mobileSerial = MobileSerialService();
  List<UsbDeviceInfo> _devices = [];
  bool _isScanning = true;
  bool _isConnecting = false;
  int _selectedIndex = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scanDevices();
  }

  Future<void> _scanDevices() async {
    setState(() {
      _isScanning = true;
      _error = null;
    });

    try {
      final devices = await _mobileSerial.getAvailableDevices();
      if (mounted) {
        setState(() {
          _devices = devices;
          _isScanning = false;
          if (devices.isEmpty) {
            _error =
                'No USB devices detected.\nPlease ensure:\n• BU04 is connected via USB-C\n• Phone supports USB OTG\n• USB access is authorized';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _error = 'Device scan error: $e';
        });
      }
    }
  }

  Future<void> _connectDevice() async {
    if (_devices.isEmpty || _selectedIndex >= _devices.length) return;

    setState(() {
      _isConnecting = true;
      _error = null;
    });

    final device = _devices[_selectedIndex];
    final success = await widget.uwbService.connect(
      simulate: false,
      port: device.displayName,
      baudRate: widget.baudRate,
    );

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Connected ${device.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _isConnecting = false;
          _error = widget.uwbService.lastError ?? 'Connection Failed';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.usb, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          const Text('USB Device Connection'),
          const Spacer(),
          if (!_isScanning)
            IconButton(
              onPressed: _scanDevices,
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: 'Rescan',
            ),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isScanning)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Scanning for USB devices...'),
                    ],
                  ),
                ),
              )
            else if (_error != null && _devices.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(Icons.usb_off, color: Colors.red.shade400, size: 40),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style:
                          TextStyle(color: Colors.red.shade700, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else ...[
              Text(
                'Found ${_devices.length} USB device(s)',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 12),
              ...List.generate(_devices.length, (i) {
                final d = _devices[i];
                final isSelected = i == _selectedIndex;
                return InkWell(
                  onTap: () => setState(() => _selectedIndex = i),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor.withValues(alpha: 0.1)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.usb,
                          color: isSelected
                              ? AppTheme.primaryColor
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.displayName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : Colors.black87,
                                ),
                              ),
                              Text(
                                'VID: 0x${d.vid.toRadixString(16).toUpperCase()}  PID: 0x${d.pid.toRadixString(16).toUpperCase()}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                    fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle,
                              color: AppTheme.primaryColor),
                      ],
                    ),
                  ),
                );
              }),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!,
                      style:
                          TextStyle(color: Colors.red.shade700, fontSize: 12)),
                ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.blue.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Connect BU04 to the phone with a USB-C cable. The system will auto-detect.',
                      style:
                          TextStyle(color: Colors.blue.shade900, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed:
              (_devices.isEmpty || _isConnecting) ? null : _connectDevice,
          icon: _isConnecting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.link),
          label: Text(_isConnecting ? 'Connecting...' : 'Connect'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

// ===== inspection Painter ( UWB Canvas Pin ) =====.
class InspectionCanvasPainter extends CustomPainter {
  final List<UwbAnchor> anchors;
  final UwbTag? currentTag;
  final UwbConfig config;
  final ui.Image? floorPlanImage;
  final List<InspectionPin> pins;
  final String? selectedPinId;
  final double padding;

  InspectionCanvasPainter({
    required this.anchors,
    this.currentTag,
    required this.config,
    this.floorPlanImage,
    this.pins = const [],
    this.selectedPinId,
    this.padding = 40.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (anchors.isEmpty) {
      _drawEmptyState(canvas, size);
      return;
    }

    // Coordinate.
    double minX = anchors.map((a) => a.x).reduce(min) - 1;
    double maxX = anchors.map((a) => a.x).reduce(max) + 1;
    double minY = anchors.map((a) => a.y).reduce(min) - 1;
    double maxY = anchors.map((a) => a.y).reduce(max) + 1;

    // DEBUG.
    debugPrint(
        '[InspectionCanvas] showFloorPlan=${config.showFloorPlan}, floorPlanImage=${floorPlanImage != null ? "${floorPlanImage!.width}x${floorPlanImage!.height}" : "null"}, xScale=${config.xScale}, yScale=${config.yScale}, xOffset=${config.xOffset}, yOffset=${config.yOffset}');

    // Translated legacy comment.
    if (config.showFloorPlan && floorPlanImage != null) {
      final img = floorPlanImage!;
      final realWidth = img.width.toDouble() / config.xScale;
      final realHeight = img.height.toDouble() / config.yScale;
      final imgLeft = config.xOffset;
      final imgBottom = config.yOffset;
      final imgRight = imgLeft + realWidth;
      final imgTop = imgBottom + realHeight;
      debugPrint(
          '[InspectionCanvas] floorPlan bounds: left=$imgLeft, right=$imgRight, bottom=$imgBottom, top=$imgTop, realW=$realWidth, realH=$realHeight');
      minX = min(minX, imgLeft - 0.5);
      maxX = max(maxX, imgRight + 0.5);
      minY = min(minY, imgBottom - 0.5);
      maxY = max(maxY, imgTop + 0.5);
    }
    debugPrint(
        '[InspectionCanvas] viewport: minX=$minX, maxX=$maxX, minY=$minY, maxY=$maxY');

    final double rangeX = maxX - minX;
    final double rangeY = maxY - minY;

    final double scaleX = (size.width - padding * 2) / rangeX;
    final double scaleY = (size.height - padding * 2) / rangeY;
    final double scale = min(scaleX, scaleY);

    final double offsetX = (size.width - rangeX * scale) / 2;
    final double offsetY = (size.height - rangeY * scale) / 2;

    Offset toCanvas(double x, double y) {
      return Offset(
        offsetX + (x - minX) * scale,
        size.height - offsetY - (y - minY) * scale,
      );
    }

    // Translated legacy note.
    _drawGrid(canvas, size, minX, maxX, minY, maxY, scale, offsetX, offsetY,
        toCanvas);

    // Translated legacy note.
    if (config.showFloorPlan && floorPlanImage != null) {
      _drawFloorPlan(canvas, size, minX, minY, scale, offsetX, offsetY);
    }

    // Fence.
    if (config.showFence && currentTag != null) {
      _drawFence(canvas, toCanvas, scale, currentTag!);
    }

    // Anchor list.
    for (var anchor in anchors) {
      _drawAnchor(canvas, toCanvas(anchor.x, anchor.y), anchor);
    }

    // Current tag data.
    if (currentTag != null) {
      _drawTag(canvas, toCanvas(currentTag!.x, currentTag!.y), currentTag!);
    }

    // Inspection Pin.
    for (int i = 0; i < pins.length; i++) {
      final pin = pins[i];
      final pos = toCanvas(pin.x, pin.y);
      _drawInspectionPin(canvas, pos, pin, i + 1, pin.id == selectedPinId);
    }

    // Coordinate tag.
    _drawAxisLabels(canvas, size, minX, maxX, minY, maxY, scale, offsetX,
        offsetY, toCanvas);
  }

  void _drawInspectionPin(Canvas canvas, Offset position, InspectionPin pin,
      int index, bool isSelected) {
    // Pin.
    Color pinColor;
    switch (pin.riskLevel) {
      case 'high':
        pinColor = Colors.red;
        break;
      case 'medium':
        pinColor = Colors.orange;
        break;
      case 'low':
        pinColor = Colors.green;
        break;
      default:
        pinColor = pin.isAnalyzed ? Colors.blue : Colors.grey;
    }

    // Translated legacy note.
    if (isSelected) {
      final glowPaint = Paint()
        ..color = pinColor.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(position, 20, glowPaint);
    }

    // Pin.
    final pinPath = Path();
    pinPath.moveTo(position.dx, position.dy + 4);
    pinPath.lineTo(position.dx - 8, position.dy - 12);
    pinPath.quadraticBezierTo(
        position.dx - 12, position.dy - 22, position.dx, position.dy - 28);
    pinPath.quadraticBezierTo(
        position.dx + 12, position.dy - 22, position.dx + 8, position.dy - 12);
    pinPath.close();

    // Translated legacy note.
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawPath(pinPath.shift(const Offset(2, 2)), shadowPaint);

    // Pin.
    final pinPaint = Paint()
      ..color = pinColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(pinPath, pinPaint);

    // Pin.
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(pinPath, borderPaint);

    // Translated legacy comment.
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(position.dx, position.dy - 16), 5, dotPaint);

    // Pin.
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$index',
        style: TextStyle(
          color: pinColor,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(position.dx - textPainter.width / 2,
          position.dy - 16 - textPainter.height / 2),
    );

    // (pin ).
    canvas.drawCircle(position, 3, Paint()..color = pinColor);
  }

  // UwbCanvasPainter.

  void _drawEmptyState(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: const TextSpan(
        text:
            'Waiting for UWB device...\nConnect a device or load a floor plan',
        style: TextStyle(color: Colors.grey, fontSize: 16),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout(maxWidth: size.width - 40);
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2,
          (size.height - textPainter.height) / 2),
    );
  }

  void _drawGrid(
      Canvas canvas,
      Size size,
      double minX,
      double maxX,
      double minY,
      double maxY,
      double scale,
      double offsetX,
      double offsetY,
      Offset Function(double, double) toCanvas) {
    final gridPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 0.8;
    final majorGridPaint = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 1.5;
    final originPaint = Paint()
      ..color = Colors.blue.shade800
      ..strokeWidth = 2.5;

    final double startX = minX.floorToDouble();
    final double startY = minY.floorToDouble();

    for (double x = startX; x <= maxX; x += 0.5) {
      Paint paint;
      if ((x - 0.0).abs() < 0.01) {
        paint = originPaint;
      } else if (x % 1 == 0) {
        paint = majorGridPaint;
      } else {
        paint = gridPaint;
      }
      canvas.drawLine(toCanvas(x, minY), toCanvas(x, maxY), paint);
    }

    for (double y = startY; y <= maxY; y += 0.5) {
      Paint paint;
      if ((y - 0.0).abs() < 0.01) {
        paint = originPaint;
      } else if (y % 1 == 0) {
        paint = majorGridPaint;
      } else {
        paint = gridPaint;
      }
      canvas.drawLine(toCanvas(minX, y), toCanvas(maxX, y), paint);
    }
  }

  void _drawFloorPlan(Canvas canvas, Size size, double minX, double minY,
      double scale, double offsetX, double offsetY) {
    if (floorPlanImage == null) return;
    final img = floorPlanImage!;
    final imgWidth = img.width.toDouble();
    final imgHeight = img.height.toDouble();

    final double realWidth = imgWidth / config.xScale;
    final double realHeight = imgHeight / config.yScale;
    final double imgRealX = config.xOffset;
    final double imgRealY = config.yOffset;

    final double canvasLeft = offsetX + (imgRealX - minX) * scale;
    final double canvasTop =
        size.height - offsetY - ((imgRealY + realHeight) - minY) * scale;
    final double canvasWidth = realWidth * scale;
    final double canvasHeight = realHeight * scale;

    final srcRect = Rect.fromLTWH(0, 0, imgWidth, imgHeight);
    final dstRect =
        Rect.fromLTWH(canvasLeft, canvasTop, canvasWidth, canvasHeight);
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..color = Color.fromRGBO(255, 255, 255, config.floorPlanOpacity);
    canvas.drawImageRect(img, srcRect, dstRect, paint);
  }

  void _drawFence(Canvas canvas, Offset Function(double, double) toCanvas,
      double scale, UwbTag tag) {
    final center = toCanvas(tag.x, tag.y);
    canvas.drawCircle(
        center,
        config.areaRadius1 * scale,
        Paint()
          ..color = Colors.green.withValues(alpha: 0.2)
          ..style = PaintingStyle.fill);
    canvas.drawCircle(
        center,
        config.areaRadius1 * scale,
        Paint()
          ..color = Colors.green
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    canvas.drawCircle(
        center,
        config.areaRadius2 * scale,
        Paint()
          ..color = Colors.orange.withValues(alpha: 0.1)
          ..style = PaintingStyle.fill);
  }

  void _drawAnchor(Canvas canvas, Offset position, UwbAnchor anchor) {
    canvas.drawCircle(position, 8, Paint()..color = Colors.brown.shade700);
    final towerPaint = Paint()
      ..color = anchor.isActive ? Colors.green.shade700 : Colors.grey
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final iconPath = Path();
    iconPath.moveTo(position.dx, position.dy - 25);
    iconPath.lineTo(position.dx - 8, position.dy);
    iconPath.moveTo(position.dx, position.dy - 25);
    iconPath.lineTo(position.dx + 8, position.dy);
    iconPath.moveTo(position.dx - 5, position.dy - 10);
    iconPath.lineTo(position.dx + 5, position.dy - 10);
    canvas.drawPath(iconPath, towerPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: anchor.id,
        style: TextStyle(
            color: Colors.grey.shade800,
            fontSize: 11,
            fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
        canvas, Offset(position.dx - textPainter.width / 2, position.dy + 12));
  }

  void _drawTag(Canvas canvas, Offset position, UwbTag tag) {
    canvas.drawCircle(
        position + const Offset(2, 2),
        12,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(position, 12, Paint()..color = AppTheme.primaryColor);
    canvas.drawCircle(
        position,
        12,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);

    final iconPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(position - const Offset(0, 4), 3, iconPaint);
    canvas.drawLine(position - const Offset(0, 1),
        position + const Offset(0, 5), iconPaint);
    canvas.drawLine(position + const Offset(-4, 1),
        position + const Offset(4, 1), iconPaint);
  }

  void _drawAxisLabels(
      Canvas canvas,
      Size size,
      double minX,
      double maxX,
      double minY,
      double maxY,
      double scale,
      double offsetX,
      double offsetY,
      Offset Function(double, double) toCanvas) {
    final textStyle = TextStyle(
      color: Colors.black87,
      fontSize: 14,
      fontWeight: FontWeight.bold,
      backgroundColor: Colors.white.withValues(alpha: 0.8),
    );

    double intervalX = 1.0;
    final double rangeX = (maxX - minX).abs();
    if (rangeX > 30) {
      intervalX = 5.0;
    } else if (rangeX > 15) {
      intervalX = 2.0;
    }

    double intervalY = 1.0;
    final double rangeY = (maxY - minY).abs();
    if (rangeY > 30) {
      intervalY = 5.0;
    } else if (rangeY > 15) {
      intervalY = 2.0;
    }

    final double startX = (minX / intervalX).ceilToDouble() * intervalX;
    final double endX = (maxX / intervalX).floorToDouble() * intervalX;
    final double startY = (minY / intervalY).ceilToDouble() * intervalY;
    final double endY = (maxY / intervalY).floorToDouble() * intervalY;

    for (double x = startX; x <= endX; x += intervalX) {
      final pos = toCanvas(x, minY);
      final tp = TextPainter(
        text: TextSpan(text: '${x.toInt()}m', style: textStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(
          canvas, Offset(pos.dx - tp.width / 2, size.height - offsetY + 8));
    }

    for (double y = startY; y <= endY; y += intervalY) {
      final pos = toCanvas(minX, y);
      final tp = TextPainter(
        text: TextSpan(text: '${y.toInt()}m', style: textStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(offsetX - tp.width - 8, pos.dy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant InspectionCanvasPainter oldDelegate) {
    return oldDelegate.currentTag?.x != currentTag?.x ||
        oldDelegate.currentTag?.y != currentTag?.y ||
        oldDelegate.anchors != anchors ||
        oldDelegate.config != config ||
        oldDelegate.floorPlanImage != floorPlanImage ||
        oldDelegate.pins.length != pins.length ||
        oldDelegate.selectedPinId != selectedPinId ||
        oldDelegate.pins != pins;
  }
}
