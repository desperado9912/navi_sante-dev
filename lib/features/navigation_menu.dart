import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/cupertino.dart';
import 'package:navi_sante/features/home/home_screen.dart';
import 'package:navi_sante/features/hospitals/hospitals.dart';
import 'package:navi_sante/features/pharmacy/pharmacy.dart';
import 'package:navi_sante/features/profile_settings/profile.dart';
import 'package:navi_sante/features/shared/widgets/platform_adaptive_app_bar.dart';


class NavigationMenu extends StatelessWidget {
  const NavigationMenu({super.key});

  static const _inactiveColor = Color(0xFF5F6368);
  static const _activeColor = Color(0xFF2A7D8F);
  static const _barRadius = 26.0;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NavigationController());
    const floatingBottom = 22.0;

    return Obx(
      () => Scaffold(
        extendBody: true,
        //all screens bg color
        backgroundColor: const Color.fromARGB(255, 37, 168, 37),
        appBar: PlatformAdaptiveAppBar(
          title: controller.titles[controller.selectedIndex.value],
        ),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, floatingBottom),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_barRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  spreadRadius: 0,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_barRadius),
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  height: 58,
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
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 11,
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

class NavigationController extends GetxController {
  final RxInt selectedIndex = 0.obs;

  final List<Widget> screens = [
    const HomeScreen(),
    const Hospitals(),
    const Pharmacy(),
    const Profile(),
  ];

  List<String> get titles => [
    'Home',
    'Find Sanctuary',
    'Pharmacy',
    'Profile',
  ];
}