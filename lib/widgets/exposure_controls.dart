import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/camera_provider.dart';
import 'screen_scale.dart';

class ExposureControls extends StatelessWidget {
  const ExposureControls({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CameraProvider>();
    final mode = provider.priorityMode;
    final ss = ScreenScale(context);

    return Row(
      children: [
        Expanded(
          child: _ControlKnob(
            label: 'Aperture',
            value: _fmtAperture(provider.selectedAperture),
            isInput: mode != PriorityMode.s,
            isAuto: mode == PriorityMode.s,
            autoValue: mode == PriorityMode.s
                ? _fmtAperture(provider.computedAperture)
                : null,
            onDrag: mode != PriorityMode.s
                ? (d) => provider.adjustAperture(d / 60)
                : null,
            ss: ss,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: ss.padding(8)),
          child: Text(
            '/',
            style: TextStyle(color: Colors.white12, fontSize: ss.sp(28)),
          ),
        ),
        Expanded(
          child: _ControlKnob(
            label: 'Shutter',
            value: _fmtShutter(provider.selectedShutter),
            isInput: mode != PriorityMode.a,
            isAuto: mode == PriorityMode.a,
            autoValue: mode == PriorityMode.a
                ? _fmtShutter(provider.computedShutter)
                : null,
            onDrag: mode != PriorityMode.a
                ? (d) => provider.adjustShutter(d / 60)
                : null,
            ss: ss,
          ),
        ),
      ],
    );
  }

  String _fmtAperture(double v) => 'f/${v.toStringAsFixed(1)}';
  String _fmtShutter(double s) =>
      s >= 1 ? '${s.toStringAsFixed(1)}"' : '1/${(1 / s).round()}';
}

class _ControlKnob extends StatelessWidget {
  final String label;
  final String value;
  final bool isInput;
  final bool isAuto;
  final String? autoValue;
  final ValueChanged<double>? onDrag;
  final ScreenScale ss;

  const _ControlKnob({
    required this.label,
    required this.value,
    required this.isInput,
    required this.isAuto,
    this.autoValue,
    this.onDrag,
    required this.ss,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: onDrag != null ? (d) => onDrag!(d.delta.dy) : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white38, fontSize: ss.sp(11)),
          ),
          SizedBox(height: ss.padding(4)),
          Text(
            isAuto ? (autoValue ?? value) : value,
            style: TextStyle(
              color: isInput ? Colors.white : Colors.grey,
              fontSize: isInput ? ss.sp(32) : ss.sp(26),
              fontWeight: isInput ? FontWeight.w500 : FontWeight.w300,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: ss.padding(2)),
          Text(
            isAuto ? '(auto)' : (onDrag != null ? '↕ drag' : ''),
            style: TextStyle(color: Colors.white24, fontSize: ss.sp(9)),
          ),
        ],
      ),
    );
  }
}
