import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/cupertino.dart';
import 'package:navi_sante/features/home/home_screen.dart';
import 'package:navi_sante/features/hospitals/hospitals.dart';
import 'package:navi_sante/features/pharmacy/pharmacy.dart';
import 'package:navi_sante/features/profile/screens/profile.dart';
import 'package:navi_sante/features/shared/widgets/platform_adaptive_app_bar.dart';

class NavigationMenu extends StatelessWidget {
  const NavigationMenu({super.key});

  static const _inactiveColor = Color(0xFF5F6368);
  static const _activeColor = Color(0xFF2A7D8F);
  static const _barRadius = 26.0;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NavigationController());
    return Obx(
      () => Scaffold(
        extendBody: true,
        //all screens bg color
        backgroundColor: const Color(0xFFF8F9F8),
        appBar: PlatformAdaptiveAppBar(
          title: controller.titles[controller.selectedIndex.value],
        ),

        // Bottom  navbar container
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_barRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 25,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            // Navbar design
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_barRadius),
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  height: 68,
                  elevation: 0,
                  backgroundColor: Colors.white,
                  indicatorColor: const Color(0x332A7D8F),
                  indicatorShape: const StadiumBorder(),
                  labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((
                    states,
                  ) {
                    final isSelected = states.contains(WidgetState.selected);
                    return TextStyle(
                      color: isSelected ? _activeColor : _inactiveColor,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      fontSize: 10,
                    );
                  }),
                  iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((
                    states,
                  ) {
                    final isSelected = states.contains(WidgetState.selected);
                    return IconThemeData(
                      color: isSelected ? _activeColor : _inactiveColor,
                      size: 26,
                    );
                  }),
                ),
                child: NavigationBar(
                  selectedIndex: controller.selectedIndex.value,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  onDestinationSelected: (index) =>
                      controller.selectedIndex.value = index,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(CupertinoIcons.house),
                      selectedIcon: Icon(CupertinoIcons.house_fill),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(CupertinoIcons.plus_app),
                      selectedIcon: Icon(CupertinoIcons.plus_app_fill),
                      label: 'Hospitals',
                    ),
                    NavigationDestination(
                      icon: Icon(CupertinoIcons.capsule),
                      selectedIcon: Icon(CupertinoIcons.capsule_fill),
                      label: 'Pharmacy',
                    ),
                    NavigationDestination(
                      icon: Icon(CupertinoIcons.person),
                      selectedIcon: Icon(CupertinoIcons.person_fill),
                      label: 'Profile',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Body elements scroll behind navbar
        body: SafeArea(
          top: true,
          bottom: false,
          child: IndexedStack(
            index: controller.selectedIndex.value,
            children: controller.screens,
          ),
        ),
      ),
    );
  }
}

// Index for screens
class NavigationController extends GetxController {
  final RxInt selectedIndex = 0.obs;

  final List<Widget> screens = [
    const ScreenWrapper(child: HomeScreen()),
    const ScreenWrapper(child: Hospitals()),
    const ScreenWrapper(child: Pharmacy()),
    const ScreenWrapper(child: Profile()),
  ];

  List<String> get titles => ['Home', 'Find Sanctuary', 'Pharmacy', 'Profile'];
}

// Fix screen bottom clipping
// Adding a padding so screen items dont get stuck behind navbar
class ScreenWrapper extends StatelessWidget {
  final Widget child;
  const ScreenWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // navbar height + a padding/safe area buffer
    return Padding(
      padding: const EdgeInsets.only(bottom: 100.0, left: 24.0, right: 24.0),
      child: child,
    );
  }
}
