import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/camera_provider.dart';
import '../engines/meter_engine.dart';
import 'value_wheel.dart';
import 'screen_scale.dart';

class MeterBar extends StatefulWidget {
  const MeterBar({super.key});

  @override
  State<MeterBar> createState() => _MeterBarState();
}

class _MeterBarState extends State<MeterBar> {
  bool _showIsoWheel = false;

  static const _isoValues = [25, 50, 100, 200, 400, 800, 1600, 3200, 6400];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CameraProvider>();
    final ss = ScreenScale(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: ss.padding(16),
            vertical: ss.padding(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MeterChip(
                label: 'ISO',
                value: provider.selectedIso.round().toString(),
                onTap: () => setState(() => _showIsoWheel = !_showIsoWheel),
                ss: ss,
              ),
              _MeterChip(
                label: '',
                value: switch (provider.meterPattern) {
                  MeterPattern.spot => '⬤ Spot',
                  MeterPattern.centerWeighted => '●○ CW',
                  MeterPattern.average => '◐ Avg',
                },
                onTap: () =>
                    provider.meterPattern = switch (provider.meterPattern) {
                      MeterPattern.spot => MeterPattern.centerWeighted,
                      MeterPattern.centerWeighted => MeterPattern.average,
                      MeterPattern.average => MeterPattern.spot,
                    },
                ss: ss,
              ),
              _MeterChip(
                label: '',
                value: switch (provider.priorityMode) {
                  PriorityMode.a => 'A',
                  PriorityMode.s => 'S',
                  PriorityMode.m => 'M',
                },
                color: Colors.cyanAccent,
                onTap: () =>
                    provider.priorityMode = switch (provider.priorityMode) {
                      PriorityMode.a => PriorityMode.s,
                      PriorityMode.s => PriorityMode.m,
                      PriorityMode.m => PriorityMode.a,
                    },
                ss: ss,
              ),
              _MeterChip(
                label: '',
                value: '${provider.focalLength.round()}mm',
                onTap: () => _showPicker(
                  context,
                  'Focal Length',
                  [
                    14,
                    18,
                    24,
                    28,
                    35,
                    50,
                    65,
                    85,
                    100,
                    135,
                    150,
                    200,
                  ].map((e) => '${e}mm').toList(),
                  provider.focalLength,
                  (v) => provider.focalLength = v,
                ),
                ss: ss,
              ),
            ],
          ),
        ),
        if (_showIsoWheel)
          Container(
            color: Colors.black.withAlpha(200),
            child: ValueWheel(
              values: _isoValues.map((e) => e.toDouble()).toList(),
              currentValue: provider.selectedIso,
              formatter: (v) => v.round().toString(),
              onChanged: (v) {
                provider.selectedIso = v;
              },
            ),
          ),
      ],
    );
  }

  void _showPicker(
    BuildContext context,
    String title,
    List<String> items,
    double current,
    ValueChanged<double> onSelected,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          SizedBox(
            height: 240,
            child: ListView(
              children: items.map((e) {
                final sel = e.startsWith(current.round().toString());
                return ListTile(
                  dense: true,
                  title: Text(
                    e,
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
                    onSelected(
                      double.tryParse(e.replaceAll(RegExp(r'[^\d]'), '')) ??
                          current,
                    );
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
}

class _MeterChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final VoidCallback onTap;
  final ScreenScale ss;

  const _MeterChip({
    required this.label,
    required this.value,
    this.color,
    required this.onTap,
    required this.ss,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: ss.padding(4)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label.isNotEmpty)
              Text(
                '$label ',
                style: TextStyle(color: Colors.white38, fontSize: ss.sp(11)),
              ),
            Text(
              value,
              style: TextStyle(
                color: color ?? Colors.white,
                fontSize: ss.sp(16),
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            SizedBox(width: ss.padding(12)),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white24,
              size: ss.sp(14),
            ),
          ],
        ),
      ),
    );
  }
}
