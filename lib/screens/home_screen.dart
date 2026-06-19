import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/camera_provider.dart';
import '../widgets/camera_viewfinder.dart';
import '../widgets/exposure_scale.dart';
import '../widgets/exposure_controls.dart';
import '../widgets/meter_bar.dart';
import '../widgets/mode_selector.dart';
import '../widgets/screen_scale.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CameraProvider>();
    final ss = ScreenScale(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Camera preview
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  const CameraViewfinder(),
                  if (provider.error != null)
                    Positioned(
                      top: ss.padding(8),
                      right: ss.padding(8),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: ss.sp(18),
                      ),
                    ),
                  Positioned(
                    top: ss.padding(8),
                    right: ss.padding(8),
                    child: GestureDetector(
                      onTap: () => _showSettings(context, provider),
                      child: Container(
                        padding: EdgeInsets.all(ss.padding(6)),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(130),
                          borderRadius: BorderRadius.circular(ss.padding(16)),
                        ),
                        child: Icon(
                          Icons.tune,
                          color: Colors.white60,
                          size: ss.sp(18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Exposure compensation scale
            Expanded(
              flex: 2,
              child: Container(
                alignment: Alignment.center,
                child: const ExposureScale(),
              ),
            ),
            // Aperture / Shutter controls
            Expanded(
              flex: 3,
              child: Container(
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(horizontal: ss.padding(24)),
                child: const ExposureControls(),
              ),
            ),
            // Meter bar (ISO, pattern, mode, focal length)
            const MeterBar(),
            // Mode selector
            const ModeSelector(),
          ],
        ),
      ),
    );
  }

  void _showSettings(BuildContext context, CameraProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      builder: (ctx) => _SettingsSheet(provider: provider),
    );
  }
}

class _SettingsSheet extends StatefulWidget {
  final CameraProvider provider;
  const _SettingsSheet({required this.provider});

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late double _aperture;
  late double _shutter;
  late double _iso;
  late double _focalLength;
  late double _evOffset;
  late double _cctOffset;
  late String _format;

  @override
  void initState() {
    super.initState();
    final p = widget.provider;
    _aperture = p.selectedAperture;
    _shutter = p.selectedShutter;
    _iso = p.selectedIso;
    _focalLength = p.focalLength;
    _evOffset = p.profile.evOffset;
    _cctOffset = p.profile.cctOffset;
    _format = p.filmFormat;
  }

  @override
  Widget build(BuildContext context) {
    final ss = ScreenScale(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) => Container(
        padding: EdgeInsets.all(ss.padding(20)),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: ListView(
          controller: scrollController,
          children: [
            Center(
              child: Container(
                width: ss.padding(40),
                height: ss.padding(4),
                margin: EdgeInsets.only(bottom: ss.padding(16)),
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(ss.padding(2)),
                ),
              ),
            ),
            Text(
              'Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: ss.sp(18),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: ss.padding(16)),
            _section('Exposure', ss),
            _exposureSliders(ss),
            SizedBox(height: ss.padding(16)),
            _section('Lens & Format', ss),
            _lensControls(ss),
            SizedBox(height: ss.padding(16)),
            _section('Calibration', ss),
            _calibrationSliders(ss),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, ScreenScale ss) => Padding(
    padding: EdgeInsets.only(bottom: ss.padding(8)),
    child: Text(
      title.toUpperCase(),
      style: TextStyle(
        color: Colors.grey,
        fontSize: ss.sp(11),
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    ),
  );

  Widget _exposureSliders(ScreenScale ss) => Column(
    children: [
      _slider(
        'Aperture',
        _aperture,
        1.4,
        22,
        (v) {
          _aperture = v;
          widget.provider.selectedAperture = v;
        },
        'f/${_aperture.toStringAsFixed(1)}',
        ss,
      ),
      _slider(
        'Shutter',
        _shutter * 1000,
        1,
        1000,
        (v) {
          _shutter = v / 1000;
          widget.provider.selectedShutter = _shutter;
        },
        _fmtShutter(_shutter),
        ss,
      ),
      _slider(
        'ISO',
        _iso,
        25,
        6400,
        (v) {
          _iso = v;
          widget.provider.selectedIso = v;
        },
        'ISO ${_iso.round()}',
        ss,
      ),
    ],
  );

  Widget _lensControls(ScreenScale ss) => Column(
    children: [
      _slider(
        'Focal Length',
        _focalLength,
        14,
        200,
        (v) {
          _focalLength = v;
          widget.provider.focalLength = v;
        },
        '${_focalLength.round()}mm',
        ss,
      ),
      SizedBox(height: ss.padding(8)),
      Row(
        children: [
          SizedBox(
            width: ss.padding(100),
            child: Text(
              'Format',
              style: TextStyle(color: Colors.white70, fontSize: ss.sp(13)),
            ),
          ),
          Expanded(
            child: DropdownButton<String>(
              value: _format,
              dropdownColor: const Color(0xFF2A2A2A),
              style: TextStyle(color: Colors.white, fontSize: ss.sp(13)),
              isExpanded: true,
              underline: Container(height: 1, color: Colors.white24),
              items: [
                '135 (35mm)',
                '120 (6x4.5)',
                '120 (6x6)',
                '120 (6x7)',
                '120 (6x9)',
                '4x5" LF',
              ].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _format = v);
                widget.provider.filmFormat = v;
              },
            ),
          ),
        ],
      ),
    ],
  );

  Widget _calibrationSliders(ScreenScale ss) => Column(
    children: [
      _slider(
        'EV Offset',
        _evOffset,
        -3,
        3,
        (v) {
          _evOffset = v;
          widget.provider.setEvOffset(v);
        },
        '${_evOffset.toStringAsFixed(1)} EV',
        ss,
      ),
      _slider(
        'CCT Offset',
        _cctOffset,
        -500,
        500,
        (v) {
          _cctOffset = v;
          widget.provider.setCctOffset(v);
        },
        '${_cctOffset.round()}K',
        ss,
      ),
    ],
  );

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
    String display,
    ScreenScale ss,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: ss.padding(8)),
      child: Row(
        children: [
          SizedBox(
            width: ss.padding(100),
            child: Text(
              label,
              style: TextStyle(color: Colors.white70, fontSize: ss.sp(13)),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: const SliderThemeData(
                trackHeight: 2,
                activeTrackColor: Colors.amber,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions:
                    ((max - min) /
                            (label == 'EV Offset'
                                ? 0.1
                                : label == 'CCT Offset'
                                ? 50
                                : label == 'Aperture'
                                ? 0.1
                                : label == 'Focal Length'
                                ? 1
                                : label == 'ISO'
                                ? 50
                                : (max - min) / 100))
                        .round()
                        .clamp(1, 200),
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: ss.padding(80),
            child: Text(
              display,
              style: TextStyle(color: Colors.white, fontSize: ss.sp(13)),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _fmtShutter(double s) =>
      s >= 1 ? '${s.toStringAsFixed(1)}s' : '1/${(1 / s).round()}s';
}
