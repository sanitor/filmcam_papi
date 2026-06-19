import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/camera_provider.dart';
import '../engines/viewfinder_engine.dart';

class CameraViewfinder extends StatelessWidget {
  const CameraViewfinder({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CameraProvider>();

    if (!provider.initialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      );
    }

    if (!provider.hasCamera) {
      return const Center(
        child: Text(
          'Camera not available',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return GestureDetector(
          onTapUp: provider.mode == AppMode.range
              ? (_) => provider.measureDistance()
              : null,
          child: Stack(
            children: [
              Positioned.fill(child: _CameraPreview(provider: provider)),
              Positioned.fill(
                child: CustomPaint(
                  painter: ViewfinderPainter(
                    frameLines: provider.getFrameLines(w, h),
                    gridLines: provider.getGridLines(w, h),
                    mode: provider.mode,
                    spotX: provider.spotX * w,
                    spotY: provider.spotY * h,
                    parallaxOffset: provider.getParallaxOffset(w, h),
                  ),
                ),
              ),
              if (provider.isMeasuring)
                Positioned.fill(
                  child: Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 12),
                          Text(
                            'Measuring distance…',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CameraPreview extends StatelessWidget {
  final CameraProvider provider;
  const _CameraPreview({required this.provider});

  @override
  Widget build(BuildContext context) {
    final controller = provider.cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return Container(color: Colors.black);
    }

    final previewSize = controller.value.previewSize;
    if (previewSize == null) return Container(color: Colors.black);

    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    // Camera plugin already handles rotation correctly. The problem
    // is that previewSize always reports sensor-native (landscape)
    // dimensions.  In portrait we swap them so FittedBox uses the
    // correct post-rotation aspect ratio.
    final double pw = previewSize.width;
    final double ph = previewSize.height;
    final double childW = isPortrait ? ph : pw;
    final double childH = isPortrait ? pw : ph;

    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: childW,
          height: childH,
          child: controller.buildPreview(),
        ),
      ),
    );
  }
}

class ViewfinderPainter extends CustomPainter {
  final List<FrameLine> frameLines;
  final List<FrameLine> gridLines;
  final AppMode mode;
  final double spotX;
  final double spotY;
  final Offset parallaxOffset;

  ViewfinderPainter({
    required this.frameLines,
    required this.gridLines,
    required this.mode,
    required this.spotX,
    required this.spotY,
    required this.parallaxOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawGridLines(canvas, size);
    _drawFrameLines(canvas, size);

    if (mode == AppMode.meter) {
      _drawSpotCircle(canvas, size);
    }

    if (parallaxOffset != Offset.zero) {
      _drawParallaxIndicator(canvas, size);
    }
  }

  void _drawGridLines(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(60)
      ..strokeWidth = 0.5;

    for (final line in gridLines) {
      canvas.drawLine(
        Offset(line.x1, line.y1),
        Offset(line.x2, line.y2),
        paint,
      );
    }
  }

  void _drawFrameLines(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(180)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (final line in frameLines) {
      canvas.drawLine(
        Offset(line.x1, line.y1) + parallaxOffset,
        Offset(line.x2, line.y2) + parallaxOffset,
        paint,
      );
    }
  }

  void _drawSpotCircle(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.yellow.withAlpha(200)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final radius = min(size.width, size.height) * 0.05;
    canvas.drawCircle(Offset(spotX, spotY), radius, paint);

    final crossPaint = Paint()
      ..color = Colors.yellow.withAlpha(150)
      ..strokeWidth = 0.5;

    final crossSize = radius * 0.3;
    canvas.drawLine(
      Offset(spotX - crossSize, spotY),
      Offset(spotX + crossSize, spotY),
      crossPaint,
    );
    canvas.drawLine(
      Offset(spotX, spotY - crossSize),
      Offset(spotX, spotY + crossSize),
      crossPaint,
    );
  }

  void _drawParallaxIndicator(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withAlpha(150)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final arrowEnd = center + parallaxOffset;
    canvas.drawLine(center, arrowEnd, paint);
    canvas.drawCircle(arrowEnd, 4, paint);
  }

  @override
  bool shouldRepaint(covariant ViewfinderPainter oldDelegate) => true;
}
