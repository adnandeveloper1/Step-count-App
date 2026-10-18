import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/theme_extensions.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../step_tracking/presentation/widgets/glass_step_card.dart';

/// What the user is told after [AuthController.deleteAccount]. Null when
/// there is nothing to say.
String? deleteAccountMessage(DeleteAccountResult result) {
  return switch (result) {
    DeleteAccountResult.deleted => 'Your Build Up account was deleted.',
    DeleteAccountResult.cancelled => null,
    DeleteAccountResult.wrongPassword =>
      'That password is wrong. Your account was not deleted.',
    DeleteAccountResult.wrongGoogleAccount =>
      'Choose the Google account you signed in with. Your account was not '
          'deleted.',
    DeleteAccountResult.tooManyAttempts =>
      'Too many tries. Wait a few minutes and try again. Your account was '
          'not deleted.',
    DeleteAccountResult.offline =>
      'No internet connection. Your account was not deleted. Connect and '
          'try again.',
    DeleteAccountResult.failed =>
      'Something went wrong. Your account was not deleted. Try again.',
    DeleteAccountResult.unfinished =>
      'Some of your data may already be deleted, but your account still '
          'exists. Connect to the internet and tap Delete Account again to '
          'finish.',
  };
}

/// The Delete Account row in Settings: asks first, then deletes the
/// signed-in account and says how it went.
class DeleteAccountTile extends ConsumerStatefulWidget {
  const DeleteAccountTile({super.key});

  static const confirmKey = Key('delete-account-confirm');
  static const passwordConfirmKey = Key('delete-account-password-confirm');

  @override
  ConsumerState<DeleteAccountTile> createState() => _DeleteAccountTileState();
}

class _DeleteAccountTileState extends ConsumerState<DeleteAccountTile> {
  bool _deleting = false;

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _AccountDialog(
        title: 'Delete your account?',
        actionLabel: 'Delete',
        actionKey: DeleteAccountTile.confirmKey,
        onAction: () => Navigator.pop(dialogContext, true),
        child: Text(
          'This permanently deletes your Build Up account and it can\'t be '
          'undone.\n\n'
          'Deleted: your profile and body details, steps and step history, '
          'coins, challenge progress, store items, saved GPS routes and your '
          'Step Race card. The data on this phone is cleared too.',
          style: GoogleFonts.sora(
            fontSize: 14,
            color: dialogContext.textSecondary,
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    // Deleting signs the user out, which replaces this screen.
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _deleting = true);
    final result = await ref
        .read(authControllerProvider)
        .deleteAccount(askPassword: _askPassword);
    if (mounted) setState(() => _deleting = false);

    final message = deleteAccountMessage(result);
    if (message == null) return;
    if (result == DeleteAccountResult.unfinished && mounted) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => _AccountDialog(
          title: 'Deleting didn\'t finish',
          actionLabel: 'OK',
          cancellable: false,
          onAction: () => Navigator.pop(dialogContext),
          child: Text(
            message,
            style: GoogleFonts.sora(
              fontSize: 14,
              color: dialogContext.textSecondary,
            ),
          ),
        ),
      );
      return;
    }
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
  }

  Future<String?> _askPassword() async {
    if (!mounted) return null;
    return showDialog<String>(
      context: context,
      builder: (_) => const _PasswordDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return ListTile(
      leading: Icon(
        // As wide as Sign Out's icon, so the two line up.
        Icons.person_remove_outlined,
        color: Colors.redAccent,
        size: screenWidth * 0.06,
      ),
      title: Text(
        'Delete Account',
        style: TextStyle(color: Colors.redAccent, fontSize: screenWidth * 0.04),
      ),
      trailing: _deleting
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: _deleting ? null : _delete,
    );
  }
}

/// Firebase needs an email account's password again before deleting it.
class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_password.text.isEmpty) return;
    Navigator.pop(context, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    return _AccountDialog(
      title: 'Enter your password',
      actionLabel: 'Delete',
      actionKey: DeleteAccountTile.passwordConfirmKey,
      onAction: _submit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'To delete your account, confirm it\'s you.',
            style: GoogleFonts.sora(fontSize: 14, color: context.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            obscureText: true,
            autofocus: true,
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(labelText: 'Password'),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
    );
  }
}

/// Matches the Sign Out dialog. Cancel closes it with no value.
class _AccountDialog extends StatelessWidget {
  const _AccountDialog({
    required this.title,
    required this.child,
    required this.actionLabel,
    required this.onAction,
    this.actionKey,
    this.cancellable = true,
  });

  final String title;
  final Widget child;
  final String actionLabel;
  final VoidCallback onAction;
  final Key? actionKey;
  final bool cancellable;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.backgroundColor,
      insetPadding: const EdgeInsets.all(24),
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.sora(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              child,
              const SizedBox(height: 32),
              Row(
                children: [
                  if (cancellable) ...[
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: context.textSecondary.withValues(
                                alpha: 0.3,
                              ),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.sora(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        key: actionKey,
                        onPressed: onAction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: Text(
                          actionLabel,
                          style: GoogleFonts.sora(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
