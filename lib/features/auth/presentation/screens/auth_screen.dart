import 'package:build_up/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../step_tracking/presentation/widgets/glass_step_card.dart';
import '../providers/auth_provider.dart';


class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  void _showCustomSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message.toUpperCase(),
          textAlign: TextAlign.center,
          style: GoogleFonts.sora(
            color: isError ? Colors.white : AppColors.backgroundDark,
            fontWeight: FontWeight.w500,
            fontSize: 14,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: isError ? Colors.redAccent : AppColors.primaryEmerald,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 8,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _submitLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showCustomSnackBar('Please enter both email and password', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(authControllerProvider).signIn(email, password);
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No account found with this email.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many failed attempts. Please try again later.';
          break;
        default:
          errorMessage = 'Login failed. Please check your credentials.';
      }
      _showCustomSnackBar(errorMessage, isError: true);
    } catch (e) {
      _showCustomSnackBar('An unexpected error occurred.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authControllerProvider).signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'account-exists-with-different-credential') {
        errorMessage = 'An account already exists with the same email.';
      } else if (e.code == 'network-request-failed') {
        errorMessage = 'Please check your internet connection.';
      } else {
        errorMessage = 'Google Sign-In failed.';
      }
      _showCustomSnackBar(errorMessage, isError: true);
    } catch (e) {
      _showCustomSnackBar('Sign-in cancelled.', isError: true);
    }finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  Future<void> _submitGuestLogin() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authControllerProvider).signInAnonymously();
      _showCustomSnackBar('Welcome Guest');
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'operation-not-allowed':
          errorMessage = 'Guest login is currently disabled.';
          break;
        case 'network-request-failed':
          errorMessage = 'Please check your internet connection.';
          break;
        default:
          errorMessage = 'Guest login failed. Please try again.';
      }
      _showCustomSnackBar(errorMessage, isError: true);
    } catch (e) {
      _showCustomSnackBar('An unexpected error occurred.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.jetBrainsMono(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  void _showForgotPasswordDialog()
  {

    final resetEmailController = TextEditingController(text: _emailController.text);

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reset Password',
                  style: GoogleFonts.sora(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Enter your email address. We will send you a link to reset your password.',
                  style: GoogleFonts.sora(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                _buildLabel('Email Address'),
                TextField(
                  controller: resetEmailController,
                  style: const TextStyle(color: Colors.white60),
                  decoration: InputDecoration(
                    hintText: 'runner@gmail.com',
                    hintStyle: const TextStyle(color: Colors.white60),
                    filled: true,
                    fillColor: AppColors.glassCardBackground,
                    prefixIcon: const Icon(Icons.mail_outline, color: Colors.white60),
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      final email = resetEmailController.text.trim();
                      if (email.isEmpty) {
                        _showCustomSnackBar('Enter email for reset', isError: true);
                        return;
                      }

                      try {
                        await ref.read(authControllerProvider).resetPassword(email);
                        if (context.mounted) {
                          Navigator.pop(context);
                          _showCustomSnackBar('Reset link sent to your email');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          _showCustomSnackBar(e.toString(), isError: true);
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryEmerald,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: Text(
                      'Send Reset Link',
                      style: GoogleFonts.sora(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.sora(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                Text(
                  'BUILD UP',
                  style: GoogleFonts.sora(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryEmerald,
                    letterSpacing: -1.0,
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 40),
                GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Email Address'),
                      TextField(
                        controller: _emailController,
                        style: const TextStyle(color: Colors.white60),
                        decoration: InputDecoration(
                          hintText: 'runner@gmail.com',
                          hintStyle: const TextStyle(color: Colors.white60),
                          filled: true,
                          fillColor:AppColors.glassCardBackground,
                          prefixIcon: const Icon(Icons.mail_outline,
                              color: Colors.white60),
                          border: OutlineInputBorder(
                            borderSide: BorderSide.none,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding:
                          const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildLabel('Password'),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: GestureDetector(
                              onTap: _showForgotPasswordDialog,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Text(
                                  'Forgot?',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryEmerald,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.white60),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          hintStyle: const TextStyle(color: Colors.white60),
                          filled: true,
                          fillColor: AppColors.glassCardBackground,
                          prefixIcon: const Icon(Icons.lock_outline,
                              color: Colors.white60),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.white60,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderSide: BorderSide.none,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding:
                          const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (_isLoading)
                        const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primaryEmerald))
                      else ...[
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _submitLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryEmerald,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Login',
                              style: GoogleFonts.sora(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton(
                            onPressed: _submitGoogleSignIn,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white24),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.g_mobiledata, color: Colors.white, size: 32),
                                const SizedBox(width: 8),
                                Text(
                                  'Sign in with Google',
                                  style: GoogleFonts.sora(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 0),
                        Center(
                          child: TextButton(
                            onPressed: _submitGuestLogin,
                            child: Text(
                              'CONTINUE AS GUEST',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                color: AppColors.primaryEmerald,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 0),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SignUpScreen()),
                            );
                          },
                          child: RichText(
                            text: TextSpan(
                              text: "DON'T HAVE AN ACCOUNT? ",
                              style: GoogleFonts.sora(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                              children: [
                                TextSpan(
                                  text: "SIGN UP",
                                  style: TextStyle(
                                    color: AppColors.primaryEmerald,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
