import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/camera_provider.dart';
import '../models/distance.dart';

class HudPanel extends StatelessWidget {
  const HudPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CameraProvider>();
    final mode = provider.mode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(180),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mode == AppMode.meter) _MeterHud(provider),
          if (mode == AppMode.range) _RangeHud(provider),
          if (mode == AppMode.colorTemp) _ColorTempHud(provider),
          if (mode == AppMode.viewfinder) _ViewfinderHud(provider),
        ],
      ),
    );
  }
}

class _MeterHud extends StatelessWidget {
  final CameraProvider provider;
  const _MeterHud(this.provider);

  @override
  Widget build(BuildContext context) {
    final exp = provider.exposure;
    if (exp == null) {
      return const Text('Metering...', style: TextStyle(color: Colors.white54));
    }

    final byAperture = exp.withAperture(provider.selectedAperture);
    final byShutter = exp.withShutter(provider.selectedShutter);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row('EV', exp.ev.toStringAsFixed(1), Colors.yellow),
        const SizedBox(height: 4),
        _row('ISO', '${provider.selectedIso.round()}', Colors.cyan),
        const SizedBox(height: 2),
        _row(
          'f/${provider.selectedAperture.toStringAsFixed(1)}',
          '${_fmtShutter(byAperture.shutterSpeed)}s',
          Colors.greenAccent,
        ),
        const SizedBox(height: 2),
        _row(
          _fmtShutter(provider.selectedShutter),
          'f/${byShutter.aperture.toStringAsFixed(1)}',
          Colors.orangeAccent,
        ),
        const SizedBox(height: 4),
        Text(
          'Pattern: ${provider.meterPattern.name}',
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ],
    );
  }
}

class _RangeHud extends StatelessWidget {
  final CameraProvider provider;
  const _RangeHud(this.provider);

  @override
  Widget build(BuildContext context) {
    final dist = provider.distance;
    final sessionType = provider.nativeSessionType;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row('Distance', dist.display, Colors.greenAccent),
        if (dist.meters > 0) ...[
          const SizedBox(height: 4),
          _row(
            'Near',
            '${provider.dofNear(dist.meters).toStringAsFixed(2)}m',
            Colors.white54,
          ),
          _row(
            'Far',
            provider.dofFar(dist.meters) == double.infinity
                ? '∞'
                : '${provider.dofFar(dist.meters).toStringAsFixed(2)}m',
            Colors.white54,
          ),
        ],
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              'Src: ${dist.source.name}',
              style: TextStyle(
                color: dist.source.name != 'none'
                    ? Colors.greenAccent
                    : Colors.orangeAccent,
                fontSize: 10,
              ),
            ),
            if (dist.source == DistanceSource.none) ...[
              const SizedBox(width: 8),
              Text(
                'Tap viewfinder to measure',
                style: TextStyle(
                  color: Colors.yellow.withAlpha(180),
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
        if (sessionType != 'none')
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Cam2: $sessionType',
              style: const TextStyle(color: Colors.white24, fontSize: 9),
            ),
          ),
      ],
    );
  }
}

class _ColorTempHud extends StatelessWidget {
  final CameraProvider provider;
  const _ColorTempHud(this.provider);

  @override
  Widget build(BuildContext context) {
    final ct = provider.colorTemp;
    if (ct.cct <= 0) {
      return const Text(
        'Point at white/gray surface',
        style: TextStyle(color: Colors.white54),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row('CCT', ct.display, const Color(0xFFFF9800)),
        const SizedBox(height: 2),
        _row('Type', ct.category, Colors.white54),
        if (ct.duv > 0)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Duv: ${ct.duv.toStringAsFixed(4)}',
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ),
      ],
    );
  }
}

class _ViewfinderHud extends StatelessWidget {
  final CameraProvider provider;
  const _ViewfinderHud(this.provider);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row('Format', provider.filmFormat, Colors.white),
        const SizedBox(height: 2),
        _row('FL', '${provider.focalLength.round()}mm', Colors.cyanAccent),
        const SizedBox(height: 2),
        _row(
          'f/',
          provider.selectedAperture.toStringAsFixed(1),
          Colors.orangeAccent,
        ),
        const SizedBox(height: 2),
        if (provider.distance.meters > 0)
          _row('Dist', provider.distance.display, Colors.greenAccent),
      ],
    );
  }
}

Widget _row(String label, String value, Color color) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '$label: ',
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 13,
          fontWeight: FontWeight.w300,
        ),
      ),
      Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

String _fmtShutter(double s) {
  if (s >= 1) return s.toStringAsFixed(1);
  return '1/${(1 / s).round()}';
}
