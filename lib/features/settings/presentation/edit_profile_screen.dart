import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../app/theme/theme_extensions.dart';
import '../../step_tracking/presentation/providers/step_provider.dart';
import '../../step_tracking/presentation/widgets/glass_step_card.dart';
import '../../../core/widgets/pro_avatar.dart';
import '../../shop/models/pro_avatar_item.dart';

/// Reads and saves the signed-in account's profile.
///
/// [save] isn't waited for: offline, Firestore keeps the write and only
/// completes it once back online. A failed write is logged. Does nothing when
/// nobody is signed in. Replaced in tests.
class ProfileCloud {
  User? get _user => FirebaseAuth.instance.currentUser;

  DocumentReference<Map<String, dynamic>>? get _doc {
    final user = _user;
    if (user == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(user.uid);
  }

  String? get displayName => _user?.displayName;

  /// The account's profile, or null when signed out or it doesn't exist.
  /// Throws when it can't be read (offline with nothing cached).
  Future<Map<String, dynamic>?> load() async {
    final doc = _doc;
    if (doc == null) return null;
    return (await doc.get()).data();
  }

  void save(Map<String, dynamic> data) => _merge(data);

  Future<void> _merge(Map<String, dynamic> data) async {
    final doc = _doc;
    if (doc == null) return;
    try {
      await doc.set({
        ...data,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Profile sync failed: $e');
    }
  }

  /// Needs the network; throws when offline.
  Future<void> updateDisplayName(String name) async =>
      _user?.updateDisplayName(name);
}

final profileCloudProvider = Provider<ProfileCloud>((ref) => ProfileCloud());

// Accepted ranges. A blank field keeps the value already saved.
const _goalError = 'Enter 500 to 100,000 steps';
const _weightError = 'Enter 20 to 300 kg';
const _heightError = 'Enter 50 to 250 cm';
const _bodyFatError = 'Enter 2 to 70 %';

// Sign-in gets this long to change the name before Save gives up.
const _nameTimeout = Duration(seconds: 15);

String? _checkRange(
  String? text, {
  required num min,
  required num max,
  required String error,
  bool wholeNumber = false,
}) {
  final value = text?.trim() ?? '';
  if (value.isEmpty) return null;
  final number = wholeNumber ? int.tryParse(value) : double.tryParse(value);
  if (number == null || number < min || number > max) return error;
  return null;
}

// 181.0 shows as "181", 82.5 as "82.5".
String _formatNumber(num value) =>
    value == value.roundToDouble() ? value.toInt().toString() : '$value';

double? _parseDouble(String text) => double.tryParse(text.trim());

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nameController;
  late TextEditingController goalController;
  late TextEditingController weightController;
  late TextEditingController heightController;
  late TextEditingController bodyFatController;

  // What each field showed when the screen opened, so the account's values
  // only replace fields the user hasn't changed yet.
  late final String _initialName;
  late final Map<TextEditingController, String> _prefilled;

  String selectedAvatar = '🤖';
  bool _avatarPicked = false;
  bool _isSaving = false;
  bool isProAvatarUnlocked = false;

  final List<String> avatars = [
    '🤖',
    '👦',
    '👧',
    '👨',
    '👩',
    '🧔',
    '👱‍♀️',
    '👾',
    '🦊',
    '🦁',
    '🐯',
    '🐼',
    '🐨',
    '🦖',
    '🏀',
    '⚽',
    '🎮',
    '🎧',
    '🚀',
    '🌈',
  ];

  @override
  void initState() {
    super.initState();
    // Values saved on the phone, so the form is filled even offline.
    final stepState = ref.read(stepNotifierProvider);
    _initialName =
        ref.read(profileCloudProvider).displayName ?? 'Build Up User';

    nameController = TextEditingController(text: _initialName);
    goalController = TextEditingController(
      text: stepState.goalSteps.toString(),
    );
    weightController = TextEditingController(
      text: _formatNumber(stepState.weight),
    );
    heightController = TextEditingController(
      text: _formatNumber(stepState.height),
    );
    bodyFatController = TextEditingController();
    _prefilled = {
      goalController: goalController.text,
      weightController: weightController.text,
      heightController: heightController.text,
      bodyFatController: '',
    };

    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final Map<String, dynamic>? data;
    try {
      data = await ref.read(profileCloudProvider).load();
    } catch (e) {
      debugPrint('Error loading profile: $e');
      return;
    }
    if (!mounted || data == null) return;

    setState(() {
      // Shown even when the picker doesn't offer it (new accounts start
      // with 🙂, 🌟 or 👤).
      final savedAvatar = data!['avatarUrl'];
      if (!_avatarPicked && savedAvatar is String && savedAvatar.isNotEmpty) {
        selectedAvatar = savedAvatar;
      }
      _fillIfUnchanged(weightController, data['weight']);
      _fillIfUnchanged(heightController, data['height']);
      _fillIfUnchanged(bodyFatController, data['bodyFat']);
      isProAvatarUnlocked = showsProAvatar(data);
    });
  }

  // Changed by the user or filled from the account since the screen opened.
  bool _changed(TextEditingController controller) =>
      controller.text.trim() != _prefilled[controller];

  void _fillIfUnchanged(TextEditingController controller, Object? value) {
    if (value is! num) return;
    if (controller.text != _prefilled[controller]) return;
    controller.text = _formatNumber(value);
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

  // Saves on the phone and queues the account write without waiting for
  // the server, so Save works offline. Only a name change waits, because
  // sign-in has no offline queue.
  Future<void> saveProfile() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final cloud = ref.read(profileCloudProvider);
    final notifier = ref.read(stepNotifierProvider.notifier);
    final stepState = ref.read(stepNotifierProvider);

    // Only what differs from what the screen opened with: the phone's
    // values can be the 70 kg / 170 cm defaults of an account that never
    // set them, and saving them would make them the account's.
    final newName = nameController.text.trim();
    final newGoal = _changed(goalController)
        ? int.tryParse(goalController.text.trim())
        : null;
    final weight = _changed(weightController)
        ? _parseDouble(weightController.text)
        : null;
    final height = _changed(heightController)
        ? _parseDouble(heightController.text)
        : null;
    final bodyFat = _changed(bodyFatController)
        ? _parseDouble(bodyFatController.text)
        : null;

    if (weight != null || height != null) {
      notifier.updateProfile(
        height ?? stepState.height,
        weight ?? stepState.weight,
      );
    }
    if (newGoal != null) notifier.updateGoal(newGoal);
    cloud.save({
      // Only a picked one: offline the account's avatar isn't loaded, and
      // selectedAvatar's default would replace it.
      if (_avatarPicked) 'avatarUrl': selectedAvatar,
      'weight': ?weight,
      'height': ?height,
      'bodyFat': ?bodyFat,
    });

    if (newName.isNotEmpty && newName != _initialName) {
      setState(() => _isSaving = true);
      var renamed = true;
      try {
        await cloud.updateDisplayName(newName).timeout(_nameTimeout);
        cloud.save({'name': newName});
      } catch (e) {
        debugPrint('Name change failed: $e');
        renamed = false;
      }
      if (!mounted) return;
      setState(() => _isSaving = false);
      if (!renamed) {
        context.showAppSnackBar(
          'Saved, but name not changed. Go online and try again',
          isError: true,
        );
        return;
      }
    }

    if (!mounted) return;
    context.showAppSnackBar('PROFILE UPDATED');
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 24.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: context.textSecondary,
        ),
      ),
    );
  }

  Widget _buildInputField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    required Key key,
    bool isNumber = false,
    FormFieldValidator<String>? validator,
  }) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextFormField(
        key: key,
        controller: controller,
        validator: validator,
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        style: GoogleFonts.sora(
          color: context.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(color: context.textSecondary),
          icon: Icon(icon, color: context.primaryColor),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text(
          'EDIT PROFILE',
          style: GoogleFonts.sora(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: context.textPrimary,
            letterSpacing: .1,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                'SELECT AVATAR',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 120, // Increased height to accommodate ProAvatar
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: avatars.length,
                  itemBuilder: (context, index) {
                    final avatar = avatars[index];
                    final isSelected = selectedAvatar == avatar;
                    return GestureDetector(
                      onTap: () => setState(() {
                        selectedAvatar = avatar;
                        _avatarPicked = true;
                      }),
                      child: Container(
                        margin: const EdgeInsets.only(right: 16),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? context.primaryColor
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: isProAvatarUnlocked
                            ? ProAvatar(
                                emojiAvatar: avatar,
                                radius: 35,
                                isPro: true,
                              )
                            : CircleAvatar(
                                radius: 35,
                                backgroundColor: context.cardColor,
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
              _buildInputField(
                nameController,
                'Enter your name',
                Icons.badge,
                key: const Key('profile.name'),
              ),
              _buildLabel('DAILY STEP GOAL'),
              _buildInputField(
                goalController,
                'e.g. 10000',
                Icons.directions_walk,
                key: const Key('profile.goal'),
                isNumber: true,
                validator: (text) => _checkRange(
                  text,
                  min: 500,
                  max: 100000,
                  error: _goalError,
                  wholeNumber: true,
                ),
              ),
              _buildLabel('WEIGHT (KG)'),
              _buildInputField(
                weightController,
                'e.g. 70.5',
                Icons.monitor_weight,
                key: const Key('profile.weight'),
                isNumber: true,
                validator: (text) =>
                    _checkRange(text, min: 20, max: 300, error: _weightError),
              ),
              _buildLabel('HEIGHT (CM)'),
              _buildInputField(
                heightController,
                'e.g. 175',
                Icons.height,
                key: const Key('profile.height'),
                isNumber: true,
                validator: (text) =>
                    _checkRange(text, min: 50, max: 250, error: _heightError),
              ),
              _buildLabel('BODY FAT (%)'),
              _buildInputField(
                bodyFatController,
                'e.g. 15',
                Icons.percent,
                key: const Key('profile.bodyFat'),
                isNumber: true,
                validator: (text) =>
                    _checkRange(text, min: 2, max: 70, error: _bodyFatError),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  key: const Key('profile.save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.primaryColor,
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
                            color: Colors.black,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'SAVE CHANGES',
                          style: GoogleFonts.sora(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            letterSpacing: 1.2,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
