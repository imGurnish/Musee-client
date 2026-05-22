import 'dart:math' as math;
import 'package:flutter/material.dart';

class PlayingBarsAnimation extends StatefulWidget {
  final double width;
  final double height;
  final int barCount;
  final double barWidth;
  final double gap;
  final Color? color;
  final bool isPlaying;

  const PlayingBarsAnimation({
    super.key,
    this.width = 24,
    this.height = 24,
    this.barCount = 4,
    this.barWidth = 3,
    this.gap = 2,
    this.color,
    this.isPlaying = true,
  });

  @override
  State<PlayingBarsAnimation> createState() => _PlayingBarsAnimationState();
}

class _PlayingBarsAnimationState extends State<PlayingBarsAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant PlayingBarsAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.color ?? Theme.of(context).primaryColor;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _EqualizerPainter(
              animationValue: widget.isPlaying ? _controller.value : 0.0,
              barCount: widget.barCount,
              barWidth: widget.barWidth,
              gap: widget.gap,
              color: themeColor,
              isPlaying: widget.isPlaying,
            ),
          );
        },
      ),
    );
  }
}

class _EqualizerPainter extends CustomPainter {
  final double animationValue;
  final int barCount;
  final double barWidth;
  final double gap;
  final Color color;
  final bool isPlaying;

  _EqualizerPainter({
    required this.animationValue,
    required this.barCount,
    required this.barWidth,
    required this.gap,
    required this.color,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Calculate start X to center the bars in the provided width
    final totalBarsWidth = (barCount * barWidth) + ((barCount - 1) * gap);
    final startX = (size.width - totalBarsWidth) / 2;

    for (int i = 0; i < barCount; i++) {
      // Define different sine phases and frequency multipliers for each bar to look natural
      final double phaseShift = i * (math.pi / 4);
      final double frequencyMultiplier = 1.0 + (i % 3) * 0.5;
      
      // Calculate dynamic height ratio [0.15, 0.9] based on animation value
      double heightRatio = 0.2;
      if (isPlaying) {
        heightRatio = 0.2 + 0.7 * (0.5 + 0.5 * math.sin(animationValue * 2 * math.pi * frequencyMultiplier + phaseShift));
      } else {
        // Paused/baseline height state (alternating slightly for distinct styling)
        heightRatio = 0.15 + (i % 2) * 0.1;
      }

      final barHeight = size.height * heightRatio;
      
      final x = startX + i * (barWidth + gap);
      final y = size.height - barHeight;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        Radius.circular(barWidth / 2),
      );

      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EqualizerPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.barCount != barCount ||
        oldDelegate.barWidth != barWidth ||
        oldDelegate.gap != gap ||
        oldDelegate.color != color ||
        oldDelegate.isPlaying != isPlaying;
  }
}
