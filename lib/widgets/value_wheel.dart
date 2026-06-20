import 'package:flutter/material.dart';

class ValueWheel extends StatefulWidget {
  final List<double> values;
  final double currentValue;
  final ValueChanged<double> onChanged;
  final String Function(double) formatter;

  const ValueWheel({
    super.key,
    required this.values,
    required this.currentValue,
    required this.onChanged,
    required this.formatter,
  });

  @override
  State<ValueWheel> createState() => _ValueWheelState();
}

class _ValueWheelState extends State<ValueWheel> {
  ScrollController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _ensureController(double scale) {
    if (_controller != null) return;
    final tileWidth = 60 * scale;
    const visibleHalf = 4;
    final idx = _closestIndex();
    final offset = idx * tileWidth - tileWidth * visibleHalf + tileWidth / 2;
    _controller = ScrollController(initialScrollOffset: offset);
  }

  int _closestIndex() {
    var best = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < widget.values.length; i++) {
      final d = (widget.values[i] - widget.currentValue).abs();
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.of(context).size.width / 375;
    final tileWidth = 60 * scale;
    final tileHeight = 36 * scale;
    final fontSize = 14 * scale;
    final currentIdx = _closestIndex();
    const visibleHalf = 4;

    _ensureController(scale);

    return SizedBox(
      height: tileHeight + 8,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: tileWidth * visibleHalf),
        itemCount: widget.values.length,
        controller: _controller,
        itemBuilder: (context, i) {
          final isSelected = i == currentIdx;
          return GestureDetector(
            onTap: () => widget.onChanged(widget.values[i]),
            child: Container(
              width: tileWidth,
              height: tileHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.cyanAccent.withAlpha(40)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                widget.formatter(widget.values[i]),
                style: TextStyle(
                  color: isSelected ? Colors.cyanAccent : Colors.white54,
                  fontSize: fontSize,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
