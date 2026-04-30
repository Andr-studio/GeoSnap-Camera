import 'package:flutter/material.dart';

import 'setting_tile.dart';
import '../../../theme/app_colors.dart';

class ColorPickerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final int selectedValue;
  final ValueChanged<Color> onSelected;
  final List<Color> colors;

  const ColorPickerTile({
    super.key,
    required this.icon,
    required this.title,
    required this.selectedValue,
    required this.onSelected,
    this.colors = const <Color>[
      Colors.white,
      Color(0xFFFFF1B6),
      Color(0xFFBFEAFF),
      Color(0xFFC9F7D4),
      Color(0xFFFFC6D6),
      Color(0xFFFFD34D),
    ],
  });

  @override
  Widget build(BuildContext context) {
    final Color selectedColor = Color(selectedValue);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              SettingIconBubble(icon: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: colors.map((Color color) {
              final bool selected = color == selectedColor;
              return GestureDetector(
                onTap: () => onSelected(color),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 30,
                  height: 30,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? AppColors.settingsAccent
                          : Colors.white24,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: color.withValues(alpha: 0.24),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
