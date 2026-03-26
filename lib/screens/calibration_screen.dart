import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bsafe_app/models/uwb_model.dart';
import 'package:bsafe_app/services/uwb_service.dart';
import 'package:bsafe_app/theme/app_theme.dart';

/// Mode： anchor， distanceauto coordinate.
class CalibrationScreen extends StatefulWidget {
  final UwbService uwbService;

  const CalibrationScreen({super.key, required this.uwbService});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  // Mode：floor_plan room_dimension.
  String _mode = 'choose'; // choose, floor_plan, room_dimension

  // Translated legacy note.
  final _roomWidthController = TextEditingController(text: '4.85');
  final _roomHeightController = TextEditingController(text: '5.44');
  double _roomWidth = 4.85;
  double _roomHeight = 5.44;

  // Translated legacy note.
  ui.Image? _floorPlanImage;
  String? _floorPlanPath;

  // Anchor ( coordinate).
  final List<_CalibrationAnchor> _placedAnchors = [];

  // Distance.
  final List<_DistancePair> _distancePairs = [];

  // Anchorheight ( ).
  double _anchorHeight = 3.0;

  // Anchor index( settingsdistance).
  int? _selectedAnchorIndex;
  int? _secondAnchorIndex;

  // ( anchormode ).
  final List<Offset> _referencePoints = [];
  double _referenceRealDistance = 0;
  bool _isPlacingRefPoints = false;

  // Result.
  double? _calculatedScale; // /.
  bool _isCalibrated = false;

  // Translated legacy note.
  final GlobalKey _canvasKey = GlobalKey();

  // Translated legacy comment.
  final TransformationController _transformController = TransformationController();
  double _currentZoom = 1.0;
  int _activePointers = 0; // ， anchor.

  void _zoomIn() {
    final zoom = (_currentZoom * 1.3).clamp(1.0, 8.0);
    _setZoom(zoom);
  }

  void _zoomOut() {
    final zoom = (_currentZoom / 1.3).clamp(1.0, 8.0);
    _setZoom(zoom);
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
    setState(() => _currentZoom = 1.0);
  }

  void _setZoom(double zoom) {
    // Translated legacy note.
    final RenderBox? box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final center = box.size.center(Offset.zero);
    final oldMatrix = _transformController.value.clone();
    final scale = zoom / _currentZoom;
    // Translated legacy note.
    final newMatrix = oldMatrix
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
    _transformController.value = newMatrix;
    setState(() => _currentZoom = zoom);
  }

