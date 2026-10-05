import 'package:flutter/material.dart';

class ProAvatar extends StatelessWidget { // Changed to StatelessWidget
  final String emojiAvatar;
  final double radius;
  final bool isPro;

  const ProAvatar({
    super.key,
    required this.emojiAvatar,
    this.radius = 40.0,
    this.isPro = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isPro) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.withOpacity(0.2),
        child: Text(
          emojiAvatar,
          style: TextStyle(fontSize: radius),
        ),
      );
    }

    final double size = radius * 2;
    // Proportional sizing for the badge based on overall frame size
    final double badgeSize = size * 0.35; 

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // 1. The Main Gold Ring with Avatar inside
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFFFD700), // Bright Gold
                width: size * 0.08, // Scales border thickness with size
              ),
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
            child: Center(
              child: Text(
                emojiAvatar,
                style: TextStyle(fontSize: radius), // Restored to normal emoji size
              ),
            ),
          ),

          // 2. The Hexagon Star Badge (Bottom Right)
          Positioned(
            bottom: -badgeSize * 0.1, // Adjusted so it overlaps nicely on the bottom right corner
            right: -badgeSize * 0.1,
            child: SizedBox(
              width: badgeSize,
              height: badgeSize,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  CustomPaint(
                    size: Size(badgeSize, badgeSize),
                    painter: HexagonPainter(),
                  ),
                  Icon(
                    Icons.star_rounded,
                    color: const Color(0xFFF57F17), // Deep orange-gold
                    size: badgeSize * 0.6,
                  ),
                  // Decorative Sparkles
                  Positioned(
                    top: 0,
                    right: -4,
                    child: Icon(Icons.auto_awesome, color: Colors.white, size: badgeSize * 0.3),
                  ),
                  Positioned(
                    bottom: 2,
                    left: -4,
                    child: Icon(Icons.auto_awesome, color: Colors.white, size: badgeSize * 0.25),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws a perfect hexagon for the badge base
class HexagonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF176), Color(0xFFFFB300)], // Light to dark gold
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Map out the 6 points of a pointy-topped hexagon
    final path = Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, h * 0.25)
      ..lineTo(w, h * 0.75)
      ..lineTo(w / 2, h)
      ..lineTo(0, h * 0.75)
      ..lineTo(0, h * 0.25)
      ..close();

    // Adds a slight drop shadow behind the hexagon to separate it from the ring
    canvas.drawShadow(path, Colors.black.withOpacity(0.3), 4, false);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
