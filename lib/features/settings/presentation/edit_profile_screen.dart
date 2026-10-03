import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../app/theme/app_colors.dart';

import '../../step_tracking/presentation/providers/step_provider.dart';
import '../../step_tracking/presentation/widgets/glass_step_card.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late TextEditingController nameController;
  late TextEditingController goalController;
  late TextEditingController weightController;
  late TextEditingController heightController;
  late TextEditingController bodyFatController;

  String selectedAvatar = '🤖';
  bool _isSaving = false;

  final List<String> avatars = [
    '🤖', '👦', '👧', '👨', '👩', '🧔', '👱‍♀️', '👾', '🦊', '🦁', '🐯', '🐼', '🐨', '🦖', '🏀', '⚽', '🎮', '🎧', '🚀', '🌈'
  ];

  @override
  void initState() {
    super.initState();
    final stepState = ref.read(stepNotifierProvider);
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? 'Build Up User';

    nameController = TextEditingController(text: displayName);
    goalController = TextEditingController(text: stepState.goalSteps.toString());
    weightController = TextEditingController();
    heightController = TextEditingController();
    bodyFatController = TextEditingController();

    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();
          if (data?['avatarUrl'] != null) {
            final savedAvatar = data?['avatarUrl'];
            if (avatars.contains(savedAvatar)) {
              setState(() {
                selectedAvatar = savedAvatar;
              });
            }
          }
          if (data?['weight'] != null) {
            weightController.text = data!['weight'].toString();
          }
          if (data?['height'] != null) {
            heightController.text = data!['height'].toString();
          }
          if (data?['bodyFat'] != null) {
            bodyFatController.text = data!['bodyFat'].toString();
          }
        }
      } catch (e) {
        debugPrint('Error loading profile: $e');
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    goalController.dispose();
    weightController.dispose();
    heightController.dispose();
    bodyFatController.dispose();
    super.dispose();
  }

  void saveProfile() async {
    if (_isSaving) return;

    final newName = nameController.text.trim();
    final newGoal = int.tryParse(goalController.text) ?? 10000;
    final weight = double.tryParse(weightController.text) ?? 70.0;
    final height = double.tryParse(heightController.text) ?? 170.0;
    final bodyFat = double.tryParse(bodyFatController.text);

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && newName.isNotEmpty) {
        await user.updateDisplayName(newName);

        double? bmi;
        if (weight > 0 && height > 0) {
          final heightInMeters = height / 100;
          bmi = weight / (heightInMeters * heightInMeters);
        }

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': newName,
          'avatarUrl': selectedAvatar,
          'weight': weight,
          'height': height,
          'bodyFat': bodyFat,
          'bmi': bmi,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

      }

      ref.read(stepNotifierProvider.notifier).updateProfile(height, weight);
      ref.read(stepNotifierProvider.notifier).updateGoal(newGoal);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'PROFILE UPDATED',
              textAlign: TextAlign.center,
              style: GoogleFonts.sora(
                color: AppColors.backgroundDark,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 1.2,
              ),
            ),
            backgroundColor: AppColors.primaryEmerald,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 8,
            duration: const Duration(seconds: 2),
          ),
        );

        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 24.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String hint, IconData icon, {bool isNumber = false}) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        style: GoogleFonts.sora(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textSecondary),
          icon: Icon(icon, color: AppColors.primaryEmerald),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'EDIT PROFILE',
          style: GoogleFonts.sora(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: .1,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Text(
              'SELECT AVATAR',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: avatars.length,
                itemBuilder: (context, index) {
                  final avatar = avatars[index];
                  final isSelected = selectedAvatar == avatar;
                  return GestureDetector(
                    onTap: () => setState(() => selectedAvatar = avatar),
                    child: Container(
                      margin: const EdgeInsets.only(right: 16),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryEmerald
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 35,
                        backgroundColor: const Color(0xFF1E293B),
                        child: Text(
                          avatar,
                          style: const TextStyle(fontSize: 35),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            _buildLabel('DISPLAY NAME'),
            _buildInputField(nameController, 'Enter your name', Icons.badge),

            _buildLabel('DAILY STEP GOAL'),
            _buildInputField(goalController, 'e.g. 10000', Icons.directions_walk, isNumber: true),

            _buildLabel('WEIGHT (KG)'),
            _buildInputField(weightController, 'e.g. 70.5', Icons.monitor_weight, isNumber: true),

            _buildLabel('HEIGHT (CM)'),
            _buildInputField(heightController, 'e.g. 175', Icons.height, isNumber: true),

            _buildLabel('BODY FAT (%)'),
            _buildInputField(bodyFatController, 'e.g. 15', Icons.percent, isNumber: true),

            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryEmerald,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                onPressed: _isSaving ? null : saveProfile,
                child: _isSaving
                    ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: AppColors.backgroundDark,
                    strokeWidth: 2,
                  ),
                )
                    : Text(
                  'SAVE CHANGES',
                  style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.backgroundDark,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}