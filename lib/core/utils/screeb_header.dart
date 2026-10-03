import 'package:flutter/material.dart';

class ScreenHeader extends StatelessWidget {
  final Widget? leftChild;
  final String title;
  final Widget? rightChild;

  const ScreenHeader({
    super.key,
    this.leftChild,
    required this.title,
    this.rightChild,
  });

  @override
  Widget build(BuildContext context) {
    // Get the status bar height
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      // Use a consistent top padding: Status Bar + Fixed Margin
      padding: EdgeInsets.only(
        top: statusBarHeight + 10,
        left: screenWidth * 0.05,
        right: screenWidth * 0.05,
        bottom: 10,
      ),
      child: SizedBox(
        height: 50, // Force a consistent height for ALL screen headers
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: leftChild ?? const SizedBox.shrink(),
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                // Use your GoogleFonts style here
                fontWeight: FontWeight.w900,
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: rightChild ?? const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}