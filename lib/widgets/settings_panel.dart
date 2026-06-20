import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/camera_provider.dart';
import '../engines/meter_engine.dart';
import 'value_wheel.dart';
import 'screen_scale.dart';

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({super.key});

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  String? _activeKey;

  static const _isoValues = [25, 50, 100, 200, 400, 800, 1600, 3200, 6400];
  static const _apertureValues = <double>[
    1.0,
    1.1,
    1.2,
    1.4,
    1.6,
    1.8,
    2.0,
    2.2,
    2.5,
    2.8,
    3.2,
    3.5,
    4.0,
    4.5,
    5.0,
    5.6,
    6.3,
    7.1,
    8.0,
    9.0,
    10,
    11,
    13,
    14,
    16,
    18,
    20,
    22,
  ];
  static const _shutterValues = <double>[
    1 / 8000,
    1 / 4000,
    1 / 2000,
    1 / 1000,
    1 / 500,
    1 / 250,
    1 / 125,
    1 / 60,
    1 / 30,
    1 / 15,
    1 / 8,
    1 / 4,
    1 / 2,
    1,
    2,
    4,
    8,
    15,
    30,
  ];
  static final _evValues = () {
    final v = <double>[];
    for (var e = -3.0; e <= 3.0; e += 1 / 3) {
      v.add(double.parse(e.toStringAsFixed(1)));
    }
    return v;
  }();
  static const _tempValues = <double>[
    2000,
    2500,
    3200,
    4000,
    4500,
    5000,
    5500,
    6000,
    6500,
    7000,
    8000,
    9000,
    10000,
  ];
  static const _tintValues = <double>[
    -150,
    -120,
    -90,
    -60,
    -30,
    0,
    30,
    60,
    90,
    120,
    150,
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.watch<CameraProvider>();
    final ss = ScreenScale(context);

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: ss.padding(16)),
      children: [
        _section('FILM', ss),
        _rowN([
          _IconTile(
            icon: Icons.camera_alt_outlined,
            value: p.filmFormat,
            ss: ss,
            onTap: () => _showFormatPicker(context, p),
          ),
          _IconTile(
            icon: Icons.light_mode_outlined,
            value: p.selectedIso.round().toString(),
            ss: ss,
            onTap: () => _setActive('iso'),
          ),
        ], ss),
        if (_activeKey == 'iso')
          _wheel(
            p.selectedIso,
            _isoValues.map((e) => e.toDouble()).toList(),
            (v) => p.selectedIso = v,
            (v) => v.round().toString(),
          ),
        Divider(color: Colors.white10, height: 16, thickness: 0.5),
        _section('EXPOSURE', ss),
        _rowN([
          _IconTile(
            icon: Icons.center_focus_strong_outlined,
            value: _meterLabel(p.meterPattern),
            ss: ss,
            onTap: () => p.meterPattern = switch (p.meterPattern) {
              MeterPattern.spot => MeterPattern.centerWeighted,
              MeterPattern.centerWeighted => MeterPattern.average,
              MeterPattern.average => MeterPattern.spot,
            },
          ),
          _IconTile(
            icon: Icons.tune,
            value: p.priorityMode.name.toUpperCase(),
            ss: ss,
            color: Colors.cyanAccent,
            onTap: () => p.priorityMode = switch (p.priorityMode) {
              PriorityMode.a => PriorityMode.s,
              PriorityMode.s => PriorityMode.m,
              PriorityMode.m => PriorityMode.a,
            },
          ),
          _IconTile(
            icon: Icons.blur_on_outlined,
            value: _fmtA(p.selectedAperture),
            ss: ss,
            isInput: p.priorityMode != PriorityMode.s,
            onTap: p.priorityMode != PriorityMode.s
                ? () => _setActive('ap')
                : null,
          ),
          _IconTile(
            icon: Icons.timer_outlined,
            value: _fmtS(p.selectedShutter),
            ss: ss,
            isInput: p.priorityMode != PriorityMode.a,
            onTap: p.priorityMode != PriorityMode.a
                ? () => _setActive('sh')
                : null,
          ),
          _IconTile(
            icon: Icons.exposure,
            value: p.priorityMode == PriorityMode.m
                ? 'Dev ${p.exposureDeviation.toStringAsFixed(1)}'
                : p.evCompensation.toStringAsFixed(1),
            ss: ss,
            color: p.evCompensation.abs() > 0.05 ? Colors.orangeAccent : null,
            isInput: p.priorityMode != PriorityMode.m,
            onTap: p.priorityMode != PriorityMode.m
                ? () => _setActive('ev')
                : null,
          ),
        ], ss),
        if (_activeKey == 'ap')
          _wheel(
            p.selectedAperture,
            _apertureValues,
            (v) => p.selectedAperture = v,
            (v) => 'f/${v.toStringAsFixed(1)}',
          ),
        if (_activeKey == 'sh')
          _wheel(
            p.selectedShutter,
            _shutterValues,
            (v) => p.selectedShutter = v,
            (v) => _fmtS(v),
          ),
        if (_activeKey == 'ev')
          _wheel(
            p.evCompensation,
            _evValues,
            (v) => p.evCompensation = v,
            (v) => v.toStringAsFixed(1),
          ),
        Divider(color: Colors.white10, height: 16, thickness: 0.5),
        _section('COLOR', ss),
        _rowN([
          _IconTile(
            icon: Icons.wb_incandescent_outlined,
            value: '${p.colorTemp.cct}K',
            ss: ss,
            onTap: () => _setActive('temp'),
          ),
          _IconTile(
            icon: Icons.palette_outlined,
            value: '${p.colorTemp.duv.toStringAsFixed(3)}',
            ss: ss,
            onTap: () => _setActive('tint'),
          ),
        ], ss),
        if (_activeKey == 'temp')
          _wheel(
            p.colorTemp.cct.toDouble(),
            _tempValues.map((e) => e.toDouble()).toList(),
            (v) {},
            (v) => '${v.round()}K',
          ),
        if (_activeKey == 'tint')
          _wheel(
            0.0,
            _tintValues.map((e) => e.toDouble()).toList(),
            (v) {},
            (v) => v.toStringAsFixed(0),
          ),
        Divider(color: Colors.white10, height: 16, thickness: 0.5),
        _section('DISTANCE', ss),
        _rowN([
          _IconTile(
            icon: Icons.straighten,
            value: p.distance.display,
            ss: ss,
          ),
          _IconTile(
            icon: Icons.arrow_back_outlined,
            value: p.distance.meters > 0
                ? '${p.distance.meters.toStringAsFixed(2)}m'
                : '--',
            ss: ss,
          ),
          _IconTile(
            icon: Icons.arrow_forward_outlined,
            value: p.distance.meters > 0
                ? '${p.distance.meters.toStringAsFixed(2)}m'
                : '--',
            ss: ss,
          ),
        ], ss),
        SizedBox(height: ss.padding(24)),
      ],
    );
  }

  void _setActive(String key) {
    setState(() {
      _activeKey = _activeKey == key ? null : key;
    });
  }

  Widget _section(String title, ScreenScale ss) => Padding(
    padding: EdgeInsets.only(bottom: ss.padding(4)),
    child: Text(
      title,
      style: TextStyle(
        color: Colors.white38,
        fontSize: ss.sp(10),
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _rowN(List<Widget> tiles, ScreenScale ss) {
    final spacing = ss.padding(4);
    final slots = <Widget>[...tiles];
    while (slots.length < 5) slots.add(const SizedBox.shrink());
    final rowChildren = <Widget>[];
    for (var i = 0; i < slots.length; i++) {
      rowChildren.add(Expanded(child: slots[i]));
      if (i < slots.length - 1) rowChildren.add(SizedBox(width: spacing));
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(children: rowChildren),
    );
  }

  Widget _wheel(
    double current,
    List<double> values,
    ValueChanged<double> onChange,
    String Function(double) fmt,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ValueWheel(
        values: values,
        currentValue: current,
        formatter: fmt,
        onChanged: onChange,
      ),
    );
  }

  String _meterLabel(MeterPattern p) => switch (p) {
    MeterPattern.spot => 'Spot',
    MeterPattern.centerWeighted => 'Center',
    MeterPattern.average => 'Average',
  };

  void _showFormatPicker(BuildContext context, CameraProvider p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              '画幅',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          SizedBox(
            height: 240,
            child: ListView(
              children:
                  [
                    '135 (35mm)',
                    '120 (6x4.5)',
                    '120 (6x6)',
                    '120 (6x7)',
                    '120 (6x9)',
                    '4x5" LF',
                  ].map((f) {
                    final sel = f == p.filmFormat;
                    return ListTile(
                      dense: true,
                      title: Text(
                        f,
                        style: TextStyle(
                          color: sel ? Colors.cyanAccent : Colors.white70,
                          fontSize: 16,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      trailing: sel
                          ? const Icon(
                              Icons.check,
                              color: Colors.cyanAccent,
                              size: 16,
                            )
                          : null,
                      onTap: () {
                        p.filmFormat = f;
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtA(double v) => 'f/${v.toStringAsFixed(1)}';
  String _fmtS(double s) =>
      s >= 1 ? '${s.toStringAsFixed(1)}"' : '1/${(1 / s).round()}';
}

class _IconTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final ScreenScale ss;
  final VoidCallback? onTap;
  final Color? color;
  final bool isInput;

  const _IconTile({
    required this.icon,
    required this.value,
    required this.ss,
    this.onTap,
    this.color,
    this.isInput = true,
  });

  @override
  Widget build(BuildContext context) {
    final col = color ?? (isInput ? Colors.white : Colors.grey);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: ss.padding(6)),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(8),
          borderRadius: BorderRadius.circular(ss.padding(6)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white54, size: ss.sp(16)),
            SizedBox(height: ss.padding(2)),
            Text(
              value,
              style: TextStyle(
                color: col,
                fontSize: ss.sp(11),
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
