import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app/theme/app_colors.dart';
import 'core/services/local_storage_service.dart';
import 'features/onboarding/onboarding_provider.dart';
import 'features/onboarding/onboarding_content.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'features/step_tracking/presentation/providers/step_provider.dart';

/// Opens onboarding on its own, without Firebase or saved data, so it can be
/// reviewed while signed in:
/// `flutter run -t lib/main_onboarding_preview.dart`
/// On web, `?p=2` opens the second page.
void main() {
  final page = (int.tryParse(Uri.base.queryParameters['p'] ?? '') ?? 1) - 1;
  runApp(
    ProviderScope(
      overrides: [storageProvider.overrideWithValue(_PreviewStorage())],
      child: _PreviewApp(
        page: page.clamp(0, onboardingPages.length - 1).toInt(),
      ),
    ),
  );
}

/// Keeps the onboarding flag in memory so the real device data is untouched.
class _PreviewStorage extends LocalStorageService {
  bool _seen = false;

  @override
  bool getOnboardingSeen() => _seen;

  @override
  void saveOnboardingSeen(bool value) => _seen = value;
}

class _PreviewApp extends ConsumerWidget {
  final int page;

  const _PreviewApp({required this.page});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seen = ref.watch(onboardingSeenProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.backgroundDark,
        useMaterial3: true,
      ),
      home: seen
          ? Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () {
                    ref.read(storageProvider).saveOnboardingSeen(false);
                    ref.invalidate(onboardingSeenProvider);
                  },
                  child: Text(
                    'Auth screen goes here.\nTap to replay onboarding.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.sora(color: AppColors.primaryEmerald),
                  ),
                ),
              ),
            )
          : OnboardingScreen(initialPage: page),
    );
  }
}
