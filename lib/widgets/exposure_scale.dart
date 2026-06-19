import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/camera_provider.dart';
import 'screen_scale.dart';

class ExposureScale extends StatelessWidget {
  const ExposureScale({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CameraProvider>();
    final isManual = provider.priorityMode == PriorityMode.m;
    final value = isManual
        ? provider.exposureDeviation
        : provider.evCompensation;
    final ss = ScreenScale(context);

    return GestureDetector(
      onHorizontalDragUpdate: isManual
          ? null
          : (d) => provider.evCompensation =
                provider.evCompensation + d.delta.dx / 60,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(7, (i) {
              final v = i - 3;
              return Container(
                width: ss.padding(28),
                alignment: Alignment.center,
                child: Text(
                  v == 0 ? '0' : '',
                  style: TextStyle(color: Colors.white24, fontSize: ss.sp(10)),
                ),
              );
            }),
          ),
          SizedBox(height: ss.padding(4)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(19, (i) {
              final tickVal = (i - 9) / 3;
              final isMain = i % 3 == 0;
              final dist = (value - tickVal).abs();
              final isClose = dist < 0.2;
              return Container(
                width: isMain ? ss.padding(3) : ss.padding(1),
                height: isMain ? ss.padding(20) : ss.padding(10),
                margin: EdgeInsets.symmetric(
                  horizontal: isMain ? ss.padding(3) : ss.padding(2),
                ),
                decoration: BoxDecoration(
                  color: isClose
                      ? (tickVal == 0
                            ? Colors.greenAccent
                            : Colors.orangeAccent)
                      : Colors.white24,
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            }),
          ),
          SizedBox(height: ss.padding(6)),
          Text(
            isManual
                ? 'Dev ${value.toStringAsFixed(1)}'
                : value.toStringAsFixed(1),
            style: TextStyle(
              color: value.abs() > 0.05 ? Colors.orangeAccent : Colors.white,
              fontSize: ss.sp(28),
              fontWeight: FontWeight.w300,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (!isManual)
            Text(
              'EV comp  ← drag →',
              style: TextStyle(color: Colors.white24, fontSize: ss.sp(9)),
            ),
        ],
      ),
    );
  }
}
