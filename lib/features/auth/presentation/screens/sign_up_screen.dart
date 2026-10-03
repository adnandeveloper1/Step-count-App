import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../step_tracking/presentation/widgets/glass_step_card.dart';
import '../providers/auth_provider.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _agreeToTerms = false;

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
            fontWeight: FontWeight.w900,
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

  Future<void> _submitSignUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showCustomSnackBar('Please fill in all fields', isError: true);
      return;
    }

    if (!_agreeToTerms) {
      _showCustomSnackBar('You must agree to the terms', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(authControllerProvider).signUp(email, password, name);
      _showCustomSnackBar('Account created successfully');
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'Email already in use';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address';
          break;
        case 'weak-password':
          errorMessage = 'Password is too weak';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Operation not allowed';
          break;
        default:
          errorMessage = e.message ?? 'Registration failed';
      }
      _showCustomSnackBar(errorMessage, isError: true);
    } catch (e) {
      _showCustomSnackBar('An unexpected error occurred', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildDarkTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.black.withOpacity(0.4),
        prefixIcon: Icon(icon, color: Colors.white38),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.primaryEmerald),
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 8),
                    Text(
                      'BUILD UP',
                      style: GoogleFonts.sora(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryEmerald,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'Initiate Protocol',
                              style: GoogleFonts.sora(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Enter your credentials to begin.',
                              style: GoogleFonts.sora(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildLabel('Full Name'),
                      _buildDarkTextField(
                        controller: _nameController,
                        hintText: 'Jane Doe',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 16),
                      _buildLabel('Email Address'),
                      _buildDarkTextField(
                        controller: _emailController,
                        hintText: 'jane@example.com',
                        icon: Icons.mail_outline,
                      ),
                      const SizedBox(height: 16),
                      _buildLabel('Password'),
                      _buildDarkTextField(
                        controller: _passwordController,
                        hintText: '••••••••',
                        icon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.white38,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Theme(
                            data: Theme.of(context).copyWith(
                              unselectedWidgetColor: Colors.white38,
                            ),
                            child: Checkbox(
                              value: _agreeToTerms,
                              activeColor: AppColors.primaryEmerald,
                              checkColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _agreeToTerms = value ?? false;
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.sora(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                                children: [
                                  const TextSpan(text: 'I agree to the '),
                                  TextSpan(
                                    text: 'terms',
                                    style: GoogleFonts.sora(
                                      color: AppColors.primaryEmerald,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const TextSpan(text: ' and\n'),
                                  TextSpan(
                                    text: 'conditions.',
                                    style: GoogleFonts.sora(
                                      color: AppColors.primaryEmerald,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      if (_isLoading)
                        const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primaryEmerald))
                      else
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _submitSignUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryEmerald,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'CREATE ACCOUNT',
                                  style: GoogleFonts.sora(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward, size: 18),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 32),
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.sora(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              children: [
                                const TextSpan(
                                    text: 'Already have an account? '),
                                TextSpan(
                                  text: 'Login',
                                  style: GoogleFonts.sora(
                                    color: AppColors.primaryEmerald,
                                    fontWeight: FontWeight.w700,
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
