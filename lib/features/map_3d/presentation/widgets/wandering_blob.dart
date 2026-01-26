import 'package:flutter/material.dart';
import 'dart:math' as math;

class WanderingBlob extends StatefulWidget {
  final Color color;
  final double size;
  final double wanderRange;

  const WanderingBlob({
    super.key,
    required this.color,
    required this.size,
    this.wanderRange = 50.0,
  });

  @override
  State<WanderingBlob> createState() => _WanderingBlobState();
}

class _WanderingBlobState extends State<WanderingBlob> {
  Offset _targetOffset = Offset.zero;
  Duration _duration = const Duration(seconds: 5);
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _updateTarget();
  }

  void _updateTarget() {
    setState(() {
      final dx = (_random.nextDouble() * 2 - 1) * widget.wanderRange;
      final dy = (_random.nextDouble() * 2 - 1) * widget.wanderRange;
      _targetOffset = Offset(dx, dy);
      _duration = Duration(milliseconds: 4000 + _random.nextInt(4000));
    });
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Offset>(
      tween: Tween<Offset>(begin: Offset.zero, end: _targetOffset),
      duration: _duration,
      curve: Curves.easeInOutSine,
      onEnd: _updateTarget,
      builder: (context, offset, child) {
        return Transform.translate(
          offset: offset,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}