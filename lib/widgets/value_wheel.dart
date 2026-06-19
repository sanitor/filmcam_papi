import 'package:flutter/material.dart';

class ValueWheel extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final scale = MediaQuery.of(context).size.width / 375;
    final tileWidth = 60 * scale;
    final tileHeight = 36 * scale;
    final fontSize = 14 * scale;
    final currentIdx = _closestIndex();
    const visibleHalf = 4;

    return SizedBox(
      height: tileHeight + 8,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: tileWidth * visibleHalf),
        itemCount: values.length,
        controller: _initialOffset(currentIdx, tileWidth),
        itemBuilder: (context, i) {
          final isSelected = i == currentIdx;
          return GestureDetector(
            onTap: () => onChanged(values[i]),
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
                formatter(values[i]),
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

  int _closestIndex() {
    var best = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < values.length; i++) {
      final d = (values[i] - currentValue).abs();
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  ScrollController _initialOffset(int idx, double tileWidth) {
    final offset = idx * tileWidth - tileWidth * 4 + tileWidth / 2;
    return ScrollController(initialScrollOffset: offset);
  }
}
