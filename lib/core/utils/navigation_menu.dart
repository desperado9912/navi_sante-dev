import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:navi_sante/features/home/screens/home_screen.dart';
import 'package:navi_sante/features/hospitals/screens/facilities.dart';
import 'package:navi_sante/features/pharmacy/screens/pharmacy.dart';
import 'package:navi_sante/features/profile/screens/profile_screen.dart';
import 'package:navi_sante/core/utils/network_banner/connectivity_banner.dart';
import 'package:navi_sante/core/utils/platform_adaptive_app_bar.dart';
import 'package:navi_sante/core/performance/fade_indexed_stack.dart';
import 'package:navi_sante/core/utils/language_cubit/language_cubit.dart';
import 'package:navi_sante/features/Scontribute/screen/contribute.dart';

// Apps core naviagtion widget (Navigation menu)
// Main entry point from auth holds all other main screens, using index stack.
/// For smooth transitions, replaced by [FadeIndexedStack].

class NavigationMenu extends StatefulWidget {
  const NavigationMenu({super.key});

  @override
  State<NavigationMenu> createState() => _NavigationMenuState();
}

class _NavigationMenuState extends State<NavigationMenu> {
  late final NavigationController controller;

  static const _inactiveColor = Color(0xFF5F6368);
  static const _activeColor = Color(0xFF2A7D8F);

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<NavigationController>()
        ? Get.find<NavigationController>()
        : Get.put(NavigationController());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LanguageCubit, LanguageState>(
      builder: (context, langState) {
        return Obx(
          () => Stack(
            children: [
              Scaffold(
                extendBody: true,
                resizeToAvoidBottomInset: false,

                //all screens bg color
                backgroundColor: const Color(0xFFF8F9F8),
                appBar: controller.selectedIndex.value == 0
                    ? null
                    : PlatformAdaptiveAppBar(
                        title: context.tr(
                          controller.titles[controller.selectedIndex.value],
                        ),
                      ),

            // Bottom  navbar container
            bottomNavigationBar: SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.300),
                      blurRadius: 38,
                      spreadRadius: 0,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),

                // Navbar design
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28.0),
                  child: NavigationBarTheme(
                    data: NavigationBarThemeData(
                      height: 60,
                      elevation: 0,
                      backgroundColor: Colors.white,
                      indicatorColor: const Color(0xFFD8F6FF),
                      indicatorShape: const StadiumBorder(),
                      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((
                        states,
                      ) {
                        final isSelected = states.contains(WidgetState.selected);
                        return TextStyle(
                          color: isSelected ? _activeColor : _inactiveColor,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          fontSize: 9,
                        );
                      }),
                      iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((
                        states,
                      ) {
                        final isSelected = states.contains(WidgetState.selected);
                        return IconThemeData(
                          color: isSelected ? _activeColor : _inactiveColor,
                          size: 24,
                        );
                      }),
                    ),

                    child: NavigationBar(
                      selectedIndex: controller.selectedIndex.value,
                      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                      onDestinationSelected: (index) =>
                          controller.selectedIndex.value = index,
                      destinations: [
                        NavigationDestination(
                          icon: const Icon(CupertinoIcons.map),
                          selectedIcon: const Icon(CupertinoIcons.map_fill),
                          label: context.tr('Discover'),
                        ),
                        NavigationDestination(
                          icon: const Icon(CupertinoIcons.waveform_path_ecg),
                          selectedIcon: const Icon(CupertinoIcons.waveform_path_ecg),
                          label: context.tr('Hospitals'),
                        ),
                        NavigationDestination(
                          icon: const Icon(CupertinoIcons.capsule),
                          selectedIcon: const Icon(CupertinoIcons.capsule_fill),
                          label: context.tr('Medications'),
                        ),
                        NavigationDestination(
                          icon: const Icon(CupertinoIcons.add_circled),
                          selectedIcon: const Icon(CupertinoIcons.add_circled_solid),
                          label: context.t('Contribute', 'Contribuer'),
                          ),
                        NavigationDestination(
                          icon: const Icon(CupertinoIcons.person),
                          selectedIcon: const Icon(CupertinoIcons.person_fill),
                          label: context.tr('Profile'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Body elements scroll behind navbar
            body: SafeArea(
              top: controller.selectedIndex.value != 0,
              bottom: false,
              child: FadeIndexedStack(
                index: controller.selectedIndex.value,
                children: controller.screens,
              ),
            ),
          ),
          const ConnectivityBanner(),
        ],
      ),
    );
  },
);
  }
}

// NAVIGATION CONTROLLER
class NavigationController extends GetxController {
  final RxInt selectedIndex = 0.obs;

  /// Index for screens
  final List<Widget> screens = [
    const RepaintBoundary(child: ScreenWrapper(child: HomeScreen())),
    const RepaintBoundary(child: ScreenWrapper(child: Hospitals())),
    const RepaintBoundary(child: ScreenWrapper(child: PharmacyScreen())),
    const RepaintBoundary(child: ScreenWrapper(child: ContributeScreen())),
    const RepaintBoundary(child: ScreenWrapper(child: ProfileScreen())),
  ];

  List<String> get titles => [
    'Discover',
    'Find Sanctuary',
    'Medications',
    'Contribute',
    'Profile',
  ];
}

// Adding a bottom padding so screen content dont get stuck behind navbar.
const double navBottomPadding = 130.0;

class ScreenWrapper extends StatelessWidget {
  final Widget child;
  const ScreenWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
