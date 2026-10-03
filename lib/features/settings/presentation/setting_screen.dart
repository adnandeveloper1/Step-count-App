import 'package:build_up/features/settings/presentation/tier_info_screen.dart';
import 'package:build_up/features/shop/presentation/screens/store_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/local_storage_service.dart';
import '../../step_tracking/presentation/providers/step_provider.dart';
import '../../../core/utils/export_service.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../step_tracking/presentation/widgets/glass_step_card.dart';
import 'scheduler_screen.dart';
import 'edit_profile_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final stepState = ref.watch(stepNotifierProvider);
    final exportService = ExportService();
    final authController = ref.watch(authControllerProvider);

    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.value;
    
    final displayName = profile?['name'] ?? profile?['displayName'] ?? 'Build Up User';
    final avatar = profile?['avatarUrl'] ?? '👦';


    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;
    final padding = screenWidth * 0.05;

    const String privacyPolicyUrl =
        'https://sites.google.com/view/buildup-app-buildup-app-/home';

    Future<void> _openPrivacyPolicy() async {
      final Uri url = Uri.parse(privacyPolicyUrl);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $privacyPolicyUrl');
      }
    }

    return SafeArea(
      child: Scaffold(
        body: Padding(
          padding: EdgeInsets.all(padding),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: screenHeight * 0.04),
                Center(
                  child: Column(
                    children: [
                      ProfileAvatarWithTier(
                        avatarEmoji: avatar, 
                        tier: stepState.currentLeague, 
                        tierName: '${stepState.tierName}',
                      ),
                      
                      SizedBox(height: screenHeight * 0.001),
                      Text(
                        displayName,
                        style: GoogleFonts.sora(
                          fontSize: screenWidth * 0.055,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.00),
                    ],
                  ),
                ),
                SizedBox(height: screenHeight * 0.03),
                GlassCard(
                  padding: EdgeInsets.all(screenWidth * 0.02),
                  child: ListTile(
                    leading: Container(
                      padding: EdgeInsets.all(screenWidth * 0.025),
                      decoration: BoxDecoration(
                        color: AppColors.primaryEmerald.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.edit, color: AppColors.primaryEmerald, size: screenWidth * 0.06),
                    ),
                    title: Text(
                      'Edit Profile',
                      style: GoogleFonts.sora(
                        fontSize: screenWidth * 0.04,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Avatar, Name, Step Goal',
                      style: GoogleFonts.sora(
                        fontSize: screenWidth * 0.03,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary, size: screenWidth * 0.05),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EditProfileScreen(),
                        ),
                      );
                    },
                  ),
                ),
               // Safe, clean guidance banner
                SizedBox(height: screenHeight * 0.01),
                Text(
                  '  SETTINGS',
                  style: TextStyle(
                    fontSize: screenWidth * 0.035,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: screenHeight * 0.01),
                const BatteryOptimizationNotice(),
                GlassCard(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  child: Column(
                    children: [

                      ListTile(
                        leading: Icon(Icons.notifications, color: AppColors.primaryEmerald, size: screenWidth * 0.06),
                        title: Text('Stand Alerts', style: TextStyle(color: AppColors.textPrimary, fontSize: screenWidth * 0.04)),
                        trailing: Switch(
                          value: true,
                          onChanged: (bool value) {},
                          activeColor: AppColors.primaryEmerald,
                        ),
                      ),
                      const Divider(color: Colors.white24),
                      ListTile(
                        leading: Icon(Icons.storefront, color: AppColors.primaryEmerald, size: screenWidth * 0.06),
                        title: Text('Store', style: TextStyle(color: AppColors.textPrimary, fontSize: screenWidth * 0.04)),
                        trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary, size: screenWidth * 0.05),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const StoreScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(color: Colors.white24),
                      ListTile(
                        leading: Icon(Icons.timer, color: AppColors.primaryEmerald, size: screenWidth * 0.06),
                        title: Text('Daily Walk Scheduler', style: TextStyle(color: AppColors.textPrimary, fontSize: screenWidth * 0.04)),
                        trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary, size: screenWidth * 0.05),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const WalkSchedulerScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(color: Colors.white24),
                      ListTile(
                        leading: Icon(Icons.picture_as_pdf, color: AppColors.primaryEmerald, size: screenWidth * 0.06),
                        title: Text('Export PDF Report', style: TextStyle(color: AppColors.textPrimary, fontSize: screenWidth * 0.04)),
                        onTap: () {
                          exportService.exportToPdf(
                            stepState.currentSteps,
                            stepState.calories,
                            stepState.distanceKm,
                          );
                        },
                      ),
                      const Divider(color: Colors.white24),
                      ListTile(
                        leading: Icon(Icons.table_chart, color: AppColors.primaryEmerald, size: screenWidth * 0.06),
                        title: Text('Export CSV Data', style: TextStyle(color: AppColors.textPrimary, fontSize: screenWidth * 0.04)),
                        onTap: () {
                          exportService.exportToCsv(
                            stepState.currentSteps,
                            stepState.calories,
                            stepState.distanceKm,
                          );

                        },
                      ),
                      const Divider(color: Colors.white24),
                      ListTile(
                        leading: Icon(Icons.privacy_tip_rounded, color: AppColors.primaryEmerald, size: screenWidth * 0.06),
                        title: Text('Privacy & Policy', style: TextStyle(color: AppColors.textPrimary, fontSize: screenWidth * 0.04)),
                        onTap: () {
                          _openPrivacyPolicy();

                        },
                      ),

                    ],
                  ),
                ),
                SizedBox(height: screenHeight * 0.03),
                Text(
                  'ACCOUNT',
                  style: TextStyle(
                    fontSize: screenWidth * 0.035,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: screenHeight * 0.015),
                GlassCard(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  child: ListTile(
                    leading: Icon(Icons.logout, color: Colors.orangeAccent, size: screenWidth * 0.06),
                    title: Text('Sign Out', style: TextStyle(color: AppColors.textPrimary, fontSize: screenWidth * 0.04)),
                    onTap: () async {
                      await authController.signOut();
                    },
                  ),
                ),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Text(
                          'Build Up Version ${snapshot.data!.version}',
                          style: GoogleFonts.sora(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  },
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileAvatarWithTier extends StatelessWidget {
  final String avatarEmoji;
  final LeagueTier tier;
  final String tierName;
  final bool showBadge;

  const ProfileAvatarWithTier({
    super.key,
    required this.avatarEmoji,
    required this.tier,
    required this.tierName,
    this.showBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final avatarSize = screenWidth * 0.25;

    Color tierColor = AppColors.primaryEmerald;
    IconData tierIcon = Icons.star;

    switch (tier) {
      case LeagueTier.diamond:
        tierColor = Colors.cyanAccent;
        tierIcon = Icons.diamond;
        break;
      case LeagueTier.gold:
        tierColor = Colors.amber;
        tierIcon = Icons.military_tech;
        break;
      case LeagueTier.silver:
        tierColor = const Color(0xFFC0C0C0);
        tierIcon = Icons.shield;
        break;
      case LeagueTier.bronze:
        tierColor = const Color(0xFFCD7F32);
        tierIcon = Icons.star;
        break;
    }

    return SizedBox(
      width: avatarSize * 1.3,
      height: showBadge ? avatarSize * 1.35 : avatarSize * 1.1,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: (){
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TierInfoScreen(),
                ),
              );
            },
            child: Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.textSecondary.withOpacity(0.1),
                border: Border.all(
                  color: tierColor,
                  width: screenWidth * 0.008,
                ),
                boxShadow: [
                  BoxShadow(
                    color: tierColor.withOpacity(0.35),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipOval(
                child: Center(
                  child: Text(
                    avatarEmoji,
                    style: TextStyle(fontSize: avatarSize * 0.6),
                  ),
                ),
              ),
            ),
          ),
          if (showBadge)
            Positioned(
              bottom: 4,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.035,
                  vertical: screenWidth * 0.015
                ),
                decoration: BoxDecoration(
                  color: tierColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tierIcon,
                      color: Colors.black,
                      size: screenWidth * 0.035,
                    ),
                    SizedBox(width: screenWidth * 0.01),
                    Text(
                      tierName.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: Colors.black,
                        fontSize: screenWidth * 0.025,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class BatteryOptimizationNotice extends StatefulWidget {
  const BatteryOptimizationNotice({super.key});

  @override
  State<BatteryOptimizationNotice> createState() => _BatteryOptimizationNoticeState();
}

class _BatteryOptimizationNoticeState extends State<BatteryOptimizationNotice> {
  bool _dismissed = true; // Hidden by default until memory state is loaded

  @override
  void initState() {
    super.initState();
    _checkDismissedState();
  }

  void _checkDismissedState() {
    final storage = LocalStorageService();
    storage.init().then((_) {
      if (mounted) {
        setState(() {
          _dismissed = storage.getBatteryPromptShown();
        });
      }
    });
  }

  void _dismissBanner() {
    final storage = LocalStorageService();
    storage.init().then((_) {
      storage.saveBatteryPromptShown(true);
      if (mounted) {
        setState(() {
          _dismissed = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(
        top: screenHeight * 0.01,      // Space before banner when visible
        bottom: screenHeight * 0.018,  // Space after banner when visible
      ),
      child: Stack(
        children: [

          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              left: screenWidth * 00,
              top: screenWidth * 0.04,
              bottom: screenWidth * 0.04,
              right: screenWidth * 0.1, // Added extra right padding to prevent text overlay with the cross
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primaryEmerald.withOpacity(0.3)),
            ),
            child: Row(
              //crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: .center,
              children: [
                Icon(
                  Icons.battery_alert_rounded,
                  color: AppColors.primaryEmerald,
                  size: screenWidth * 0.25,
                ),
                SizedBox(width: screenWidth * 0.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Keep Tracking in Your Pocket',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: screenWidth * 0.04,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: screenWidth * 0.01),
                      Text(
                        'To ensure background step counts update smoothly when your phone is asleep, go to App Info > Battery settings and change it to "Unrestricted".',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: screenWidth * 0.035,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Small close button absolute positioned in the top right corner
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              icon: const Icon(
                Icons.close,
                color: AppColors.textSecondary,
                size: 18,
              ),
              splashRadius: 20,
              onPressed: _dismissBanner,
            ),
          ),
        ],
      ),
    );
  }
}