import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import 'auth_screen.dart';
import '../../../step_tracking/presentation/screens/dashboard_screen.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          return const DashboardView();
        }
        return const AuthScreen();
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Text('Error loading session.'),
        ),
      ),
    );
  }
}