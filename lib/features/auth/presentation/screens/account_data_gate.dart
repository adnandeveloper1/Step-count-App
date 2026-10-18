import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/account_data_provider.dart';
import '../providers/auth_provider.dart';

/// Shows [child] once the phone holds the signed-in account's data (see
/// accountDataProvider), so the home screen never syncs an empty fresh
/// install over the account.
class AccountDataGate extends ConsumerWidget {
  const AccountDataGate({super.key, required this.uid, required this.child});

  final String uid;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(accountDataProvider(uid))
        .when(
          // Try again shows the spinner while it loads.
          skipLoadingOnRefresh: false,
          data: (_) => child,
          loading: () => const Scaffold(
            key: Key('accountData.loading'),
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Scaffold(
            key: const Key('accountData.error'),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Couldn't load your data. Check your connection and "
                      'try again.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const Key('accountData.retry'),
                      onPressed: () => ref.invalidate(accountDataProvider(uid)),
                      child: const Text('Try again'),
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.read(authControllerProvider).signOut(),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
  }
}
