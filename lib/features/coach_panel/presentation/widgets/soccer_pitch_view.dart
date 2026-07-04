import 'package:flutter/material.dart';

class SoccerPitchView extends StatelessWidget {
  final Map<String, Offset> playerPositions;
  final Widget Function(String slotId, Offset position) slotBuilder;
  final double aspectRatio;

  const SoccerPitchView({
    super.key,
    required this.playerPositions,
    required this.slotBuilder,
    this.aspectRatio = 0.65, // Standard vertical pitch
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50), // Grass green
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Stack(
          children: [
            // Pitch lines
            Positioned.fill(
              child: CustomPaint(
                painter: _SoccerPitchPainter(),
              ),
            ),
            // Player slots
            LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: playerPositions.entries.map((entry) {
                    return Positioned(
                      left: entry.value.dx * constraints.maxWidth,
                      top: entry.value.dy * constraints.maxHeight,
                      child: FractionalTranslation(
                        translation: const Offset(-0.5, -0.5), // Center the slot exactly on the coordinate
                        child: slotBuilder(entry.key, entry.value),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SoccerPitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Center line
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );

    // Center circle
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.15,
      paint,
    );
    // Center dot
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      3.0,
      Paint()..color = Colors.white.withValues(alpha: 0.7)..style = PaintingStyle.fill,
    );

    // Penalty areas (Top & Bottom)
    final penaltyWidth = size.width * 0.5;
    final penaltyHeight = size.height * 0.15;
    final penaltyX = (size.width - penaltyWidth) / 2;

    // Top penalty area
    canvas.drawRect(
      Rect.fromLTWH(penaltyX, 0, penaltyWidth, penaltyHeight),
      paint,
    );

    // Bottom penalty area
    canvas.drawRect(
      Rect.fromLTWH(penaltyX, size.height - penaltyHeight, penaltyWidth, penaltyHeight),
      paint,
    );

    // Goal areas (Top & Bottom)
    final goalWidth = size.width * 0.25;
    final goalHeight = size.height * 0.05;
    final goalX = (size.width - goalWidth) / 2;

    // Top goal area
    canvas.drawRect(
      Rect.fromLTWH(goalX, 0, goalWidth, goalHeight),
      paint,
    );

    // Bottom goal area
    canvas.drawRect(
      Rect.fromLTWH(goalX, size.height - goalHeight, goalWidth, goalHeight),
      paint,
    );
    
    // Penalty arcs
    final arcRectTop = Rect.fromCircle(center: Offset(size.width / 2, penaltyHeight), radius: size.width * 0.15);
    canvas.drawArc(arcRectTop, 0, 3.14, false, paint);
    
    final arcRectBottom = Rect.fromCircle(center: Offset(size.width / 2, size.height - penaltyHeight), radius: size.width * 0.15);
    canvas.drawArc(arcRectBottom, 3.14, 3.14, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
