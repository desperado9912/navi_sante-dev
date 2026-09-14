import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:navi_sante/core/utils/language_cubit/app_translations.dart';
import 'package:navi_sante/features/auth/services/auth_gate.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onCompleted;

  const OnboardingScreen({super.key, this.onCompleted});

  static const String _onboardingBox = 'onboarding';
  static const String _completedKey = 'completed';

  static Future<void> init() async {
    await Hive.openBox<bool>(_onboardingBox);
  }

  static bool isOnboardingCompleted() {
    final box = Hive.box<bool>(_onboardingBox);
    return box.get(_completedKey) ?? false;
  }

  static Future<void> setOnboardingCompleted() async {
    final box = Hive.box<bool>(_onboardingBox);
    await box.put(_completedKey, true);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9F8),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.07, 
            vertical: screenHeight * 0.03
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Section: MAIN IMAGE
              Expanded(
                flex: 8,
                child: Image.asset(
                  'assets/onboarding.png',
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(height: 4),

              // Midlle Section: MAIN TEXT
              Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03),
                    child: Text(
                      context.tr('Managing your health has never been easier.'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Text(
                context.tr(
                  'With fast search assisted by a robust AI, quickly find medical facilities according to your medical needs.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF5F6368),
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 36),

              //Lower Section: 3 APP FEATURES CARD
              Container(
                // (screenWidth * 0.04) or EdgeInsets.all(16.0)
                padding: EdgeInsets.all(screenWidth * 0.04),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Option 1
                    Expanded(
                      child: _buildFeatureItem(
                        icon: Icons.location_on,
                        title: context.tr('Health map'),
                        desc: context.tr('Find hospitals, clinics and pharmacies nearby.'),
                      ),
                    ),
                    // Divider line between 1 and 2
                    Container(
                      width: 1,
                      height: screenHeight * 0.15,
                      color: const Color(0xFFF1F5F9),
                    ),
                    // Option 2
                    Expanded(
                      child: _buildFeatureItem(
                        icon: CupertinoIcons.chat_bubble_text,
                        title: context.tr('AI Chat'),
                        desc: context.tr('Ask health questions and get reliable answers.'),
                      ),
                    ),
                    // Divider line between 2 and 3
                    Container(
                      width: 1,
                      height: screenHeight * 0.15,
                      color: const Color(0xFFF1F5F9),
                    ),
                    // Option 3
                    Expanded(
                      child: _buildFeatureItem(
                        icon: CupertinoIcons.capsule,
                        title: context.tr('Medication'),
                        desc: context.tr('Search for a medications and compare prices.'),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              //Bottom section: CTA GET STARTED BUTTON
              Center(
                child: SizedBox(
                  width: screenWidth * 0.85,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      await OnboardingScreen.setOnboardingCompleted();
                      widget.onCompleted?.call();
                    },
                    style: ButtonStyle(
                      elevation: WidgetStateProperty.all(3),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                        if (states.contains(WidgetState.pressed)) {
                          return const Color(0xFF2B8796); // lighter color variation
                        }
                        return const Color(0xFF2A7D8F);
                      }),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          context.tr('Get Started'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          CupertinoIcons.chevron_forward,
                          color: Colors.white,
                          size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget to keep code clean and reusable
  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(
              0xFFE0F2F1,
            ), // Soft light teal circular background
            child: Icon(icon, color: const Color(0xFF2A7D8F), size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color:  Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF5F6368),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class StartupWrapper extends StatefulWidget {
  const StartupWrapper({super.key});

  @override
  State<StartupWrapper> createState() => _StartupWrapperState();
}

class _StartupWrapperState extends State<StartupWrapper> {
  @override
  void initState() {
    super.initState();
    // Only remove splash if going to onboarding (AuthGate handles its own splash removal)
    if (!OnboardingScreen.isOnboardingCompleted()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FlutterNativeSplash.remove();
      });
    }
  }

  void _onOnboardingCompleted() {
    setState(() {
      // Trigger rebuild to check the flag again
    });
  }

  @override
  Widget build(BuildContext context) {
    if (OnboardingScreen.isOnboardingCompleted()) {
      return const AuthGate();
    } else {
      return OnboardingScreen(onCompleted: _onOnboardingCompleted);
    }
  }
}
