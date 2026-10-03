import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import 'theme/app_colors.dart';
import '../features/home/presentation/screens/main_screen.dart';
import '../features/auth/presentation/screens/auth_screen.dart';
import '../features/shop/presentation/providers/theme_provider.dart';

class BuildUpApp extends ConsumerWidget {
  const BuildUpApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final themeState = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Build Up',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.backgroundDark,
        primaryColor: themeState.primaryColor,
        colorScheme: ColorScheme.dark(
          primary: themeState.primaryColor,
          surface: AppColors.backgroundDark,
        ),
        textTheme: GoogleFonts.interTextTheme(
          Theme.of(context).textTheme,
        ).apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        ),
        useMaterial3: true,
      ),
      home: authState.when(
        data: (user) => user != null ? const MainNavigationScreen() : const AuthScreen(),
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, stackTrace) => const Scaffold(body: Center(child: Text('Authentication Error'))),
      ),
    );
  }
}