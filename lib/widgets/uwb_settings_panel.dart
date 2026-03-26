import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:bsafe_app/models/uwb_model.dart';
import 'package:bsafe_app/services/uwb_service.dart';
import 'package:bsafe_app/theme/app_theme.dart';

/// UWB settings - UWB TWR settings.
class UwbSettingsPanel extends StatefulWidget {
  final UwbService uwbService;
  final VoidCallback? onClose;

  const UwbSettingsPanel({
    super.key,
    required this.uwbService,
    this.onClose,
  });

  @override
  State<UwbSettingsPanel> createState() => _UwbSettingsPanelState();
}

class _UwbSettingsPanelState extends State<UwbSettingsPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Translated legacy note.
  late TextEditingController _gridWidthController;
  late TextEditingController _gridHeightController;
  late TextEditingController _area1Controller;
  late TextEditingController _area2Controller;
  late TextEditingController _correctionAController;
  late TextEditingController _correctionBController;
  late TextEditingController _xOffsetController;
  late TextEditingController _yOffsetController;
  late TextEditingController _xScaleController;
  late TextEditingController _yScaleController;
  late TextEditingController _floorPlanOpacityController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    final config = widget.uwbService.config;
    _gridWidthController =
        TextEditingController(text: config.gridWidth.toString());
    _gridHeightController =
        TextEditingController(text: config.gridHeight.toString());
    _area1Controller =
        TextEditingController(text: config.areaRadius1.toString());
    _area2Controller =
        TextEditingController(text: config.areaRadius2.toString());
    _correctionAController =
        TextEditingController(text: config.correctionA.toString());
    _correctionBController =
        TextEditingController(text: config.correctionB.toString());
    _xOffsetController = TextEditingController(text: config.xOffset.toString());
    _yOffsetController = TextEditingController(text: config.yOffset.toString());
    _xScaleController = TextEditingController(text: config.xScale.toString());
    _yScaleController = TextEditingController(text: config.yScale.toString());
    _floorPlanOpacityController =
        TextEditingController(text: config.floorPlanOpacity.toString());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _gridWidthController.dispose();
    _gridHeightController.dispose();
    _area1Controller.dispose();
    _area2Controller.dispose();
    _correctionAController.dispose();
    _correctionBController.dispose();
    _xOffsetController.dispose();
    _yOffsetController.dispose();
    _xScaleController.dispose();
    _yScaleController.dispose();
    _floorPlanOpacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      width: 320,
      height: screenHeight * 0.75, // Use 75% of screen height
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.75,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.settings, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (widget.onClose != null)
                  IconButton(
                    onPressed: widget.onClose,
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),

          // Tab.
          Container(
            color: Colors.grey.shade100,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: AppTheme.primaryColor,
              labelStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'Features'),
                Tab(text: 'Floor Plan'),
                Tab(text: 'Grid'),
                Tab(text: 'Serial Config'),
              ],
            ),
          ),

          // Tab content.
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFunctionSettings(),
                _buildMapSettings(),
                _buildGridSettings(),
                _buildSerialSettings(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Settings Tab.
  Widget _buildFunctionSettings() {
    final config = widget.uwbService.config;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Translated legacy note.
          _buildSectionTitle('Feature Selection'),
          _buildCheckboxRow('Show Anchor List', config.showAnchorList, (v) {
            _updateConfig(config.copyWith(showAnchorList: v));
          }),
          _buildCheckboxRow('Auto Get Anchor Coords', config.autoGetAnchorCoords, (v) {
            _updateConfig(config.copyWith(autoGetAnchorCoords: v));
          }),
          _buildCheckboxRow('Show Tag List', config.showTagList, (v) {
            _updateConfig(config.copyWith(showTagList: v));
          }),
          _buildCheckboxRow('Show History Trajectory', config.showHistoryTrajectory, (v) {
            _updateConfig(config.copyWith(showHistoryTrajectory: v));
          }),
          _buildCheckboxRow('Trajectory/Navigation Mode', config.showTrajectory, (v) {
            _updateConfig(config.copyWith(showTrajectory: v));
          }),
          _buildCheckboxRow('Geofence Mode', config.showFence, (v) {
            _updateConfig(config.copyWith(showFence: v));
          }),

          const SizedBox(height: 16),

          // Fencemode.
          _buildSectionTitle('Geofence Mode'),
          _buildNumberInputRow('Zone 1 (m)', _area1Controller, (v) {
            _updateConfig(config.copyWith(areaRadius1: v));
          }),
          _buildNumberInputRow('Zone 2 (m)', _area2Controller, (v) {
            _updateConfig(config.copyWith(areaRadius2: v));
          }),
          RadioGroup<bool>(
            groupValue: config.innerFenceAlarm,
            onChanged: (v) =>
                _updateConfig(config.copyWith(innerFenceAlarm: v)),
            child: const Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    title: Text('Outer Fence Alarm', style: TextStyle(fontSize: 12)),
                    value: false,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    title: Text('Inner Fence Alarm', style: TextStyle(fontSize: 12)),
                    value: true,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Trajectory/ mode.
          _buildSectionTitle('Trajectory/Navigation Mode'),
          _buildDropdownRow('Positioning Mode', config.positioningMode, ['2D Positioning', '3D Positioning'],
              (v) {
            _updateConfig(config.copyWith(positioningMode: v));
          }),
          _buildDropdownRow(
              'Algorithm', config.algorithm, ['Kalman/Average', 'Least Squares', 'Trilateration'], (v) {
            _updateConfig(config.copyWith(algorithm: v));
          }),

          const SizedBox(height: 16),

          // Distance settings.
          _buildSectionTitle('Distance Correction'),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'y = (${config.correctionA.toStringAsFixed(4)}) * x + (${config.correctionB.toStringAsFixed(2)})',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          _buildNumberInputRow('Coefficient a', _correctionAController, (v) {
            _updateConfig(config.copyWith(correctionA: v));
          }),
          _buildNumberInputRow('Coefficient b', _correctionBController, (v) {
            _updateConfig(config.copyWith(correctionB: v));
          }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Correction coefficients set')),
                );
              },
              child: const Text('Set Correction Coefficients'),
            ),
          ),

          const SizedBox(height: 16),

          // Distance.
          _buildSectionTitle('Distance Index Mapping'),
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
                  'Fix hardware distance order mismatch with anchor IDs.\n'
                  'E.g.: If standing at Anchor2 but showing Anchor3,\n'
                  'swap D2↔D3 mapping.',
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Current Mapping: ${config.distanceIndexMap}',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _describeMapping(config.distanceIndexMap),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Button.
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildSwapButton('D0↔D1', [1, 0, 2, 3]),
              _buildSwapButton('D0↔D2', [2, 1, 0, 3]),
              _buildSwapButton('D0↔D3', [3, 1, 2, 0]),
              _buildSwapButton('D1↔D2', [0, 2, 1, 3]),
              _buildSwapButton('D1↔D3', [0, 3, 2, 1]),
              _buildSwapButton('D2↔D3', [0, 1, 3, 2]),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                _updateConfig(config.copyWith(
                  distanceIndexMap: [0, 1, 2, 3],
                ));
                setState(() {});
              },
              icon: const Icon(Icons.restore, size: 16),
              label: const Text('Reset to Default [0,1,2,3]'),
            ),
          ),
        ],
      ),
    );
  }

  // Settings Tab.
  Widget _buildMapSettings() {
    final config = widget.uwbService.config;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Floor Plan'),
          
          // Show load.
          if (config.floorPlanImagePath != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Map Loaded',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      widget.uwbService.clearFloorPlan();
                      setState(() {});
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Clear Map',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickFloorPlanImage,
                  icon: widget.uwbService.isLoadingFloorPlan
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.folder_open, size: 16),
                  label: Text(widget.uwbService.isLoadingFloorPlan ? 'Loading...' : 'Open'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: config.floorPlanImagePath != null
                      ? () {
                          // Saveconfig ( ).
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Configuration auto-saved')),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.save, size: 16),
                  label: const Text('Save'),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Show/.
          _buildCheckboxRow('Show Floor Plan', config.showFloorPlan, (v) {
            widget.uwbService.toggleFloorPlan(v);
            setState(() {});
          }),
          
          // Translated legacy note.
          if (config.floorPlanImagePath != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(
                  width: 60,
                  child: Text('Opacity', style: TextStyle(fontSize: 13)),
                ),
                Expanded(
                  child: Slider(
                    value: config.floorPlanOpacity,
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    label: '${(config.floorPlanOpacity * 100).toInt()}%',
                    onChanged: (v) {
                      widget.uwbService.updateFloorPlanOpacity(v);
                      _floorPlanOpacityController.text = v.toStringAsFixed(2);
                      setState(() {});
                    },
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    '${(config.floorPlanOpacity * 100).toInt()}%',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 16),
          _buildSectionTitle('Offset Settings'),
          _buildNumberInputRowWithUnit('X Offset', _xOffsetController, 'm', (v) {
            _updateConfig(config.copyWith(xOffset: v));
          }),
          _buildNumberInputRowWithUnit('Y Offset', _yOffsetController, 'm', (v) {
            _updateConfig(config.copyWith(yOffset: v));
          }),
          const SizedBox(height: 16),
          _buildSectionTitle('Scale Settings'),
          _buildNumberInputRowWithUnit('X Scale', _xScaleController, 'px/m', (v) {
            _updateConfig(config.copyWith(xScale: v));
          }),
          _buildNumberInputRowWithUnit('Y Scale', _yScaleController, 'px/m', (v) {
            _updateConfig(config.copyWith(yScale: v));
          }),
          const SizedBox(height: 16),
          _buildSectionTitle('Flip Settings'),
          _buildCheckboxRow('Flip X', config.flipX, (v) {
            _updateConfig(config.copyWith(flipX: v));
          }),
          _buildCheckboxRow('Flip Y', config.flipY, (v) {
            _updateConfig(config.copyWith(flipY: v));
          }),
          _buildCheckboxRow('Show Origin', config.showOrigin, (v) {
            _updateConfig(config.copyWith(showOrigin: v));
          }),
          const SizedBox(height: 16),
          
          // Hint.
          if (config.floorPlanImagePath != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Format: ${config.floorPlanFileType.toUpperCase()}  |  ${config.floorPlanImagePath!.split('\\').last.split('/').last}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Hint.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Supported file formats:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Images: PNG, JPG, BMP, GIF, WEBP',
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
                ),
                const SizedBox(height: 2),
                Text(
                  '• Vector: SVG (scalable)',
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
                ),
                const SizedBox(height: 2),
                Text(
                  '• Document: PDF (first page extracted)',
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
                ),
                const SizedBox(height: 2),
                Text(
                  '• Engineering: DWG/DXF (convert to PDF/SVG first)',
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tip: X/Y Scale = pixels per meter on the image',
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Translated legacy comment.
  Future<void> _pickFloorPlanImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          // Translated legacy note.
          'png', 'jpg', 'jpeg', 'bmp', 'gif', 'webp',
          // Translated legacy note.
          'svg',
          // PDF.
          'pdf',
          // CAD (hint ).
          'dwg', 'dxf',
        ],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        await widget.uwbService.loadFloorPlanImage(filePath);
        
        if (mounted) {
          setState(() {});
          
          final ext = filePath.split('.').last.toLowerCase();
          String formatName;
          switch (ext) {
            case 'svg':
              formatName = 'SVG Vector';
              break;
            case 'pdf':
              formatName = 'PDF Document';
              break;
            case 'dwg':
            case 'dxf':
              // DWG error service.
              return;
            default:
              formatName = '${ext.toUpperCase()} Image';
          }
          
          if (widget.uwbService.floorPlanImage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$formatName loaded'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load floor plan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Settings Tab.
  Widget _buildGridSettings() {
    final config = widget.uwbService.config;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Grid Parameters'),
          _buildNumberInputRowWithUnit('Width', _gridWidthController, 'm', (v) {
            _updateConfig(config.copyWith(gridWidth: v));
          }),
          _buildNumberInputRowWithUnit('Height', _gridHeightController, 'm', (v) {
            _updateConfig(config.copyWith(gridHeight: v));
          }),
          const SizedBox(height: 16),
          _buildCheckboxRow('Show Grid', config.showGrid, (v) {
            _updateConfig(config.copyWith(showGrid: v));
          }),
          const SizedBox(height: 24),
          _buildSectionTitle('Quick Settings'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickGridButton('0.25m', 0.25),
              _buildQuickGridButton('0.5m', 0.5),
              _buildQuickGridButton('1m', 1.0),
              _buildQuickGridButton('2m', 2.0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickGridButton(String label, double size) {
    return OutlinedButton(
      onPressed: () {
        _gridWidthController.text = size.toString();
        _gridHeightController.text = size.toString();
        _updateConfig(widget.uwbService.config.copyWith(
          gridWidth: size,
          gridHeight: size,
        ));
      },
      child: Text(label),
    );
  }

  // Serialconfig Tab.
  Widget _buildSerialSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Serial Configuration'),

          // Connect.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.uwbService.isConnected
                  ? Colors.green.shade50
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.uwbService.isConnected
                    ? Colors.green.shade300
                    : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  widget.uwbService.isConnected
                      ? Icons.check_circle
                      : Icons.info_outline,
                  color: widget.uwbService.isConnected
                      ? Colors.green
                      : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.uwbService.isConnected ? 'Connected' : 'Disconnected',
                    style: TextStyle(
                      color: widget.uwbService.isConnected
                          ? Colors.green.shade700
                          : Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Translated legacy note.
          _buildSectionTitle('Baud Rate'),
          DropdownButtonFormField<int>(
            initialValue: 115200,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(),
            ),
            items: [9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600]
                .map((rate) => DropdownMenuItem(
                      value: rate,
                      child: Text('$rate'),
                    ))
                .toList(),
            onChanged: (value) {
              // TODO: update.
            },
          ),

          const SizedBox(height: 16),

          // Button.
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Serial.
                    Navigator.pop(context, 'search_ports');
                  },
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Scan Ports'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: widget.uwbService.isConnected
                    ? ElevatedButton.icon(
                        onPressed: () {
                          widget.uwbService.disconnect();
                          setState(() {});
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Disconnect'),
                      )
                    : ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context, 'connect');
                        },
                        icon: const Icon(Icons.usb, size: 18),
                        label: const Text('Connect'),
                      ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          _buildSectionTitle('Tips'),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• BU04 uses CH340 or CP210x chip',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Default baud rate is 115200',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Install drivers if device is not recognized',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Translated legacy note.
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildCheckboxRow(String label, bool value, Function(bool) onChanged) {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberInputRow(String label, TextEditingController controller,
      Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            child: SizedBox(
              height: 32,
              child: TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  final value = double.tryParse(v);
                  if (value != null) onChanged(value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberInputRowWithUnit(
      String label,
      TextEditingController controller,
      String unit,
      Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            child: SizedBox(
              height: 32,
              child: TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  final value = double.tryParse(v);
                  if (value != null) onChanged(value);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 50,
            child: Text(unit,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownRow(String label, String value, List<String> options,
      Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            child: SizedBox(
              height: 32,
              child: DropdownButtonFormField<String>(
                initialValue: value,
                isDense: true,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  border: OutlineInputBorder(),
                ),
                items: options
                    .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _describeMapping(List<int> map) {
    if (map.length != 4) return 'Invalid Mapping';
    if (map[0] == 0 && map[1] == 1 && map[2] == 2 && map[3] == 3) {
      return 'Default Order (No Swaps)';
    }
    final swaps = <String>[];
    for (int i = 0; i < 4; i++) {
      if (map[i] != i) {
        swaps.add('HW D$i → Anchor${map[i]}');
      }
    }
    return swaps.join(', ');
  }

  Widget _buildSwapButton(String label, List<int> mapping) {
    final config = widget.uwbService.config;
    final isActive = config.distanceIndexMap.length == 4 &&
        config.distanceIndexMap[0] == mapping[0] &&
        config.distanceIndexMap[1] == mapping[1] &&
        config.distanceIndexMap[2] == mapping[2] &&
        config.distanceIndexMap[3] == mapping[3];

    return SizedBox(
      height: 32,
      child: isActive
          ? ElevatedButton(
              onPressed: () {
                _updateConfig(config.copyWith(
                  distanceIndexMap: [0, 1, 2, 3],
                ));
                setState(() {});
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: Text(label),
            )
          : OutlinedButton(
              onPressed: () {
                _updateConfig(config.copyWith(
                  distanceIndexMap: mapping,
                ));
                setState(() {});
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: Text(label),
            ),
    );
  }

  void _updateConfig(UwbConfig config) {
    widget.uwbService.updateConfig(config);
    setState(() {});
  }
}
