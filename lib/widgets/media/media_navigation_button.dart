import 'package:flutter/material.dart';

/// A circular semi-transparent navigation button for media viewers
class MediaNavigationButton extends StatelessWidget {
  final IconData icon;
  final bool visible;
  final VoidCallback? onPressed;

  const MediaNavigationButton({
    super.key,
    required this.icon,
    this.visible = true,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: IgnorePointer(
        ignoring: !visible,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon),
            color: Colors.white,
            iconSize: 32,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}
