import 'package:flutter/material.dart';

/// A gradient bottom bar with navigation controls for media viewers
class MediaNavigationBar extends StatelessWidget {
  final int currentIndex;
  final int totalCount;
  final bool visible;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const MediaNavigationBar({
    super.key,
    required this.currentIndex,
    required this.totalCount,
    this.visible = true,
    this.onPrevious,
    this.onNext,
  });

  bool get hasPrevious => currentIndex > 0;
  bool get hasNext => currentIndex < totalCount - 1;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: IgnorePointer(
          ignoring: !visible,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.transparent,
                ],
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous),
                      color: hasPrevious ? Colors.white : Colors.white38,
                      onPressed: hasPrevious ? onPrevious : null,
                      iconSize: 32,
                    ),
                    const SizedBox(width: 32),
                    Text(
                      '${currentIndex + 1} / $totalCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 32),
                    IconButton(
                      icon: const Icon(Icons.skip_next),
                      color: hasNext ? Colors.white : Colors.white38,
                      onPressed: hasNext ? onNext : null,
                      iconSize: 32,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
