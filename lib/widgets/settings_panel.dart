import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/camera_provider.dart';
import '../engines/meter_engine.dart';
import 'screen_scale.dart';

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({super.key});

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  static const _isoValues = [25, 50, 100, 200, 400, 800, 1600, 3200, 6400];
  static const _apertureValues = <double>[
    1.0, 1.1, 1.2, 1.4, 1.6, 1.8, 2.0, 2.2, 2.5, 2.8, 3.2, 3.5, 4.0, 4.5,
    5.0, 5.6, 6.3, 7.1, 8.0, 9.0, 10, 11, 13, 14, 16, 18, 20, 22,
  ];
  static const _shutterValues = <double>[
    1 / 8000, 1 / 4000, 1 / 2000, 1 / 1000, 1 / 500, 1 / 250, 1 / 125,
    1 / 60, 1 / 30, 1 / 15, 1 / 8, 1 / 4, 1 / 2, 1, 2, 4, 8, 15, 30,
  ];
  static final _evValues = () {
    final v = <double>[];
    for (var e = -3.0; e <= 3.0; e += 1 / 3) {
      v.add(double.parse(e.toStringAsFixed(1)));
    }
    return v;
  }();
  static const _tempValues = <double>[
    2000, 2500, 3200, 4000, 4500, 5000, 5500, 6000, 6500, 7000, 8000, 9000, 10000,
  ];
  static const _tintValues = <double>[-150, -120, -90, -60, -30, 0, 30, 60, 90, 120, 150];
  static const _focalValues = [16, 24, 28, 35, 50, 85, 100, 135, 200];

  String? _pressKey;
  double? _pressStartY;
  int? _pressStartIdx;
  int? _dragIdx;
  List<String>? _pressLabels;
  ValueChanged<int>? _pressOnIndexChanged;
  double? _tileLocalTop;
  double? _tileHeight;
  ScrollController? _rulerController;
  double? _rulerBaseOffset;
  double? _rulerPad;
  double? _rulerItemH;
  final _stackKey = GlobalKey();
  final _tileKeys = <String, GlobalKey>{};

  int _closestIndex(List<String> labels, String current) {
    for (var i = 0; i < labels.length; i++) {
      if (labels[i] == current) return i;
    }
    return 0;
  }

  void _onTileDown(String key, List<String> labels, int startIdx,
      ValueChanged<int> onIndexChanged, double y) {
    final tileKey = _tileKeys[key];
    if (tileKey?.currentContext != null) {
      final tileRB = tileKey!.currentContext!.findRenderObject() as RenderBox?;
      final stackRB =
          _stackKey.currentContext?.findRenderObject() as RenderBox?;
      if (tileRB != null && stackRB != null) {
        final tileGlobal = tileRB.localToGlobal(Offset.zero);
        final stackGlobal = stackRB.localToGlobal(Offset.zero);
        _tileLocalTop = tileGlobal.dy - stackGlobal.dy;
        _tileHeight = tileRB.size.height;
      }
    }
    _rulerController?.dispose();
    _rulerBaseOffset = null;
    _rulerController = ScrollController();
    setState(() {
      _pressKey = key;
      _pressStartY = y;
      _pressStartIdx = startIdx;
      _dragIdx = startIdx;
      _pressLabels = labels;
      _pressOnIndexChanged = onIndexChanged;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerRuler());
  }

  void _onTileDragUpdate(double y) {
    if (_pressKey == null || _pressStartY == null) return;
    final dy = y - _pressStartY!;
    final base = _rulerBaseOffset ?? 0;
    final target = base - dy;
    if (_rulerController != null && _rulerController!.hasClients) {
      _rulerController!
          .jumpTo(target.clamp(0.0, _rulerController!.position.maxScrollExtent));
    }
    _syncSelectionFromCenter();
  }

  void _onTileUp() {
    _centerRuler();
    _rulerController?.dispose();
    _rulerController = null;
    setState(() {
      _pressKey = null;
      _pressStartY = null;
      _pressStartIdx = null;
      _pressLabels = null;
      _pressOnIndexChanged = null;
      _tileLocalTop = null;
      _tileHeight = null;
    });
  }

  void _centerRuler() {
    if (_rulerController == null) return;
    if (!_rulerController!.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _centerRuler());
      return;
    }
    final idx = _dragIdx ?? _pressStartIdx ?? 0;
    final itemH = _rulerItemH ?? _calcItemH();
    final pad = _rulerPad ?? _calcPad();
    final halfViewport = _rulerController!.position.viewportDimension / 2;
    final target = pad + idx * itemH + itemH / 2 - halfViewport;
    final max = _rulerController!.position.maxScrollExtent;
    final min = _rulerController!.position.minScrollExtent;
    final clamped = target.clamp(min, max);
    _rulerController!.jumpTo(clamped);
    _rulerBaseOffset = clamped;
  }

  void _syncSelectionFromCenter() {
    if (_rulerController == null || !_rulerController!.hasClients) return;
    final itemH = _rulerItemH ?? _calcItemH();
    final pad = _rulerPad ?? _calcPad();
    final center =
        _rulerController!.position.pixels +
        _rulerController!.position.viewportDimension / 2;
    final relCenter = center - pad;
    final idx = (relCenter / itemH).floor().clamp(0, _pressLabels!.length - 1);
    if (idx == _dragIdx) return;
    _dragIdx = idx;
    _pressOnIndexChanged!(idx);
    setState(() {});
  }

  double _calcItemH() {
    final h = MediaQuery.of(context).size.height;
    final scale = (h / ScreenScale.referenceWidth).clamp(0.6, 2.0);
    return 48.0 * scale;
  }

  double _calcPad() {
    final itemH = _calcItemH();
    final len = _pressLabels?.length ?? 5;
    final visCount = len.clamp(3, 5).toDouble();
    final rulerH = itemH * visCount;
    return (rulerH - itemH) / 2;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<CameraProvider>();
    final ss = ScreenScale(context);
    final showRuler = _pressKey != null && _tileLocalTop != null;

    return Stack(
      key: _stackKey,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: ss.padding(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            _section('CAMERA', ss),
            _rowN([
              _IconTile(
                icon: Icons.camera_alt_outlined,
                value: p.filmFormat,
                ss: ss,
                onTap: () => _showFormatPicker(context, p),
              ),
              _dragTile(
                key_: 'fl',
                icon: Icons.zoom_in,
                value: '${p.focalLength.round()}mm',
                labels: _focalValues.map((e) => '${e}mm').toList(),
                startIdx: _closestIndex(
                    _focalValues.map((e) => '${e}mm').toList(),
                    '${p.focalLength.round()}mm'),
                onIndexChanged: (i) =>
                    p.focalLength = _focalValues[i].toDouble(),
                ss: ss,
              ),
              _dragTile(
                key_: 'iso',
                icon: Icons.light_mode_outlined,
                value: p.selectedIso.round().toString(),
                labels: _isoValues.map((e) => e.round().toString()).toList(),
                startIdx: _closestIndex(
                    _isoValues.map((e) => e.round().toString()).toList(),
                    p.selectedIso.round().toString()),
                onIndexChanged: (i) =>
                    p.selectedIso = _isoValues[i].toDouble(),
                ss: ss,
              ),
            ], ss),
            Divider(color: Colors.white10, height: 16, thickness: 0.5),
            _section('EXPOSURE', ss),
            _rowN([
              _dragTile(
                key_: 'meter',
                icon: Icons.center_focus_strong_outlined,
                value: _meterLabel(p.meterPattern),
                labels: const ['Spot', 'Center', 'Average'],
                startIdx: p.meterPattern.index,
                onIndexChanged: (i) =>
                    p.meterPattern = MeterPattern.values[i],
                ss: ss,
              ),
              _dragTile(
                key_: 'prio',
                icon: Icons.tune,
                value: p.priorityMode.name.toUpperCase(),
                labels: const ['A', 'S', 'M'],
                startIdx: p.priorityMode.index,
                onIndexChanged: (i) =>
                    p.priorityMode = PriorityMode.values[i],
                ss: ss,
                color: Colors.cyanAccent,
              ),
              _dragTile(
                key_: 'ap',
                icon: Icons.blur_on_outlined,
                value: _fmtA(p.selectedAperture),
                labels: _apertureValues.map((e) => _fmtA(e)).toList(),
                startIdx: _closestIndex(
                    _apertureValues.map((e) => _fmtA(e)).toList(),
                    _fmtA(p.selectedAperture)),
                onIndexChanged: (i) =>
                    p.selectedAperture = _apertureValues[i],
                ss: ss,
                enabled: p.priorityMode != PriorityMode.s,
              ),
              _dragTile(
                key_: 'sh',
                icon: Icons.timer_outlined,
                value: _fmtS(p.selectedShutter),
                labels: _shutterValues.map((e) => _fmtS(e)).toList(),
                startIdx: _closestIndex(
                    _shutterValues.map((e) => _fmtS(e)).toList(),
                    _fmtS(p.selectedShutter)),
                onIndexChanged: (i) =>
                    p.selectedShutter = _shutterValues[i],
                ss: ss,
                enabled: p.priorityMode != PriorityMode.a,
              ),
              _dragTile(
                key_: 'ev',
                icon: Icons.exposure,
                value: p.priorityMode == PriorityMode.m
                    ? 'Dev ${p.exposureDeviation.toStringAsFixed(1)}'
                    : p.evCompensation.toStringAsFixed(1),
                labels: _evValues.map((e) => e.toStringAsFixed(1)).toList(),
                startIdx: _closestIndex(
                    _evValues.map((e) => e.toStringAsFixed(1)).toList(),
                    p.evCompensation.toStringAsFixed(1)),
                onIndexChanged: (i) => p.evCompensation = _evValues[i],
                ss: ss,
                color: p.evCompensation.abs() > 0.05
                    ? Colors.orangeAccent
                    : null,
                enabled: p.priorityMode != PriorityMode.m,
              ),
            ], ss),
            Divider(color: Colors.white10, height: 16, thickness: 0.5),
            _section('COLOR', ss),
            _rowN([
              _dragTile(
                key_: 'temp',
                icon: Icons.wb_incandescent_outlined,
                value: '${p.colorTemp.cct}K',
                labels: _tempValues.map((e) => '${e.round()}K').toList(),
                startIdx: _closestIndex(
                    _tempValues.map((e) => '${e.round()}K').toList(),
                    '${p.colorTemp.cct}K'),
                onIndexChanged: (i) {},
                ss: ss,
              ),
              _dragTile(
                key_: 'tint',
                icon: Icons.palette_outlined,
                value: p.colorTemp.duv.toStringAsFixed(3),
                labels: _tintValues.map((e) => e.toStringAsFixed(0)).toList(),
                startIdx: _closestIndex(
                    _tintValues.map((e) => e.toStringAsFixed(0)).toList(),
                    '0'),
                onIndexChanged: (i) {},
                ss: ss,
              ),
            ], ss),
            Divider(color: Colors.white10, height: 16, thickness: 0.5),
            _section('DISTANCE', ss),
            _rowN([
              _IconTile(
                  icon: Icons.straighten, value: p.distance.display, ss: ss),
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
            SizedBox(height: ss.padding(16)),
          ],
          ),
          ),
        if (showRuler) _buildRuler(ss),
      ],
    );
  }

  Widget _buildRuler(ScreenScale ss) {
    final labels = _pressLabels!;
    final sel = _dragIdx ?? 0;
    final itemH = ss.padding(48);
    _rulerItemH = itemH;
    final visCount = labels.length.clamp(3, 5);
    final rulerH = itemH * visCount;
    final pad = (rulerH - itemH) / 2;
    _rulerPad = pad;
    final tileCenter = _tileLocalTop! + _tileHeight! / 2;
    final top = (tileCenter - rulerH / 2).clamp(0.0, double.infinity);

    return Positioned(
      left: ss.padding(8),
      right: ss.padding(8),
      top: top,
      height: rulerH,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(ss.padding(6)),
          border: Border.all(color: Colors.white12),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListView.builder(
          scrollDirection: Axis.vertical,
          controller: _rulerController,
          itemCount: labels.length,
          itemExtent: itemH,
          padding: EdgeInsets.only(top: pad, bottom: pad),
          itemBuilder: (context, i) {
            final isSel = i == sel;
            return Container(
              alignment: Alignment.center,
              child: Text(
                labels[i],
                style: TextStyle(
                  color: isSel ? Colors.cyanAccent : Colors.white54,
                  fontSize: ss.sp(14),
                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _dragTile({
    required String key_,
    required IconData icon,
    required String value,
    required List<String> labels,
    required int startIdx,
    required ValueChanged<int> onIndexChanged,
    required ScreenScale ss,
    Color? color,
    bool enabled = true,
  }) {
    _tileKeys[key_] ??= GlobalKey();
    return GestureDetector(
      key: _tileKeys[key_],
      onTapDown: enabled
          ? (d) => _onTileDown(
              key_, labels, startIdx, onIndexChanged, d.globalPosition.dy)
          : null,
      onVerticalDragUpdate: enabled
          ? (d) => _onTileDragUpdate(d.globalPosition.dy)
          : null,
      onVerticalDragEnd: enabled ? (_) => _onTileUp() : null,
      onTapUp: enabled ? (_) => _onTileUp() : null,
      child: _IconTile(
        icon: icon,
        value: value,
        ss: ss,
        color: color,
        isInput: enabled,
      ),
    );
  }

  Widget _section(String title, ScreenScale ss) => Padding(
    padding: EdgeInsets.only(bottom: ss.padding(4)),
    child: Text(
      title,
      style: TextStyle(
        color: Colors.white38,
        fontSize: ss.sp(8),
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _rowN(List<Widget> tiles, ScreenScale ss) {
    final spacing = ss.padding(4);
    final slots = <Widget>[...tiles];
    while (slots.length < 5) {
      slots.add(const SizedBox.shrink());
    }
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
              children: [
                '135 (35mm)', '120 (6x4.5)', '120 (6x6)',
                '120 (6x7)', '120 (6x9)', '4x5" LF'
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
                      ? const Icon(Icons.check,
                          color: Colors.cyanAccent, size: 16)
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
