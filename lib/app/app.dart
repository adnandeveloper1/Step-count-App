import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/home/presentation/screens/main_screen.dart';
import '../features/auth/presentation/screens/auth_screen.dart';
import '../features/shop/presentation/providers/theme_provider.dart';

class BuildUpApp extends ConsumerWidget {
  const BuildUpApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final themeState = ref.watch(themeProvider);
    final activeTheme = themeState.activeTheme;

    final dynamicThemeData = ThemeData(
      brightness: activeTheme.brightness,
      scaffoldBackgroundColor: activeTheme.backgroundColor,
      primaryColor: activeTheme.primaryColor,
      colorScheme: ColorScheme(
        brightness: activeTheme.brightness,
        primary: activeTheme.primaryColor,
        onPrimary: Colors.black,
        secondary: activeTheme.primaryColor,
        onSecondary: Colors.white,
        error: Colors.red,
        onError: Colors.white,
        surface: activeTheme.cardColor,
        onSurface: activeTheme.textPrimary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: activeTheme.primaryColor,
        contentTextStyle: GoogleFonts.sora(
          color: Colors.black,
          fontWeight: FontWeight.w900,
          fontSize: 13,
          letterSpacing: 1.2,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 8,
      ),
      textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme).apply(
        bodyColor: activeTheme.textPrimary,
        displayColor: activeTheme.textPrimary,
      ),
      useMaterial3: true,
    );
    return MaterialApp(
      title: 'Build Up',
      debugShowCheckedModeBanner: false,
      theme: dynamicThemeData,
      home: authState.when(
        data: (user) => user != null ? const MainNavigationScreen() : const AuthScreen(),
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, stackTrace) => const Scaffold(body: Center(child: Text('Authentication Error'))),
      ),
    );
  }
}