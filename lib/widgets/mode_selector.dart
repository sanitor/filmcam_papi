import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/camera_provider.dart';
import 'screen_scale.dart';

class ModeSelector extends StatelessWidget {
  const ModeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CameraProvider>();
    final mode = provider.mode;
    final ss = ScreenScale(context);

    return Container(
      padding: EdgeInsets.symmetric(vertical: ss.padding(8)),
      decoration: BoxDecoration(color: Colors.black.withAlpha(200)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ModeButton(
            icon: Icons.light_mode,
            label: 'Meter',
            selected: mode == AppMode.meter,
            onTap: () => provider.setMode(AppMode.meter),
            ss: ss,
          ),
          _ModeButton(
            icon: Icons.straighten,
            label: 'Range',
            selected: mode == AppMode.range,
            onTap: () {
              provider.setMode(AppMode.range);
              provider.refreshDistance();
            },
            ss: ss,
          ),
          _ModeButton(
            icon: Icons.wb_sunny,
            label: 'Color',
            selected: mode == AppMode.colorTemp,
            onTap: () => provider.setMode(AppMode.colorTemp),
            ss: ss,
          ),
          _ModeButton(
            icon: Icons.camera_outlined,
            label: 'Frame',
            selected: mode == AppMode.viewfinder,
            onTap: () => provider.setMode(AppMode.viewfinder),
            ss: ss,
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ScreenScale ss;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.ss,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: ss.padding(16),
          vertical: ss.padding(8),
        ),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withAlpha(25) : Colors.transparent,
          borderRadius: BorderRadius.circular(ss.padding(20)),
          border: Border.all(
            color: selected ? Colors.white.withAlpha(100) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : Colors.white54,
              size: ss.sp(22),
            ),
            SizedBox(height: ss.padding(2)),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white54,
                fontSize: ss.sp(11),
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
