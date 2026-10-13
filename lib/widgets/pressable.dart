import 'package:flutter/material.dart';

class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.95,
  });
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;
  int _lastTapMs = 0;

  void _onTapDown(TapDownDetails d) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTapMs < 150) return; // حماية من الضغط المتكرر
    _lastTapMs = now;
    if (mounted) setState(() => _pressed = true);
  }

  void _onTapUp(TapUpDetails d) {
    if (mounted) setState(() => _pressed = false);
  }

  void _onTapCancel() {
    if (mounted) setState(() => _pressed = false);
  }

  void _onTap() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTapMs < 150) return;
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: _onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _pressed ? widget.scale : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      );
}
