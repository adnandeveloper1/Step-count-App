import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

extension ThemeContextExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  bool get isDarkMode => theme.brightness == Brightness.dark;

  Color get primaryColor => theme.primaryColor;
  Color get backgroundColor => theme.scaffoldBackgroundColor;
  Color get cardColor => theme.colorScheme.surface;
  Color get textPrimary => theme.colorScheme.onSurface;
  Color get textSecondary => isDarkMode ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);

  void showAppSnackBar(String message, {bool isError = false, Color? backgroundColor}) {
    ScaffoldMessenger.of(this).clearSnackBars();
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(
          message.toUpperCase(),
          textAlign: TextAlign.center,
          style: GoogleFonts.sora(
            color: isError ? Colors.white : Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: isError ? Colors.redAccent : (backgroundColor ?? primaryColor),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 8,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}