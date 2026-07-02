import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class FloatingNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const FloatingNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<FloatingNavItem> items;

  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      // Matches the bottom of AppGradients.scaffoldBg so the bar blends into
      // the gradient instead of reading as a lighter navy band.
      color: AppColors.navyDeep,
      child: SafeArea(
        top: false,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavItem(
                    item: items[i],
                    selected: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final FloatingNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.gold : AppColors.grey;
    const duration = Duration(milliseconds: 120);
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: selected ? 1.08 : 1.0,
            duration: duration,
            curve: Curves.easeOut,
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: color),
              duration: duration,
              builder: (context, animatedColor, _) => Icon(
                selected ? item.activeIcon : item.icon,
                color: animatedColor,
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: duration,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
            child: Text(item.label),
          ),
        ],
      ),
    );
  }
}