  @override
  void dispose() {
    _roomWidthController.dispose();
    _roomHeightController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anchor Calibration'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_mode != 'choose')
            TextButton.icon(
              onPressed: _resetCalibration,
              icon: const Icon(Icons.refresh, color: Colors.white70),
              label: const Text('Reset', style: TextStyle(color: Colors.white70)),
            ),
          if (_isCalibrated)
            ElevatedButton.icon(
              onPressed: _applyCalibration,
              icon: const Icon(Icons.check),
              label: const Text('Apply'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _mode == 'choose' ? _buildModeChooser() : _buildCalibrationView(),
    );
  }

  // ===== mode =====.
  Widget _buildModeChooser() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.tune, size: 64, color: AppTheme.primaryColor),
              const SizedBox(height: 16),
              const Text(
                'Select Calibration Method',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Click on the floor plan or room diagram to place anchors, then input distances to auto-calculate coordinates',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 40),

              // ：load.
              _buildModeCard(
                icon: Icons.image,
                title: 'Load Floor Plan',
                subtitle: 'Load a floor plan (PNG/JPG/PDF) and click to place anchors',
                color: AppTheme.primaryColor,
                onTap: () => _pickFloorPlan(),
              ),

              const SizedBox(height: 16),

              // Translated legacy comment.
              _buildModeCard(
                icon: Icons.square_foot,
                title: 'Enter Room Dimensions',
                subtitle: 'Enter room width and height (meters) to auto-generate a diagram',
                color: Colors.teal,
                onTap: () => _showRoomDimensionDialog(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: isMobile ? 28 : 36, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.bold,
                            color: color)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  color: Colors.grey.shade400, size: isMobile ? 16 : 20),
            ],
          ),
        ),
      ),
    );
  }

  // Translated legacy comment.
  Widget _buildCalibrationView() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    if (isMobile) {
      return _buildMobileCalibrationView();
    }

    return Row(
      children: [
        // Translated legacy comment.
        Expanded(
          flex: 3,
          child: Column(
            children: [
              // Translated legacy note.
              _buildToolBar(),
              // Translated legacy comment.
              Expanded(
                child: _buildZoomableCanvas(),
              ),
            ],
          ),
        ),
        // ：settings.
        SizedBox(
          width: 320,
          child: _buildSidePanel(),
        ),
      ],
    );
  }

  // ===== mobile =====.
  Widget _buildMobileCalibrationView() {
    return Column(
      children: [
        // Translated legacy note.
        _buildMobileToolBar(),
        // Translated legacy comment.
        Expanded(
          flex: 3,
          child: _buildZoomableCanvas(),
        ),
        // Settings ( ).
        Expanded(
          flex: 4,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Translated legacy note.
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Content.
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Anchorheight.
                        _buildHeightSetting(),
                        const Divider(height: 24),

                        // Anchor list.
                        _buildAnchorList(),
                        const Divider(height: 24),

                        // Distancesettings.
                        _buildDistanceSection(),
                        const Divider(height: 24),

                        // Result( button).
                        if (_isCalibrated) _buildCalibrationResultInfo(),

                        // Hint.
                        _buildInstructions(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                // 「 」button.
                if (_isCalibrated)
                  SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _applyCalibration,
                          icon: const Icon(Icons.check),
                          label: const Text('Apply to System'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
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

  // ===== mobile =====.
  /// ( InteractiveViewer + button).
  Widget _buildZoomableCanvas() {
    return Stack(
      children: [
        Container(
          color: Colors.grey.shade200,
          child: ClipRect(
            child: Listener(
              onPointerDown: (_) => _activePointers++,
              onPointerUp: (_) => _activePointers--,
              onPointerCancel: (_) => _activePointers--,
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: 1.0,
                maxScale: 8.0,
                panEnabled: true,
                scaleEnabled: true,
                onInteractionEnd: (details) {
                  // Update.
                  final scale = _transformController.value.getMaxScaleOnAxis();
                  setState(() => _currentZoom = scale);
                },
                child: GestureDetector(
                  onTapDown: _handleCanvasTap,
                child: CustomPaint(
                  key: _canvasKey,
                  painter: _CalibrationPainter(
                    mode: _mode,
                    floorPlanImage: _floorPlanImage,
                    roomWidth: _roomWidth,
                    roomHeight: _roomHeight,
                    anchors: _placedAnchors,
                    distancePairs: _distancePairs,
                    selectedIndex: _selectedAnchorIndex,
                    secondIndex: _secondAnchorIndex,
                    calculatedScale: _calculatedScale,
                    referencePoints: _referencePoints,
                    zoom: _currentZoom,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ),
      ),
        // Button.
        Positioned(
          right: 8,
          bottom: 8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Show.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_currentZoom.toStringAsFixed(1)}x',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 4),
              // Translated legacy note.
              _zoomButton(Icons.add, _zoomIn),
              const SizedBox(height: 4),
              // Translated legacy note.
              _zoomButton(Icons.remove, _zoomOut),
              const SizedBox(height: 4),
              // Translated legacy note.
              _zoomButton(Icons.fit_screen, _resetZoom),
            ],
          ),
        ),
      ],
    );
  }

  Widget _zoomButton(IconData icon, VoidCallback onPressed) {
    return Material(
      elevation: 2,
      shape: const CircleBorder(),
      color: Colors.white,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: Colors.grey.shade700),
        ),
      ),
    );
  }

  Widget _buildMobileToolBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Icon(
            _mode == 'floor_plan' ? Icons.image : Icons.square_foot,
            size: 18,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _mode == 'floor_plan' ? 'Floor Plan Calibration' : '$_roomWidth×${_roomHeight}m',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_placedAnchors.length} anchor(s) placed',
              style: TextStyle(color: Colors.blue.shade700, fontSize: 11),
            ),
          ),
          if (_isCalibrated) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 14),
                  SizedBox(width: 2),
                  Text('Calibrated',
                      style: TextStyle(
                          color: Colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Translated legacy comment.
  Widget _buildToolBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Icon(
            _mode == 'floor_plan' ? Icons.image : Icons.square_foot,
            size: 20,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            _mode == 'floor_plan'
                ? 'Floor Plan Calibration'
                : 'Room Size Calibration ($_roomWidth × $_roomHeight m)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Click canvas to place anchors (${_placedAnchors.length} placed)',
              style: TextStyle(color: Colors.blue.shade700, fontSize: 13),
            ),
          ),
          if (_isCalibrated) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Calibrated',
                    style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Translated legacy comment.
  Widget _buildSidePanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
            ),
            child: const Row(
              children: [
                Icon(Icons.cell_tower, color: Colors.white),
                SizedBox(width: 8),
                Text('Anchor Settings',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Anchorheight.
                  _buildHeightSetting(),
                  const Divider(height: 24),

                  // Anchor list.
                  _buildAnchorList(),
                  const Divider(height: 24),

                  // Distancesettings.
                  _buildDistanceSection(),
                  const Divider(height: 24),

                  // Result.
                  if (_isCalibrated) _buildCalibrationResult(),

                  // Hint.
                  _buildInstructions(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== heightsettings =====.
  Widget _buildHeightSetting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Anchor Height (uniform)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: _anchorHeight.toString(),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  suffixText: 'm',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) {
                  final h = double.tryParse(v);
                  if (h != null && h > 0) {
                    setState(() => _anchorHeight = h);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Text('(ceiling height)',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ],
    );
  }

  // ===== anchor =====.
  Widget _buildAnchorList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Placed Anchors',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            Text('${_placedAnchors.length}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 8),
        if (_placedAnchors.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Center(
              child: Text(
                'Click canvas to place anchors',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          )
        else
          ..._placedAnchors.asMap().entries.map((entry) {
            final i = entry.key;
            final a = entry.value;
            final isSelected = i == _selectedAnchorIndex;
            final isSecond = i == _secondAnchorIndex;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.blue.shade50
                    : isSecond
                        ? Colors.orange.shade50
                        : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? Colors.blue
                      : isSecond
                          ? Colors.orange
                          : Colors.grey.shade200,
                  width: isSelected || isSecond ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: _getAnchorColor(i),
                    child: Text('${i + 1}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        if (_isCalibrated && a.realX != null && a.realY != null)
                          Text(
                            '(${a.realX!.toStringAsFixed(2)}, ${a.realY!.toStringAsFixed(2)}) m',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.green.shade700,
                                fontFamily: 'monospace'),
                          )
                        else
                          Text(
                            'Pixels: (${a.pixelX.toInt()}, ${a.pixelY.toInt()})',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600),
                          ),
                      ],
                    ),
                  ),
                  // Distance.
                  InkWell(
                    onTap: () => _selectAnchorForDistance(i),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isSelected || isSecond
                            ? Colors.blue.shade100
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.straighten, size: 16),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => _removeAnchor(i),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.close,
                          size: 16, color: Colors.red.shade400),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ===== distancesettings =====.
  Widget _buildDistanceSection() {
    // Mode： ， distancesettings.
    if (_mode == 'room_dimension' && _placedAnchors.length <= 1) {
      return _buildRoomSingleAnchorInfo();
    }
    // Anchormode：show distance UI.
    if (_placedAnchors.length == 1 && _mode == 'floor_plan') {
      return _buildReferenceDistanceSection();
    }
    return _buildMultiAnchorDistanceSection();
  }

  // Mode anchorhint.
  Widget _buildRoomSingleAnchorInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Anchor Distances',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.teal.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.teal.shade700, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _placedAnchors.isEmpty
                      ? 'Click room diagram to place anchors'
                      : 'Coordinates auto-calculated from room size. Ready to apply.',
                  style: TextStyle(fontSize: 12, color: Colors.teal.shade700),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Anchormode：.
  Widget _buildReferenceDistanceSection() {
    final refPixelDist = _referencePoints.length == 2
        ? sqrt(pow(_referencePoints[1].dx - _referencePoints[0].dx, 2) +
            pow(_referencePoints[1].dy - _referencePoints[0].dy, 2))
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Scale Settings',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            if (_referencePoints.length < 2)
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _referencePoints.clear();
                    _isPlacingRefPoints = true;
                  });
                },
                icon: const Icon(Icons.straighten, size: 16),
                label: Text(
                  _isPlacingRefPoints ? 'Click floor plan...' : 'Mark Reference Distance',
                  style: const TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isPlacingRefPoints ? Colors.orange : AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            if (_referencePoints.length == 2)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _referencePoints.clear();
                    _referenceRealDistance = 0;
                    _isPlacingRefPoints = true;
                    _isCalibrated = false;
                    _calculatedScale = null;
                  });
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Re-mark', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Mark two points of known distance on the floor plan, then enter the real distance',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        if (_isPlacingRefPoints)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.touch_app, color: Colors.orange.shade700, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Click reference point ${_referencePoints.length + 1} on the floor plan',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                  ),
                ),
              ],
            ),
          ),
        if (_referencePoints.length == 2)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        color: Colors.purple.shade300,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(child: Text('A', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.swap_horiz, size: 16),
                    const SizedBox(width: 4),
                    Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        color: Colors.purple.shade300,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(child: Text('B', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: TextFormField(
                          initialValue: _referenceRealDistance > 0 ? _referenceRealDistance.toString() : '',
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            suffixText: 'm',
                            hintText: 'Distance',
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            isDense: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (val) {
                            final d = double.tryParse(val) ?? 0;
                            setState(() {
                              _referenceRealDistance = d;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                if (refPixelDist > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Pixel distance: ${refPixelDist.toStringAsFixed(1)} px',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ),
              ],
            ),
          ),
        if (_referencePoints.length == 2 && _referenceRealDistance > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _recalculate,
                icon: const Icon(Icons.calculate, size: 18),
                label: const Text('Calculate Calibration'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Anchormode.
  Widget _buildMultiAnchorDistanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Anchor Distances',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            if (_placedAnchors.length >= 2)
              TextButton.icon(
                onPressed: _addDistancePair,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Distance', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Select two anchors and enter the real distance (meters)',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        if (_distancePairs.isEmpty && _placedAnchors.length >= 2)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: Colors.orange.shade700, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'At least one distance pair is needed to calculate scale',
                    style:
                        TextStyle(fontSize: 12, color: Colors.orange.shade700),
                  ),
                ),
              ],
            ),
          ),
        ..._distancePairs.asMap().entries.map((entry) {
          final i = entry.key;
          final pair = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: _getAnchorColor(pair.anchorA),
                      child: Text('${pair.anchorA + 1}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 9)),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.swap_horiz, size: 16),
                    const SizedBox(width: 4),
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: _getAnchorColor(pair.anchorB),
                      child: Text('${pair.anchorB + 1}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 9)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: TextFormField(
                          initialValue:
                              pair.distance > 0 ? pair.distance.toString() : '',
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            suffixText: 'm',
                            hintText: 'Distance',
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            isDense: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: const TextStyle(fontSize: 13),
                          onChanged: (v) {
                            final d = double.tryParse(v);
                            if (d != null && d > 0) {
                              setState(() {
                                _distancePairs[i] = _DistancePair(
                                    pair.anchorA, pair.anchorB, d,
                                    pixelDistance: pair.pixelDistance);
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _distancePairs.removeAt(i);
                          _recalculate();
                        });
                      },
                      child: Icon(Icons.close,
                          size: 16, color: Colors.red.shade400),
                    ),
                  ],
                ),
                if (pair.pixelDistance > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Pixel distance: ${pair.pixelDistance.toStringAsFixed(1)} px',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ),
              ],
            ),
          );
        }),
        if (_distancePairs.isNotEmpty &&
            _distancePairs.any((d) => d.distance > 0))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _recalculate,
                icon: const Icon(Icons.calculate, size: 18),
                label: const Text('Calculate Calibration'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ===== result =====.
  Widget _buildCalibrationResult() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text('Calibration Complete',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 15)),
                ],
              ),
              const SizedBox(height: 8),
              Text('Scale: ${_calculatedScale!.toStringAsFixed(4)} m/px',
                  style:
                      const TextStyle(fontSize: 13, fontFamily: 'monospace')),
              const SizedBox(height: 8),
              const Text('Anchor Coordinates:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ..._placedAnchors
                  .where((a) => a.realX != null)
                  .map((a) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '  ${a.name}: (${a.realX!.toStringAsFixed(2)}, ${a.realY!.toStringAsFixed(2)}, ${_anchorHeight.toStringAsFixed(1)})',
                          style: const TextStyle(
                              fontSize: 12, fontFamily: 'monospace'),
                        ),
                      )),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _applyCalibration,
            icon: const Icon(Icons.check),
            label: const Text('Apply to System'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const Divider(height: 24),
      ],
    );
  }

  // ===== result( ， button， mobile )=====.
  Widget _buildCalibrationResultInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text('Calibration Complete',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 15)),
                ],
              ),
              const SizedBox(height: 8),
              Text('Scale: ${_calculatedScale!.toStringAsFixed(4)} m/px',
                  style:
                      const TextStyle(fontSize: 13, fontFamily: 'monospace')),
              const SizedBox(height: 8),
              const Text('Anchor Coordinates:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ..._placedAnchors
                  .where((a) => a.realX != null)
                  .map((a) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '  ${a.name}: (${a.realX!.toStringAsFixed(2)}, ${a.realY!.toStringAsFixed(2)}, ${_anchorHeight.toStringAsFixed(1)})',
                          style: const TextStyle(
                              fontSize: 12, fontFamily: 'monospace'),
                        ),
                      )),
            ],
          ),
        ),
        const Divider(height: 24),
      ],
    );
  }

  // Translated legacy comment.
  Widget _buildInstructions() {
    final isSingleAnchorFloorPlan = _mode == 'floor_plan';
    final isRoomMode = _mode == 'room_dimension';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Steps:',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.blue.shade800)),
          const SizedBox(height: 8),
          if (isRoomMode) ...[
            _buildStep(1, 'Click room diagram to place anchors (at least 1)', _placedAnchors.isNotEmpty),
            _buildStep(2, 'Coordinates auto-calculated from room size', _isCalibrated),
            _buildStep(3, 'Click "Apply to System" to finish', false),
          ] else if (isSingleAnchorFloorPlan) ...[
            _buildStep(1, 'Click canvas to place 1 anchor', _placedAnchors.isNotEmpty),
            _buildStep(2, 'Click "Mark Reference Distance" to place 2 reference points', _referencePoints.length > 1),
            _buildStep(3, 'Enter the real distance between the 2 reference points (meters)', _referenceRealDistance > 0),
            _buildStep(4, 'Click "Calculate Calibration"', _isCalibrated),
            _buildStep(5, 'Click "Apply to System" to finish', false),
          ] else ...[
            _buildStep(1, 'Click canvas to place anchors (at least 1)', _placedAnchors.isNotEmpty),
            if (_placedAnchors.length > 1) ...[
              _buildStep(2, 'Click 📏 to select anchor pairs', _selectedAnchorIndex != null),
              _buildStep(3, 'Enter real distance between anchors (meters)', _distancePairs.any((d) => d.distance > 0)),
            ],
            _buildStep(4, 'Click "Calculate Calibration"', _isCalibrated),
            _buildStep(5, 'Click "Apply to System" to finish', false),
          ],
        ],
      ),
    );
  }

  Widget _buildStep(int num, String text, bool done) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: done ? Colors.green : Colors.grey.shade400,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$num. $text',
              style: TextStyle(
                fontSize: 12,
                color: done ? Colors.green.shade700 : Colors.grey.shade700,
                decoration: done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Translated legacy comment.

  Future<void> _pickFloorPlan() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'bmp', 'pdf'],
      dialogTitle: 'Select Floor Plan',
    );
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      try {
        ui.Image? image;

        if (path.toLowerCase().endsWith('.pdf')) {
          // Ensure pdfrx cache directory is set
          Pdfrx.getCacheDirectory ??= () async => (await getTemporaryDirectory()).path;
          // Render the first page of the PDF to an image
          final doc = await PdfDocument.openFile(path);
          try {
            final page = doc.pages[0];
            final pageImage = await page.render(
              width: (page.width * 2).toInt(),
              height: (page.height * 2).toInt(),
            );
            if (pageImage == null) throw Exception('PDF page rendering failed');
            final pixels = pageImage.pixels;
            final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
            final descriptor = ui.ImageDescriptor.raw(
              buffer,
              width: pageImage.width,
              height: pageImage.height,
              pixelFormat: ui.PixelFormat.rgba8888,
            );
            final codec = await descriptor.instantiateCodec();
            final frame = await codec.getNextFrame();
            descriptor.dispose();
            buffer.dispose();
            image = frame.image;
          } finally {
            doc.dispose();
          }
        } else {
          final file = File(path);
          final bytes = await file.readAsBytes();
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          image = frame.image;
        }

        setState(() {
          _floorPlanImage = image;
          _floorPlanPath = path;
          _mode = 'floor_plan';
          _placedAnchors.clear();
          _distancePairs.clear();
          _isCalibrated = false;
          _calculatedScale = null;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load floor plan: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showRoomDimensionDialog() {
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
              controller: _roomWidthController,
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
              controller: _roomHeightController,
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
              final w = double.tryParse(_roomWidthController.text);
              final h = double.tryParse(_roomHeightController.text);
              if (w != null && h != null && w > 0 && h > 0) {
                setState(() {
                  _roomWidth = w;
                  _roomHeight = h;
                  _mode = 'room_dimension';
                  _placedAnchors.clear();
                  _distancePairs.clear();
                  _isCalibrated = false;
                  _calculatedScale = null;
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleCanvasTap(TapDownDetails details) {
    final RenderBox? box =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    // 1 ( )， ， anchor.
    if (_activePointers > 1) return;

    // InteractiveViewer Transform auto hit test coordinate coordinate.
    // Details.localPosition coordinate，.
    final localPosition = details.localPosition;
    final size = box.size;

    if (_mode == 'room_dimension') {
      // Mode：.
      const padding = 60.0;
      final drawWidth = size.width - padding * 2;
      final drawHeight = size.height - padding * 2;
      final scaleX = drawWidth / _roomWidth;
      final scaleY = drawHeight / _roomHeight;
      final scale = min(scaleX, scaleY);
      final ox = (size.width - _roomWidth * scale) / 2;
      final oy = (size.height - _roomHeight * scale) / 2;

      // Translated legacy note.
      final px = localPosition.dx;
      final py = localPosition.dy;
      if (px >= ox &&
          px <= ox + _roomWidth * scale &&
          py >= oy &&
          py <= oy + _roomHeight * scale) {
        // Coordinate.
        final realX = (px - ox) / scale;
        final realY = _roomHeight - (py - oy) / scale; // Y.

        setState(() {
          _placedAnchors.add(_CalibrationAnchor(
            name: 'Anchor${_placedAnchors.length}',
            pixelX: px,
            pixelY: py,
            realX: realX,
            realY: realY,
          ));
          _isCalibrated = false;
          // Mode autoupdatedistance distance.
          _updatePixelDistances();
          // Mode coordinate， auto.
          _autoCalibRoomMode();
        });
      }
    } else if (_mode == 'floor_plan') {
      if (_isPlacingRefPoints) {
        // Count occurrences of detected offset patterns.
        if (_referencePoints.length < 2) {
          setState(() {
            _referencePoints.add(localPosition);
            if (_referencePoints.length == 2) {
              _isPlacingRefPoints = false;
            }
          });
        }
      } else {
        // Anchormode.
        setState(() {
          _placedAnchors.add(_CalibrationAnchor(
            name: 'Anchor${_placedAnchors.length}',
            pixelX: localPosition.dx,
            pixelY: localPosition.dy,
          ));
          _isCalibrated = false;
          _updatePixelDistances();
        });
      }
    }
  }

  void _selectAnchorForDistance(int index) {
    setState(() {
      if (_selectedAnchorIndex == null) {
        _selectedAnchorIndex = index;
        _secondAnchorIndex = null;
      } else if (_selectedAnchorIndex == index) {
        _selectedAnchorIndex = null;
        _secondAnchorIndex = null;
      } else {
        _secondAnchorIndex = index;
        // Auto distance.
        _addDistancePairFromSelection();
        _selectedAnchorIndex = null;
        _secondAnchorIndex = null;
      }
    });
  }

  void _addDistancePairFromSelection() {
    if (_selectedAnchorIndex == null || _secondAnchorIndex == null) return;
    final a = _selectedAnchorIndex!;
    final b = _secondAnchorIndex!;

    // Translated legacy note.
    final exists = _distancePairs.any((p) =>
        (p.anchorA == a && p.anchorB == b) ||
        (p.anchorA == b && p.anchorB == a));
    if (exists) return;

    final pixDist = _pixelDistance(a, b);
    setState(() {
      _distancePairs.add(_DistancePair(a, b, 0, pixelDistance: pixDist));
    });
  }

  void _addDistancePair() {
    if (_placedAnchors.length < 2) return;
    // Translated legacy note.
    for (int i = 0; i < _placedAnchors.length; i++) {
      for (int j = i + 1; j < _placedAnchors.length; j++) {
        final exists = _distancePairs.any((p) =>
            (p.anchorA == i && p.anchorB == j) ||
            (p.anchorA == j && p.anchorB == i));
        if (!exists) {
          final pixDist = _pixelDistance(i, j);
          setState(() {
            _distancePairs.add(_DistancePair(i, j, 0, pixelDistance: pixDist));
          });
          return;
        }
      }
    }
    // Translated legacy note.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All anchor pair distances added')),
      );
    }
  }

  void _removeAnchor(int index) {
    setState(() {
      _placedAnchors.removeAt(index);
      // Updatedistance.
      _distancePairs
          .removeWhere((p) => p.anchorA == index || p.anchorB == index);
      for (int i = 0; i < _distancePairs.length; i++) {
        final p = _distancePairs[i];
        _distancePairs[i] = _DistancePair(
          p.anchorA > index ? p.anchorA - 1 : p.anchorA,
          p.anchorB > index ? p.anchorB - 1 : p.anchorB,
          p.distance,
          pixelDistance: p.pixelDistance,
        );
      }
      _isCalibrated = false;
      _calculatedScale = null;
    });
  }

  double _pixelDistance(int a, int b) {
    final ax = _placedAnchors[a].pixelX;
    final ay = _placedAnchors[a].pixelY;
    final bx = _placedAnchors[b].pixelX;
    final by = _placedAnchors[b].pixelY;
    return sqrt(pow(ax - bx, 2) + pow(ay - by, 2));
  }

  void _updatePixelDistances() {
    for (int i = 0; i < _distancePairs.length; i++) {
      final p = _distancePairs[i];
      if (p.anchorA < _placedAnchors.length &&
          p.anchorB < _placedAnchors.length) {
        _distancePairs[i] = _DistancePair(p.anchorA, p.anchorB, p.distance,
            pixelDistance: _pixelDistance(p.anchorA, p.anchorB));
      }
    }
  }

  void _autoCalibRoomMode() {
    // Mode coordinate， distance.
    if (_mode == 'room_dimension' && _placedAnchors.isNotEmpty) {
      setState(() {
        _calculatedScale = 1.0; // Mode.
        _isCalibrated = true;
      });
    }
  }

  void _recalculate() {
    if (_mode == 'room_dimension') {
      _autoCalibRoomMode();
      return;
    }

    // Anchor + mode.
    if (_placedAnchors.length == 1 && _referencePoints.length == 2 && _referenceRealDistance > 0) {
      final dx = _referencePoints[1].dx - _referencePoints[0].dx;
      final dy = _referencePoints[1].dy - _referencePoints[0].dy;
      final refPixelDist = sqrt(dx * dx + dy * dy);
      if (refPixelDist > 0) {
        final scale = _referenceRealDistance / refPixelDist;
        setState(() {
          _calculatedScale = scale;
          _placedAnchors[0] = _CalibrationAnchor(
            name: _placedAnchors[0].name,
            pixelX: _placedAnchors[0].pixelX,
            pixelY: _placedAnchors[0].pixelY,
            realX: 0.0,
            realY: 0.0,
          );
          _isCalibrated = true;
        });
      }
      return;
    }

    // Anchormode： distance.
    final validPairs = _distancePairs.where((p) => p.distance > 0).toList();
    if (validPairs.isEmpty) return;

    // PixelDistance update.
    _updatePixelDistances();

    // Moving average window size.
    double totalScale = 0;
    int count = 0;
    for (final pair in validPairs) {
      final pixDist = (pair.anchorA < _placedAnchors.length &&
              pair.anchorB < _placedAnchors.length)
          ? _pixelDistance(pair.anchorA, pair.anchorB)
          : pair.pixelDistance;
      if (pixDist > 0) {
        totalScale += pair.distance / pixDist;
        count++;
      }
    }
    if (count == 0) return;

    final avgScale = totalScale / count;

    // Anchor ， anchor coordinate.
    final originX = _placedAnchors[0].pixelX;
    final originY = _placedAnchors[0].pixelY;

    setState(() {
      _calculatedScale = avgScale;
      for (int i = 0; i < _placedAnchors.length; i++) {
        final a = _placedAnchors[i];
        _placedAnchors[i] = _CalibrationAnchor(
          name: a.name,
          pixelX: a.pixelX,
          pixelY: a.pixelY,
          realX: (a.pixelX - originX) * avgScale,
          realY: -(a.pixelY - originY) * avgScale,
        );
      }
      _isCalibrated = true;
    });
  }

  void _resetCalibration() {
    _transformController.value = Matrix4.identity();
    setState(() {
      _currentZoom = 1.0;
      _placedAnchors.clear();
      _distancePairs.clear();
      _referencePoints.clear();
      _referenceRealDistance = 0;
      _isPlacingRefPoints = false;
      _isCalibrated = false;
      _calculatedScale = null;
      _selectedAnchorIndex = null;
      _secondAnchorIndex = null;
      _mode = 'choose';
      _floorPlanImage = null;
      _floorPlanPath = null;
    });
  }

  Future<void> _applyCalibration() async {
    if (!_isCalibrated || _placedAnchors.isEmpty) return;

    final uwb = widget.uwbService;

    // Clear anchor.
    while (uwb.anchors.isNotEmpty) {
      uwb.removeAnchor(0);
    }

    // Anchor list.
    for (final a in _placedAnchors) {
      final x = a.realX ?? 0.0;
      final y = a.realY ?? 0.0;
      uwb.addAnchor(UwbAnchor(
        id: a.name,
        x: x,
        y: y,
        z: _anchorHeight,
        isActive: true,
      ));
    }

    // ， floor plan.
    if (_mode == 'floor_plan' &&
        _floorPlanPath != null &&
        _calculatedScale != null &&
        _floorPlanImage != null) {
      final img = _floorPlanImage!;
      final imgWidth = img.width.toDouble();
      final imgHeight = img.height.toDouble();

      // ， image show.
      final RenderBox? box =
          _canvasKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        final widgetSize = box.size;
        // _CalibrationPainter._drawFloorPlan.
        final scaleX = widgetSize.width / imgWidth;
        final scaleY = widgetSize.height / imgHeight;
        final displayScale = min(scaleX, scaleY) * 0.9;
        final ox = (widgetSize.width - imgWidth * displayScale) / 2;
        final oy = (widgetSize.height - imgHeight * displayScale) / 2;

        // Anchor widget coordinate image coordinate.
        final originImageX =
            (_placedAnchors[0].pixelX - ox) / displayScale;
        final originImageY =
            (_placedAnchors[0].pixelY - oy) / displayScale;

        // Floor plan image cache.
        // _calculatedScale = /widget.
        // Image = widget / displayScale.
        // /image = _calculatedScale * displayScale.
        final metersPerImagePixel = _calculatedScale! * displayScale;
        final pixelsPerMeter = 1.0 / metersPerImagePixel;

        // ：image UWB coordinate.
        // Image (X=0) coordinate.
        final offsetX = -originImageX * metersPerImagePixel;
        // Image (Y=imgHeight) coordinate.
        final offsetY =
            -(imgHeight - originImageY) * metersPerImagePixel;

        debugPrint('[Calibration] displayScale=$displayScale, ox=$ox, oy=$oy');
        debugPrint('[Calibration] originImageX=$originImageX, originImageY=$originImageY');
        debugPrint('[Calibration] metersPerImagePixel=$metersPerImagePixel, pixelsPerMeter=$pixelsPerMeter');
        debugPrint('[Calibration] offsetX=$offsetX, offsetY=$offsetY');
        debugPrint('[Calibration] imgWidth=$imgWidth, imgHeight=$imgHeight');

        uwb.updateConfig(uwb.config.copyWith(
          xScale: pixelsPerMeter,
          yScale: pixelsPerMeter,
          xOffset: offsetX,
          yOffset: offsetY,
          flipX: false,
          flipY: false,
          showFloorPlan: true,
        ));
        debugPrint('[Calibration] config after update: showFloorPlan=${uwb.config.showFloorPlan}, xScale=${uwb.config.xScale}, yScale=${uwb.config.yScale}, xOffset=${uwb.config.xOffset}, yOffset=${uwb.config.yOffset}');
      }

      // Load (await imageload ).
      await uwb.loadFloorPlanImage(_floorPlanPath!);
    } else if (_mode == 'room_dimension') {
      // Mode，.
      uwb.updateConfig(uwb.config.copyWith(
        showFloorPlan: false,
      ));
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Calibration applied: ${_placedAnchors.length} anchor(s)'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  Color _getAnchorColor(int index) {
    const colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal
    ];
    return colors[index % colors.length];
  }
}

// Translated legacy comment.
class _CalibrationAnchor {
  final String name;
  final double pixelX;
  final double pixelY;
  final double? realX; // Coordinate ( ).
  final double? realY;

  _CalibrationAnchor({
    required this.name,
    required this.pixelX,
    required this.pixelY,
    this.realX,
    this.realY,
  });
}

class _DistancePair {
  final int anchorA;
  final int anchorB;
  final double distance; // Distance ( ).
  final double pixelDistance; // Distance.

  _DistancePair(this.anchorA, this.anchorB, this.distance,
      {this.pixelDistance = 0});
}

// ===== Painter =====.
class _CalibrationPainter extends CustomPainter {
  final String mode;
  final ui.Image? floorPlanImage;
  final double roomWidth;
  final double roomHeight;
  final List<_CalibrationAnchor> anchors;
  final List<_DistancePair> distancePairs;
  final int? selectedIndex;
  final int? secondIndex;
  final double? calculatedScale;
  final List<Offset> referencePoints;
  final double zoom;

  _CalibrationPainter({
    required this.mode,
    this.floorPlanImage,
    required this.roomWidth,
    required this.roomHeight,
    required this.anchors,
    required this.distancePairs,
    this.selectedIndex,
    this.secondIndex,
    this.calculatedScale,
    this.referencePoints = const [],
    this.zoom = 1.0,
  });

  static const _anchorColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (mode == 'room_dimension') {
      _drawRoom(canvas, size);
    } else if (mode == 'floor_plan') {
      _drawFloorPlan(canvas, size);
    }

    // Distance.
    _drawDistanceLines(canvas, size);

    // Translated legacy note.
    _drawReferencePoints(canvas, size);

    // Anchor list.
    for (int i = 0; i < anchors.length; i++) {
      _drawAnchor(canvas, anchors[i], i);
    }
  }

  void _drawRoom(Canvas canvas, Size size) {
    const padding = 60.0;
    final drawWidth = size.width - padding * 2;
    final drawHeight = size.height - padding * 2;
    final scaleX = drawWidth / roomWidth;
    final scaleY = drawHeight / roomHeight;
    final scale = min(scaleX, scaleY);
    final ox = (size.width - roomWidth * scale) / 2;
    final oy = (size.height - roomHeight * scale) / 2;

    // Translated legacy note.
    final roomRect =
        Rect.fromLTWH(ox, oy, roomWidth * scale, roomHeight * scale);
    canvas.drawRect(roomRect, Paint()..color = Colors.white);
    canvas.drawRect(
      roomRect,
      Paint()
        ..color = Colors.grey.shade800
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Translated legacy comment.
    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 0.5;
    for (double x = 0; x <= roomWidth; x += 1.0) {
      canvas.drawLine(
        Offset(ox + x * scale, oy),
        Offset(ox + x * scale, oy + roomHeight * scale),
        gridPaint,
      );
    }
    for (double y = 0; y <= roomHeight; y += 1.0) {
      canvas.drawLine(
        Offset(ox, oy + y * scale),
        Offset(ox + roomWidth * scale, oy + y * scale),
        gridPaint,
      );
    }

    // Translated legacy comment.
    _drawDimensionLabel(
        canvas,
        Offset(ox, oy + roomHeight * scale + 20),
        Offset(ox + roomWidth * scale, oy + roomHeight * scale + 20),
        '${roomWidth}m');

    // Translated legacy comment.
    _drawDimensionLabel(
        canvas,
        Offset(ox + roomWidth * scale + 20, oy),
        Offset(ox + roomWidth * scale + 20, oy + roomHeight * scale),
        '${roomHeight}m',
        vertical: true);

    // Translated legacy note.
    _drawCornerLabel(canvas, Offset(ox, oy + roomHeight * scale), '(0, 0)');
    _drawCornerLabel(
        canvas,
        Offset(ox + roomWidth * scale, oy + roomHeight * scale),
        '($roomWidth, 0)');
    _drawCornerLabel(canvas, Offset(ox, oy), '(0, $roomHeight)');
    _drawCornerLabel(canvas, Offset(ox + roomWidth * scale, oy),
        '($roomWidth, $roomHeight)');
  }

  void _drawCornerLabel(Canvas canvas, Offset pos, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy + 4));
  }

  void _drawDimensionLabel(Canvas canvas, Offset start, Offset end, String text,
      {bool vertical = false}) {
    final paint = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 1;

    canvas.drawLine(start, end, paint);

    // Translated legacy note.
    if (!vertical) {
      canvas.drawLine(start, start + const Offset(8, -4), paint);
      canvas.drawLine(start, start + const Offset(8, 4), paint);
      canvas.drawLine(end, end + const Offset(-8, -4), paint);
      canvas.drawLine(end, end + const Offset(-8, 4), paint);
    }

    final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
            color: Colors.grey.shade800,
            fontSize: 13,
            fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    if (vertical) {
      canvas.save();
      canvas.translate(mid.dx + 10, mid.dy);
      canvas.rotate(-pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, 0));
      canvas.restore();
    } else {
      tp.paint(canvas, Offset(mid.dx - tp.width / 2, mid.dy + 4));
    }
  }

  void _drawFloorPlan(Canvas canvas, Size size) {
    if (floorPlanImage == null) return;

    final img = floorPlanImage!;
    final imgWidth = img.width.toDouble();
    final imgHeight = img.height.toDouble();

    // Floor plan image cache.
    final scaleX = size.width / imgWidth;
    final scaleY = size.height / imgHeight;
    final scale = min(scaleX, scaleY) * 0.9;
    final ox = (size.width - imgWidth * scale) / 2;
    final oy = (size.height - imgHeight * scale) / 2;

    final srcRect = Rect.fromLTWH(0, 0, imgWidth, imgHeight);
    final dstRect = Rect.fromLTWH(ox, oy, imgWidth * scale, imgHeight * scale);

    // Translated legacy note.
    canvas.drawRect(dstRect, Paint()..color = Colors.white);

    // Floor plan image cache.
    canvas.drawImageRect(
        img, srcRect, dstRect, Paint()..filterQuality = FilterQuality.medium);

    // Translated legacy note.
    canvas.drawRect(
      dstRect,
      Paint()
        ..color = Colors.grey.shade600
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawReferencePoints(Canvas canvas, Size size) {
    if (referencePoints.isEmpty) return;
    final s = 1.0 / zoom;

    // Draw reference points
    for (int i = 0; i < referencePoints.length; i++) {
      final pos = referencePoints[i];
      canvas.drawCircle(pos, 8 * s, Paint()..color = Colors.purple.shade300);
      canvas.drawCircle(
        pos,
        8 * s,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * s,
      );
      // Label
      final label = i == 0 ? 'A' : 'B';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
              color: Colors.white, fontSize: 10 * s, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
    }

    // Draw line between reference points
    if (referencePoints.length == 2) {
      final dashPaint = Paint()
        ..color = Colors.purple.shade300
        ..strokeWidth = 2 * s
        ..style = PaintingStyle.stroke;

      canvas.drawLine(referencePoints[0], referencePoints[1], dashPaint);
    }
  }

  void _drawDistanceLines(Canvas canvas, Size size) {
    for (final pair in distancePairs) {
      if (pair.anchorA >= anchors.length || pair.anchorB >= anchors.length) {
        continue;
      }

      final a = anchors[pair.anchorA];
      final b = anchors[pair.anchorB];
      final start = Offset(a.pixelX, a.pixelY);
      final end = Offset(b.pixelX, b.pixelY);

      // Translated legacy note.
      final paint = Paint()
        ..color = Colors.blue.shade400
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      canvas.drawLine(start, end, paint);

      // Distancetag.
      if (pair.distance > 0) {
        final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
        final labelBg = Paint()..color = Colors.white;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: mid, width: 60, height: 20),
            const Radius.circular(4),
          ),
          labelBg,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: mid, width: 60, height: 20),
            const Radius.circular(4),
          ),
          Paint()
            ..color = Colors.blue.shade400
            ..style = PaintingStyle.stroke,
        );

        final tp = TextPainter(
          text: TextSpan(
            text: '${pair.distance}m',
            style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 11,
                fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        tp.paint(canvas, Offset(mid.dx - tp.width / 2, mid.dy - tp.height / 2));
      }
    }
  }

  void _drawAnchor(Canvas canvas, _CalibrationAnchor anchor, int index) {
    final pos = Offset(anchor.pixelX, anchor.pixelY);
    final color = _anchorColors[index % _anchorColors.length];
    final isSelected = index == selectedIndex;
    final isSecond = index == secondIndex;
    final s = 1.0 / zoom; // inverse scale so markers stay constant screen size

    // Translated legacy note.
    if (isSelected || isSecond) {
      canvas.drawCircle(
        pos,
        24 * s,
        Paint()
          ..color =
              (isSelected ? Colors.blue : Colors.orange).withValues(alpha: 0.3)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * s),
      );
    }

    // Translated legacy note.
    canvas.drawCircle(
      pos + Offset(2 * s, 2 * s),
      14 * s,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.15)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * s),
    );

    // Anchor list.
    canvas.drawCircle(pos, 14 * s, Paint()..color = color);
    canvas.drawCircle(
      pos,
      14 * s,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * s,
    );

    // Translated legacy note.
    final tp = TextPainter(
      text: TextSpan(
        text: '${index + 1}',
        style: TextStyle(
            color: Colors.white, fontSize: 13 * s, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));

    // Current tag data.
    final nameTp = TextPainter(
      text: TextSpan(
        text: anchor.name,
        style: TextStyle(
            color: Colors.grey.shade800,
            fontSize: 11 * s,
            fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    nameTp.layout();

    // Current tag data.
    final labelRect = Rect.fromLTWH(
      pos.dx - nameTp.width / 2 - 4 * s,
      pos.dy + 18 * s,
      nameTp.width + 8 * s,
      nameTp.height + 4 * s,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, Radius.circular(4 * s)),
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    nameTp.paint(canvas, Offset(pos.dx - nameTp.width / 2, pos.dy + 20 * s));

    // Coordinatetag.
    if (anchor.realX != null && anchor.realY != null) {
      final coordTp = TextPainter(
        text: TextSpan(
          text:
              '(${anchor.realX!.toStringAsFixed(2)}, ${anchor.realY!.toStringAsFixed(2)})',
          style: TextStyle(
              color: Colors.green.shade700,
              fontSize: 9 * s,
              fontFamily: 'monospace'),
        ),
        textDirection: TextDirection.ltr,
      );
      coordTp.layout();
      final coordRect = Rect.fromLTWH(
        pos.dx - coordTp.width / 2 - 3 * s,
        pos.dy + 32 * s,
        coordTp.width + 6 * s,
        coordTp.height + 2 * s,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(coordRect, Radius.circular(3 * s)),
        Paint()..color = Colors.green.shade50,
      );
      coordTp.paint(canvas, Offset(pos.dx - coordTp.width / 2, pos.dy + 33 * s));
    }
  }

  @override
  bool shouldRepaint(covariant _CalibrationPainter oldDelegate) => true;
}
