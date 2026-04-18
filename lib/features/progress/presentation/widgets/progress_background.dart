// lib/features/progress/presentation/widgets/progress_background.dart

import 'package:flutter/material.dart';
import 'dart:math' as math;

class ProgressBackground extends StatefulWidget {
  final Widget child;
  final bool isLoading;

  const ProgressBackground({
    super.key,
    required this.child,
    this.isLoading = false,
  });

  @override
  State<ProgressBackground> createState() => _ProgressBackgroundState();
}

class _ProgressBackgroundState extends State<ProgressBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final math.Random _random = math.Random(42); // Fixed seed for consistent pattern

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base gradient background with soft colors
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFF8F6FF), // Very light purple
                const Color(0xFFF3E5F5), // Soft lavender
                const Color(0xFFF0EAF8), // Light purple with hint of blue
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),

        // Animated soft elements
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              children: [
                // Large floating soft circles
                ...List.generate(5, (index) {
                  return _buildSoftCircle(
                    index: index,
                    progress: _controller.value,
                  );
                }),

                // Gentle wave patterns
                ...List.generate(3, (index) {
                  return _buildSoftWave(
                    index: index,
                    progress: _controller.value,
                  );
                }),

                // Tiny floating particles (like gentle sparkles)
                ...List.generate(15, (index) {
                  return _buildSoftParticle(
                    index: index,
                    progress: _controller.value,
                  );
                }),
              ],
            );
          },
        ),

        // Very subtle white overlay to keep content readable
        Container(
          color: Colors.white.withValues(alpha: 0.2),
        ),

        // Main content
        widget.child,
      ],
    );
  }

  Widget _buildSoftCircle({
    required int index,
    required double progress,
  }) {
    // Create unique positions for each circle
    final baseX = (index * 0.25) % 1.0;
    final baseY = (index * 0.35) % 1.0;

    // Gentle floating motion
    final offsetX = math.sin(progress * 2 * math.pi + index * 2) * 0.08;
    final offsetY = math.cos(progress * 1.8 * math.pi + index * 2) * 0.08;

    final positionX = (baseX + offsetX).clamp(-0.2, 1.2);
    final positionY = (baseY + offsetY).clamp(-0.2, 1.2);

    // Soft sizes and opacities
    final size = 180.0 + (index % 4) * 60.0;
    final opacity = 0.08 + (index % 3) * 0.04;

    // Soft colors matching progress page theme
    final colors = [
      const Color(0xFF8E7CFF).withValues(alpha: opacity), // Soft purple
      const Color(0xFFF9C1C1).withValues(alpha: opacity), // Soft pink/red
      const Color(0xFFB8A9FF).withValues(alpha: opacity), // Light purple
      const Color(0xFFA8E6CF).withValues(alpha: opacity), // Soft mint
      const Color(0xFFFFD3B6).withValues(alpha: opacity), // Soft peach
    ];

    return Positioned(
      left: MediaQuery.of(context).size.width * positionX - size / 2,
      top: MediaQuery.of(context).size.height * positionY - size / 2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors[index % colors.length],
          boxShadow: [
            BoxShadow(
              color: colors[index % colors.length].withValues(alpha: 0.1),
              blurRadius: 40,
              spreadRadius: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoftWave({
    required int index,
    required double progress,
  }) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    // Different wave positions
    final startY = height * (0.2 + index * 0.25);
    final amplitude = 15.0 + index * 8.0;
    final frequency = 0.003 + index * 0.0015;
    final speed = 0.3 + index * 0.2;

    // Wave colors
    final colors = [
      const Color(0xFF8E7CFF),
      const Color(0xFFFFB6B6),
      const Color(0xFFA8E6CF),
    ];

    return Positioned(
      top: startY,
      left: 0,
      right: 0,
      child: Opacity(
        opacity: 0.08,
        child: CustomPaint(
          painter: _SoftWavePainter(
            progress: progress * speed,
            amplitude: amplitude,
            frequency: frequency,
            color: colors[index % colors.length],
          ),
          size: Size(width, amplitude * 3),
        ),
      ),
    );
  }

  Widget _buildSoftParticle({
    required int index,
    required double progress,
  }) {
    // Tiny floating particles
    final baseX = (index * 0.37) % 1.0;
    final baseY = (index * 0.53) % 1.0;

    final offsetX = math.sin(progress * 4 * math.pi + index * 3) * 0.1;
    final offsetY = math.cos(progress * 3.5 * math.pi + index * 3) * 0.1;

    final positionX = (baseX + offsetX).clamp(0.0, 1.0);
    final positionY = (baseY + offsetY).clamp(0.0, 1.0);

    final size = 3.0 + (index % 4) * 2.0;
    final opacity = 0.1 + (index % 5) * 0.03;

    return Positioned(
      left: MediaQuery.of(context).size.width * positionX,
      top: MediaQuery.of(context).size.height * positionY,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF9283FB).withValues(alpha: opacity),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9383FC).withValues(alpha: opacity * 0.5),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftWavePainter extends CustomPainter {
  final double progress;
  final double amplitude;
  final double frequency;
  final Color color;

  _SoftWavePainter({
    required this.progress,
    required this.amplitude,
    required this.frequency,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

    final path = Path();
    final startX = 0.0;
    final startY = size.height / 2;

    path.moveTo(startX, startY + amplitude * math.sin(progress * 2 * math.pi));

    for (double x = 0; x <= size.width; x += 15) {
      final y = startY +
          amplitude *
              math.sin(
                x * frequency + progress * 2 * math.pi,
              );
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);

    // Draw a second, more subtle wave for depth
    final paint2 = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    final path2 = Path();
    path2.moveTo(
        startX,
        startY +
            amplitude *
                0.6 *
                math.sin(progress * 2 * math.pi + 1.0));

    for (double x = 0; x <= size.width; x += 15) {
      final y = startY +
          amplitude *
              0.6 *
              math.sin(
                x * frequency * 1.3 + progress * 2 * math.pi + 1.0,
              );
      path2.lineTo(x, y);
    }

    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant _SoftWavePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}